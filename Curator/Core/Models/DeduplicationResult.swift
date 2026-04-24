import Foundation

/// Value type representing a deduplication operation result for history tracking.
///
/// Contains summary statistics of a completed dedup operation: date, counts,
/// saved disk space, and duration. Designed as a Sendable value type for safe
/// use across concurrency domains before being persisted to SwiftData.
///
/// Usage:
/// ```
/// ResultSummaryViewModel.populateFrom(...) -> sets properties
/// let record = ResultSummaryViewModel.saveToHistory() -> returns DeduplicationResult
/// // Persist to SwiftData via DeduplicationResultEntity
/// ```
struct DeduplicationResult: Sendable, Equatable {
    /// Unique identifier for this history record.
    let id: UUID

    /// Date when the dedup operation was completed.
    let date: Date

    /// Number of photos removed in this operation.
    let removedCount: Int

    /// Total number of duplicate groups processed.
    let totalGroups: Int

    /// Total bytes of disk space saved by removing duplicates.
    let savedSpaceBytes: Int64

    /// Duration of the dedup operation in seconds.
    let durationSeconds: Double
}
