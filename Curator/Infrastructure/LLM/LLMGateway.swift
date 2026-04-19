import Foundation

/// Actor-isolated unified gateway for LLM provider access.
///
/// Manages a prioritized list of providers, delegating calls to the primary
/// provider with automatic exponential backoff retry (max 3 attempts) and
/// failover to backup providers when the primary is unavailable.
///
/// All mutable state (current provider index, retry counts) is isolated
/// within this actor for thread-safe concurrent access.
actor LLMGateway: LLMGatewayProtocol {

    /// The list of providers in priority order. Index 0 is primary.
    private let providers: [any LLMProvider]

    /// Maximum retry attempts per provider before failover.
    private let maxRetries: Int

    /// Base delay for exponential backoff in seconds.
    private let baseRetryDelay: TimeInterval

    /// Exponential backoff multiplier.
    private let retryMultiplier: Double

    /// Creates an LLMGateway with a prioritized list of providers.
    ///
    /// - Parameters:
    ///   - providers: Providers in priority order. The first is primary.
    ///   - maxRetries: Maximum retry attempts per provider (default: 3).
    ///   - baseRetryDelay: Base delay between retries in seconds (default: 1.0).
    ///   - retryMultiplier: Exponential factor for backoff (default: 2.0).
    init(
        providers: [any LLMProvider],
        maxRetries: Int = 3,
        baseRetryDelay: TimeInterval = 1.0,
        retryMultiplier: Double = 2.0
    ) {
        self.providers = providers
        self.maxRetries = maxRetries
        self.baseRetryDelay = baseRetryDelay
        self.retryMultiplier = retryMultiplier
    }

    // MARK: - LLMGatewayProtocol

    /// Analyzes images using the primary provider with retry and failover.
    ///
    /// Tries the primary provider up to `maxRetries` times with exponential
    /// backoff. If all retries are exhausted, falls back to the next provider
    /// in the list and repeats the retry cycle. Throws if every provider fails.
    func analyze(images: [Data], prompt: String, model: String) async throws -> LLMResponse {
        var lastError: Error?

        for provider in providers {
            do {
                return try await analyzeWithRetry(
                    provider: provider,
                    images: images,
                    prompt: prompt,
                    model: model
                )
            } catch {
                lastError = error
                // Move to next provider (failover)
            }
        }

        // All providers exhausted — throw the last error
        if let infraError = lastError as? InfrastructureError {
            throw infraError
        }
        throw InfrastructureError.llmProviderUnavailable(provider: "all")
    }

    /// Estimates cost using the primary (first) provider.
    func estimateCost(imageCount: Int, model: String) async -> CostEstimate {
        guard let primary = providers.first else {
            return CostEstimate(
                estimatedTokens: 0,
                estimatedCost: 0,
                modelID: model,
                providerName: "none"
            )
        }
        return primary.estimateCost(imageCount: imageCount, model: model)
    }

    // MARK: - Private Retry Logic

    /// Executes analysis with exponential backoff retry for a single provider.
    private func analyzeWithRetry(
        provider: any LLMProvider,
        images: [Data],
        prompt: String,
        model: String
    ) async throws -> LLMResponse {
        var lastError: Error?

        for attempt in 0..<maxRetries {
            do {
                return try await provider.analyze(images: images, prompt: prompt, model: model)
            } catch {
                lastError = error
                if attempt < maxRetries - 1 {
                    let delay = baseRetryDelay * pow(retryMultiplier, Double(attempt))
                    try await Task.sleep(for: .seconds(delay))
                }
            }
        }

        guard let error = lastError else {
            throw InfrastructureError.llmProviderUnavailable(provider: "unknown")
        }
        throw error
    }
}
