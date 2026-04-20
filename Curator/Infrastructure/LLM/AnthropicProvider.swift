import Foundation

/// Protocol abstracting URLSession for testability.
///
/// Production code uses the default URLSession conformance;
/// tests inject a mock implementation to verify request construction
/// and response parsing without real network calls.
protocol URLSessionProtocol: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

/// Extend URLSession to conform to the protocol for production use.
extension URLSession: URLSessionProtocol {}

/// Anthropic Claude API implementation of the LLMProvider protocol.
///
/// Sends image analysis requests to the Anthropic Messages API endpoint,
/// encoding images as base64 in the JSON request body. Handles HTTP error
/// mapping to InfrastructureError and parses token usage from responses.
final class AnthropicProvider: LLMProvider, Sendable {
    let name = "Anthropic"

    private let apiKey: String
    private let baseURL: String
    private let urlSession: any URLSessionProtocol

    /// Creates an Anthropic provider.
    ///
    /// - Parameters:
    ///   - apiKey: The Anthropic API key. Empty string disables real calls.
    ///   - baseURL: The base URL for the API. Falls back to Anthropic default when empty.
    ///   - urlSession: The URL session used for network requests. Defaults to `.shared`.
    init(apiKey: String, baseURL: String = "", urlSession: (any URLSessionProtocol)? = nil) {
        self.apiKey = apiKey
        self.baseURL = baseURL.isEmpty ? Self.defaultBaseURL : baseURL
        self.urlSession = urlSession ?? URLSession.shared
    }

    // MARK: - LLMProvider

    func analyze(images: [Data], prompt: String, model: String) async throws -> LLMResponse {
        let request = try buildRequest(images: images, prompt: prompt, model: model)
        return try await executeRequest(request, model: model)
    }

    func estimateCost(imageCount: Int, model: String) -> CostEstimate {
        // Try to match the model string to a known model for pricing.
        let matchedModel = LLMModelID(rawValue: model)

        let estimatedTokens: Int
        let estimatedCost: Double

        if let matched = matchedModel {
            // Estimate: images contribute tokens, plus a base prompt overhead.
            estimatedTokens = imageCount * LLMModelID.estimatedTokensPerImage + 500
            // Assume ~80% input, ~20% output split.
            let inputTokens = Double(estimatedTokens) * 0.8
            let outputTokens = Double(estimatedTokens) * 0.2
            estimatedCost = (inputTokens / 1_000_000.0 * matched.inputPricePerMillionTokens)
                + (outputTokens / 1_000_000.0 * matched.outputPricePerMillionTokens)
        } else {
            // Unknown model: use a conservative default estimate.
            estimatedTokens = imageCount * LLMModelID.estimatedTokensPerImage + 500
            estimatedCost = Double(estimatedTokens) / 1_000_000.0 * 5.0
        }

        return CostEstimate(
            estimatedTokens: estimatedTokens,
            estimatedCost: estimatedCost,
            modelID: model,
            providerName: name,
            estimatedAPICalls: 1,
            currency: "USD"
        )
    }

    // MARK: - Private

    /// Default base URL for the Anthropic Messages API.
    private static let defaultBaseURL = "https://api.anthropic.com"

    /// Anthropic API version header value.
    private static let apiVersion = "2023-06-01"

    /// Builds the URLRequest for the Anthropic Messages API.
    private func buildRequest(images: [Data], prompt: String, model: String) throws -> URLRequest {
        let endpoint = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + "/v1/messages"
        guard let url = URL(string: endpoint) else {
            throw InfrastructureError.networkError(
                underlying: NSError(domain: "AnthropicProvider", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "Invalid API URL"
                ])
            )
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(Self.apiVersion, forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")

        let maxTokens = LLMModelID(rawValue: model)?.defaultMaxTokens ?? 4096

        var contentBlocks: [[String: Any]] = []

        // Add image blocks with media type detection.
        for imageData in images {
            let mediaType = detectMediaType(from: imageData)
            let imageBlock: [String: Any] = [
                "type": "image",
                "source": [
                    "type": "base64",
                    "media_type": mediaType,
                    "data": imageData.base64EncodedString()
                ]
            ]
            contentBlocks.append(imageBlock)
        }

        // Add text prompt block.
        contentBlocks.append([
            "type": "text",
            "text": prompt
        ])

        let body: [String: Any] = [
            "model": model,
            "max_tokens": maxTokens,
            "messages": [
                ["role": "user", "content": contentBlocks]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    /// Executes the request and handles rate-limit retry and error mapping.
    private func executeRequest(_ request: URLRequest, model: String, attempt: Int = 0) async throws -> LLMResponse {
        let (data, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw InfrastructureError.networkError(
                underlying: NSError(domain: "AnthropicProvider", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "Invalid response type"
                ])
            )
        }

        // Handle rate limiting — throw dedicated error if retries exhausted.
        if httpResponse.statusCode == 429 {
            if attempt < 3 {
                let retryAfter = parseRetryAfter(from: httpResponse)
                try await Task.sleep(for: .seconds(retryAfter))
                return try await executeRequest(request, model: model, attempt: attempt + 1)
            }
            let retryAfter = parseRetryAfter(from: httpResponse)
            throw InfrastructureError.rateLimitExceeded(provider: name, retryAfter: retryAfter)
        }

        // Handle HTTP errors.
        if !(200...299).contains(httpResponse.statusCode) {
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw InfrastructureError.llmProviderError(
                provider: name,
                statusCode: httpResponse.statusCode,
                message: message
            )
        }

        return try parseResponse(data: data, model: model)
    }

    /// Parses the Anthropic Messages API JSON response into an LLMResponse.
    private func parseResponse(data: Data, model: String) throws -> LLMResponse {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw InfrastructureError.llmProviderError(
                provider: name,
                statusCode: 200,
                message: "Failed to parse response JSON"
            )
        }

        // Extract text from content blocks.
        let contentArray = json["content"] as? [[String: Any]] ?? []
        let text = contentArray
            .compactMap { $0["text"] as? String }
            .joined(separator: "\n")

        // Extract token usage.
        let usage = json["usage"] as? [String: Any] ?? [:]
        let inputTokens = usage["input_tokens"] as? Int ?? 0
        let outputTokens = usage["output_tokens"] as? Int ?? 0

        // Prefer the model from the response; fall back to the requested model.
        let responseModel = json["model"] as? String ?? model

        return LLMResponse(
            text: text,
            modelID: responseModel,
            providerName: name,
            inputTokens: inputTokens,
            outputTokens: outputTokens
        )
    }

    /// Parses the Retry-After header value from an HTTP response.
    private func parseRetryAfter(from response: HTTPURLResponse) -> TimeInterval {
        guard let value = response.value(forHTTPHeaderField: "retry-after") else {
            return 1.0
        }
        if let seconds = Double(value) {
            return seconds
        }
        return 1.0
    }

    /// Detects image media type from file signature (magic bytes).
    private func detectMediaType(from data: Data) -> String {
        guard data.count >= 4 else { return "image/jpeg" }
        let prefix = [data[0], data[1], data[2], data[3]]

        if prefix[0] == 0x89, prefix[1] == 0x50, prefix[2] == 0x4E, prefix[3] == 0x47 {
            return "image/png"
        } else if prefix[0] == 0x47, prefix[1] == 0x49, prefix[2] == 0x46 {
            return "image/gif"
        } else if prefix[0] == 0x52, prefix[1] == 0x49, prefix[2] == 0x46, prefix[3] == 0x46 {
            // RIFF header — could be WebP
            if data.count >= 12,
               data[8] == 0x57, data[9] == 0x45, data[10] == 0x42, data[11] == 0x50 {
                return "image/webp"
            }
        }
        return "image/jpeg"
    }
}
