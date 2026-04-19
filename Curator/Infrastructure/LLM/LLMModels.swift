import Foundation

/// Enum representing supported LLM model identifiers and their pricing.
///
/// Each case maps to a specific model API identifier and carries
/// per-million-token pricing for cost estimation. The raw value is
/// the exact string sent to the provider API.
enum LLMModelID: String, Sendable, CaseIterable {
    /// Anthropic Claude Sonnet 4 — balanced performance and cost.
    case claudeSonnet = "claude-sonnet-4-20250514"
    /// Anthropic Claude Haiku — fast and economical for lightweight tasks.
    case claudeHaiku = "claude-haiku-4-20250506"

    // MARK: - Pricing

    /// Input price per 1 million tokens in USD.
    var inputPricePerMillionTokens: Double {
        switch self {
        case .claudeSonnet: return 3.0
        case .claudeHaiku: return 0.80
        }
    }

    /// Output price per 1 million tokens in USD.
    var outputPricePerMillionTokens: Double {
        switch self {
        case .claudeSonnet: return 15.0
        case .claudeHaiku: return 4.0
        }
    }

    /// Default maximum output tokens for this model.
    var defaultMaxTokens: Int {
        switch self {
        case .claudeSonnet: return 4096
        case .claudeHaiku: return 4096
        }
    }

    /// Estimated tokens per image for cost estimation purposes.
    static let estimatedTokensPerImage: Int = 1000
}
