import XCTest
@testable import Curator

/// ATDD Tests for Story 2.3 - Multi-Provider Support (Failover Enhancement)
///
/// Tests verify:
/// - Primary provider 5xx error triggers automatic failover to fallback provider
/// - Failover completes within 10 seconds (NFR21)
/// - 429 rate limit causes retry within same provider, then failover after retries exhausted
/// - 4xx client errors (non-429) do not retry, directly failover
/// - Gateway creates correct provider instances from multi-provider config
/// - AppDependencies registers both primary and fallback providers
/// - AppDependencies backward compat: only primary provider when no fallback configured
///
/// TDD RED PHASE: These tests will fail until the failover logic and
/// multi-provider registration are enhanced.
final class MultiProviderFailoverTests: XCTestCase {

    // MARK: - Mock Providers

    /// Mock LLM provider that can simulate different error types.
    private final class MockLLMProvider: LLMProvider, Sendable {
        let name: String
        private let _errorToThrow: Error?
        private let _errorCount: Int  // How many times to throw before succeeding
        private let _delay: TimeInterval
        let callCount: LockedInt

        init(
            name: String,
            errorToThrow: Error? = nil,
            errorCount: Int = 0,
            delay: TimeInterval = 0
        ) {
            self.name = name
            self._errorToThrow = errorToThrow
            self._errorCount = errorCount
            self._delay = delay
            self.callCount = LockedInt()
        }

        func analyze(images: [Data], prompt: String, model: String) async throws -> LLMResponse {
            let count = callCount.increment()
            if _delay > 0 {
                try await Task.sleep(for: .seconds(_delay))
            }
            if let error = _errorToThrow {
                if _errorCount == 0 || count <= _errorCount {
                    throw error
                }
            }
            return LLMResponse(
                text: "Response from \(name)",
                modelID: model,
                providerName: name,
                inputTokens: 100,
                outputTokens: 50
            )
        }

        func estimateCost(imageCount: Int, model: String) -> CostEstimate {
            CostEstimate(
                estimatedTokens: imageCount * 1000,
                estimatedCost: Double(imageCount) * 0.01,
                modelID: model,
                providerName: name
            )
        }
    }

    /// Thread-safe integer counter for tracking mock call counts.
    private final class LockedInt: @unchecked Sendable {
        private let lock = NSLock()
        private var _value = 0

        func increment() -> Int {
            lock.lock()
            defer { lock.unlock() }
            _value += 1
            return _value
        }

        var value: Int {
            lock.lock()
            defer { lock.unlock() }
            return _value
        }
    }

    // MARK: - AC1: Primary 5xx Failover

    /// [P0] Primary provider 5xx error triggers automatic failover to fallback
    func testPrimary5xxTriggersFailoverToFallback() async throws {
        // Given: Primary provider throws 5xx, fallback provider succeeds
        let primaryError = InfrastructureError.llmProviderError(
            provider: "Anthropic",
            statusCode: 500,
            message: "Internal Server Error"
        )
        let failingPrimary = MockLLMProvider(name: "Anthropic", errorToThrow: primaryError)
        let workingFallback = MockLLMProvider(name: "DeepSeek")

        // Use maxRetries=1 to speed up test (fail fast on 5xx)
        let gateway = LLMGateway(
            providers: [failingPrimary, workingFallback],
            maxRetries: 1,
            baseRetryDelay: 0.01
        )

        // When: Calling analyze
        let response = try await gateway.analyze(
            images: [Data("fake".utf8)],
            prompt: "test",
            model: "test-model"
        )

        // Then: Response comes from fallback provider
        XCTAssertEqual(response.providerName, "DeepSeek",
            "Should failover to fallback when primary returns 5xx")
        XCTAssertEqual(response.text, "Response from DeepSeek")
    }

    /// [P0] Failover completes within NFR21 time constraint (10 seconds)
    func testFailoverCompletesWithin10Seconds() async throws {
        // Given: Primary provider fails fast (no delay), fallback succeeds
        let primaryError = InfrastructureError.llmProviderError(
            provider: "Anthropic",
            statusCode: 503,
            message: "Service Unavailable"
        )
        let failingPrimary = MockLLMProvider(name: "Anthropic", errorToThrow: primaryError)
        let workingFallback = MockLLMProvider(name: "Fallback")

        let gateway = LLMGateway(
            providers: [failingPrimary, workingFallback],
            maxRetries: 1,
            baseRetryDelay: 0.01
        )

        let startTime = Date()

        let response = try await gateway.analyze(
            images: [Data("fake".utf8)],
            prompt: "test",
            model: "test-model"
        )

        let elapsed = Date().timeIntervalSince(startTime)

        XCTAssertLessThan(elapsed, 10.0,
            "Failover should complete within 10 seconds (NFR21)")
        XCTAssertEqual(response.providerName, "Fallback")
    }

    // MARK: - AC3: Rate Limit (429) Retry Then Failover

    /// [P0] 429 rate limit retries within same provider, then failovers
    func testRateLimit429RetriesThenFailover() async throws {
        // Given: Primary provider always returns 429, fallback succeeds
        let rateLimitError = InfrastructureError.rateLimitExceeded(
            provider: "Anthropic",
            retryAfter: 0.01
        )
        let rateLimitedPrimary = MockLLMProvider(name: "Anthropic", errorToThrow: rateLimitError)
        let workingFallback = MockLLMProvider(name: "DeepSeek")

        let gateway = LLMGateway(
            providers: [rateLimitedPrimary, workingFallback],
            maxRetries: 2,
            baseRetryDelay: 0.01
        )

        // When: Calling analyze — primary retries then failovers
        let response = try await gateway.analyze(
            images: [Data("fake".utf8)],
            prompt: "test",
            model: "test-model"
        )

        // Then: Should get response from fallback
        XCTAssertEqual(response.providerName, "DeepSeek",
            "Should failover to backup after 429 retries exhausted")

        // And: Primary should have been called maxRetries times
        XCTAssertEqual(rateLimitedPrimary.callCount.value, 2,
            "Primary should be retried maxRetries times before failover")
    }

    /// [P1] 429 with retry-after respects the retry delay
    func testRateLimit429RespectsRetryAfterDelay() async throws {
        // Given: Primary returns 429 on first call, succeeds on second, no fallback needed
        let rateLimitError = InfrastructureError.rateLimitExceeded(
            provider: "Anthropic",
            retryAfter: 0.01
        )
        let recoveringPrimary = MockLLMProvider(
            name: "Anthropic",
            errorToThrow: rateLimitError,
            errorCount: 1  // Fail once, then succeed
        )

        let gateway = LLMGateway(
            providers: [recoveringPrimary],
            maxRetries: 3,
            baseRetryDelay: 0.01
        )

        // When: Calling analyze
        let response = try await gateway.analyze(
            images: [Data("fake".utf8)],
            prompt: "test",
            model: "test-model"
        )

        // Then: Should succeed after retry within same provider
        XCTAssertEqual(response.providerName, "Anthropic",
            "Should succeed on retry within same provider after 429")
        XCTAssertEqual(recoveringPrimary.callCount.value, 2,
            "Should have been called twice (1 fail + 1 success)")
    }

    // MARK: - AC1: 4xx Client Errors (non-429) Direct Failover

    /// [P1] 4xx client errors (non-429) do not retry, directly failover
    func testClientError4xxDirectlyFailovers() async throws {
        // Given: Primary returns 401 (client error, not 429)
        let clientError = InfrastructureError.llmProviderError(
            provider: "Anthropic",
            statusCode: 401,
            message: "Invalid API key"
        )
        let failingPrimary = MockLLMProvider(name: "Anthropic", errorToThrow: clientError)
        let workingFallback = MockLLMProvider(name: "DeepSeek")

        let gateway = LLMGateway(
            providers: [failingPrimary, workingFallback],
            maxRetries: 3,
            baseRetryDelay: 0.01
        )

        // When: Calling analyze
        let response = try await gateway.analyze(
            images: [Data("fake".utf8)],
            prompt: "test",
            model: "test-model"
        )

        // Then: Should failover without retrying 4xx
        XCTAssertEqual(response.providerName, "DeepSeek",
            "Should failover immediately for 4xx client errors (no retry)")
        XCTAssertEqual(failingPrimary.callCount.value, 1,
            "Should NOT retry 4xx errors — call primary only once")
    }

    // MARK: - AC3: All Providers Rate Limited

    /// [P1] When all providers return 429, throws rateLimitExceeded
    func testAllProvidersRateLimitedThrowsError() async throws {
        // Given: Both providers return 429
        let rateLimitError = InfrastructureError.rateLimitExceeded(
            provider: "Provider",
            retryAfter: 0.01
        )
        let rateLimitedPrimary = MockLLMProvider(name: "Anthropic", errorToThrow: rateLimitError)
        let rateLimitedFallback = MockLLMProvider(name: "DeepSeek", errorToThrow: rateLimitError)

        let gateway = LLMGateway(
            providers: [rateLimitedPrimary, rateLimitedFallback],
            maxRetries: 1,
            baseRetryDelay: 0.01
        )

        // When/Then: Should throw rate limit error
        do {
            _ = try await gateway.analyze(
                images: [Data("fake".utf8)],
                prompt: "test",
                model: "test-model"
            )
            XCTFail("Should throw when all providers are rate limited")
        } catch let error as InfrastructureError {
            if case .rateLimitExceeded = error {
                // Expected
            } else {
                XCTFail("Expected rateLimitExceeded, got \(error)")
            }
        } catch {
            XCTFail("Expected InfrastructureError, got \(type(of: error))")
        }
    }

    // MARK: - AC1: AppDependencies Multi-Provider Registration

    /// [P1] AppDependencies registers both providers when fallback is configured
    func testAppDependenciesRegistersBothProviders() async throws {
        // Given: Multi-provider config with primary and fallback
        let primaryConfig = LLMProviderConfig(
            providerType: .anthropic,
            baseURL: "https://api.anthropic.com",
            apiKey: "sk-ant-key",
            modelID: "claude-sonnet-4-20250514",
            displayName: nil
        )
        let fallbackConfig = LLMProviderConfig(
            providerType: .openAICompatible,
            baseURL: "https://api.deepseek.com",
            apiKey: "ds-key",
            modelID: "deepseek-chat",
            displayName: "DeepSeek"
        )
        let config = LLMConfig(primary: primaryConfig, fallback: fallbackConfig)
        config.save()

        // When: Registering the gateway
        await MainActor.run {
            let dependencies = AppDependencies()
            dependencies.registerLLMGateway()

            // Then: Gateway should be registered
            XCTAssertNotNil(dependencies.llmGateway,
                "LLMGateway should be registered")
        }
    }

    /// [P1] AppDependencies registers only primary when no fallback configured
    func testAppDependenciesRegistersOnlyPrimaryWhenNoFallback() async throws {
        // Given: Multi-provider config with only primary (no fallback)
        let primaryConfig = LLMProviderConfig(
            providerType: .anthropic,
            baseURL: "https://api.anthropic.com",
            apiKey: "sk-ant-key",
            modelID: "claude-sonnet-4-20250514",
            displayName: nil
        )
        let config = LLMConfig(primary: primaryConfig, fallback: nil)
        config.save()

        // When: Registering the gateway
        await MainActor.run {
            let dependencies = AppDependencies()
            dependencies.registerLLMGateway()

            // Then: Gateway should be registered with single provider
            XCTAssertNotNil(dependencies.llmGateway,
                "LLMGateway should be registered even with only primary provider")
        }
    }

    // MARK: - AC2: LLMModelID OpenAI-Compatible Models

    /// [P1] LLMModelID supports OpenAI-compatible model identifiers
    func testLLMModelIDSupportsOpenAICompatibleModels() throws {
        // GPT-4o model should exist
        let gpt4o = LLMModelID(rawValue: "gpt-4o")
        XCTAssertNotNil(gpt4o, "LLMModelID should support gpt-4o")

        // GPT-4o Mini should exist
        let gpt4oMini = LLMModelID(rawValue: "gpt-4o-mini")
        XCTAssertNotNil(gpt4oMini, "LLMModelID should support gpt-4o-mini")

        // DeepSeek Chat should exist
        let deepseek = LLMModelID(rawValue: "deepseek-chat")
        XCTAssertNotNil(deepseek, "LLMModelID should support deepseek-chat")
    }

    /// [P1] LLMModelID OpenAI-compatible models have pricing information
    func testLLMModelIDOpenAICompatibleModelsHavePricing() throws {
        let gpt4o = LLMModelID(rawValue: "gpt-4o")!
        XCTAssertGreaterThan(gpt4o.inputPricePerMillionTokens, 0,
            "gpt-4o should have positive input pricing")
        XCTAssertGreaterThan(gpt4o.outputPricePerMillionTokens, 0,
            "gpt-4o should have positive output pricing")
    }
}
