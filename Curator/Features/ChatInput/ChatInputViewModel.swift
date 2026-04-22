import SwiftUI
import Observation

/// ViewModel for the Agent input bar, managing user input and Agent execution lifecycle.
///
/// Bridges the UI layer with the Agent execution engine. Creates CuratorAgent instances
/// via CuratorAgentFactory and manages AgentJob state for SwiftUI observation.
///
/// Marked `@MainActor` to ensure all UI state updates occur on the main thread.
/// Uses `@Observable` macro (macOS 15+) for efficient SwiftUI view updates.
@MainActor
@Observable
final class ChatInputViewModel {

    // MARK: - Observable State

    /// Current text in the input field.
    var inputText: String = ""

    /// Whether the ViewModel is currently submitting an instruction.
    var isSubmitting: Bool = false

    /// The current AgentJob, if one is active.
    /// SwiftUI views observe this via @Observable for state-driven rendering.
    var agentJob: AgentJob?

    /// The current active session for multi-turn context.
    var currentSession: Session?

    // MARK: - Dependencies

    /// Application dependencies container providing CuratorAgentFactory and AgentToolRegistry.
    private let dependencies: AppDependencies

    /// The current CuratorAgent instance, retained so cancellation can propagate to the SDK.
    private var currentAgent: CuratorAgent?

    /// The background Task consuming the agent's event stream, stored for cancellation.
    private var executionTask: _Concurrency.Task<Void, Never>?

    // MARK: - Initialization

    /// Creates a ChatInputViewModel with the specified dependencies.
    ///
    /// - Parameter dependencies: The AppDependencies container. Tests can inject
    ///   mock dependencies; production code passes the app-level container.
    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
    }

    // MARK: - Computed Properties

    /// Whether an Agent is currently running.
    ///
    /// Returns `true` when `agentJob` exists and its state is `.running`.
    var isAgentRunning: Bool {
        guard let job = agentJob else { return false }
        return job.state == .running
    }

    /// Whether the submit button should be enabled.
    ///
    /// Returns `true` when text is non-empty (after trimming) and Agent is not running.
    var isInputEnabled: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isAgentRunning
    }

    /// Whether quick command suggestions should be visible.
    ///
    /// Returns `true` when no AgentJob exists or AgentJob is in `.planning` state
    /// with no prior execution history (no steps generated yet).
    var quickCommandsVisible: Bool {
        guard let job = agentJob else { return true }
        // Show quick commands only in planning state with no steps
        return job.state == .planning && job.steps.isEmpty
    }

    // MARK: - Actions

    /// Submits the current input text as an Agent instruction.
    ///
    /// Validates the input (non-empty after trimming), then delegates to
    /// `createAndStartAgent(for:)` to create a CuratorAgent and AgentJob.
    /// Clears `inputText` and sets `isSubmitting` on success.
    ///
    /// No-op when:
    /// - Input is empty or whitespace-only
    /// - Agent is already running (prevents double-submit)
    /// - CuratorAgentFactory is not available in dependencies
    func submitInput() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard !isAgentRunning && !isSubmitting else { return }

        createAndStartAgent(for: trimmed)
    }

    /// Submits a quick command suggestion directly.
    ///
    /// Bypasses `inputText` -- takes the command string directly and submits it.
    /// Equivalent to typing the command and pressing Enter.
    ///
    /// - Parameter command: The preset command text to submit.
    func submitQuickCommand(_ command: String) {
        guard !isAgentRunning && !isSubmitting else { return }
        createAndStartAgent(for: command)
    }

    /// Cancels the currently running Agent execution.
    ///
    /// Propagates cancellation to both the AgentJob state machine and the underlying
    /// CuratorAgent (which calls `agent.interrupt()` on the SDK agent loop).
    /// No-op when no AgentJob exists or when the job is already in a terminal state.
    func cancelExecution() {
        agentJob?.cancel()
        // Propagate cancellation to the SDK agent to stop API calls and tool execution
        if let agent = currentAgent {
            _Concurrency.Task {
                await agent.cancel()
            }
        }
        executionTask?.cancel()
        isSubmitting = false
    }

    /// Creates a new session, saving the current one first.
    ///
    /// Flow:
    /// 1. Save current session (if exists) via sessionManager
    /// 2. Create new session via sessionManager
    /// 3. Set new session as currentSession
    /// 4. Clear agentJob (shows QuickCommandSuggestions)
    func createNewSession() {
        guard let sessionManager = dependencies.sessionManager else { return }

        _Concurrency.Task {
            // Save current session if it exists
            if var current = self.currentSession {
                current.isActive = false
                try? await sessionManager.saveSession(current)
            }

            // Create new session
            let newSession = await sessionManager.createSession()
            self.currentSession = newSession
            self.agentJob = nil
            self.isSubmitting = false
        }
    }

    // MARK: - Private Methods

    /// Creates a new CuratorAgent and AgentJob, then starts execution.
    ///
    /// This is the core connection logic:
    /// 1. Get toolRegistry and curatorAgentFactory from dependencies
    /// 2. Create CuratorAgent via factory
    /// 3. Create new AgentJob and call start()
    /// 4. In background Task: ensure session, append user message, execute agent
    /// 5. On completion: append assistant response to session
    ///
    /// - Parameter userMessage: The validated user instruction text.
    private func createAndStartAgent(for userMessage: String) {
        guard let factory = dependencies.curatorAgentFactory else { return }
        guard let registry = dependencies.toolRegistry else { return }

        // Create a new CuratorAgent for this instruction
        let curatorAgent = factory.createAgent(
            tools: registry.allTools,
            systemPrompt: nil
        )
        self.currentAgent = curatorAgent

        // Create a new AgentJob and start consuming its event stream
        let job = AgentJob()
        job.start()
        self.agentJob = job
        self.isSubmitting = true
        self.inputText = ""

        // Execute in a Task where session creation and agent execution can be awaited.
        // The Task inherits @MainActor but yields at each await point, so UI remains responsive.
        self.executionTask = _Concurrency.Task { [weak self] in
            guard let self else { return }

            // Ensure we have a session before proceeding
            if self.currentSession == nil, let sessionManager = self.dependencies.sessionManager {
                let session = await sessionManager.createSession()
                self.currentSession = session
            }

            // Append user message to session
            let userMsg = SessionMessage(
                id: UUID(),
                role: .user,
                content: userMessage,
                timestamp: Date()
            )
            if var session = self.currentSession {
                session.messages.append(userMsg)
                if session.title == "New Session" {
                    session.title = String(userMessage.prefix(50))
                }
                session.updatedAt = Date()
                self.currentSession = session

                if let sessionManager = self.dependencies.sessionManager {
                    try? await sessionManager.saveSession(session)
                }
            }

            // Set SessionContext for cost tracking, then execute the agent.
            // TaskLocal value persists for the duration of this scope,
            // so cost records are associated with the correct session.
            let sessionID = self.currentSession?.id.uuidString
            await SessionContext.$current.withValue(sessionID) {
                let stream = await curatorAgent.execute(userMessage)
                for await event in stream {
                    await self.agentJob?.emit(event)
                }
            }

            // Execution finished
            self.isSubmitting = false

            // Append assistant response to session
            if let summary = self.agentJob?.executionSummary,
               var session = self.currentSession {
                let assistantMsg = SessionMessage(
                    id: UUID(),
                    role: .assistant,
                    content: summary.message,
                    timestamp: Date()
                )
                session.messages.append(assistantMsg)
                session.updatedAt = Date()
                self.currentSession = session

                if let sessionManager = self.dependencies.sessionManager {
                    try? await sessionManager.saveSession(session)
                }
            }
        }
    }
}
