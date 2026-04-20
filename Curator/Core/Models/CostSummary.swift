import Foundation

/// Aggregated cost summary across multiple LLM calls.
///
/// Provides total cost, per-provider breakdowns, and per-session
/// breakdowns for a given time period or query scope.
struct CostSummary: Sendable {
    /// Total cost in USD across all matching records.
    let totalCost: Double
    /// Total input tokens across all matching records.
    let totalInputTokens: Int
    /// Total output tokens across all matching records.
    let totalOutputTokens: Int
    /// Number of LLM calls represented in this summary.
    let callCount: Int
    /// Cost breakdown by provider name.
    let byProvider: [String: Double]
    /// Cost breakdown by session identifier.
    let bySession: [String: Double]
    /// The date range this summary covers.
    let dateRange: DateInterval?

    static let zero = CostSummary(
        totalCost: 0,
        totalInputTokens: 0,
        totalOutputTokens: 0,
        callCount: 0,
        byProvider: [:],
        bySession: [:],
        dateRange: nil
    )
}
