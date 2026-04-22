import Foundation
import Observation

/// UI rendering state for the Agent Execution Panel.
///
/// Maps `AgentJobState` to display-friendly states for SwiftUI consumption.
/// The `empty` case covers both "no AgentJob" and "AgentJob in planning"
/// (planning is handled by QuickCommandSuggestions).
enum ExecutionDisplayState: Sendable, Equatable {
    case empty
    case executing
    case review
    case completed
    case failed
    case cancelled
}

/// ViewModel bridging AgentJob state to the Agent Execution Panel UI.
///
/// Observes an `AgentJob` (which is itself `@Observable`) and exposes
/// computed properties that map AgentJob state to UI-friendly rendering states.
/// SwiftUI views observe this ViewModel via `@Observable` for efficient updates.
///
/// Architecture note: This ViewModel does not own the AgentJob lifecycle.
/// The AgentJob is managed by `ChatInputViewModel`; this ViewModel only reads.
@MainActor
@Observable
final class AgentExecutionViewModel {

    // MARK: - Observable State

    /// The current AgentJob to observe. Set by MainWorkspaceView via .onChange.
    /// When nil, displayState is `.empty`.
    var agentJob: AgentJob?

    // MARK: - Initialization

    init() {}

    // MARK: - Computed Properties

    /// Maps AgentJob state to a UI rendering state.
    ///
    /// Mapping logic:
    /// - nil / .planning -> .empty (QuickCommandSuggestions handles planning)
    /// - .running / .confirm -> .executing
    /// - .review -> .review
    /// - .completed -> .completed
    /// - .failed -> .failed
    /// - .cancelled -> .cancelled
    var displayState: ExecutionDisplayState {
        guard let job = agentJob else { return .empty }
        switch job.state {
        case .planning:
            return .empty
        case .running, .confirm:
            return .executing
        case .review:
            return .review
        case .completed:
            return .completed
        case .failed:
            return .failed
        case .cancelled:
            return .cancelled
        }
    }

    /// Whether the agent is currently executing (running or confirming).
    var isRunning: Bool {
        displayState == .executing
    }

    /// Steps from the current AgentJob, or empty array when no job.
    var steps: [AgentStep] {
        agentJob?.steps ?? []
    }

    /// General reasoning messages from the current AgentJob.
    var reasoningMessages: [String] {
        agentJob?.reasoningMessages ?? []
    }

    /// User-friendly formatted summary of execution results.
    ///
    /// Returns nil when no executionSummary is available.
    var formattedSummary: String? {
        guard let summary = agentJob?.executionSummary else { return nil }
        return summary.message
    }

    /// User-friendly formatted execution duration.
    ///
    /// Formats as "Xm Ys" for minutes+seconds, or "Xs" for seconds only.
    /// Returns nil when no executionSummary is available.
    var formattedDuration: String? {
        guard let summary = agentJob?.executionSummary else { return nil }
        let totalSeconds = Int(summary.duration)
        if totalSeconds >= 60 {
            let minutes = totalSeconds / 60
            let seconds = totalSeconds % 60
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(totalSeconds)s"
        }
    }

    /// User-friendly error message from the AgentJob failure.
    ///
    /// Returns nil when no error is available.
    var errorMessage: String? {
        guard let error = agentJob?.error else { return nil }
        switch error {
        case .analysisFailed(let reason):
            return "Analysis failed: \(reason)"
        case .insufficientPermission(let required):
            return "Insufficient permission: \(required) required"
        case .operationCancelled:
            return "Operation was cancelled"
        case .assetNotFound:
            return "Requested asset not found"
        case .invalidState(let reason):
            return "Invalid state: \(reason)"
        }
    }
}
