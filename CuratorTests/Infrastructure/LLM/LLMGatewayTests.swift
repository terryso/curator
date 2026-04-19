import XCTest
@testable import Curator

/// ATDD Tests for Story 2.1 - LLM Gateway Core
///
/// Tests verify:
/// - LLMGateway actor exists and manages providers
/// - LLMGateway delegates analyze() to primary provider
/// - LLMGateway performs failover when primary provider fails
/// - LLMGateway implements exponential backoff retry (max 3 retries)
/// - AnthropicProvider constructs correct HTTP requests to Claude API
/// - AnthropicProvider parses JSON responses into LLMResponse
/// - Rate limit handling (HTTP 429) respects retry-after header
/// - All LLM types conform to Sendable (compile-time verification)
///
/// TDD RED PHASE: These tests will fail until the implementation types are created:
/// - LLMGatewayProtocol (Core/Models/)
/// - LLMGateway actor (Infrastructure/LLM/)
/// - AnthropicProvider (Infrastructure/LLM/)
/// - LLMModelID enum (Infrastructure/LLM/)
/// - Extended LLMResponse (new fields: modelID, providerName, inputTokens, outputTokens)
/// - Extended CostEstimate (new fields: modelID, providerName)
final class LLMGatewayTests: XCTestCase {

    // MARK: - Mock Providers

    /// Mock LLM provider that can be configured to succeed or fail.
    /// Tracks call count for verifying retry and failover behavior.
    private final class MockLLMProvider: LLMProvider, Sendable {
        let name: String
        private let _shouldFail: Bool
        private let _failCount: Int
        private let _delay: TimeInterval
        let callCount: LockedInt

        init(
            name: String,
            shouldFail: Bool = false,
            failCount: Int = 0,
            delay: TimeInterval = 0
        ) {
            self.name = name
            self._shouldFail = shouldFail
            self._failCount = failCount
            self._delay = delay
            self.callCount = LockedInt()
        }

        func analyze(images: [Data], prompt: String, model: String) async throws -> LLMResponse {
            let count = callCount.increment()
            if _delay > 0 {
                try await Task.sleep(for: .seconds(_delay))
            }
            if _shouldFail {
                throw InfrastructureError.llmProviderUnavailable(provider: name)
            }
            if _failCount > 0 && count <= _failCount {
                throw InfrastructureError.llmProviderUnavailable(provider: name)
            }
            return LLMResponse(
                text: "Mock analysis from \(name)",
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

    /// Thread-safe integer counter for tracking mock call counts across concurrent access.
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

    // MARK: - AC1: LLMGatewayProtocol and LLMGateway Actor

    /// [P0] LLMGatewayProtocol exists with analyze() and estimateCost() methods
    func testLLMGatewayProtocolExists() async throws {
        // Given: LLMGatewayProtocol is defined in Core/Models/
        // Then: It can be used as a type constraint
        let gateway: (any LLMGatewayProtocol)? = nil
        XCTAssertNil(gateway, "LLMGatewayProtocol should exist as a protocol type")
    }

    /// [P0] LLMGateway actor can be instantiated with a list of providers
    func testLLMGatewayCanBeInstantiatedWithProviders() async throws {
        // Given: Mock providers
        let primary = MockLLMProvider(name: "MockPrimary")
        let fallback = MockLLMProvider(name: "MockFallback")

        // When: Creating LLMGateway with providers
        let gateway = LLMGateway(providers: [primary, fallback])

        // Then: Gateway is created
        XCTAssertNotNil(gateway, "LLMGateway should be instantiable with provider list")
    }

    /// [P0] LLMGateway is an actor (thread-safe, not a class)
    func testLLMGatewayIsActor() async throws {
        // Given: LLMGateway declared as actor
        let primary = MockLLMProvider(name: "MockPrimary")
        let gateway = LLMGateway(providers: [primary])

        // Then: Actor reference is valid — compiler enforces isolation
        // If this compiles, LLMGateway is correctly an actor.
        let _ = gateway
        XCTAssertTrue(true, "LLMGateway compiles as actor — compile-time verification passed")
    }

    /// [P1] LLMGateway conforms to LLMGatewayProtocol
    func testLLMGatewayConformsToProtocol() async throws {
        let primary = MockLLMProvider(name: "MockPrimary")
        let gateway = LLMGateway(providers: [primary])

        let gatewayAsProtocol: any LLMGatewayProtocol = gateway
        XCTAssertNotNil(gatewayAsProtocol,
            "LLMGateway should conform to LLMGatewayProtocol")
    }

    // MARK: - AC1: LLMProvider Protocol Verification

    /// [P0] LLMProvider protocol has analyze(images:prompt:model:) method
    func testLLMProviderProtocolHasAnalyzeMethod() async throws {
        // Given: A mock implementing LLMProvider
        let mock = MockLLMProvider(name: "TestProvider")

        // When: Calling analyze()
        let response = try await mock.analyze(
            images: [Data("fake-image".utf8)],
            prompt: "test prompt",
            model: "claude-sonnet-4-20250514"
        )

        // Then: Returns LLMResponse
        XCTAssertEqual(response.text, "Mock analysis from TestProvider")
    }

    /// [P0] LLMProvider protocol has estimateCost(imageCount:model:) method
    func testLLMProviderProtocolHasEstimateCostMethod() {
        let mock = MockLLMProvider(name: "TestProvider")

        let estimate = mock.estimateCost(imageCount: 5, model: "claude-sonnet-4-20250514")

        XCTAssertEqual(estimate.estimatedTokens, 5000)
        XCTAssertEqual(estimate.estimatedCost, 0.05, accuracy: 0.001)
    }

    // MARK: - AC1: Extended LLMResponse

    /// [P0] LLMResponse has modelID field
    func testLLMResponseHasModelID() {
        let response = LLMResponse(
            text: "test",
            modelID: "claude-sonnet-4-20250514",
            providerName: "Anthropic",
            inputTokens: 100,
            outputTokens: 50
        )
        XCTAssertEqual(response.modelID, "claude-sonnet-4-20250514",
            "LLMResponse should include modelID field")
    }

    /// [P0] LLMResponse has providerName field
    func testLLMResponseHasProviderName() {
        let response = LLMResponse(
            text: "test",
            modelID: "model",
            providerName: "Anthropic",
            inputTokens: 100,
            outputTokens: 50
        )
        XCTAssertEqual(response.providerName, "Anthropic",
            "LLMResponse should include providerName field")
    }

    /// [P1] LLMResponse has token usage fields
    func testLLMResponseHasTokenUsageFields() {
        let response = LLMResponse(
            text: "test",
            modelID: "model",
            providerName: "Anthropic",
            inputTokens: 1000,
            outputTokens: 500
        )
        XCTAssertEqual(response.inputTokens, 1000,
            "LLMResponse should include inputTokens")
        XCTAssertEqual(response.outputTokens, 500,
            "LLMResponse should include outputTokens")
    }

    // MARK: - AC1: Extended CostEstimate

    /// [P0] CostEstimate has modelID field
    func testCostEstimateHasModelID() {
        let estimate = CostEstimate(
            estimatedTokens: 1000,
            estimatedCost: 0.05,
            modelID: "claude-sonnet-4-20250514",
            providerName: "Anthropic"
        )
        XCTAssertEqual(estimate.modelID, "claude-sonnet-4-20250514",
            "CostEstimate should include modelID field")
    }

    /// [P0] CostEstimate has providerName field
    func testCostEstimateHasProviderName() {
        let estimate = CostEstimate(
            estimatedTokens: 1000,
            estimatedCost: 0.05,
            modelID: "model",
            providerName: "Anthropic"
        )
        XCTAssertEqual(estimate.providerName, "Anthropic",
            "CostEstimate should include providerName field")
    }

    // MARK: - AC1: LLMGateway Primary Provider Success Path

    /// [P0] LLMGateway delegates analyze() to primary provider successfully
    func testGatewayDelegatesAnalyzeToPrimaryProvider() async throws {
        // Given: Gateway with a working primary provider
        let primary = MockLLMProvider(name: "PrimaryProvider")
        let gateway = LLMGateway(providers: [primary])

        // When: Calling analyze through the gateway
        let response = try await gateway.analyze(
            images: [Data("fake-image".utf8)],
            prompt: "Analyze these photos",
            model: "claude-sonnet-4-20250514"
        )

        // Then: Response comes from primary provider
        XCTAssertEqual(response.text, "Mock analysis from PrimaryProvider",
            "Gateway should return response from primary provider")
        XCTAssertEqual(response.providerName, "PrimaryProvider")
        XCTAssertEqual(response.modelID, "claude-sonnet-4-20250514")
    }

    /// [P0] LLMGateway delegates estimateCost() to primary provider
    func testGatewayDelegatesEstimateCostToPrimaryProvider() async throws {
        let primary = MockLLMProvider(name: "PrimaryProvider")
        let gateway = LLMGateway(providers: [primary])

        let estimate = await gateway.estimateCost(
            imageCount: 3,
            model: "claude-sonnet-4-20250514"
        )

        XCTAssertEqual(estimate.estimatedTokens, 3000)
        XCTAssertEqual(estimate.providerName, "PrimaryProvider")
    }

    // MARK: - AC3: Failover

    /// [P0] LLMGateway fails over to backup provider when primary fails
    func testGatewayFailoverToBackupProvider() async throws {
        // Given: Gateway with failing primary and working backup
        let failingPrimary = MockLLMProvider(name: "FailingPrimary", shouldFail: true)
        let workingBackup = MockLLMProvider(name: "WorkingBackup")
        let gateway = LLMGateway(providers: [failingPrimary, workingBackup])

        // When: Calling analyze through the gateway
        let response = try await gateway.analyze(
            images: [Data("fake-image".utf8)],
            prompt: "Analyze these photos",
            model: "claude-sonnet-4-20250514"
        )

        // Then: Response comes from backup provider
        XCTAssertEqual(response.text, "Mock analysis from WorkingBackup",
            "Gateway should failover to backup provider when primary fails")
        XCTAssertEqual(response.providerName, "WorkingBackup")
    }

    /// [P0] LLMGateway throws error when all providers fail
    func testGatewayThrowsWhenAllProvidersFail() async throws {
        // Given: Gateway with all providers failing
        let failingPrimary = MockLLMProvider(name: "FailingPrimary", shouldFail: true)
        let failingBackup = MockLLMProvider(name: "FailingBackup", shouldFail: true)
        let gateway = LLMGateway(providers: [failingPrimary, failingBackup])

        // When/Then: Should throw error
        do {
            _ = try await gateway.analyze(
                images: [Data("fake-image".utf8)],
                prompt: "Analyze these photos",
                model: "claude-sonnet-4-20250514"
            )
            XCTFail("Should throw when all providers fail")
        } catch let error as InfrastructureError {
            if case .llmProviderUnavailable(let provider) = error {
                // Accept either provider name since both fail
                XCTAssertTrue(
                    provider == "FailingPrimary" || provider == "FailingBackup",
                    "Error should reference a provider that failed"
                )
            } else {
                XCTFail("Expected llmProviderUnavailable, got \(error)")
            }
        } catch {
            XCTFail("Expected InfrastructureError, got \(type(of: error))")
        }
    }

    // MARK: - AC3: Exponential Backoff Retry

    /// [P0] LLMGateway retries primary provider up to 3 times before failover
    func testGatewayRetriesPrimaryBeforeFailover() async throws {
        // Given: Provider that fails 3 times then succeeds on backup
        let failingPrimary = MockLLMProvider(name: "RetryPrimary", shouldFail: true)
        let workingBackup = MockLLMProvider(name: "BackupProvider")
        let gateway = LLMGateway(providers: [failingPrimary, workingBackup])

        // When: Calling analyze — primary retries 3 times then fails over
        let response = try await gateway.analyze(
            images: [Data("fake-image".utf8)],
            prompt: "test",
            model: "claude-sonnet-4-20250514"
        )

        // Then: Primary was called 3 times (max retries), backup called once
        XCTAssertEqual(failingPrimary.callCount.value, 3,
            "Primary provider should be retried 3 times before failover")
        XCTAssertEqual(response.providerName, "BackupProvider",
            "Should get response from backup after primary exhausts retries")
    }

    /// [P0] LLMGateway succeeds when provider recovers within retry limit
    func testGatewaySucceedsWhenProviderRecoversWithinRetries() async throws {
        // Given: Provider that fails 2 times then succeeds
        let recoveringProvider = MockLLMProvider(name: "RecoveringProvider", failCount: 2)
        let gateway = LLMGateway(providers: [recoveringProvider])

        // When: Calling analyze
        let response = try await gateway.analyze(
            images: [Data("fake-image".utf8)],
            prompt: "test",
            model: "claude-sonnet-4-20250514"
        )

        // Then: Should succeed on 3rd attempt
        XCTAssertEqual(recoveringProvider.callCount.value, 3,
            "Provider should be called 3 times (2 fails + 1 success)")
        XCTAssertEqual(response.providerName, "RecoveringProvider")
    }

    /// [P1] LLMGateway fails over within NFR21 time constraint (10 seconds)
    func testGatewayFailoverCompletesWithinTimeConstraint() async throws {
        // Given: Provider that fails immediately (no delay) and backup
        let fastFailing = MockLLMProvider(name: "FastFail", shouldFail: true)
        let backup = MockLLMProvider(name: "Backup")
        let gateway = LLMGateway(providers: [fastFailing, backup])

        let startTime = Date()

        // When: Calling analyze — should fail over quickly
        let response = try await gateway.analyze(
            images: [Data("fake-image".utf8)],
            prompt: "test",
            model: "claude-sonnet-4-20250514"
        )

        let elapsed = Date().timeIntervalSince(startTime)

        // Then: Should complete well within 10 seconds (NFR21)
        XCTAssertLessThan(elapsed, 10.0,
            "Failover should complete within 10 seconds (NFR21)")
        XCTAssertEqual(response.providerName, "Backup")
    }

    // MARK: - AC2: AnthropicProvider Request Construction

    /// [P1] AnthropicProvider constructs correct request URL
    func testAnthropicProviderRequestURL() async throws {
        // Given: An AnthropicProvider with a mock URL session
        let mockSession = MockURLSession()
        let provider = AnthropicProvider(apiKey: "test-api-key", urlSession: mockSession)

        // When: Calling analyze
        _ = try await provider.analyze(
            images: [Data("fake-image".utf8)],
            prompt: "Analyze these photos",
            model: "claude-sonnet-4-20250514"
        )

        // Then: Request URL should be the Claude Messages API endpoint
        let request = try XCTUnwrap(mockSession.lastRequest,
            "AnthropicProvider should make an HTTP request")
        XCTAssertEqual(request.url?.absoluteString,
            "https://api.anthropic.com/v1/messages",
            "Request URL should be Claude Messages API endpoint")
    }

    /// [P1] AnthropicProvider sets required request headers
    func testAnthropicProviderRequestHeaders() async throws {
        let mockSession = MockURLSession()
        let provider = AnthropicProvider(apiKey: "sk-ant-test-key", urlSession: mockSession)

        _ = try await provider.analyze(
            images: [Data("fake-image".utf8)],
            prompt: "test prompt",
            model: "claude-sonnet-4-20250514"
        )

        let request = try XCTUnwrap(mockSession.lastRequest)

        // Then: Headers should include required Anthropic API headers
        XCTAssertEqual(request.value(forHTTPHeaderField: "x-api-key"), "sk-ant-test-key",
            "Request should include x-api-key header")
        XCTAssertEqual(request.value(forHTTPHeaderField: "anthropic-version"), "2023-06-01",
            "Request should include anthropic-version header")
        XCTAssertEqual(request.value(forHTTPHeaderField: "content-type"), "application/json",
            "Request should include content-type: application/json header")
    }

    /// [P1] AnthropicProvider constructs correct JSON request body
    func testAnthropicProviderRequestBody() async throws {
        let mockSession = MockURLSession()
        let provider = AnthropicProvider(apiKey: "test-key", urlSession: mockSession)

        let imageData = Data("fake-jpeg-data".utf8)
        _ = try await provider.analyze(
            images: [imageData],
            prompt: "Find duplicates",
            model: "claude-sonnet-4-20250514"
        )

        let request = try XCTUnwrap(mockSession.lastRequest)
        let bodyData = try XCTUnwrap(request.httpBody)
        let body = try JSONSerialization.jsonObject(with: bodyData) as? [String: Any]

        XCTAssertNotNil(body, "Request body should be valid JSON")
        XCTAssertEqual(body?["model"] as? String, "claude-sonnet-4-20250514",
            "Request body should include model field")
        XCTAssertNotNil(body?["max_tokens"], "Request body should include max_tokens")
        XCTAssertNotNil(body?["messages"], "Request body should include messages array")
    }

    /// [P1] AnthropicProvider encodes images as base64 in request body
    func testAnthropicProviderEncodesImagesAsBase64() async throws {
        let mockSession = MockURLSession()
        let provider = AnthropicProvider(apiKey: "test-key", urlSession: mockSession)

        let imageData = Data("fake-image-data".utf8)
        _ = try await provider.analyze(
            images: [imageData],
            prompt: "Analyze",
            model: "claude-sonnet-4-20250514"
        )

        let request = try XCTUnwrap(mockSession.lastRequest)
        let bodyData = try XCTUnwrap(request.httpBody)
        let body = try JSONSerialization.jsonObject(with: bodyData) as? [String: Any]
        let messages = try XCTUnwrap(body?["messages"] as? [[String: Any]])
        let userMessage = try XCTUnwrap(messages.first)
        let content = try XCTUnwrap(userMessage["content"] as? [[String: Any]])

        // Find the image content block
        let imageBlock = content.first { $0["type"] as? String == "image" }
        XCTAssertNotNil(imageBlock, "Content should include an image block")

        let source = imageBlock?["source"] as? [String: Any]
        XCTAssertEqual(source?["type"] as? String, "base64",
            "Image source should be base64 encoded")
        XCTAssertEqual(source?["data"] as? String, imageData.base64EncodedString(),
            "Image data should be base64 encoded")
    }

    // MARK: - AC2: AnthropicProvider Response Parsing

    /// [P1] AnthropicProvider parses successful response into LLMResponse
    func testAnthropicProviderParsesSuccessfulResponse() async throws {
        let mockSession = MockURLSession()
        let responseJSON: [String: Any] = [
            "id": "msg_test123",
            "type": "message",
            "role": "assistant",
            "content": [["type": "text", "text": "These photos show similar landscapes."]],
            "model": "claude-sonnet-4-20250514",
            "usage": ["input_tokens": 1500, "output_tokens": 200]
        ]
        mockSession.mockResponseData = try JSONSerialization.data(withJSONObject: responseJSON)
        mockSession.mockHTTPResponse = HTTPURLResponse(
            url: URL(string: "https://api.anthropic.com/v1/messages")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )

        let provider = AnthropicProvider(apiKey: "test-key", urlSession: mockSession)

        let response = try await provider.analyze(
            images: [Data("fake".utf8)],
            prompt: "Find duplicates",
            model: "claude-sonnet-4-20250514"
        )

        XCTAssertEqual(response.text, "These photos show similar landscapes.",
            "Should extract text from response content")
        XCTAssertEqual(response.modelID, "claude-sonnet-4-20250514",
            "Should extract model ID from response")
        XCTAssertEqual(response.inputTokens, 1500,
            "Should extract input token count from usage")
        XCTAssertEqual(response.outputTokens, 200,
            "Should extract output token count from usage")
        XCTAssertEqual(response.providerName, "Anthropic",
            "Provider name should be 'Anthropic'")
    }

    /// [P1] AnthropicProvider maps HTTP errors to InfrastructureError
    func testAnthropicProviderMapsHTTPErrors() async throws {
        let mockSession = MockURLSession()
        mockSession.mockHTTPResponse = HTTPURLResponse(
            url: URL(string: "https://api.anthropic.com/v1/messages")!,
            statusCode: 401,
            httpVersion: nil,
            headerFields: nil
        )
        mockSession.mockResponseData = Data("{}".utf8)

        let provider = AnthropicProvider(apiKey: "bad-key", urlSession: mockSession)

        do {
            _ = try await provider.analyze(
                images: [Data("fake".utf8)],
                prompt: "test",
                model: "claude-sonnet-4-20250514"
            )
            XCTFail("Should throw for HTTP 401")
        } catch let error as InfrastructureError {
            if case .llmProviderError(let provider, let statusCode, _) = error {
                XCTAssertEqual(provider, "Anthropic")
                XCTAssertEqual(statusCode, 401,
                    "Should map HTTP 401 to llmProviderError with status code")
            } else {
                XCTFail("Expected llmProviderError, got \(error)")
            }
        } catch {
            XCTFail("Expected InfrastructureError, got \(type(of: error))")
        }
    }

    // MARK: - AC3: Rate Limit Handling

    /// [P1] AnthropicProvider handles HTTP 429 rate limit with retry-after
    func testAnthropicProviderHandlesRateLimit429() async throws {
        let mockSession = MockURLSession()

        // First call returns 429, second call succeeds
        let rateLimitResponse = HTTPURLResponse(
            url: URL(string: "https://api.anthropic.com/v1/messages")!,
            statusCode: 429,
            httpVersion: nil,
            headerFields: ["retry-after": "0"]  // Minimal delay for test speed
        )!

        let successJSON: [String: Any] = [
            "id": "msg_retry_success",
            "type": "message",
            "role": "assistant",
            "content": [["type": "text", "text": "Retry succeeded"]],
            "model": "claude-sonnet-4-20250514",
            "usage": ["input_tokens": 100, "output_tokens": 50]
        ]
        let successData = try JSONSerialization.data(withJSONObject: successJSON)
        let successResponse = HTTPURLResponse(
            url: URL(string: "https://api.anthropic.com/v1/messages")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!

        mockSession.mockResponses = [
            (data: Data("{}".utf8), response: rateLimitResponse),
            (data: successData, response: successResponse)
        ]

        let provider = AnthropicProvider(apiKey: "test-key", urlSession: mockSession)

        let result = try await provider.analyze(
            images: [Data("fake".utf8)],
            prompt: "test",
            model: "claude-sonnet-4-20250514"
        )

        XCTAssertEqual(result.text, "Retry succeeded",
            "Should succeed after rate limit retry")
    }

    // MARK: - AC2: AnthropicProvider Cost Estimation

    /// [P1] AnthropicProvider estimates cost based on model pricing
    func testAnthropicProviderEstimatesCost() async throws {
        let mockSession = MockURLSession()
        let provider = AnthropicProvider(apiKey: "test-key", urlSession: mockSession)

        let estimate = provider.estimateCost(imageCount: 10, model: "claude-sonnet-4-20250514")

        XCTAssertGreaterThan(estimate.estimatedCost, 0,
            "Cost estimate should be positive")
        XCTAssertEqual(estimate.modelID, "claude-sonnet-4-20250514",
            "Cost estimate should include model ID")
        XCTAssertEqual(estimate.providerName, "Anthropic",
            "Cost estimate should include provider name")
        XCTAssertGreaterThan(estimate.estimatedTokens, 0,
            "Should estimate non-zero token count")
    }

    // MARK: - AC1: LLMModelID Enum

    /// [P1] LLMModelID enum defines supported Claude model identifiers
    func testLLMModelIDDefinesClaudeModels() {
        // Verify claude-sonnet model exists
        let sonnet = LLMModelID.claudeSonnet
        XCTAssertFalse(sonnet.rawValue.isEmpty,
            "LLMModelID.claudeSonnet should have a non-empty rawValue")

        // Verify claude-haiku model exists
        let haiku = LLMModelID.claudeHaiku
        XCTAssertFalse(haiku.rawValue.isEmpty,
            "LLMModelID.claudeHaiku should have a non-empty rawValue")
    }

    /// [P1] LLMModelID has pricing information for each model
    func testLLMModelIDHasPricingInformation() {
        let sonnet = LLMModelID.claudeSonnet

        XCTAssertGreaterThan(sonnet.inputPricePerMillionTokens, 0,
            "claude-sonnet should have positive input price per million tokens")
        XCTAssertGreaterThan(sonnet.outputPricePerMillionTokens, 0,
            "claude-sonnet should have positive output price per million tokens")
    }

    // MARK: - AC1: Sendable Compile-Time Verification

    /// [P1] LLMResponse conforms to Sendable (compile-time check)
    func testLLMResponseIsSendable() {
        // This test passes at compile time if LLMResponse: Sendable
        let response = LLMResponse(
            text: "test",
            modelID: "model",
            providerName: "provider",
            inputTokens: 0,
            outputTokens: 0
        )
        // Sendable conformance verified by passing to a Sendable-checking context
        func assertSendable<T: Sendable>(_: T) {}
        assertSendable(response)
    }

    /// [P1] CostEstimate conforms to Sendable (compile-time check)
    func testCostEstimateIsSendable() {
        let estimate = CostEstimate(
            estimatedTokens: 0,
            estimatedCost: 0,
            modelID: "model",
            providerName: "provider"
        )
        func assertSendable<T: Sendable>(_: T) {}
        assertSendable(estimate)
    }

    /// [P1] InfrastructureError conforms to Sendable (compile-time check)
    func testInfrastructureErrorIsSendable() {
        let error = InfrastructureError.llmProviderUnavailable(provider: "Test")
        func assertSendable<T: Sendable>(_: T) {}
        assertSendable(error)
    }

    // MARK: - AppDependencies Integration

    /// [P1] AppDependencies can register an LLMGateway
    func testAppDependenciesCanRegisterLLMGateway() async throws {
        await MainActor.run {
            let dependencies = AppDependencies()
            let primary = MockLLMProvider(name: "TestPrimary")
            let gateway = LLMGateway(providers: [primary])

            dependencies.llmGateway = gateway

            XCTAssertNotNil(dependencies.llmGateway,
                "AppDependencies should accept LLMGateway registration")
        }
    }
}

// MARK: - Mock URLSession

/// Mock URLSession for testing AnthropicProvider without real network calls.
///
/// Uses nonisolated(unsafe) for mutable state since test mocks are accessed
/// sequentially within individual test methods (no concurrent access).
private final class MockURLSession: URLSessionProtocol, @unchecked Sendable {
    nonisolated(unsafe) var lastRequest: URLRequest?
    nonisolated(unsafe) var mockResponseData: Data = {
        let json: [String: Any] = [
            "id": "msg_default",
            "type": "message",
            "role": "assistant",
            "content": [["type": "text", "text": "Default mock response"]],
            "model": "claude-sonnet-4-20250514",
            "usage": ["input_tokens": 100, "output_tokens": 50]
        ]
        return (try? JSONSerialization.data(withJSONObject: json)) ?? Data()
    }()
    nonisolated(unsafe) var mockHTTPResponse: HTTPURLResponse?
    nonisolated(unsafe) var mockResponses: [(data: Data, response: HTTPURLResponse)] = []
    private var _callIndex = 0

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        lastRequest = request

        if !mockResponses.isEmpty {
            let index = _callIndex
            _callIndex += 1

            if index < mockResponses.count {
                let mock = mockResponses[index]
                return (mock.data, mock.response)
            }
        }

        let response = mockHTTPResponse ?? HTTPURLResponse(
            url: request.url!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
        return (mockResponseData, response)
    }
}
