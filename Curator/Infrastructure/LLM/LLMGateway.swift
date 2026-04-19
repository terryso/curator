import Foundation
import os.log

/// Actor-isolated unified gateway for LLM provider access.
///
/// Manages a prioritized list of providers, delegating calls to the primary
/// provider with automatic exponential backoff retry (max 3 attempts) and
/// failover to backup providers when the primary is unavailable.
///
/// Error-type-aware failover strategy:
/// - **429 rate limit**: Retries with retry-after delay, then failovers after retries exhausted.
/// - **5xx server error**: Retries with exponential backoff, then failovers.
/// - **4xx client error (non-429)**: No retry, immediate failover.
/// - **Network/timeout**: Retries with exponential backoff, then failovers.
///
/// All mutable state (current provider index, retry counts) is isolated
/// within this actor for thread-safe concurrent access.
actor LLMGateway: LLMGatewayProtocol {

    /// Logger for failover and retry events.
    private static let logger = Logger(subsystem: "com.curator.app", category: "LLMGateway")

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
        self.maxRetries = max(1, maxRetries)
        self.baseRetryDelay = baseRetryDelay
        self.retryMultiplier = retryMultiplier
    }

    // MARK: - LLMGatewayProtocol

    /// Analyzes images using the primary provider with retry and failover.
    ///
    /// Error-type-aware strategy:
    /// - 4xx client errors (non-429): failover immediately without retrying.
    /// - 429 rate limit: retry up to maxRetries within the same provider, then failover.
    /// - 5xx server errors: retry with exponential backoff, then failover.
    /// - Network/timeout errors: retry with exponential backoff, then failover.
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
                Self.logger.warning("Provider '\(provider.name)' failed: \(error.localizedDescription). Failover to next provider.")
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

    /// Executes analysis with error-type-aware retry for a single provider.
    ///
    /// - **4xx client errors (non-429)**: Immediate throw — no retry, triggers failover.
    /// - **429 rate limit**: Retries with retry-after delay from the error.
    /// - **5xx/network errors**: Retries with exponential backoff.
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
            } catch let error as InfrastructureError {
                lastError = error

                // 4xx client errors (non-429): do not retry — failover immediately.
                if case .llmProviderError(_, let statusCode, _) = error,
                   (400...499).contains(statusCode), statusCode != 429 {
                    throw error
                }

                // 429 rate limit: use retry-after delay from the error (capped at 60s).
                if case .rateLimitExceeded(_, let retryAfter) = error {
                    if attempt < maxRetries - 1 {
                        try await Task.sleep(for: .seconds(min(retryAfter, 60)))
                        continue
                    }
                    throw error
                }

                // All other errors (5xx, network): exponential backoff retry.
                if attempt < maxRetries - 1 {
                    let delay = baseRetryDelay * pow(retryMultiplier, Double(attempt))
                    try await Task.sleep(for: .seconds(delay))
                }
            } catch {
                lastError = error
                // Non-InfrastructureError: retry with exponential backoff.
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
