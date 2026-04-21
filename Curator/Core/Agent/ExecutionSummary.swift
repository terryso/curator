import Foundation

/// Summary of a completed Agent execution.
///
/// Captures overall execution statistics for result display.
struct ExecutionSummary: Sendable, Equatable {
    let totalSteps: Int
    let completedSteps: Int
    let failedSteps: Int
    let duration: TimeInterval
    let message: String
}
