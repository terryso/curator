import Foundation

/// LLM provider configuration stored in UserDefaults.
///
/// Holds the base URL, API key, and model identifier needed to connect
/// to an LLM provider. Persisted as JSON in UserDefaults under `llm.config`.
struct LLMConfig: Codable, Sendable, Equatable {
    /// The base URL of the LLM API endpoint (e.g. "https://api.anthropic.com").
    let baseURL: String
    /// The API key for authentication.
    let apiKey: String
    /// The model identifier to use (e.g. "claude-sonnet-4-20250514").
    let modelID: String

    /// UserDefaults key for persisting the config.
    static let storageKey = "llm.config"

    /// Default Anthropic base URL.
    static let defaultBaseURL = "https://api.anthropic.com"

    /// Whether this config has all required fields populated.
    var isConfigured: Bool {
        !baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !modelID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// The full API endpoint URL (baseURL + /v1/messages).
    var messagesEndpoint: String {
        let base = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return "\(base)/v1/messages"
    }

    // MARK: - Persistence

    /// Loads config from UserDefaults.
    static func load() -> LLMConfig? {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return nil }
        return try? JSONDecoder().decode(LLMConfig.self, from: data)
    }

    /// Saves config to UserDefaults.
    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }

    /// Removes stored config from UserDefaults.
    static func clear() {
        UserDefaults.standard.removeObject(forKey: storageKey)
    }

    /// Whether a config has been stored.
    static var isStored: Bool {
        UserDefaults.standard.data(forKey: storageKey) != nil
    }
}
