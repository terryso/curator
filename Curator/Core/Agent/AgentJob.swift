import Foundation
import Observation

/// State machine-driven Agent execution engine.
///
/// Manages the complete lifecycle of an Agent task:
/// Planning -> Running -> Review -> Confirm -> Completed/Cancelled/Failed.
///
/// Emits events through AsyncStream<AgentEvent> for ViewModel consumption.
/// SwiftUI views observe this object directly via @Observable.
@MainActor
@Observable
final class AgentJob {

    // MARK: - Public State

    /// Current state in the AgentJob lifecycle.
    var state: AgentJobState = .planning

    /// Steps generated during the Planning phase and updated during execution.
    private(set) var steps: [AgentStep] = []

    /// Summary of execution, populated after completion.
    var executionSummary: ExecutionSummary?

    /// Error information, populated when state is .failed.
    var error: DomainError?

    // MARK: - Internal State

    private var continuation: AsyncStream<AgentEvent>.Continuation?
    private var executionTask: Task<Void, Never>?
    private var _eventStream: AsyncStream<AgentEvent>?

    /// Event stream for ViewModels to consume.
    /// Created lazily on first access via makeEventStream().
    var eventStream: AsyncStream<AgentEvent> {
        if let stream = _eventStream {
            return stream
        }
        let (stream, continuation) = AsyncStream<AgentEvent>.makeStream()
        self.continuation = continuation
        self._eventStream = stream
        return stream
    }

    // MARK: - Legal State Transitions

    /// Returns true if the transition from `from` to `to` is legal.
    private static func isLegalTransition(from: AgentJobState, to: AgentJobState) -> Bool {
        switch (from, to) {
        case (.planning, .running): return true
        case (.planning, .cancelled): return true
        case (.running, .review): return true
        case (.running, .cancelled): return true
        case (.running, .completed): return true
        case (.running, .failed): return true
        case (.review, .confirm): return true
        case (.review, .cancelled): return true
        case (.review, .running): return true
        case (.confirm, .completed): return true
        case (.confirm, .failed): return true
        default: return false
        }
    }

    // MARK: - Public Methods

    /// Start execution by consuming the event stream.
    /// Calling multiple times is a no-op.
    func start() {
        guard executionTask == nil else { return }
        let stream = eventStream
        executionTask = Task { [weak self] in
            guard let self else { return }
            for await event in stream {
                self.processEvent(event)
                if self.state == .completed || self.state == .cancelled || self.state == .failed {
                    break
                }
            }
            self.continuation?.finish()
        }
    }

    /// General reasoning messages not tied to a specific step.
    /// Populated when the agent reasons before any toolUse step is created.
    private(set) var reasoningMessages: [String] = []

    /// Cancel the running execution, preserving partial results.
    func cancel() {
        if state != .completed && state != .cancelled && state != .failed {
            transition(to: .cancelled)
        }
        executionTask?.cancel()
        continuation?.finish()
    }

    /// Emit an event into the event stream.
    func emit(_ event: AgentEvent) {
        continuation?.yield(event)
    }

    // MARK: - State Machine

    /// Transition to a new state with validation.
    ///
    /// Illegal transitions trigger assertionFailure in Debug and are silently ignored in Release.
    func transition(to newState: AgentJobState) {
        guard Self.isLegalTransition(from: state, to: newState) else {
            assertionFailure("Illegal state transition from \(state) to \(newState)")
            return
        }
        state = newState
    }

    // MARK: - Event Processing

    /// Process a single event, updating state accordingly.
    private func processEvent(_ event: AgentEvent) {
        switch event {
        case .planGenerated(let newSteps):
            steps = newSteps
            transition(to: .running)

        case .stepStarted(let stepID, let title):
            updateStep(id: stepID) { step in
                step.title = title
                step.status = .running
            }

        case .stepProgress(let stepID, let completed, let total):
            updateStep(id: stepID) { step in
                step.completedCount = completed
                step.totalCount = total
            }

        case .stepReasoning(let stepID, let message):
            if let index = steps.firstIndex(where: { $0.id == stepID }) {
                steps[index].reasoningMessages.append(message)
            } else {
                reasoningMessages.append(message)
            }

        case .stepCompleted(let stepID, _):
            updateStep(id: stepID) { step in
                step.status = .completed
            }

        case .stepFailed(let stepID, let domainError):
            updateStep(id: stepID) { step in
                step.status = .failed
            }
            error = domainError
            transition(to: .failed)

        case .reviewReady:
            transition(to: .review)

        case .executionCompleted(let summary):
            executionSummary = summary
            if state == .confirm || state == .running {
                transition(to: .completed)
            }
        }
    }

    /// Update a step by ID if found.
    private func updateStep(id: UUID, _ update: (inout AgentStep) -> Void) {
        guard let index = steps.firstIndex(where: { $0.id == id }) else { return }
        update(&steps[index])
    }

}
