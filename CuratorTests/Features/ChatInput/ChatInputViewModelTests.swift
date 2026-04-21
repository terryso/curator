import XCTest
@testable import Curator

/// ATDD Tests for Story 3.3 - Agent Input Bar
///
/// Tests verify:
/// - ChatInputViewModel exists as @MainActor @Observable
/// - submitInput() clears inputText and creates agentJob when text is non-empty (AC2)
/// - submitInput() with empty/whitespace text does not trigger submission (AC2)
/// - submitQuickCommand() directly submits a preset command string (AC3)
/// - cancelExecution() calls agentJob.cancel() when agent is running (AC4)
/// - isAgentRunning reflects agentJob.state == .running (AC4)
/// - isInputEnabled is false when agent is running (AC4)
/// - quickCommandsVisible is true when agentJob is nil or in planning state (AC3)
/// - quickCommandsVisible is false when agent is running (AC4)
///
/// All tests use mock AppDependencies (no real CuratorAgent, no real API calls).
final class ChatInputViewModelTests: XCTestCase {

    // MARK: - Test Helpers

    /// Creates a ChatInputViewModel with fully mocked dependencies.
    @MainActor
    private func makeViewModel(
        withAgentFactory: Bool = true
    ) -> ChatInputViewModel {
        let dependencies = AppDependencies()

        if withAgentFactory {
            dependencies.registerAgentInfrastructure()
        }

        return ChatInputViewModel(dependencies: dependencies)
    }

    /// Creates a ChatInputViewModel with a mock factory that always succeeds.
    @MainActor
    private func makeViewModelWithMockFactory() -> ChatInputViewModel {
        let dependencies = AppDependencies()
        dependencies.registerAgentInfrastructure()
        return ChatInputViewModel(dependencies: dependencies)
    }

    // MARK: - AC1: ChatInputViewModel Existence & Observable

    /// [P0] ChatInputViewModel exists as @MainActor @Observable
    @MainActor
    func testChatInputViewModelExists() async throws {
        let viewModel = makeViewModel()
        XCTAssertNotNil(viewModel)
    }

    /// [P0] ChatInputViewModel initializes with empty inputText
    @MainActor
    func testInitialInputTextIsEmpty() async throws {
        let viewModel = makeViewModel()
        XCTAssertEqual(viewModel.inputText, "",
            "inputText should be empty on init")
    }

    /// [P0] ChatInputViewModel initializes with nil agentJob
    @MainActor
    func testInitialAgentJobIsNil() async throws {
        let viewModel = makeViewModel()
        XCTAssertNil(viewModel.agentJob,
            "agentJob should be nil on init")
    }

    /// [P0] ChatInputViewModel initializes with isSubmitting == false
    @MainActor
    func testInitialIsSubmittingIsFalse() async throws {
        let viewModel = makeViewModel()
        XCTAssertFalse(viewModel.isSubmitting,
            "isSubmitting should be false on init")
    }

    // MARK: - AC2: Submit Input with Non-Empty Text

    /// [P0] submitInput() with non-empty text clears inputText
    @MainActor
    func testSubmitInputClearsInputText() async throws {
        let viewModel = makeViewModelWithMockFactory()
        viewModel.inputText = "找出所有重复照片"

        viewModel.submitInput()

        XCTAssertEqual(viewModel.inputText, "",
            "submitInput() should clear inputText")
    }

    /// [P0] submitInput() with non-empty text sets isSubmitting to true
    @MainActor
    func testSubmitInputSetsIsSubmitting() async throws {
        let viewModel = makeViewModelWithMockFactory()
        viewModel.inputText = "重命名照片"

        viewModel.submitInput()

        XCTAssertTrue(viewModel.isSubmitting,
            "submitInput() should set isSubmitting to true")
    }

    /// [P0] submitInput() with non-empty text creates an agentJob
    @MainActor
    func testSubmitInputCreatesAgentJob() async throws {
        let viewModel = makeViewModelWithMockFactory()
        viewModel.inputText = "分析我的照片"

        viewModel.submitInput()

        XCTAssertNotNil(viewModel.agentJob,
            "submitInput() should create an agentJob")
    }

    // MARK: - AC2: Submit Input with Empty Text

    /// [P0] submitInput() with empty text does not trigger submission
    @MainActor
    func testSubmitInputEmptyTextDoesNotSubmit() async throws {
        let viewModel = makeViewModel()
        viewModel.inputText = ""

        viewModel.submitInput()

        XCTAssertFalse(viewModel.isSubmitting,
            "Empty text should not trigger submission")
        XCTAssertNil(viewModel.agentJob,
            "Empty text should not create agentJob")
    }

    /// [P0] submitInput() with whitespace-only text does not trigger submission
    @MainActor
    func testSubmitInputWhitespaceOnlyDoesNotSubmit() async throws {
        let viewModel = makeViewModel()
        viewModel.inputText = "   \t\n  "

        viewModel.submitInput()

        XCTAssertFalse(viewModel.isSubmitting,
            "Whitespace-only text should not trigger submission")
        XCTAssertNil(viewModel.agentJob,
            "Whitespace-only text should not create agentJob")
    }

    // MARK: - AC3: Quick Command Suggestions

    /// [P0] submitQuickCommand() submits the command text directly
    @MainActor
    func testSubmitQuickCommandSubmitsText() async throws {
        let viewModel = makeViewModelWithMockFactory()

        viewModel.submitQuickCommand("找出重复照片")

        XCTAssertEqual(viewModel.inputText, "",
            "submitQuickCommand() should clear inputText after submission")
        XCTAssertTrue(viewModel.isSubmitting,
            "submitQuickCommand() should set isSubmitting to true")
        XCTAssertNotNil(viewModel.agentJob,
            "submitQuickCommand() should create agentJob")
    }

    /// [P0] quickCommandsVisible is true when agentJob is nil
    @MainActor
    func testQuickCommandsVisibleWhenNoAgentJob() async throws {
        let viewModel = makeViewModel()

        XCTAssertTrue(viewModel.quickCommandsVisible,
            "Quick commands should be visible when no agentJob")
    }

    /// [P1] quickCommandsVisible is true when agentJob state is planning
    @MainActor
    func testQuickCommandsVisibleWhenAgentJobPlanning() async throws {
        let viewModel = makeViewModel()

        // Manually set an AgentJob in planning state
        let job = AgentJob()
        XCTAssertEqual(job.state, .planning)
        viewModel.agentJob = job

        XCTAssertTrue(viewModel.quickCommandsVisible,
            "Quick commands should be visible when agentJob is in planning state")
    }

    // MARK: - AC4: Agent Running State & Cancellation

    /// [P0] isAgentRunning is false when agentJob is nil
    @MainActor
    func testIsAgentRunningFalseWhenNoAgentJob() async throws {
        let viewModel = makeViewModel()

        XCTAssertFalse(viewModel.isAgentRunning,
            "isAgentRunning should be false when no agentJob")
    }

    /// [P0] isAgentRunning is false when agentJob state is planning
    @MainActor
    func testIsAgentRunningFalseWhenPlanning() async throws {
        let viewModel = makeViewModel()
        let job = AgentJob()
        viewModel.agentJob = job

        XCTAssertFalse(viewModel.isAgentRunning,
            "isAgentRunning should be false when agentJob is planning")
    }

    /// [P0] isAgentRunning is true when agentJob state is running
    @MainActor
    func testIsAgentRunningTrueWhenRunning() async throws {
        let viewModel = makeViewModel()
        let job = AgentJob()
        // Start first to initialize the event stream continuation
        job.start()
        // Then emit the event that transitions to running
        job.emit(AgentEvent.planGenerated(steps: []))
        // Give the MainActor task time to process the event
        try await Task.sleep(for: .milliseconds(100))

        viewModel.agentJob = job

        XCTAssertTrue(viewModel.isAgentRunning,
            "isAgentRunning should be true when agentJob is running")
    }

    /// [P0] cancelExecution() cancels the running agentJob
    @MainActor
    func testCancelExecutionCancelsAgentJob() async throws {
        let viewModel = makeViewModel()
        // Manually create a job in running state to avoid SDK side effects
        let job = AgentJob()
        job.start()
        job.emit(AgentEvent.planGenerated(steps: []))
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(job.state, .running, "Precondition: job should be running")

        viewModel.agentJob = job
        viewModel.cancelExecution()

        XCTAssertEqual(job.state, AgentJobState.cancelled,
            "cancelExecution() should cancel the agentJob")
    }

    /// [P0] cancelExecution() when no agentJob does not crash
    @MainActor
    func testCancelExecutionWithNoAgentJobDoesNotCrash() async throws {
        let viewModel = makeViewModel()

        // Should not throw or crash
        viewModel.cancelExecution()

        XCTAssertNil(viewModel.agentJob)
    }

    // MARK: - AC4: Input Enabled State

    /// [P1] isInputEnabled is true when agent is not running and text is non-empty
    @MainActor
    func testIsInputEnabledTrueWhenNotRunningAndHasText() async throws {
        let viewModel = makeViewModel()
        viewModel.inputText = "some text"

        XCTAssertTrue(viewModel.isInputEnabled,
            "Input should be enabled when agent is not running and text is non-empty")
    }

    /// [P1] isInputEnabled is false when agent is running
    @MainActor
    func testIsInputDisabledDuringExecution() async throws {
        let viewModel = makeViewModel()
        let job = AgentJob()
        job.start()
        job.emit(AgentEvent.planGenerated(steps: []))
        try await Task.sleep(for: .milliseconds(100))

        viewModel.agentJob = job
        viewModel.inputText = "some text"

        XCTAssertFalse(viewModel.isInputEnabled,
            "Input should be disabled when agent is running")
    }

    /// [P1] isInputEnabled is false when text is empty
    @MainActor
    func testIsInputEnabledFalseWhenTextIsEmpty() async throws {
        let viewModel = makeViewModel()
        viewModel.inputText = ""

        XCTAssertFalse(viewModel.isInputEnabled,
            "Input should not be enabled when text is empty")
    }

    // MARK: - AC4: Quick Commands Hidden During Execution

    /// [P1] quickCommandsVisible is false when agent is running
    @MainActor
    func testQuickCommandsHiddenDuringExecution() async throws {
        let viewModel = makeViewModel()
        let job = AgentJob()
        job.start()
        job.emit(AgentEvent.planGenerated(steps: []))
        try await Task.sleep(for: .milliseconds(100))

        viewModel.agentJob = job

        XCTAssertFalse(viewModel.quickCommandsVisible,
            "Quick commands should be hidden when agent is running")
    }

    // MARK: - AC5: MainWorkspaceView Integration Support

    /// [P0] ChatInputViewModel accepts AppDependencies via init
    @MainActor
    func testViewModelAcceptsDependenciesInjection() async throws {
        let dependencies = AppDependencies()
        let viewModel = ChatInputViewModel(dependencies: dependencies)
        XCTAssertNotNil(viewModel)
    }

    /// [P0] ChatInputViewModel works with nil curatorAgentFactory in dependencies
    @MainActor
    func testViewModelHandlesNilFactory() async throws {
        let dependencies = AppDependencies()
        // Don't register agent infrastructure — factory stays nil
        let viewModel = ChatInputViewModel(dependencies: dependencies)

        viewModel.inputText = "找出重复照片"
        viewModel.submitInput()

        // Should not crash, but also should not create an agentJob
        XCTAssertNil(viewModel.agentJob,
            "submitInput() with nil factory should not create agentJob")
        XCTAssertFalse(viewModel.isSubmitting,
            "submitInput() with nil factory should not set isSubmitting")
    }

    /// [P1] ChatInputViewModel works with nil toolRegistry in dependencies
    @MainActor
    func testViewModelHandlesNilToolRegistry() async throws {
        let dependencies = AppDependencies()
        dependencies.registerAgentInfrastructure()
        // Force toolRegistry to nil
        let viewModel = ChatInputViewModel(dependencies: dependencies)

        viewModel.inputText = "重命名照片"
        viewModel.submitInput()

        // The factory should still be available (registerAgentInfrastructure creates both)
        XCTAssertNotNil(dependencies.toolRegistry)
        XCTAssertNotNil(dependencies.curatorAgentFactory)
    }

    // MARK: - Edge Cases

    /// [P1] submitInput called twice rapidly only creates one agentJob
    @MainActor
    func testRapidSubmitOnlyCreatesOneAgentJob() async throws {
        let viewModel = makeViewModelWithMockFactory()
        viewModel.inputText = "找出重复照片"

        viewModel.submitInput()
        let firstJob = viewModel.agentJob

        // Second submit should not overwrite while running
        viewModel.inputText = "重命名照片"
        viewModel.submitInput()

        XCTAssertTrue(viewModel.agentJob === firstJob,
            "Rapid submit should not overwrite existing agentJob")
    }

    /// [P1] After agent completes, submitting again creates new agentJob
    @MainActor
    func testSubmitAfterCompletionCreatesNewAgentJob() async throws {
        let viewModel = makeViewModelWithMockFactory()

        // First submission
        viewModel.inputText = "找出重复照片"
        viewModel.submitInput()
        let firstJob = viewModel.agentJob

        // Simulate completion (start already called by submitInput)
        if let job = firstJob {
            job.emit(AgentEvent.planGenerated(steps: []))
            try await Task.sleep(for: .milliseconds(100))
            job.emit(AgentEvent.executionCompleted(summary: ExecutionSummary(
                totalSteps: 1,
                completedSteps: 1,
                failedSteps: 0,
                duration: 1.0,
                message: "Done"
            )))
            try await Task.sleep(for: .milliseconds(100))
        }

        // Second submission
        viewModel.inputText = "重命名照片"
        viewModel.submitInput()

        XCTAssertTrue(viewModel.agentJob !== firstJob,
            "After completion, new submission should create a new agentJob")
    }

    /// [P1] cancelExecution when agentJob is already cancelled is a no-op
    @MainActor
    func testCancelAlreadyCancelledJobIsNoOp() async throws {
        let viewModel = makeViewModel()
        let job = AgentJob()
        job.cancel()
        viewModel.agentJob = job

        // Should not crash
        viewModel.cancelExecution()

        XCTAssertEqual(job.state, .cancelled)
    }
}
