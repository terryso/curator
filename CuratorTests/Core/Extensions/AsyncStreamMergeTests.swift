import XCTest
@testable import Curator

/// ATDD Tests for Story 3.6 - Agent Real-time Streaming Communication
///
/// Tests verify:
/// - AC2: Event merge prevents over-rendering (NFR7)
/// - AsyncStream+Extensions.mergeProgressEvents() logic
///
/// TDD RED PHASE: These tests will fail until:
/// - AsyncStream+Extensions.swift is created with mergeProgressEvents()
final class AsyncStreamMergeTests: XCTestCase {

    // MARK: - AC2: Event Merge Prevents Over-Rendering (NFR7)

    /// [P0] Consecutive stepProgress events for the same stepID are merged
    /// into a single event (only the latest kept).
    func testMergeConsecutiveProgressEvents() async throws {
        let stepID = UUID()

        // Build an input stream with 5 consecutive stepProgress events
        let (inputStream, inputContinuation) = AsyncStream<AgentEvent>.makeStream()

        for i in 1...5 {
            inputContinuation.yield(.stepProgress(stepID: stepID, completed: i, total: 5))
        }
        // Add a non-progress event to flush the merge window
        inputContinuation.yield(.stepCompleted(stepID: stepID, result: StepResult(stepID: stepID, message: "Done", data: [:])))
        inputContinuation.finish()

        // Apply merge
        let mergedStream = inputStream.mergeProgressEvents()

        var collectedEvents: [AgentEvent] = []
        for await event in mergedStream {
            collectedEvents.append(event)
        }

        // Should have exactly 2 events: 1 merged stepProgress + 1 stepCompleted
        // (5 consecutive stepProgress merged into 1)
        let progressCount = collectedEvents.filter { if case .stepProgress = $0 { return true } else { return false } }.count
        let completedCount = collectedEvents.filter { if case .stepCompleted = $0 { return true } else { return false } }.count

        XCTAssertEqual(progressCount, 1,
            "5 consecutive stepProgress events should merge into 1")
        XCTAssertEqual(completedCount, 1,
            "stepCompleted should not be merged")

        // The merged progress should have the latest values (completed: 5, total: 5)
        for event in collectedEvents {
            if case .stepProgress(_, let completed, let total) = event {
                XCTAssertEqual(completed, 5,
                    "Merged progress should keep latest completed value")
                XCTAssertEqual(total, 5,
                    "Merged progress should keep latest total value")
            }
        }
    }

    /// [P0] Non-progress events (stepStarted, stepCompleted, stepReasoning) are never merged.
    func testMergePreservesNonProgressEvents() async throws {
        let stepID = UUID()

        let (inputStream, inputContinuation) = AsyncStream<AgentEvent>.makeStream()

        inputContinuation.yield(.stepStarted(stepID: stepID, title: "Test"))
        inputContinuation.yield(.stepReasoning(stepID: stepID, message: "Thinking"))
        inputContinuation.yield(.stepReasoning(stepID: stepID, message: "More thinking"))
        inputContinuation.yield(.stepCompleted(stepID: stepID, result: StepResult(stepID: stepID, message: "Done", data: [:])))
        inputContinuation.finish()

        let mergedStream = inputStream.mergeProgressEvents()

        var collectedEvents: [AgentEvent] = []
        for await event in mergedStream {
            collectedEvents.append(event)
        }

        XCTAssertEqual(collectedEvents.count, 4,
            "Non-progress events should never be merged (stepStarted, 2x stepReasoning, stepCompleted)")
    }

    /// [P0] Event ordering is preserved after merge: non-progress events
    /// appear in the same relative order.
    func testMergePreservesOrdering() async throws {
        let stepID1 = UUID()
        let stepID2 = UUID()

        let (inputStream, inputContinuation) = AsyncStream<AgentEvent>.makeStream()

        inputContinuation.yield(.stepStarted(stepID: stepID1, title: "Step 1"))
        inputContinuation.yield(.stepProgress(stepID: stepID1, completed: 1, total: 3))
        inputContinuation.yield(.stepProgress(stepID: stepID1, completed: 2, total: 3))
        inputContinuation.yield(.stepReasoning(stepID: stepID1, message: "Reasoning"))
        inputContinuation.yield(.stepStarted(stepID: stepID2, title: "Step 2"))
        inputContinuation.yield(.stepProgress(stepID: stepID2, completed: 1, total: 1))
        inputContinuation.yield(.stepCompleted(stepID: stepID2, result: StepResult(stepID: stepID2, message: "Done", data: [:])))
        inputContinuation.finish()

        let mergedStream = inputStream.mergeProgressEvents()

        var collectedEvents: [AgentEvent] = []
        for await event in mergedStream {
            collectedEvents.append(event)
        }

        // Expected order: stepStarted(1), merged stepProgress(1), stepReasoning, stepStarted(2), stepProgress(2), stepCompleted(2)
        // Verify stepStarted(1) comes before stepStarted(2)
        let started1Index = collectedEvents.firstIndex { if case .stepStarted(let id, _) = $0 { return id == stepID1 } else { return false } }
        let started2Index = collectedEvents.firstIndex { if case .stepStarted(let id, _) = $0 { return id == stepID2 } else { return false } }

        XCTAssertNotNil(started1Index)
        XCTAssertNotNil(started2Index)
        XCTAssertLessThan(started1Index!, started2Index!,
            "stepStarted(1) should come before stepStarted(2)")

        // Verify stepReasoning comes between the two stepStarted events
        let reasoningIndex = collectedEvents.firstIndex { if case .stepReasoning = $0 { return true } else { return false } }
        XCTAssertNotNil(reasoningIndex)
        XCTAssertGreaterThan(reasoningIndex!, started1Index!,
            "stepReasoning should come after stepStarted(1)")
        XCTAssertLessThan(reasoningIndex!, started2Index!,
            "stepReasoning should come before stepStarted(2)")
    }

    /// [P1] Progress events separated by a non-progress event are not merged together.
    /// This validates that the merge only coalesces consecutive progress events for the same stepID.
    func testMergeDebounceWindow() async throws {
        let stepID = UUID()

        let (inputStream, inputContinuation) = AsyncStream<AgentEvent>.makeStream()

        // First batch: 3 progress events
        inputContinuation.yield(.stepProgress(stepID: stepID, completed: 1, total: 3))
        inputContinuation.yield(.stepProgress(stepID: stepID, completed: 2, total: 3))
        inputContinuation.yield(.stepProgress(stepID: stepID, completed: 3, total: 3))

        // Non-progress event separates the batches
        inputContinuation.yield(.stepReasoning(stepID: stepID, message: "Halfway done"))

        // Second batch: 2 more progress events (same stepID, after non-progress)
        inputContinuation.yield(.stepProgress(stepID: stepID, completed: 1, total: 5))
        inputContinuation.yield(.stepProgress(stepID: stepID, completed: 2, total: 5))

        // Flush
        inputContinuation.yield(.stepCompleted(stepID: stepID, result: StepResult(stepID: stepID, message: "Done", data: [:])))
        inputContinuation.finish()

        let mergedStream = inputStream.mergeProgressEvents()

        var collectedEvents: [AgentEvent] = []
        for await event in mergedStream {
            collectedEvents.append(event)
        }

        let progressCount = collectedEvents.filter { if case .stepProgress = $0 { return true } else { return false } }.count

        // Should have 2 progress events: one from first batch (flushed by stepReasoning),
        // one from second batch (flushed by stepCompleted)
        XCTAssertEqual(progressCount, 2,
            "Progress events separated by non-progress events should not be merged together (batch1: 3->1, batch2: 2->1)")

        // Verify the merged progress values
        var progressEvents: [(completed: Int, total: Int)] = []
        for event in collectedEvents {
            if case .stepProgress(_, let completed, let total) = event {
                progressEvents.append((completed, total))
            }
        }
        XCTAssertEqual(progressEvents.count, 2)
        XCTAssertEqual(progressEvents[0].completed, 3, "First batch should have latest value (3/3)")
        XCTAssertEqual(progressEvents[0].total, 3)
        XCTAssertEqual(progressEvents[1].completed, 2, "Second batch should have latest value (2/5)")
        XCTAssertEqual(progressEvents[1].total, 5)
    }

    /// [P1] Cancelling the merged stream does not leak memory (continuation finished, Task cancelled).
    func testCancelCleansUpStream() async throws {
        let (inputStream, inputContinuation) = AsyncStream<AgentEvent>.makeStream()
        let mergedStream = inputStream.mergeProgressEvents()

        // Start consuming
        let consumerTask = _Concurrency.Task {
            var count = 0
            for await _ in mergedStream {
                count += 1
                if count > 100 { break } // Safety limit
            }
        }

        // Yield some events then cancel
        inputContinuation.yield(.stepProgress(stepID: UUID(), completed: 1, total: 5))
        try await Task.sleep(for: .milliseconds(50))

        consumerTask.cancel()
        inputContinuation.finish()

        // Consumer task should complete without hanging
        let _ = await consumerTask.result

        // If we reach here without timeout, the stream was properly cleaned up
        XCTAssertTrue(true, "Stream cleanup completed without hanging")
    }

    /// [P1] Multiple stepIDs' progress events are tracked independently.
    func testMergeTracksMultipleStepIDs() async throws {
        let stepID1 = UUID()
        let stepID2 = UUID()

        let (inputStream, inputContinuation) = AsyncStream<AgentEvent>.makeStream()

        // Interleaved progress for two different steps
        inputContinuation.yield(.stepProgress(stepID: stepID1, completed: 1, total: 3))
        inputContinuation.yield(.stepProgress(stepID: stepID2, completed: 1, total: 5))
        inputContinuation.yield(.stepProgress(stepID: stepID1, completed: 2, total: 3))
        inputContinuation.yield(.stepProgress(stepID: stepID2, completed: 2, total: 5))

        // Flush
        inputContinuation.yield(.stepCompleted(stepID: stepID1, result: StepResult(stepID: stepID1, message: "Done1", data: [:])))
        inputContinuation.yield(.stepCompleted(stepID: stepID2, result: StepResult(stepID: stepID2, message: "Done2", data: [:])))
        inputContinuation.finish()

        let mergedStream = inputStream.mergeProgressEvents()

        var collectedEvents: [AgentEvent] = []
        for await event in mergedStream {
            collectedEvents.append(event)
        }

        // Should have 4 events: 2 merged progress (one per stepID) + 2 stepCompleted
        // (progress for stepID1: 2 events -> 1, progress for stepID2: 2 events -> 1)
        let progressCount = collectedEvents.filter { if case .stepProgress = $0 { return true } else { return false } }.count
        XCTAssertEqual(progressCount, 2,
            "Progress events for different stepIDs should be tracked independently")

        // Verify each merged progress has the latest values
        var progress1Completed: Int?
        var progress2Completed: Int?
        for event in collectedEvents {
            if case .stepProgress(let id, let completed, _) = event {
                if id == stepID1 { progress1Completed = completed }
                if id == stepID2 { progress2Completed = completed }
            }
        }

        XCTAssertEqual(progress1Completed, 2,
            "Step1 progress should have latest completed value")
        XCTAssertEqual(progress2Completed, 2,
            "Step2 progress should have latest completed value")
    }

    /// [P1] Empty input stream produces empty output stream.
    func testMergeEmptyStream() async throws {
        let (inputStream, inputContinuation) = AsyncStream<AgentEvent>.makeStream()
        inputContinuation.finish()

        let mergedStream = inputStream.mergeProgressEvents()

        var count = 0
        for await _ in mergedStream {
            count += 1
        }

        XCTAssertEqual(count, 0,
            "Empty input stream should produce empty output stream")
    }
}
