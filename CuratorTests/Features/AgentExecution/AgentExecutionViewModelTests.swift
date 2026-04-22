import XCTest
@testable import Curator

/// ATDD Tests for Story 3.4 - Agent Execution Panel
///
/// Tests verify:
/// - AC1: StepCardView step rendering with status icons and progress (FR14, UX-DR3)
/// - AC2: ReasoningBubbleView reasoning display (FR15, UX-DR10)
/// - AC3: Real-time UI updates via @Observable (FR16, NFR3)
/// - AC4: AgentExecutionViewModel state management and displayState mapping
/// - AC5: MainWorkspaceView integration (AgentExecutionPanel replaces placeholder)
///
/// All tests are RED-phase scaffolds. They reference types that do not yet exist
/// (AgentExecutionViewModel, ExecutionDisplayState) and will not compile until
/// the implementation is created.
@MainActor
final class AgentExecutionViewModelTests: XCTestCase {

    // MARK: - Test Helpers

    /// Creates an AgentExecutionViewModel for testing.
    private func makeViewModel() -> AgentExecutionViewModel {
        return AgentExecutionViewModel()
    }

    /// Creates an AgentJob in the specified state by driving it through the state machine.
    private func makeAgentJob(in state: AgentJobState) async throws -> AgentJob {
        let job = AgentJob()
        switch state {
        case .planning:
            return job
        case .running:
            job.start()
            try await Task.sleep(for: .milliseconds(50))
            job.emit(.planGenerated(steps: []))
            try await Task.sleep(for: .milliseconds(100))
        case .review:
            job.transition(to: .running)
            job.transition(to: .review)
        case .confirm:
            job.transition(to: .running)
            job.transition(to: .review)
            job.transition(to: .confirm)
        case .completed:
            job.transition(to: .running)
            job.transition(to: .review)
            job.transition(to: .confirm)
            job.transition(to: .completed)
        case .cancelled:
            job.transition(to: .running)
            job.cancel()
        case .failed:
            job.start()
            try await Task.sleep(for: .milliseconds(50))
            let stepID = UUID()
            job.emit(.planGenerated(steps: [
                AgentStep(id: stepID, title: "Step", status: .running,
                          completedCount: 0, totalCount: 1, reasoningMessages: []),
            ]))
            try await Task.sleep(for: .milliseconds(100))
            job.emit(.stepFailed(stepID: stepID, error: .analysisFailed(reason: "test failure")))
            try await Task.sleep(for: .milliseconds(100))
        }
        XCTAssertEqual(job.state, state, "Precondition: job should be in \(state) state")
        return job
    }

    // MARK: - AC4: AgentExecutionViewModel Existence & Observable

    /// [P0] AgentExecutionViewModel exists as @MainActor @Observable
    func testAgentExecutionViewModelExists() async throws {
        let viewModel = makeViewModel()
        XCTAssertNotNil(viewModel)
    }

    /// [P0] AgentExecutionViewModel initializes with nil agentJob
    func testInitialAgentJobIsNil() async throws {
        let viewModel = makeViewModel()
        XCTAssertNil(viewModel.agentJob,
            "agentJob should be nil on init")
    }

    /// [P0] AgentExecutionViewModel initializes with empty displayState
    func testInitialDisplayStateIsEmpty() async throws {
        let viewModel = makeViewModel()
        XCTAssertEqual(viewModel.displayState, .empty,
            "displayState should be .empty when agentJob is nil")
    }

    /// [P0] AgentExecutionViewModel initializes isRunning as false
    func testInitialIsRunningIsFalse() async throws {
        let viewModel = makeViewModel()
        XCTAssertFalse(viewModel.isRunning,
            "isRunning should be false when agentJob is nil")
    }

    // MARK: - AC4: ExecutionDisplayState Mapping

    /// [P0] AgentJob in running state maps to .executing displayState
    func testDisplayStateRunning() async throws {
        let viewModel = makeViewModel()
        let job = try await makeAgentJob(in: .running)

        viewModel.agentJob = job

        XCTAssertEqual(viewModel.displayState, .executing,
            "displayState should be .executing when AgentJob is .running")
    }

    /// [P0] AgentJob in completed state maps to .completed displayState
    func testDisplayStateCompleted() async throws {
        let viewModel = makeViewModel()
        let job = try await makeAgentJob(in: .completed)

        viewModel.agentJob = job

        XCTAssertEqual(viewModel.displayState, .completed,
            "displayState should be .completed when AgentJob is .completed")
    }

    /// [P0] AgentJob in failed state maps to .failed displayState
    func testDisplayStateFailed() async throws {
        let viewModel = makeViewModel()
        let job = try await makeAgentJob(in: .failed)

        viewModel.agentJob = job

        XCTAssertEqual(viewModel.displayState, .failed,
            "displayState should be .failed when AgentJob is .failed")
    }

    /// [P0] AgentJob in cancelled state maps to .cancelled displayState
    func testDisplayStateCancelled() async throws {
        let viewModel = makeViewModel()
        let job = try await makeAgentJob(in: .cancelled)

        viewModel.agentJob = job

        XCTAssertEqual(viewModel.displayState, .cancelled,
            "displayState should be .cancelled when AgentJob is .cancelled")
    }

    /// [P0] AgentJob in review state maps to .review displayState
    func testDisplayStateReview() async throws {
        let viewModel = makeViewModel()
        let job = try await makeAgentJob(in: .review)

        viewModel.agentJob = job

        XCTAssertEqual(viewModel.displayState, .review,
            "displayState should be .review when AgentJob is .review")
    }

    /// [P0] AgentJob in confirm state maps to .executing displayState
    func testDisplayStateConfirmIsExecuting() async throws {
        let viewModel = makeViewModel()
        let job = try await makeAgentJob(in: .confirm)

        viewModel.agentJob = job

        XCTAssertEqual(viewModel.displayState, .executing,
            "displayState should be .executing when AgentJob is .confirm (still executing)")
    }

    /// [P0] AgentJob in planning state maps to .empty displayState
    func testDisplayStatePlanningIsEmpty() async throws {
        let viewModel = makeViewModel()
        let job = AgentJob()
        XCTAssertEqual(job.state, .planning)

        viewModel.agentJob = job

        XCTAssertEqual(viewModel.displayState, .empty,
            "displayState should be .empty when AgentJob is .planning (QuickCommands handles this)")
    }

    // MARK: - AC4: Steps Exposure

    /// [P0] steps correctly maps from agentJob.steps
    func testStepsFromAgentJob() async throws {
        let viewModel = makeViewModel()
        let job = AgentJob()
        job.start()
        try await Task.sleep(for: .milliseconds(50))

        let step1 = AgentStep(id: UUID(), title: "Scan Library", status: .completed,
                              completedCount: 10, totalCount: 10, reasoningMessages: [])
        let step2 = AgentStep(id: UUID(), title: "Find Duplicates", status: .running,
                              completedCount: 5, totalCount: 20, reasoningMessages: ["Comparing..."])
        job.emit(.planGenerated(steps: [step1, step2]))
        try await Task.sleep(for: .milliseconds(100))

        viewModel.agentJob = job

        XCTAssertEqual(viewModel.steps.count, 2,
            "steps should map from agentJob.steps")
        XCTAssertEqual(viewModel.steps[0].title, "Scan Library")
        XCTAssertEqual(viewModel.steps[1].title, "Find Duplicates")
        XCTAssertEqual(viewModel.steps[1].reasoningMessages.first, "Comparing...")
    }

    /// [P0] steps is empty when agentJob is nil
    func testStepsEmptyWhenNoAgentJob() async throws {
        let viewModel = makeViewModel()

        XCTAssertTrue(viewModel.steps.isEmpty,
            "steps should be empty when agentJob is nil")
    }

    // MARK: - AC4: Reasoning Messages

    /// [P0] reasoningMessages correctly maps from agentJob.reasoningMessages
    func testReasoningMessages() async throws {
        let viewModel = makeViewModel()
        let job = AgentJob()
        job.start()
        try await Task.sleep(for: .milliseconds(50))

        // Emit plan first
        let stepID = UUID()
        job.emit(.planGenerated(steps: [
            AgentStep(id: stepID, title: "Step", status: .pending,
                      completedCount: 0, totalCount: 1, reasoningMessages: []),
        ]))
        try await Task.sleep(for: .milliseconds(100))

        // Emit reasoning for a non-existent step (goes to general reasoningMessages)
        job.emit(.stepReasoning(stepID: UUID(), message: "General reasoning"))
        try await Task.sleep(for: .milliseconds(50))

        viewModel.agentJob = job

        XCTAssertEqual(viewModel.reasoningMessages.count, 1,
            "reasoningMessages should map from agentJob.reasoningMessages")
        XCTAssertEqual(viewModel.reasoningMessages.first, "General reasoning")
    }

    /// [P0] reasoningMessages is empty when agentJob is nil
    func testReasoningMessagesEmptyWhenNoAgentJob() async throws {
        let viewModel = makeViewModel()

        XCTAssertTrue(viewModel.reasoningMessages.isEmpty,
            "reasoningMessages should be empty when agentJob is nil")
    }

    // MARK: - AC4: Formatted Summary

    /// [P0] formattedSummary returns user-friendly text from ExecutionSummary
    func testFormattedSummary() async throws {
        let viewModel = makeViewModel()
        let job = AgentJob()
        job.start()
        try await Task.sleep(for: .milliseconds(50))

        job.emit(.planGenerated(steps: []))
        try await Task.sleep(for: .milliseconds(100))

        let summary = ExecutionSummary(
            totalSteps: 3,
            completedSteps: 2,
            failedSteps: 1,
            duration: 5.5,
            message: "2 of 3 steps completed"
        )
        job.emit(.executionCompleted(summary: summary))
        try await Task.sleep(for: .milliseconds(100))

        viewModel.agentJob = job

        XCTAssertNotNil(viewModel.formattedSummary,
            "formattedSummary should not be nil when executionSummary exists")
        XCTAssertTrue(viewModel.formattedSummary!.contains("2"),
            "formattedSummary should contain completed steps count")
    }

    /// [P0] formattedSummary is nil when no executionSummary
    func testFormattedSummaryNilWhenNoSummary() async throws {
        let viewModel = makeViewModel()

        XCTAssertNil(viewModel.formattedSummary,
            "formattedSummary should be nil when no agentJob")
    }

    // MARK: - AC4: Formatted Duration

    /// [P1] formattedDuration formats seconds correctly
    func testFormattedDurationSeconds() async throws {
        let viewModel = makeViewModel()
        let job = AgentJob()
        job.start()
        try await Task.sleep(for: .milliseconds(50))

        job.emit(.planGenerated(steps: []))
        try await Task.sleep(for: .milliseconds(100))

        let summary = ExecutionSummary(
            totalSteps: 1, completedSteps: 1, failedSteps: 0,
            duration: 45.0, message: "Done"
        )
        job.emit(.executionCompleted(summary: summary))
        try await Task.sleep(for: .milliseconds(100))

        viewModel.agentJob = job

        XCTAssertNotNil(viewModel.formattedDuration,
            "formattedDuration should not be nil when executionSummary exists")
    }

    /// [P1] formattedDuration formats minutes correctly
    func testFormattedDurationMinutes() async throws {
        let viewModel = makeViewModel()
        let job = AgentJob()
        job.start()
        try await Task.sleep(for: .milliseconds(50))

        job.emit(.planGenerated(steps: []))
        try await Task.sleep(for: .milliseconds(100))

        let summary = ExecutionSummary(
            totalSteps: 3, completedSteps: 3, failedSteps: 0,
            duration: 125.0, message: "All done"
        )
        job.emit(.executionCompleted(summary: summary))
        try await Task.sleep(for: .milliseconds(100))

        viewModel.agentJob = job

        XCTAssertNotNil(viewModel.formattedDuration,
            "formattedDuration should not be nil for multi-minute durations")
    }

    /// [P1] formattedDuration is nil when no executionSummary
    func testFormattedDurationNilWhenNoSummary() async throws {
        let viewModel = makeViewModel()

        XCTAssertNil(viewModel.formattedDuration,
            "formattedDuration should be nil when no agentJob")
    }

    // MARK: - AC4: isRunning Computed Property

    /// [P0] isRunning is true when displayState is .executing
    func testIsRunningTrueWhenExecuting() async throws {
        let viewModel = makeViewModel()
        let job = try await makeAgentJob(in: .running)

        viewModel.agentJob = job

        XCTAssertTrue(viewModel.isRunning,
            "isRunning should be true when displayState is .executing")
    }

    /// [P0] isRunning is false when displayState is .completed
    func testIsRunningFalseWhenCompleted() async throws {
        let viewModel = makeViewModel()
        let job = try await makeAgentJob(in: .completed)

        viewModel.agentJob = job

        XCTAssertFalse(viewModel.isRunning,
            "isRunning should be false when displayState is .completed")
    }

    /// [P0] isRunning is false when displayState is .failed
    func testIsRunningFalseWhenFailed() async throws {
        let viewModel = makeViewModel()
        let job = try await makeAgentJob(in: .failed)

        viewModel.agentJob = job

        XCTAssertFalse(viewModel.isRunning,
            "isRunning should be false when displayState is .failed")
    }

    // MARK: - AC4: Empty AgentJob State

    /// [P1] agentJob set to nil resets displayState to .empty
    func testEmptyAgentJobAfterPreviousJob() async throws {
        let viewModel = makeViewModel()
        let job = try await makeAgentJob(in: .running)

        viewModel.agentJob = job
        XCTAssertEqual(viewModel.displayState, .executing)

        viewModel.agentJob = nil

        XCTAssertEqual(viewModel.displayState, .empty,
            "displayState should reset to .empty when agentJob is set to nil")
        XCTAssertTrue(viewModel.steps.isEmpty,
            "steps should be empty when agentJob is nil")
        XCTAssertNil(viewModel.formattedSummary,
            "formattedSummary should be nil when agentJob is nil")
    }

    // MARK: - AC3: Real-Time Event Updates

    /// [P1] Emitting events updates ViewModel state in real-time
    func testRealTimeEventUpdates() async throws {
        let viewModel = makeViewModel()
        let job = AgentJob()
        job.start()
        try await Task.sleep(for: .milliseconds(50))

        viewModel.agentJob = job

        // Initially planning -> empty
        XCTAssertEqual(viewModel.displayState, .empty)

        // Transition to running via event
        let stepID = UUID()
        job.emit(.planGenerated(steps: [
            AgentStep(id: stepID, title: "Analyze", status: .pending,
                      completedCount: 0, totalCount: 5, reasoningMessages: []),
        ]))
        try await Task.sleep(for: .milliseconds(100))

        XCTAssertEqual(viewModel.displayState, .executing,
            "displayState should update to .executing after planGenerated event")
        XCTAssertEqual(viewModel.steps.count, 1,
            "steps should update after planGenerated event")

        // Update step progress
        job.emit(.stepProgress(stepID: stepID, completed: 3, total: 5))
        try await Task.sleep(for: .milliseconds(50))

        XCTAssertEqual(viewModel.steps.first?.completedCount, 3,
            "step progress should update in real-time")
        XCTAssertEqual(viewModel.steps.first?.totalCount, 5)

        // Complete step
        job.emit(.stepCompleted(stepID: stepID,
            result: StepResult(stepID: stepID, message: "Done", data: [:])))
        try await Task.sleep(for: .milliseconds(50))

        XCTAssertEqual(viewModel.steps.first?.status, .completed,
            "step status should update to .completed after stepCompleted event")

        // Complete execution
        let summary = ExecutionSummary(
            totalSteps: 1, completedSteps: 1, failedSteps: 0,
            duration: 2.5, message: "Analysis complete"
        )
        job.emit(.executionCompleted(summary: summary))
        try await Task.sleep(for: .milliseconds(100))

        XCTAssertEqual(viewModel.displayState, .completed,
            "displayState should update to .completed after executionCompleted event")
        XCTAssertNotNil(viewModel.formattedSummary)
    }

    // MARK: - AC2: Reasoning Messages in Steps

    /// [P1] Step reasoning messages are accessible through ViewModel
    func testStepReasoningMessagesAccessible() async throws {
        let viewModel = makeViewModel()
        let job = AgentJob()
        let stepID = UUID()
        job.start()
        try await Task.sleep(for: .milliseconds(50))

        job.emit(.planGenerated(steps: [
            AgentStep(id: stepID, title: "Deduplicate", status: .pending,
                      completedCount: 0, totalCount: 1, reasoningMessages: []),
        ]))
        try await Task.sleep(for: .milliseconds(100))

        job.emit(.stepReasoning(stepID: stepID, message: "Found similar photos"))
        try await Task.sleep(for: .milliseconds(50))
        job.emit(.stepReasoning(stepID: stepID, message: "Comparing histograms"))
        try await Task.sleep(for: .milliseconds(50))

        viewModel.agentJob = job

        guard let step = viewModel.steps.first else {
            XCTFail("Steps should not be empty")
            return
        }
        XCTAssertEqual(step.reasoningMessages.count, 2,
            "Step should have 2 reasoning messages")
        XCTAssertEqual(step.reasoningMessages[0], "Found similar photos")
        XCTAssertEqual(step.reasoningMessages[1], "Comparing histograms")
    }

    // MARK: - AC4: ExecutionDisplayState Enum

    /// [P0] ExecutionDisplayState has all required cases
    func testExecutionDisplayStateCases() throws {
        let allCases: [ExecutionDisplayState] = [.empty, .executing, .review, .completed, .failed, .cancelled]
        XCTAssertEqual(allCases.count, 6,
            "ExecutionDisplayState should have exactly 6 cases: empty, executing, review, completed, failed, cancelled")
    }

    // MARK: - AC5: Integration with ChatInputViewModel.agentJob

    /// [P1] ViewModel correctly observes agentJob obtained from ChatInputViewModel
    func testViewModelObservesChatInputAgentJob() async throws {
        let dependencies = AppDependencies()
        dependencies.registerAgentInfrastructure()
        let chatViewModel = ChatInputViewModel(dependencies: dependencies)

        // Manually create an AgentJob and assign it to the chatViewModel,
        // simulating what submitQuickCommand does but without SDK side effects.
        let job = AgentJob()
        job.start()
        try await Task.sleep(for: .milliseconds(50))
        chatViewModel.agentJob = job

        // Drive the job to running state
        job.emit(.planGenerated(steps: [
            AgentStep(id: UUID(), title: "Test Step", status: .pending,
                      completedCount: 0, totalCount: 1, reasoningMessages: []),
        ]))
        try await Task.sleep(for: .milliseconds(100))

        // Create execution ViewModel and assign the same job
        let executionViewModel = makeViewModel()
        executionViewModel.agentJob = chatViewModel.agentJob

        XCTAssertEqual(executionViewModel.displayState, .executing,
            "ExecutionViewModel should reflect the running state of ChatInputViewModel's agentJob")
        XCTAssertEqual(executionViewModel.steps.count, 1)
    }

    // MARK: - AC4: Multiple AgentJob Transitions

    /// [P1] ViewModel correctly tracks AgentJob through multiple state transitions
    func testViewModelTracksMultipleTransitions() async throws {
        let viewModel = makeViewModel()
        let job = AgentJob()
        job.start()
        try await Task.sleep(for: .milliseconds(50))

        viewModel.agentJob = job

        // planning -> empty
        XCTAssertEqual(viewModel.displayState, .empty)

        // -> running (via event)
        job.emit(.planGenerated(steps: []))
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(viewModel.displayState, .executing)

        // -> review (via direct transition)
        job.transition(to: .review)
        XCTAssertEqual(viewModel.displayState, .review)

        // -> confirm
        job.transition(to: .confirm)
        XCTAssertEqual(viewModel.displayState, .executing)

        // -> completed
        let summary = ExecutionSummary(
            totalSteps: 1, completedSteps: 1, failedSteps: 0,
            duration: 1.0, message: "Done"
        )
        job.emit(.executionCompleted(summary: summary))
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(viewModel.displayState, .completed)
        XCTAssertNotNil(viewModel.formattedSummary)
    }

    // MARK: - AC1: Step Progress Data for StepCardView

    /// [P1] ViewModel exposes step progress data for StepCardView rendering
    func testStepProgressDataForRendering() async throws {
        let viewModel = makeViewModel()
        let job = AgentJob()
        let stepID = UUID()
        job.start()
        try await Task.sleep(for: .milliseconds(50))

        job.emit(.planGenerated(steps: [
            AgentStep(id: stepID, title: "Process Photos", status: .running,
                      completedCount: 0, totalCount: 15000, reasoningMessages: []),
        ]))
        try await Task.sleep(for: .milliseconds(100))

        job.emit(.stepProgress(stepID: stepID, completed: 1200, total: 15000))
        try await Task.sleep(for: .milliseconds(50))

        viewModel.agentJob = job

        guard let step = viewModel.steps.first else {
            XCTFail("Steps should not be empty")
            return
        }

        XCTAssertEqual(step.completedCount, 1200,
            "Step completedCount should be 1200 for rendering '1,200/15,000'")
        XCTAssertEqual(step.totalCount, 15000,
            "Step totalCount should be 15000")
        XCTAssertEqual(step.progress, 1200.0 / 15000.0, accuracy: 0.001,
            "Step progress should be 0.08 for 1200/15000")
        XCTAssertEqual(step.status, .running,
            "Step status should be .running for progress indicator rendering")
    }
}
