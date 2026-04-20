import Foundation

/// A single LLM API call cost record.
///
/// Captures the provider, model, token usage, and calculated cost
/// for each completed LLM call. Used by CostTracker for persistence
/// and by CostSummary for aggregation.
struct CostRecord: Sendable, Codable, Identifiable {
    /// Unique identifier for this cost record.
    let id: UUID
    /// The LLM provider name (e.g. "Anthropic", "Fallback").
    let providerName: String
    /// The model identifier used for this call.
    let modelID: String
    /// Number of tokens consumed in the prompt/input.
    let inputTokens: Int
    /// Number of tokens generated in the completion/output.
    let outputTokens: Int
    /// Calculated cost in USD.
    let costUSD: Double
    /// Timestamp of the LLM call.
    let timestamp: Date
    /// Session identifier for grouping calls by conversation.
    let sessionID: String

    init(
        id: UUID = UUID(),
        providerName: String,
        modelID: String,
        inputTokens: Int,
        outputTokens: Int,
        costUSD: Double,
        timestamp: Date = Date(),
        sessionID: String
    ) {
        self.id = id
        self.providerName = providerName
        self.modelID = modelID
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.costUSD = costUSD
        self.timestamp = timestamp
        self.sessionID = sessionID
    }
}
