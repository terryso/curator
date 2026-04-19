import Foundation

/// Response from an LLM analysis request.
///
/// Contains the generated text along with metadata about which model and
/// provider produced the response, plus token usage for cost tracking.
struct LLMResponse: Sendable {
    /// The generated text content from the LLM.
    let text: String
    /// The model identifier used for this request (e.g. "claude-sonnet-4-20250514").
    let modelID: String
    /// The name of the provider that handled this request (e.g. "Anthropic").
    let providerName: String
    /// Number of tokens consumed in the prompt/input.
    let inputTokens: Int
    /// Number of tokens generated in the completion/output.
    let outputTokens: Int
}
