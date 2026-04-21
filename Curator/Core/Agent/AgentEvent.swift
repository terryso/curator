import Foundation

/// Events emitted by an AgentJob during execution.
///
/// These events flow through AsyncStream<AgentEvent> from the AgentJob
/// to the ViewModel, which translates them into @Observable state updates
/// for SwiftUI consumption.
enum AgentEvent: Sendable {
    /// Agent generated an execution plan with steps.
    case planGenerated(steps: [AgentStep])

    /// A specific step started executing.
    case stepStarted(stepID: UUID, title: String)

    /// Progress update for a specific step.
    case stepProgress(stepID: UUID, completed: Int, total: Int)

    /// Agent reasoning/explanation for current step.
    case stepReasoning(stepID: UUID, message: String)

    /// A step completed successfully with a result.
    case stepCompleted(stepID: UUID, result: StepResult)

    /// A step failed with an error.
    case stepFailed(stepID: UUID, error: DomainError)

    /// Agent has results ready for user review.
    case reviewReady(items: [ReviewItem])

    /// Entire execution completed with a summary.
    case executionCompleted(summary: ExecutionSummary)
}
