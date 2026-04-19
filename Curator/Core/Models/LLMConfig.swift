import Foundation

/// Multi-provider LLM configuration stored in UserDefaults.
///
/// Holds a primary provider configuration and an optional fallback provider.
/// The fallback is used when the primary provider fails (5xx, timeout, etc.).
///
/// Backward compatible: old single-provider format JSON (with baseURL/apiKey/modelID
/// at the top level) is auto-migrated to the new multi-provider format on load,
/// with `providerType` set to `.anthropic`.
struct LLMConfig: Codable, Sendable, Equatable {
    /// The primary provider configuration.
    let primary: LLMProviderConfig
    /// The optional fallback provider configuration (nil when not configured).
    let fallback: LLMProviderConfig?

    /// UserDefaults key for persisting the config.
    static let storageKey = "llm.config"

    /// Default Anthropic base URL (backward compatibility).
    static let defaultBaseURL = "https://api.anthropic.com"

    // MARK: - Backward-Compatible Convenience

    /// Creates a single-provider config from the legacy API.
    ///
    /// Used by onboarding and settings views that haven't been updated to
    /// the multi-provider format yet. Stores as an Anthropic primary provider.
    init(baseURL: String, apiKey: String, modelID: String) {
        self.primary = LLMProviderConfig(
            providerType: .anthropic,
            baseURL: baseURL,
            apiKey: apiKey,
            modelID: modelID,
            displayName: nil
        )
        self.fallback = nil
    }

    /// Creates a multi-provider config with primary and optional fallback.
    init(primary: LLMProviderConfig, fallback: LLMProviderConfig? = nil) {
        self.primary = primary
        self.fallback = fallback
    }

    /// Primary provider's base URL (backward compatibility).
    var baseURL: String { primary.baseURL }
    /// Primary provider's API key (backward compatibility).
    var apiKey: String { primary.apiKey }
    /// Primary provider's model ID (backward compatibility).
    var modelID: String { primary.modelID }
    /// Whether the primary provider is configured (backward compatibility).
    var isConfigured: Bool { primary.isConfigured }
    /// The full API endpoint URL for the primary provider (backward compatibility).
    var messagesEndpoint: String {
        let base = primary.baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return "\(base)/v1/messages"
    }

    // MARK: - Persistence

    /// Loads config from UserDefaults, with backward-compatible migration.
    ///
    /// If the stored JSON matches the old single-provider format (top-level
    /// baseURL/apiKey/modelID), it is automatically migrated to the new
    /// multi-provider format with `providerType` set to `.anthropic`.
    static func load() -> LLMConfig? {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return nil }

        // Try new multi-provider format first.
        if let config = try? JSONDecoder().decode(LLMConfig.self, from: data) {
            return config
        }

        // Fallback: try old single-provider format and auto-migrate.
        if let legacy = try? JSONDecoder().decode(LegacyLLMConfig.self, from: data) {
            return LLMConfig(
                primary: LLMProviderConfig(
                    providerType: .anthropic,
                    baseURL: legacy.baseURL,
                    apiKey: legacy.apiKey,
                    modelID: legacy.modelID,
                    displayName: nil
                ),
                fallback: nil
            )
        }

        return nil
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

/// Legacy single-provider LLM config format for backward-compatible migration.
///
/// Used internally by `LLMConfig.load()` to decode old-format JSON.
/// This type is not intended for direct use in new code.
private struct LegacyLLMConfig: Codable, Sendable, Equatable {
    let baseURL: String
    let apiKey: String
    let modelID: String
}
