import Foundation

/// Protocol for tracking LLM API call costs.
///
/// Defined in the Domain layer; concrete actor implementation in Infrastructure.
/// Supports recording individual call costs and querying aggregated summaries.
protocol CostTrackerProtocol: Sendable {
    /// Records a completed LLM call's cost.
    func record(_ record: CostRecord) async throws
    /// Returns the cost summary for the current calendar month.
    func monthlySummary() async throws -> CostSummary
    /// Returns the cost summary for a specific session.
    func sessionSummary(_ sessionID: String) async throws -> CostSummary

    // MARK: - Story 2.6 Extensions

    /// Returns the aggregated cost summary for all recorded calls (all time).
    func allTimeSummary() async throws -> CostSummary

    /// Returns the most recent cost records, ordered by timestamp descending.
    /// - Parameter limit: Maximum number of records to return.
    func recentRecords(limit: Int) async throws -> [CostRecord]
}
