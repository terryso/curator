import XCTest
@testable import Curator

/// ATDD Tests for Story 2.3 - Multi-Provider Support (OpenAICompatibleProvider)
///
/// Tests verify:
/// - OpenAICompatibleProvider constructs correct OpenAI Chat Completions API requests
/// - Request uses Bearer auth header (not x-api-key)
/// - Request body uses OpenAI messages format with image_url content blocks
/// - Response parsing extracts text from choices[].message.content
/// - Token usage mapped from prompt_tokens/completion_tokens
/// - HTTP errors mapped to InfrastructureError
/// - 429 rate limit handling with retry-after header
/// - Cost estimation with OpenAI-compatible pricing
///
/// All tests use MockURLSession for deterministic verification.
final class OpenAICompatibleProviderTests: XCTestCase {

    // MARK: - Mock URLSession (reused from LLMGatewayTests pattern)

    /// Mock URLSession for testing OpenAICompatibleProvider without real network calls.
    private final class MockURLSession: URLSessionProtocol, @unchecked Sendable {
        nonisolated(unsafe) var lastRequest: URLRequest?
        nonisolated(unsafe) var mockResponseData: Data = {
            let json: [String: Any] = [
                "id": "chatcmpl-default",
                "object": "chat.completion",
                "model": "gpt-4o",
                "choices": [
                    [
                        "index": 0,
                        "message": ["role": "assistant", "content": "Default mock response"],
                        "finish_reason": "stop"
                    ]
                ],
                "usage": ["prompt_tokens": 100, "completion_tokens": 50, "total_tokens": 150]
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

    // MARK: - AC2: OpenAI Chat Completions API Request Format

    /// [P0] OpenAICompatibleProvider constructs correct request URL
    func testOpenAICompatibleProviderRequestURL() async throws {
        let mockSession = MockURLSession()
        let provider = OpenAICompatibleProvider(
            name: "DeepSeek",
            apiKey: "test-api-key",
            baseURL: "https://api.deepseek.com",
            urlSession: mockSession
        )

        _ = try await provider.analyze(
            images: [Data("fake-image".utf8)],
            prompt: "Analyze these photos",
            model: "deepseek-chat"
        )

        let request = try XCTUnwrap(mockSession.lastRequest,
            "OpenAICompatibleProvider should make an HTTP request")
        XCTAssertEqual(request.url?.absoluteString,
            "https://api.deepseek.com/v1/chat/completions",
            "Request URL should be base URL + /v1/chat/completions")
    }

    /// [P0] OpenAICompatibleProvider uses Bearer authorization header
    func testOpenAICompatibleProviderUsesBearerAuth() async throws {
        let mockSession = MockURLSession()
        let provider = OpenAICompatibleProvider(
            name: "OpenAI",
            apiKey: "sk-test-key",
            baseURL: "https://api.openai.com",
            urlSession: mockSession
        )

        _ = try await provider.analyze(
            images: [Data("fake".utf8)],
            prompt: "test",
            model: "gpt-4o"
        )

        let request = try XCTUnwrap(mockSession.lastRequest)
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer sk-test-key",
            "Should use Authorization: Bearer header (not x-api-key)")
        XCTAssertNil(request.value(forHTTPHeaderField: "x-api-key"),
            "Should NOT use x-api-key header (that's Anthropic-specific)")
    }

    /// [P0] OpenAICompatibleProvider constructs correct JSON request body
    func testOpenAICompatibleProviderRequestBody() async throws {
        let mockSession = MockURLSession()
        let provider = OpenAICompatibleProvider(
            name: "OpenAI",
            apiKey: "test-key",
            baseURL: "https://api.openai.com",
            urlSession: mockSession
        )

        let imageData = Data("fake-jpeg-data".utf8)
        _ = try await provider.analyze(
            images: [imageData],
            prompt: "Find duplicates",
            model: "gpt-4o"
        )

        let request = try XCTUnwrap(mockSession.lastRequest)
        let bodyData = try XCTUnwrap(request.httpBody)
        let body = try JSONSerialization.jsonObject(with: bodyData) as? [String: Any]

        XCTAssertNotNil(body, "Request body should be valid JSON")
        XCTAssertEqual(body?["model"] as? String, "gpt-4o",
            "Request body should include model field")
        XCTAssertNotNil(body?["messages"], "Request body should include messages array")
        XCTAssertNotNil(body?["max_tokens"], "Request body should include max_tokens")
    }

    /// [P0] OpenAICompatibleProvider encodes images as image_url content blocks
    func testOpenAICompatibleProviderEncodesImagesAsImageURL() async throws {
        let mockSession = MockURLSession()
        let provider = OpenAICompatibleProvider(
            name: "OpenAI",
            apiKey: "test-key",
            baseURL: "https://api.openai.com",
            urlSession: mockSession
        )

        let imageData = Data("fake-image-data".utf8)
        _ = try await provider.analyze(
            images: [imageData],
            prompt: "Analyze",
            model: "gpt-4o"
        )

        let request = try XCTUnwrap(mockSession.lastRequest)
        let bodyData = try XCTUnwrap(request.httpBody)
        let body = try JSONSerialization.jsonObject(with: bodyData) as? [String: Any]
        let messages = try XCTUnwrap(body?["messages"] as? [[String: Any]])
        let userMessage = try XCTUnwrap(messages.first)
        XCTAssertEqual(userMessage["role"] as? String, "user",
            "Message should have role: user")
        let content = try XCTUnwrap(userMessage["content"] as? [[String: Any]])

        // Find the image_url content block
        let imageBlock = content.first { $0["type"] as? String == "image_url" }
        XCTAssertNotNil(imageBlock, "Content should include an image_url block")

        let imageURL = imageBlock?["image_url"] as? [String: Any]
        XCTAssertNotNil(imageURL, "image_url block should have image_url object")
        let urlString = imageURL?["url"] as? String ?? ""
        XCTAssertTrue(urlString.hasPrefix("data:image/jpeg;base64,"),
            "Image URL should be a data URI with base64 encoding")
        XCTAssertTrue(urlString.contains(imageData.base64EncodedString()),
            "Image data should be base64 encoded in the data URI")
    }

    /// [P0] OpenAICompatibleProvider includes text prompt in messages content
    func testOpenAICompatibleProviderIncludesTextPrompt() async throws {
        let mockSession = MockURLSession()
        let provider = OpenAICompatibleProvider(
            name: "OpenAI",
            apiKey: "test-key",
            baseURL: "https://api.openai.com",
            urlSession: mockSession
        )

        _ = try await provider.analyze(
            images: [Data("fake".utf8)],
            prompt: "Find duplicate photos",
            model: "gpt-4o"
        )

        let request = try XCTUnwrap(mockSession.lastRequest)
        let bodyData = try XCTUnwrap(request.httpBody)
        let body = try JSONSerialization.jsonObject(with: bodyData) as? [String: Any]
        let messages = try XCTUnwrap(body?["messages"] as? [[String: Any]])
        let userMessage = try XCTUnwrap(messages.first)
        let content = try XCTUnwrap(userMessage["content"] as? [[String: Any]])

        // Find the text content block
        let textBlock = content.first { $0["type"] as? String == "text" }
        XCTAssertNotNil(textBlock, "Content should include a text block")
        XCTAssertEqual(textBlock?["text"] as? String, "Find duplicate photos",
            "Text block should contain the prompt text")
    }

    /// [P1] OpenAICompatibleProvider does not send anthropic-version header
    func testOpenAICompatibleProviderNoAnthropicVersionHeader() async throws {
        let mockSession = MockURLSession()
        let provider = OpenAICompatibleProvider(
            name: "DeepSeek",
            apiKey: "test-key",
            baseURL: "https://api.deepseek.com",
            urlSession: mockSession
        )

        _ = try await provider.analyze(
            images: [Data("fake".utf8)],
            prompt: "test",
            model: "deepseek-chat"
        )

        let request = try XCTUnwrap(mockSession.lastRequest)
        XCTAssertNil(request.value(forHTTPHeaderField: "anthropic-version"),
            "Should NOT send anthropic-version header")
    }

    // MARK: - AC2: Response Parsing

    /// [P1] OpenAICompatibleProvider parses successful response into LLMResponse
    func testOpenAICompatibleProviderParsesSuccessfulResponse() async throws {
        let mockSession = MockURLSession()
        let responseJSON: [String: Any] = [
            "id": "chatcmpl-test123",
            "object": "chat.completion",
            "model": "gpt-4o",
            "choices": [
                [
                    "index": 0,
                    "message": ["role": "assistant", "content": "These photos show similar landscapes."],
                    "finish_reason": "stop"
                ]
            ],
            "usage": ["prompt_tokens": 1500, "completion_tokens": 200, "total_tokens": 1700]
        ]
        mockSession.mockResponseData = try JSONSerialization.data(withJSONObject: responseJSON)
        mockSession.mockHTTPResponse = HTTPURLResponse(
            url: URL(string: "https://api.openai.com/v1/chat/completions")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )

        let provider = OpenAICompatibleProvider(
            name: "OpenAI",
            apiKey: "test-key",
            baseURL: "https://api.openai.com",
            urlSession: mockSession
        )

        let response = try await provider.analyze(
            images: [Data("fake".utf8)],
            prompt: "Find duplicates",
            model: "gpt-4o"
        )

        XCTAssertEqual(response.text, "These photos show similar landscapes.",
            "Should extract text from choices[0].message.content")
        XCTAssertEqual(response.modelID, "gpt-4o",
            "Should extract model from response")
        XCTAssertEqual(response.inputTokens, 1500,
            "Should extract prompt_tokens as inputTokens")
        XCTAssertEqual(response.outputTokens, 200,
            "Should extract completion_tokens as outputTokens")
        XCTAssertEqual(response.providerName, "OpenAI",
            "Provider name should match the configured name")
    }

    /// [P1] OpenAICompatibleProvider maps HTTP errors to InfrastructureError
    func testOpenAICompatibleProviderMapsHTTPErrors() async throws {
        let mockSession = MockURLSession()
        mockSession.mockHTTPResponse = HTTPURLResponse(
            url: URL(string: "https://api.openai.com/v1/chat/completions")!,
            statusCode: 401,
            httpVersion: nil,
            headerFields: nil
        )
        mockSession.mockResponseData = Data("{\"error\":{\"message\":\"Invalid API key\",\"type\":\"invalid_request_error\"}}".utf8)

        let provider = OpenAICompatibleProvider(
            name: "OpenAI",
            apiKey: "bad-key",
            baseURL: "https://api.openai.com",
            urlSession: mockSession
        )

        do {
            _ = try await provider.analyze(
                images: [Data("fake".utf8)],
                prompt: "test",
                model: "gpt-4o"
            )
            XCTFail("Should throw for HTTP 401")
        } catch let error as InfrastructureError {
            if case .llmProviderError(let provider, let statusCode, _) = error {
                XCTAssertEqual(provider, "OpenAI")
                XCTAssertEqual(statusCode, 401,
                    "Should map HTTP 401 to llmProviderError with status code")
            } else {
                XCTFail("Expected llmProviderError, got \(error)")
            }
        } catch {
            XCTFail("Expected InfrastructureError, got \(type(of: error))")
        }
    }

    /// [P1] OpenAICompatibleProvider throws rateLimitExceeded on 429 immediately
    /// (retry is handled by LLMGateway, not the provider).
    func testOpenAICompatibleProviderThrowsRateLimitOn429() async throws {
        let mockSession = MockURLSession()

        let rateLimitResponse = HTTPURLResponse(
            url: URL(string: "https://api.openai.com/v1/chat/completions")!,
            statusCode: 429,
            httpVersion: nil,
            headerFields: ["retry-after": "5"]
        )!

        mockSession.mockResponses = [
            (data: Data("{}".utf8), response: rateLimitResponse)
        ]

        let provider = OpenAICompatibleProvider(
            name: "OpenAI",
            apiKey: "test-key",
            baseURL: "https://api.openai.com",
            urlSession: mockSession
        )

        do {
            _ = try await provider.analyze(
                images: [Data("fake".utf8)],
                prompt: "test",
                model: "gpt-4o"
            )
            XCTFail("Should throw rateLimitExceeded on 429")
        } catch let error as InfrastructureError {
            if case .rateLimitExceeded(let provider, let retryAfter) = error {
                XCTAssertEqual(provider, "OpenAI")
                XCTAssertEqual(retryAfter, 5.0,
                    "Should extract retry-after from response header")
            } else {
                XCTFail("Expected rateLimitExceeded, got \(error)")
            }
        } catch {
            XCTFail("Expected InfrastructureError, got \(type(of: error))")
        }
    }

    /// [P1] OpenAICompatibleProvider throws rateLimitExceeded after exhausting retries
    func testOpenAICompatibleProviderThrowsRateLimitAfterRetriesExhausted() async throws {
        let mockSession = MockURLSession()

        // All calls return 429
        let rateLimitResponse = HTTPURLResponse(
            url: URL(string: "https://api.openai.com/v1/chat/completions")!,
            statusCode: 429,
            httpVersion: nil,
            headerFields: ["retry-after": "0"]
        )!

        mockSession.mockHTTPResponse = rateLimitResponse
        mockSession.mockResponseData = Data("{\"error\":{\"message\":\"Rate limit exceeded\"}}".utf8)

        let provider = OpenAICompatibleProvider(
            name: "OpenAI",
            apiKey: "test-key",
            baseURL: "https://api.openai.com",
            urlSession: mockSession
        )

        do {
            _ = try await provider.analyze(
                images: [Data("fake".utf8)],
                prompt: "test",
                model: "gpt-4o"
            )
            XCTFail("Should throw rateLimitExceeded after exhausting retries")
        } catch let error as InfrastructureError {
            if case .rateLimitExceeded(let provider, _) = error {
                XCTAssertEqual(provider, "OpenAI",
                    "Rate limit error should reference the provider name")
            } else {
                XCTFail("Expected rateLimitExceeded, got \(error)")
            }
        } catch {
            XCTFail("Expected InfrastructureError, got \(type(of: error))")
        }
    }

    // MARK: - AC2: Custom Base URL Support

    /// [P1] OpenAICompatibleProvider supports custom base URL for DeepSeek
    func testOpenAICompatibleProviderCustomBaseURL() async throws {
        let mockSession = MockURLSession()
        let provider = OpenAICompatibleProvider(
            name: "DeepSeek",
            apiKey: "ds-test-key",
            baseURL: "https://api.deepseek.com",
            urlSession: mockSession
        )

        _ = try await provider.analyze(
            images: [Data("fake".utf8)],
            prompt: "test",
            model: "deepseek-chat"
        )

        let request = try XCTUnwrap(mockSession.lastRequest)
        XCTAssertEqual(request.url?.absoluteString,
            "https://api.deepseek.com/v1/chat/completions",
            "Should use the configured custom base URL")
    }

    // MARK: - AC2: Cost Estimation

    /// [P1] OpenAICompatibleProvider estimates cost based on model pricing
    func testOpenAICompatibleProviderEstimatesCost() async throws {
        let mockSession = MockURLSession()
        let provider = OpenAICompatibleProvider(
            name: "OpenAI",
            apiKey: "test-key",
            baseURL: "https://api.openai.com",
            urlSession: mockSession
        )

        let estimate = provider.estimateCost(imageCount: 10, model: "gpt-4o")

        XCTAssertGreaterThan(estimate.estimatedCost, 0,
            "Cost estimate should be positive")
        XCTAssertEqual(estimate.modelID, "gpt-4o",
            "Cost estimate should include model ID")
        XCTAssertEqual(estimate.providerName, "OpenAI",
            "Cost estimate should include provider name")
        XCTAssertGreaterThan(estimate.estimatedTokens, 0,
            "Should estimate non-zero token count")
    }

    // MARK: - AC2: Sendable Conformance

    /// [P1] OpenAICompatibleProvider conforms to LLMProvider (and thus Sendable)
    func testOpenAICompatibleProviderConformsToLLMProvider() async throws {
        let provider: any LLMProvider = OpenAICompatibleProvider(
            name: "TestProvider",
            apiKey: "test-key",
            baseURL: "https://api.test.com"
        )

        XCTAssertEqual(provider.name, "TestProvider",
            "Provider name should match configured name")
        func assertSendable<T: Sendable>(_: T) {}
        assertSendable(provider)
    }
}
