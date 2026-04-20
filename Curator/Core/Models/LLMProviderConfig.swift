import Foundation

/// Enum representing supported LLM provider types.
///
/// Used by `LLMProviderConfig` to identify which provider backend to use.
/// New provider types are added here as the system expands.
enum LLMProviderType: String, Sendable, Codable, CaseIterable {
    case anthropic
    case openAICompatible

    /// User-facing display name for the provider type.
    var displayName: String {
        switch self {
        case .anthropic: return "Anthropic"
        case .openAICompatible: return "OpenAI Compatible"
        }
    }
}

/// Configuration for a single LLM provider instance.
///
/// Stores the provider type, base URL, API key, and model identifier
/// needed to connect to an LLM provider. Display name is optional
/// for user-friendly identification in the UI.
struct LLMProviderConfig: Codable, Sendable, Equatable {
    /// The type of LLM provider (e.g. .anthropic, .openAICompatible).
    let providerType: LLMProviderType
    /// The base URL of the LLM API endpoint (e.g. "https://api.anthropic.com").
    let baseURL: String
    /// The API key for authentication.
    let apiKey: String
    /// The model identifier to use (e.g. "claude-sonnet-4-20250514").
    let modelID: String
    /// Optional user-friendly display name (e.g. "DeepSeek", "Groq").
    let displayName: String?

    /// Whether this config has all required fields populated.
    var isConfigured: Bool {
        !baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !modelID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
