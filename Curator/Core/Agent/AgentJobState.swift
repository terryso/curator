import Foundation

/// States in the AgentJob lifecycle state machine.
///
/// Legal transitions:
/// - Planning -> Running (planGenerated event)
/// - Planning -> Cancelled (user cancels during planning)
/// - Running -> Review (reviewReady event)
/// - Running -> Cancelled (user cancels)
/// - Running -> Failed (fatal stepFailed event)
/// - Review -> Confirm (user confirms review results)
/// - Review -> Cancelled (user rejects/cancels)
/// - Review -> Running (agent needs additional processing)
/// - Confirm -> Completed (executionCompleted event)
/// - Confirm -> Failed (execution confirmation failed)
enum AgentJobState: String, Sendable, Equatable {
    case planning
    case running
    case review
    case confirm
    case completed
    case cancelled
    case failed
}
