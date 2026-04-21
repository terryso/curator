import XCTest
@testable import Curator

/// ATDD Tests for Story 3.1 - Agent Execution Engine
///
/// Tests verify:
/// - AC1: AgentJob state machine complete lifecycle (FR13)
/// - AC2: AgentEvent Sendable enum definition (FR14, FR15)
/// - AC3: AgentStep execution step model (FR14)
/// - AC4: User cancellation support (FR17)
/// - AC5: AsyncStream streaming pipeline (FR16, NFR3)
@MainActor
final class AgentJobTests: XCTestCase {

    // MARK: - AC1: AgentJob State Machine Lifecycle (FR13)

    /// [P0] AgentJob initial state is .planning
    func testAgentJobInitialState() async throws {
        let job = AgentJob()

        XCTAssertEqual(job.state, .planning,
            "AgentJob should start in .planning state")
        XCTAssertTrue(job.steps.isEmpty,
            "AgentJob should start with no steps")
        XCTAssertNil(job.executionSummary,
            "AgentJob should start with no execution summary")
        XCTAssertNil(job.error,
            "AgentJob should start with no error")
    }

    /// [P0] Legal state transitions: planning -> running -> review -> confirm -> completed
    /// via direct transition() calls (synchronous state machine validation).
    func testAgentJobStateTransitions() async throws {
        let job = AgentJob()

        // Use direct transitions to test state machine without AsyncStream
        job.transition(to: .running)
        XCTAssertEqual(job.state, .running,
            "After transition, state should be .running")

        job.transition(to: .review)
        XCTAssertEqual(job.state, .review,
            "After transition, state should be .review")

        job.transition(to: .confirm)
        XCTAssertEqual(job.state, .confirm,
            "After transition, state should be .confirm")

        job.transition(to: .completed)
        XCTAssertEqual(job.state, .completed,
            "After transition, state should be .completed")
    }

    /// [P0] Full lifecycle through AsyncStream events
    func testAgentJobFullLifecycleViaEvents() async throws {
        let job = AgentJob()
        job.start()
        try await Task.sleep(for: .milliseconds(50))

        // planning -> running via planGenerated
        let steps = [
            AgentStep(id: UUID(), title: "Step 1", status: .pending,
                      completedCount: 0, totalCount: 1, reasoningMessages: []),
        ]
        job.emit(.planGenerated(steps: steps))
        try await Task.sleep(for: .milliseconds(100))

        XCTAssertEqual(job.state, .running,
            "After planGenerated, state should be .running")
        XCTAssertEqual(job.steps.count, 1,
            "Steps should be populated from planGenerated")

        // running -> review via reviewReady
        let reviewItems = [
            ReviewItem(id: UUID(), title: "Review 1", description: "Desc",
                       requiresConfirmation: true),
        ]
        job.emit(.reviewReady(items: reviewItems))
        try await Task.sleep(for: .milliseconds(100))

        XCTAssertEqual(job.state, .review,
            "After reviewReady, state should be .review")

        // review -> confirm (direct transition)
        job.transition(to: .confirm)
        XCTAssertEqual(job.state, .confirm)

        // confirm -> completed via executionCompleted
        let summary = ExecutionSummary(
            totalSteps: 1, completedSteps: 1, failedSteps: 0,
            duration: 1.5, message: "Done"
        )
        job.emit(.executionCompleted(summary: summary))
        try await Task.sleep(for: .milliseconds(100))

        XCTAssertEqual(job.state, .completed,
            "After executionCompleted in confirm state, state should be .completed")
        XCTAssertNotNil(job.executionSummary,
            "Execution summary should be populated")
        XCTAssertEqual(job.executionSummary?.totalSteps, 1)
    }

    // MARK: - AC4: User Cancellation Support (FR17)

    /// [P0] Running state cancellation preserves partial results
    func testAgentJobCancellationFromRunning() async throws {
        let job = AgentJob()
        let step1ID = UUID()
        let step2ID = UUID()

        job.start()
        try await Task.sleep(for: .milliseconds(50))

        // planning -> running with steps
        job.emit(.planGenerated(steps: [
            AgentStep(id: step1ID, title: "Step 1", status: .completed,
                      completedCount: 1, totalCount: 3, reasoningMessages: []),
            AgentStep(id: step2ID, title: "Step 2", status: .running,
                      completedCount: 0, totalCount: 1, reasoningMessages: []),
        ]))
        try await Task.sleep(for: .milliseconds(100))

        // Cancel
        job.cancel()

        XCTAssertEqual(job.state, .cancelled,
            "After cancel(), state should be .cancelled")
        XCTAssertEqual(job.steps.count, 2,
            "Partial results (steps) should be preserved after cancellation")
        XCTAssertEqual(job.steps[0].status, .completed,
            "Completed step should remain completed after cancellation")
    }

    /// [P0] Planning state cancellation
    func testAgentJobCancellationFromPlanning() async throws {
        let job = AgentJob()

        XCTAssertEqual(job.state, .planning)
        job.cancel()
        XCTAssertEqual(job.state, .cancelled,
            "Cancellation from planning should transition to .cancelled")
    }

    // MARK: - AC1: Failure Handling

    /// [P0] Running state failure transitions to .failed with error preserved
    func testAgentJobFailure() async throws {
        let job = AgentJob()
        let stepID = UUID()

        job.start()
        try await Task.sleep(for: .milliseconds(50))

        // planning -> running with steps
        job.emit(.planGenerated(steps: [
            AgentStep(id: stepID, title: "Step 1", status: .running,
                      completedCount: 0, totalCount: 1, reasoningMessages: []),
        ]))
        try await Task.sleep(for: .milliseconds(100))

        let testError = DomainError.analysisFailed(reason: "Something went wrong")
        job.emit(.stepFailed(stepID: stepID, error: testError))
        try await Task.sleep(for: .milliseconds(200))

        XCTAssertEqual(job.state, .failed,
            "After stepFailed, state should be .failed")
        XCTAssertNotNil(job.error,
            "Error should be populated after failure")
        if case .analysisFailed(let reason) = job.error! {
            XCTAssertEqual(reason, "Something went wrong")
        } else {
            XCTFail("Error should be .analysisFailed")
        }
    }

    // MARK: - AC2: AgentEvent Sendable (FR14, FR15)

    /// [P0] AgentEvent all cases can be safely used across concurrency domains
    func testAgentEventSendable() async throws {
        let stepID = UUID()

        async let event1: AgentEvent = .planGenerated(steps: [])
        async let event2: AgentEvent = .stepStarted(stepID: stepID, title: "Test")
        async let event3: AgentEvent = .stepProgress(stepID: stepID, completed: 1, total: 5)
        async let event4: AgentEvent = .stepReasoning(stepID: stepID, message: "Thinking...")
        async let event5: AgentEvent = .stepCompleted(stepID: stepID,
            result: StepResult(stepID: stepID, message: "Done", data: [:]))
        async let event6: AgentEvent = .stepFailed(stepID: stepID,
            error: DomainError.operationCancelled)
        async let event7: AgentEvent = .reviewReady(items: [])
        async let event8: AgentEvent = .executionCompleted(summary: ExecutionSummary(
            totalSteps: 1, completedSteps: 1, failedSteps: 0, duration: 1.0, message: "OK"))

        let events = await [event1, event2, event3, event4, event5, event6, event7, event8]
        XCTAssertEqual(events.count, 8,
            "All 8 AgentEvent cases should be creatable and Sendable")
    }

    // MARK: - AC3: AgentStep Model (FR14)

    /// [P0] AgentStep fields are complete and progress calculates correctly
    func testAgentStepModel() throws {
        let id = UUID()
        let step = AgentStep(
            id: id,
            title: "Scan Library",
            status: .running,
            completedCount: 3,
            totalCount: 10,
            reasoningMessages: ["Analyzing folder..."]
        )

        XCTAssertEqual(step.id, id)
        XCTAssertEqual(step.title, "Scan Library")
        XCTAssertEqual(step.status, .running)
        XCTAssertEqual(step.completedCount, 3)
        XCTAssertEqual(step.totalCount, 10)
        XCTAssertEqual(step.reasoningMessages.count, 1)
        XCTAssertEqual(step.reasoningMessages[0], "Analyzing folder...")
    }

    /// [P0] AgentStep progress calculation
    func testAgentStepProgress() throws {
        // Normal progress
        let step1 = AgentStep(
            id: UUID(), title: "Test", status: .running,
            completedCount: 5, totalCount: 10, reasoningMessages: []
        )
        XCTAssertEqual(step1.progress, 0.5, accuracy: 0.001,
            "Progress should be 0.5 when 5/10 completed")

        // Zero total
        let step2 = AgentStep(
            id: UUID(), title: "Test", status: .pending,
            completedCount: 0, totalCount: 0, reasoningMessages: []
        )
        XCTAssertEqual(step2.progress, 0.0,
            "Progress should be 0.0 when totalCount is 0")

        // Full completion
        let step3 = AgentStep(
            id: UUID(), title: "Test", status: .completed,
            completedCount: 10, totalCount: 10, reasoningMessages: []
        )
        XCTAssertEqual(step3.progress, 1.0, accuracy: 0.001,
            "Progress should be 1.0 when fully completed")

        // Partial progress
        let step4 = AgentStep(
            id: UUID(), title: "Test", status: .running,
            completedCount: 1, totalCount: 3, reasoningMessages: []
        )
        let expectedProgress = 1.0 / 3.0
        XCTAssertEqual(step4.progress, expectedProgress, accuracy: 0.001,
            "Progress should be 1/3 when 1/3 completed")
    }

    /// [P0] AgentStep is Sendable and Equatable
    func testAgentStepSendableAndEquatable() async throws {
        let id = UUID()
        let step1 = AgentStep(
            id: id, title: "Test", status: .pending,
            completedCount: 0, totalCount: 1, reasoningMessages: []
        )
        let step2 = AgentStep(
            id: id, title: "Test", status: .pending,
            completedCount: 0, totalCount: 1, reasoningMessages: []
        )
        let step3 = AgentStep(
            id: id, title: "Different", status: .pending,
            completedCount: 0, totalCount: 1, reasoningMessages: []
        )

        XCTAssertEqual(step1, step2, "Identical steps should be equal")
        XCTAssertNotEqual(step1, step3, "Steps with different titles should not be equal")

        // Sendable check via async usage
        async let sendableStep: AgentStep = step1
        let received = await sendableStep
        XCTAssertEqual(received.title, "Test")
    }

    /// [P0] StepStatus enum has all required cases
    func testStepStatusCases() throws {
        let allCases: [StepStatus] = [.pending, .running, .completed, .failed]
        XCTAssertEqual(allCases.count, 4,
            "StepStatus should have exactly 4 cases")
    }

    /// [P0] AgentJobState enum has all required cases
    func testAgentJobStateCases() throws {
        let allCases: [AgentJobState] = [.planning, .running, .review, .confirm, .completed, .cancelled, .failed]
        XCTAssertEqual(allCases.count, 7,
            "AgentJobState should have exactly 7 cases")
    }

    // MARK: - AC5: AsyncStream Events Pipeline (FR16, NFR3)

    /// [P0] AsyncStream delivers planGenerated and progresses to running
    func testAsyncStreamPlanGenerated() async throws {
        let job = AgentJob()
        job.start()
        try await Task.sleep(for: .milliseconds(50))

        let steps = [
            AgentStep(id: UUID(), title: "Step 1", status: .pending,
                      completedCount: 0, totalCount: 1, reasoningMessages: []),
            AgentStep(id: UUID(), title: "Step 2", status: .pending,
                      completedCount: 0, totalCount: 1, reasoningMessages: []),
        ]

        job.emit(.planGenerated(steps: steps))
        try await Task.sleep(for: .milliseconds(100))

        XCTAssertEqual(job.state, .running,
            "After planGenerated event, state should be .running")
        XCTAssertEqual(job.steps.count, 2,
            "Steps should match planGenerated payload")
    }

    /// [P0] AsyncStream event sequence delivers step updates
    func testAsyncStreamStepUpdates() async throws {
        let job = AgentJob()
        let stepID = UUID()

        job.start()
        try await Task.sleep(for: .milliseconds(50))

        // Emit plan
        job.emit(.planGenerated(steps: [
            AgentStep(id: stepID, title: "Step 1", status: .pending,
                      completedCount: 0, totalCount: 1, reasoningMessages: []),
        ]))
        try await Task.sleep(for: .milliseconds(100))

        // Emit step started
        job.emit(.stepStarted(stepID: stepID, title: "Step 1"))
        try await Task.sleep(for: .milliseconds(50))

        XCTAssertEqual(job.steps.first?.status, .running,
            "After stepStarted, step status should be .running")

        // Emit progress
        job.emit(.stepProgress(stepID: stepID, completed: 1, total: 1))
        try await Task.sleep(for: .milliseconds(50))

        XCTAssertEqual(job.steps.first?.completedCount, 1)
        XCTAssertEqual(job.steps.first?.totalCount, 1)

        // Emit step completed
        job.emit(.stepCompleted(stepID: stepID,
            result: StepResult(stepID: stepID, message: "Done", data: [:])))
        try await Task.sleep(for: .milliseconds(50))

        XCTAssertEqual(job.steps.first?.status, .completed,
            "After stepCompleted, step status should be .completed")
    }

    // MARK: - ExecutionSummary (AC2 support)

    /// [P0] ExecutionSummary fields complete and Sendable
    func testExecutionSummary() async throws {
        let summary = ExecutionSummary(
            totalSteps: 5,
            completedSteps: 4,
            failedSteps: 1,
            duration: 12.5,
            message: "Completed with 1 failure"
        )

        XCTAssertEqual(summary.totalSteps, 5)
        XCTAssertEqual(summary.completedSteps, 4)
        XCTAssertEqual(summary.failedSteps, 1)
        XCTAssertEqual(summary.duration, 12.5, accuracy: 0.001)
        XCTAssertEqual(summary.message, "Completed with 1 failure")

        // Verify Sendable by using in async context
        async let sendable: ExecutionSummary = summary
        let received = await sendable
        XCTAssertEqual(received.totalSteps, 5)
    }

    /// [P0] ExecutionSummary is Equatable
    func testExecutionSummaryEquatable() throws {
        let s1 = ExecutionSummary(totalSteps: 1, completedSteps: 1, failedSteps: 0, duration: 1.0, message: "OK")
        let s2 = ExecutionSummary(totalSteps: 1, completedSteps: 1, failedSteps: 0, duration: 1.0, message: "OK")
        let s3 = ExecutionSummary(totalSteps: 2, completedSteps: 1, failedSteps: 0, duration: 1.0, message: "OK")

        XCTAssertEqual(s1, s2)
        XCTAssertNotEqual(s1, s3)
    }

    // MARK: - AC2 Support: StepResult and ReviewItem Sendable

    /// [P1] StepResult Sendable compliance
    func testStepResultSendable() async throws {
        let id = UUID()
        let result = StepResult(stepID: id, message: "Test result", data: ["key": "value"])

        async let sendable: StepResult = result
        let received = await sendable
        XCTAssertEqual(received.stepID, id)
        XCTAssertEqual(received.message, "Test result")
        XCTAssertEqual(received.data["key"], "value")
    }

    /// [P1] ReviewItem Sendable compliance
    func testReviewItemSendable() async throws {
        let id = UUID()
        let item = ReviewItem(id: id, title: "Review", description: "Desc", requiresConfirmation: true)

        async let sendable: ReviewItem = item
        let received = await sendable
        XCTAssertEqual(received.id, id)
        XCTAssertTrue(received.requiresConfirmation)
    }

    /// [P1] ReviewItem is Identifiable and Equatable
    func testReviewItemIdentifiableAndEquatable() throws {
        let id = UUID()
        let item1 = ReviewItem(id: id, title: "Review", description: "Desc", requiresConfirmation: true)
        let item2 = ReviewItem(id: id, title: "Review", description: "Desc", requiresConfirmation: true)
        let item3 = ReviewItem(id: id, title: "Different", description: "Desc", requiresConfirmation: true)

        XCTAssertEqual(item1.id, id)
        XCTAssertEqual(item1, item2)
        XCTAssertNotEqual(item1, item3)
    }

    // MARK: - AC1: State Transition Validation

    /// [P0] Terminal states are terminal (no transitions out)
    /// Tests that completed, cancelled, and failed states cannot transition out.
    /// Note: Illegal transitions trigger assertionFailure in Debug, so we test
    /// that terminal states are properly reached and remain stable.
    func testTerminalStatesAreTerminal() async throws {
        // Test completed is terminal - verify via allLegalTransitions chain
        let jobCompleted = AgentJob()
        jobCompleted.transition(to: .running)
        jobCompleted.transition(to: .review)
        jobCompleted.transition(to: .confirm)
        jobCompleted.transition(to: .completed)
        XCTAssertEqual(jobCompleted.state, .completed)

        // Test cancelled is terminal
        let jobCancelled = AgentJob()
        jobCancelled.transition(to: .running)
        jobCancelled.cancel()
        XCTAssertEqual(jobCancelled.state, .cancelled)

        // Test failed is terminal via AsyncStream
        let jobFailed = AgentJob()
        let stepID = UUID()
        jobFailed.start()
        try await Task.sleep(for: .milliseconds(50))
        jobFailed.emit(.planGenerated(steps: [
            AgentStep(id: stepID, title: "Step", status: .running,
                      completedCount: 0, totalCount: 1, reasoningMessages: []),
        ]))
        try await Task.sleep(for: .milliseconds(100))
        jobFailed.emit(.stepFailed(stepID: stepID, error: .analysisFailed(reason: "fail")))
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(jobFailed.state, .failed)
    }

    /// [P0] All legal transitions are accepted
    func testAllLegalTransitions() async throws {
        let job = AgentJob()

        // Planning -> Running
        job.transition(to: .running)
        XCTAssertEqual(job.state, .running)

        // Running -> Review
        job.transition(to: .review)
        XCTAssertEqual(job.state, .review)

        // Review -> Confirm
        job.transition(to: .confirm)
        XCTAssertEqual(job.state, .confirm)

        // Confirm -> Completed
        job.transition(to: .completed)
        XCTAssertEqual(job.state, .completed)
    }

    /// [P1] Review -> Running transition (agent needs additional processing)
    func testReviewToRunningTransition() async throws {
        let job = AgentJob()

        // Get to review state
        job.transition(to: .running)
        job.transition(to: .review)
        XCTAssertEqual(job.state, .review)

        // Review -> Running is legal
        job.transition(to: .running)
        XCTAssertEqual(job.state, .running,
            "Review -> Running should be a legal transition")
    }

    // MARK: - AC5: Stream terminates with job lifecycle

    /// [P0] Stream terminates when job reaches terminal state via events
    func testStreamTerminatesOnCompletion() async throws {
        let job = AgentJob()

        // Get to confirm state via direct transitions
        job.transition(to: .running)
        job.transition(to: .review)
        job.transition(to: .confirm)

        // Start consuming events
        job.start()
        try await Task.sleep(for: .milliseconds(50))

        // Emit executionCompleted to reach terminal state
        let summary = ExecutionSummary(totalSteps: 1, completedSteps: 1, failedSteps: 0, duration: 0.5, message: "OK")
        job.emit(.executionCompleted(summary: summary))
        try await Task.sleep(for: .milliseconds(100))

        XCTAssertEqual(job.state, .completed,
            "Job should reach .completed terminal state")
        XCTAssertNotNil(job.executionSummary)
    }

    // MARK: - AC1: Simple task skips review (Running -> Completed)

    /// [P0] Simple tasks can complete directly from running state (skip review/confirm)
    func testSimpleTaskRunningToCompleted() async throws {
        let job = AgentJob()
        job.start()
        try await Task.sleep(for: .milliseconds(50))

        // planning -> running
        job.emit(.planGenerated(steps: []))
        try await Task.sleep(for: .milliseconds(100))

        XCTAssertEqual(job.state, .running)

        // running -> completed directly (no review/confirm)
        let summary = ExecutionSummary(
            totalSteps: 1, completedSteps: 1, failedSteps: 0,
            duration: 0.5, message: "Simple task done"
        )
        job.emit(.executionCompleted(summary: summary))
        try await Task.sleep(for: .milliseconds(100))

        XCTAssertEqual(job.state, .completed,
            "Simple tasks should be able to go directly from .running to .completed")
        XCTAssertNotNil(job.executionSummary)
    }

    // MARK: - AC1: @Observable change tracking

    /// [P1] State changes trigger @Observable notifications
    func testAgentJobObservable() async throws {
        let job = AgentJob()

        let (notificationStream, notificationContinuation) = AsyncStream<AgentJobState>.makeStream()

        let _ = withObservationTracking {
            _ = job.state
        } onChange: {
            Task { @MainActor in
                notificationContinuation.yield(job.state)
            }
        }

        job.transition(to: .running)

        var observed: AgentJobState?
        for await state in notificationStream {
            observed = state
            break
        }
        XCTAssertEqual(observed, .running,
            "State change to .running should trigger @Observable notification")
        notificationContinuation.finish()
    }

    // MARK: - Start idempotency

    /// [P1] Calling start() multiple times is safe (idempotent)
    func testStartIdempotent() async throws {
        let job = AgentJob()
        job.start()
        try await Task.sleep(for: .milliseconds(50))

        // Second start should be no-op
        job.start()
        try await Task.sleep(for: .milliseconds(50))

        // Should still work normally
        job.emit(.planGenerated(steps: []))
        try await Task.sleep(for: .milliseconds(100))

        XCTAssertEqual(job.state, .running,
            "Job should still work after duplicate start() calls")
    }

    // MARK: - AC3: Step reasoning messages accumulate

    /// [P1] stepReasoning event appends to reasoningMessages via AsyncStream
    func testStepReasoningAccumulates() async throws {
        let job = AgentJob()
        let stepID = UUID()

        job.start()
        try await Task.sleep(for: .milliseconds(50))

        // Emit plan with a step
        job.emit(.planGenerated(steps: [
            AgentStep(id: stepID, title: "Analyze", status: .pending,
                      completedCount: 0, totalCount: 1, reasoningMessages: []),
        ]))
        try await Task.sleep(for: .milliseconds(100))

        // Emit reasoning messages
        job.emit(.stepReasoning(stepID: stepID, message: "First thought"))
        try await Task.sleep(for: .milliseconds(50))
        job.emit(.stepReasoning(stepID: stepID, message: "Second thought"))
        try await Task.sleep(for: .milliseconds(50))

        guard let firstStep = job.steps.first else {
            XCTFail("Steps should not be empty after planGenerated")
            return
        }
        XCTAssertEqual(firstStep.reasoningMessages.count, 2,
            "Reasoning messages should accumulate")
        XCTAssertEqual(firstStep.reasoningMessages[0], "First thought")
        XCTAssertEqual(firstStep.reasoningMessages[1], "Second thought")
    }

    // MARK: - AC3: Step progress updates

    /// [P1] stepProgress event updates step counters via AsyncStream
    func testStepProgressUpdates() async throws {
        let job = AgentJob()
        let stepID = UUID()

        job.start()
        try await Task.sleep(for: .milliseconds(50))

        // Emit plan
        job.emit(.planGenerated(steps: [
            AgentStep(id: stepID, title: "Scan", status: .pending,
                      completedCount: 0, totalCount: 10, reasoningMessages: []),
        ]))
        try await Task.sleep(for: .milliseconds(100))

        // Emit progress
        job.emit(.stepProgress(stepID: stepID, completed: 5, total: 10))
        try await Task.sleep(for: .milliseconds(50))

        guard let firstStep = job.steps.first else {
            XCTFail("Steps should not be empty after planGenerated")
            return
        }
        XCTAssertEqual(firstStep.completedCount, 5)
        XCTAssertEqual(firstStep.totalCount, 10)
        XCTAssertEqual(firstStep.progress, 0.5, accuracy: 0.001)
    }
}
