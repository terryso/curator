import Foundation

/// Status of an individual Agent execution step.
enum StepStatus: String, Sendable, Equatable {
    case pending
    case running
    case completed
    case failed
}

/// A single step in the Agent execution plan.
///
/// Represents an atomic unit of work within an AgentJob.
/// Steps are created during the Planning phase and updated
/// as the AgentJob progresses through Running/Review/Confirm.
struct AgentStep: Sendable, Identifiable, Equatable {
    let id: UUID
    var title: String
    var status: StepStatus
    var completedCount: Int
    var totalCount: Int
    var reasoningMessages: [String]

    /// Progress as a ratio of completedCount / totalCount (0.0 to 1.0).
    /// Returns 0.0 when totalCount is 0.
    var progress: Double {
        guard totalCount > 0 else { return 0.0 }
        return Double(completedCount) / Double(totalCount)
    }
}
