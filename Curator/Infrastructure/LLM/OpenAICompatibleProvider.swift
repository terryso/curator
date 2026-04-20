import Foundation

/// OpenAI-compatible API implementation of the LLMProvider protocol.
///
/// Supports any API that follows the OpenAI Chat Completions format,
/// including OpenAI, DeepSeek, Groq, Together AI, and self-hosted models.
/// Configuration (base URL, API key, model) is injected at init time.
///
/// Key differences from AnthropicProvider:
/// - Uses `Authorization: Bearer` header (not `x-api-key`)
/// - Endpoint is `/v1/chat/completions` (not `/v1/messages`)
/// - Images encoded as `image_url` data URIs (not base64 source blocks)
/// - Response text from `choices[].message.content` (not `content[].text`)
/// - Token usage from `prompt_tokens/completion_tokens` (not `input_tokens/output_tokens`)
final class OpenAICompatibleProvider: LLMProvider, Sendable {
    /// User-friendly provider name (e.g. "DeepSeek", "Groq", "OpenAI").
    let name: String

    private let apiKey: String
    private let baseURL: String
    private let urlSession: any URLSessionProtocol

    /// Creates an OpenAI-compatible provider.
    ///
    /// - Parameters:
    ///   - name: User-friendly display name for this provider.
    ///   - apiKey: The API key for authentication.
    ///   - baseURL: The base URL for the API endpoint.
    ///   - urlSession: The URL session used for network requests. Defaults to `.shared`.
    init(name: String, apiKey: String, baseURL: String, urlSession: (any URLSessionProtocol)? = nil) {
        self.name = name
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.urlSession = urlSession ?? URLSession.shared
    }

    // MARK: - LLMProvider

    func analyze(images: [Data], prompt: String, model: String) async throws -> LLMResponse {
        let request = try buildRequest(images: images, prompt: prompt, model: model)
        return try await executeRequest(request, model: model)
    }

    func estimateCost(imageCount: Int, model: String) -> CostEstimate {
        let matchedModel = LLMModelID(rawValue: model)

        let estimatedTokens: Int
        let estimatedCost: Double

        if let matched = matchedModel {
            estimatedTokens = imageCount * LLMModelID.estimatedTokensPerImage + 500
            let inputTokens = Double(estimatedTokens) * 0.8
            let outputTokens = Double(estimatedTokens) * 0.2
            estimatedCost = (inputTokens / 1_000_000.0 * matched.inputPricePerMillionTokens)
                + (outputTokens / 1_000_000.0 * matched.outputPricePerMillionTokens)
        } else {
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

    /// Builds the URLRequest for the OpenAI Chat Completions API.
    private func buildRequest(images: [Data], prompt: String, model: String) throws -> URLRequest {
        let endpoint = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + "/v1/chat/completions"
        guard let url = URL(string: endpoint) else {
            throw InfrastructureError.networkError(
                underlying: NSError(domain: "OpenAICompatibleProvider", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "Invalid API URL"
                ])
            )
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "content-type")

        let maxTokens = LLMModelID(rawValue: model)?.defaultMaxTokens ?? 4096

        var contentBlocks: [[String: Any]] = []

        // Add image blocks as image_url data URIs.
        for imageData in images {
            let mediaType = detectMediaType(from: imageData)
            let dataURI = "data:\(mediaType);base64,\(imageData.base64EncodedString())"
            let imageBlock: [String: Any] = [
                "type": "image_url",
                "image_url": ["url": dataURI]
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

    /// Executes the request and maps HTTP errors to InfrastructureError.
    ///
    /// Note: Retry logic is handled by LLMGateway. This method throws immediately
    /// on rate-limit (429) so the gateway can apply its error-type-aware retry strategy.
    private func executeRequest(_ request: URLRequest, model: String) async throws -> LLMResponse {
        let (data, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw InfrastructureError.networkError(
                underlying: NSError(domain: "OpenAICompatibleProvider", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "Invalid response type"
                ])
            )
        }

        // Handle rate limiting — throw immediately so gateway can manage retries.
        if httpResponse.statusCode == 429 {
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

    /// Parses the OpenAI Chat Completions API JSON response into an LLMResponse.
    private func parseResponse(data: Data, model: String) throws -> LLMResponse {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw InfrastructureError.llmProviderError(
                provider: name,
                statusCode: 200,
                message: "Failed to parse response JSON"
            )
        }

        // Extract text from choices[0].message.content.
        let choices = json["choices"] as? [[String: Any]] ?? []
        let firstChoice = choices.first
        let message = firstChoice?["message"] as? [String: Any]
        let text = message?["content"] as? String ?? ""

        // Extract token usage (OpenAI uses prompt_tokens/completion_tokens).
        let usage = json["usage"] as? [String: Any] ?? [:]
        let inputTokens = usage["prompt_tokens"] as? Int ?? 0
        let outputTokens = usage["completion_tokens"] as? Int ?? 0

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
            if data.count >= 12,
               data[8] == 0x57, data[9] == 0x45, data[10] == 0x42, data[11] == 0x50 {
                return "image/webp"
            }
        }
        return "image/jpeg"
    }
}
