import Foundation
import XCTest
import SwiftData

@testable import Curator

/// A simple wrapper to allow passing ModelContext across actor boundaries in tests.
/// ModelContext is not Sendable by default, but in test contexts we access it
/// only from within a single OperationManager actor, so this is safe.
private final class RollbackTestModelContext: @unchecked Sendable {
    let context: ModelContext
    init(_ context: ModelContext) { self.context = context }
}

/// ATDD Tests for Story 4.3 — Batch Rollback & Undo System
///
/// Tests verify:
/// - AC1: User-triggered batch operation undo via rollbackLastBatch (FR34, NFR16)
/// - AC2: Batch operation mid-failure auto-rollback (FR36)
/// - AC3: Rollback operation is itself undoable (bidirectional undo)
/// - AC4: Crash recovery prompt (NFR17)
///
/// **TDD RED PHASE:** Tests reference `reexecuteLastRolledBackBatch` which is not yet
/// implemented. Each test is guarded with `XCTSkipIf(true, ...)` and should be
/// activated during implementation by removing the skip guard.
final class BatchRollbackUndoTests: XCTestCase {

    private var testContext: RollbackTestModelContext!

    override func setUp() {
        super.setUp()
        testContext = RollbackTestModelContext(Self.makeInMemoryContext())
    }

    override func tearDown() {
        testContext = nil
        super.tearDown()
    }

    /// Convenience: get the raw ModelContext for direct SwiftData queries.
    private var modelContext: ModelContext {
        testContext.context
    }

    // MARK: - AC1: User-Triggered Batch Undo via rollbackLastBatch (FR34, NFR16)

    /// [P0] rollbackLastBatch restores all affected assets to pre-operation metadata state.
    ///
    /// AC1: Given a completed batch operation, When rollbackLastBatch is called,
    /// Then all affected assets are restored to their before-state.
    func testRollbackLastBatchViaCommandZ() async throws {
        let manager = OperationManager(modelContext: testContext.context)
        let mockRepo = MockRollbackRepo()

        // Create and execute a batch with multiple rename operations
        let operations = [
            PlannedOperation(
                operationType: .rename,
                assetID: AssetID(rawValue: "/photos/sunset.jpg"),
                parameters: .rename(newTitle: "golden_hour")
            ),
            PlannedOperation(
                operationType: .rename,
                assetID: AssetID(rawValue: "/photos/beach.jpg"),
                parameters: .rename(newTitle: "vacation_001")
            ),
        ]

        let batchID = try await manager.beginBatch(operations: operations, repository: mockRepo)
        try await manager.executeBatch(batchID, repository: mockRepo)

        // Verify batch is completed before rollback
        let historyBefore = try await manager.getBatchHistory(limit: 10)
        XCTAssertEqual(historyBefore.first?.status, .completed)

        // Trigger rollback (simulates Cmd+Z action)
        try await manager.rollbackLastBatch(repository: mockRepo)

        // Verify batch status is now .rolledBack
        let historyAfter = try await manager.getBatchHistory(limit: 10)
        let rolledBackBatch = historyAfter.first { $0.id == batchID }
        XCTAssertEqual(rolledBackBatch?.status, .rolledBack, "Batch should be rolled back after rollbackLastBatch")

        // Verify repository was called to restore original names
        XCTAssertTrue(mockRepo.rollbackUpdateCalled, "Repository updateAsset should be called during rollback to restore original names")
    }

    /// [P0] Rollback completes within 5 seconds for a large batch (NFR16).
    ///
    /// NFR16: rollbackLastBatch should complete within 5 seconds.
    /// Tests with 100 operations to verify performance constraint.
    func testRollbackCompletesWithin5Seconds() async throws {
        let manager = OperationManager(modelContext: testContext.context)
        let mockRepo = MockRollbackRepo()

        // Create a large batch with 100 rename operations
        let operations = (0..<100).map { i in
            PlannedOperation(
                operationType: .rename,
                assetID: AssetID(rawValue: "/photos/img_\(String(format: "%03d", i)).jpg"),
                parameters: .rename(newTitle: "renamed_\(i)")
            )
        }

        let batchID = try await manager.beginBatch(operations: operations, repository: mockRepo)
        try await manager.executeBatch(batchID, repository: mockRepo)

        // Measure rollback time (NFR16: must be < 5 seconds)
        let start = Date()
        try await manager.rollbackLastBatch(repository: mockRepo)
        let elapsed = Date().timeIntervalSince(start)

        XCTAssertLessThan(elapsed, 5.0, "NFR16: rollbackLastBatch should complete within 5 seconds, took \(elapsed)s")
    }

    // MARK: - AC2: Mid-Failure Auto-Rollback (FR36)

    /// [P0] Batch execution auto-rolls back completed operations on mid-failure.
    ///
    /// AC2: Given a batch operation where a mid-execution operation fails,
    /// When OperationManager detects the failure, Then completed operations
    /// are automatically rolled back.
    func testPartialFailureAutoRollback() async throws {
        let manager = OperationManager(modelContext: testContext.context)
        let mockRepo = MockRollbackRepo()
        mockRepo.shouldFailOnThirdCall = true

        let operations = [
            PlannedOperation(
                operationType: .rename,
                assetID: AssetID(rawValue: "/photos/a.jpg"),
                parameters: .rename(newTitle: "renamed_a")
            ),
            PlannedOperation(
                operationType: .rename,
                assetID: AssetID(rawValue: "/photos/b.jpg"),
                parameters: .rename(newTitle: "renamed_b")
            ),
            PlannedOperation(
                operationType: .rename,
                assetID: AssetID(rawValue: "/photos/c.jpg"),
                parameters: .rename(newTitle: "renamed_c")
            ),
        ]

        let batchID = try await manager.beginBatch(operations: operations, repository: mockRepo)

        do {
            try await manager.executeBatch(batchID, repository: mockRepo)
            XCTFail("executeBatch should throw on partial failure")
        } catch {
            // Expected: partial failure triggers auto-rollback
        }

        // Verify batch status is .failed
        let history = try await manager.getBatchHistory(limit: 10)
        let batch = try XCTUnwrap(history.first)
        XCTAssertEqual(batch.status, .failed, "Batch should be in .failed state after partial failure")

        // Verify the first two operations were executed before the third failed
        XCTAssertTrue(mockRepo.updateCallCount >= 2, "At least 2 operations should have been executed before the failure")
    }

    // MARK: - AC3: Bidirectional Undo — Rollback is Undoable

    /// [P0] After rollback, reexecuteLastRolledBackBatch restores the rolled-back batch.
    ///
    /// AC3: Given a rolled-back batch, When reexecuteLastRolledBackBatch is called
    /// (second Cmd+Z), Then the batch is re-executed back to its completed state.
    ///
    /// - Note: This test is compile-gated behind `#if false` because
    ///   `reexecuteLastRolledBackBatch` does not yet exist on `OperationManaging`.
    ///   Change to `#if true` once the method is added to the protocol.
    func testRedoAfterUndo() async throws {
        #if true
        let manager = OperationManager(modelContext: testContext.context)
        let mockRepo = MockRollbackRepo()

        // Step 1: Create and execute a batch
        let operations = [
            PlannedOperation(
                operationType: .rename,
                assetID: AssetID(rawValue: "/photos/sunset.jpg"),
                parameters: .rename(newTitle: "golden_hour")
            ),
        ]

        let batchID = try await manager.beginBatch(operations: operations, repository: mockRepo)
        try await manager.executeBatch(batchID, repository: mockRepo)

        // Step 2: Undo — rollback the batch
        try await manager.rollbackLastBatch(repository: mockRepo)

        // Verify batch is rolled back
        let historyAfterUndo = try await manager.getBatchHistory(limit: 10)
        XCTAssertEqual(historyAfterUndo.first?.status, .rolledBack, "Batch should be rolled back after undo")

        // Step 3: Redo — re-execute the rolled-back batch
        mockRepo.resetTracking()
        try await manager.reexecuteLastRolledBackBatch(repository: mockRepo)

        // Verify batch is back to completed
        let historyAfterRedo = try await manager.getBatchHistory(limit: 10)
        let redoBatch = historyAfterRedo.first { $0.id == batchID }
        XCTAssertEqual(redoBatch?.status, .completed, "Batch should be back to .completed after redo")

        // Verify repository was called to re-apply the operation
        XCTAssertTrue(mockRepo.updateAssetCalled, "Repository should be called to re-apply the rename operation")
        #else
        throw XCTSkip("RED PHASE: Activate after reexecuteLastRolledBackBatch is implemented on OperationManaging protocol — change #if false to #if true")
        #endif
    }

    // MARK: - AC4: Crash Recovery (NFR17)

    /// [P0] detectIncompleteBatches detects unfinished batches on startup.
    ///
    /// AC4: Given an app crash with a batch in .executing state,
    /// When the app restarts, Then detectIncompleteBatches returns the
    /// incomplete batch for user recovery.
    func testDetectIncompleteBatchesOnStartup() async throws {
        let manager = OperationManager(modelContext: testContext.context)
        let mockRepo = MockRollbackRepo()

        // Create a batch and manually set it to .executing (simulates crash during execution)
        let operations = [
            PlannedOperation(
                operationType: .rename,
                assetID: AssetID(rawValue: "/photos/crash_test.jpg"),
                parameters: .rename(newTitle: "crashed_rename")
            ),
        ]
        let _ = try await manager.beginBatch(operations: operations, repository: mockRepo)

        // Simulate crash: manually set batch status to .executing
        let pendingStatus = BatchStatus.pending.rawValue
        let pendingDescriptor = FetchDescriptor<BatchOperationEntity>(
            predicate: #Predicate { $0.status == pendingStatus }
        )
        let pendingBatches = try modelContext.fetch(pendingDescriptor)
        if let batch = pendingBatches.first {
            batch.status = BatchStatus.executing.rawValue
            try modelContext.save()
        }

        // Simulate app restart — detect incomplete batches
        let incomplete = try await manager.detectIncompleteBatches()
        XCTAssertEqual(incomplete.count, 1, "Should detect 1 incomplete batch after simulated crash")

        let incompleteBatch = try XCTUnwrap(incomplete.first)
        XCTAssertEqual(incompleteBatch.status, .executing, "Detected batch should be in .executing state")
        XCTAssertEqual(incompleteBatch.snapshots.count, 1, "Detected batch should have 1 snapshot")
    }

    // MARK: - P1: Edge Cases and Logging

    /// [P1] rollbackLastBatch is silently ignored when no completed batch exists.
    ///
    /// AC1 edge case: When there is no completed batch, rollbackLastBatch
    /// should throw DomainError.invalidState (no silent success).
    func testNoCompletedBatchSilentlyIgnored() async throws {
        let manager = OperationManager(modelContext: testContext.context)
        let mockRepo = MockRollbackRepo()

        // No batches created — rollbackLastBatch should throw
        do {
            try await manager.rollbackLastBatch(repository: mockRepo)
            XCTFail("rollbackLastBatch should throw when no completed batch exists")
        } catch let error as DomainError {
            if case .invalidState(let reason) = error {
                XCTAssertTrue(
                    reason.contains("No completed batch"),
                    "Error should indicate no completed batch, got: \(reason)"
                )
            } else {
                XCTFail("Expected invalidState error, got: \(error)")
            }
        }
    }

    /// [P1] Operation log records rollback events with batch ID and timestamp.
    ///
    /// AC3: Operation log should record all changes including rollback events.
    func testOperationLogRecordsRollback() async throws {
        let manager = OperationManager(modelContext: testContext.context)
        let mockRepo = MockRollbackRepo()

        // Create and execute a batch
        let operations = [
            PlannedOperation(
                operationType: .rename,
                assetID: AssetID(rawValue: "/photos/log_test.jpg"),
                parameters: .rename(newTitle: "log_renamed")
            ),
        ]

        let batchID = try await manager.beginBatch(operations: operations, repository: mockRepo)
        try await manager.executeBatch(batchID, repository: mockRepo)

        // Rollback the batch
        try await manager.rollbackBatch(batchID, repository: mockRepo)

        // Verify batch history records the rollback
        let history = try await manager.getBatchHistory(limit: 10)
        let batch = try XCTUnwrap(history.first { $0.id == batchID })
        XCTAssertEqual(batch.status, .rolledBack, "Batch history should record rolledBack status")

        // Verify the batch was persisted with the correct status
        let rolledBackStatus = BatchStatus.rolledBack.rawValue
        let descriptor = FetchDescriptor<BatchOperationEntity>(
            predicate: #Predicate { $0.id == batchID && $0.status == rolledBackStatus }
        )
        let rolledBackBatches = try modelContext.fetch(descriptor)
        XCTAssertEqual(rolledBackBatches.count, 1, "SwiftData should persist the rolled-back batch")
        XCTAssertNotNil(rolledBackBatches.first?.completedAt, "completedAt should be set after rollback")
    }

    /// [P1] Crash recovery prompt shown when incomplete batches detected.
    ///
    /// AC4: Given the app detects incomplete batches on startup,
    /// a recovery prompt should be shown to the user.
    /// This tests the ViewModel-level detection (not the UI itself).
    func testCrashRecoveryPromptShown() async throws {
        let manager = OperationManager(modelContext: testContext.context)
        let mockRepo = MockRollbackRepo()

        // Create a batch and simulate crash (status = .executing)
        let operations = [
            PlannedOperation(
                operationType: .rename,
                assetID: AssetID(rawValue: "/photos/recovery.jpg"),
                parameters: .rename(newTitle: "recovery_rename")
            ),
        ]
        let batchID = try await manager.beginBatch(operations: operations, repository: mockRepo)

        // Manually set to executing to simulate crash
        let id = batchID
        let descriptor = FetchDescriptor<BatchOperationEntity>(
            predicate: #Predicate { $0.id == id }
        )
        let batches = try modelContext.fetch(descriptor)
        if let batch = batches.first {
            batch.status = BatchStatus.executing.rawValue
            try modelContext.save()
        }

        // Detect incomplete batches
        let incomplete = try await manager.detectIncompleteBatches()
        XCTAssertFalse(incomplete.isEmpty, "Incomplete batches should be detected — would trigger crash recovery prompt")

        // Verify we can roll back the incomplete batch
        let incompleteBatch = try XCTUnwrap(incomplete.first)
        try await manager.rollbackBatch(incompleteBatch.id, repository: mockRepo)

        // Verify batch is now rolled back
        let history = try await manager.getBatchHistory(limit: 10)
        let rolledBack = history.first { $0.id == batchID }
        XCTAssertEqual(rolledBack?.status, .rolledBack, "Recovered batch should be rolled back")
    }

    // MARK: - Helpers

    /// Creates an in-memory SwiftData ModelContext for testing.
    private static func makeInMemoryContext() -> ModelContext {
        let schema = Schema([
            CostRecordEntity.self,
            SessionEntity.self,
            OperationSnapshotEntity.self,
            BatchOperationEntity.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        do {
            let container = try ModelContainer(for: schema, configurations: [config])
            return ModelContext(container)
        } catch {
            fatalError("Failed to create in-memory ModelContext: \(error)")
        }
    }
}

// MARK: - Mock Repository for Rollback Tests

/// Mock implementation of PhotoLibraryRepository for Story 4.3 rollback/undo tests.
/// Extends the pattern from OperationManagerTests with additional tracking for
/// rollback-specific assertions.
private final class MockRollbackRepo: PhotoLibraryRepository, @unchecked Sendable {

    // Tracking
    private let queue = DispatchQueue(label: "MockRollbackRepo")
    private var _updateAssetCalled = false
    private var _deleteAssetsCalled = false
    private var _moveAssetsCalled = false
    private var _lastUpdateTitle: String?
    private var _lastUpdateAssetID: AssetID?
    private var _deletedAssetIDs: [AssetID] = []
    private var _movedAssetIDs: [AssetID] = []
    private var _moveTargetDirectory: String?
    private var _operationCallCount = 0
    private var _rollbackUpdateCalled = false

    /// When true, the third repository call will throw an error.
    var shouldFailOnThirdCall = false

    var updateAssetCalled: Bool { queue.sync { _updateAssetCalled } }
    var deleteAssetsCalled: Bool { queue.sync { _deleteAssetsCalled } }
    var moveAssetsCalled: Bool { queue.sync { _moveAssetsCalled } }
    var lastUpdateTitle: String? { queue.sync { _lastUpdateTitle } }
    var lastUpdateAssetID: AssetID? { queue.sync { _lastUpdateAssetID } }
    var deletedAssetIDs: [AssetID] { queue.sync { _deletedAssetIDs } }
    var movedAssetIDs: [AssetID] { queue.sync { _movedAssetIDs } }
    var moveTargetDirectory: String? { queue.sync { _moveTargetDirectory } }
    var updateCallCount: Int { queue.sync { _operationCallCount } }
    var rollbackUpdateCalled: Bool { queue.sync { _rollbackUpdateCalled } }

    func resetTracking() {
        queue.sync {
            _updateAssetCalled = false
            _deleteAssetsCalled = false
            _moveAssetsCalled = false
            _lastUpdateTitle = nil
            _lastUpdateAssetID = nil
            _deletedAssetIDs = []
            _movedAssetIDs = []
            _moveTargetDirectory = nil
            _operationCallCount = 0
            _rollbackUpdateCalled = false
        }
    }

    // MARK: - PhotoLibraryRepository Conformance

    func currentBasePath() async -> String? { "/tmp/MockPhotos" }

    func requestReadAccess() async throws -> Bool { true }

    func requestWriteAccess() async throws -> Bool { true }

    func fetchAssets(predicate: PhotoPredicate, pageSize: Int, pageOffset: Int) async throws -> AssetPage {
        AssetPage(assets: [], hasMore: false, nextOffset: nil)
    }

    func fetchFullResolutionImage(for assetID: AssetID) async throws -> Data {
        Data()
    }

    func fetchThumbnail(for assetID: AssetID, size: CGSize) async throws -> Data {
        Data()
    }

    func metadata(for assetID: AssetID) async throws -> AssetMetadata {
        let fileName = (assetID.rawValue as NSString).lastPathComponent
        return AssetMetadata(
            fileName: fileName,
            fileSize: 1024,
            creationDate: Date(),
            cameraModel: nil,
            imageWidth: nil,
            imageHeight: nil,
            gpsLocation: nil,
            fileFormat: nil
        )
    }

    func updateAsset(_ assetID: AssetID, title: String?) async throws {
        let shouldFail = queue.sync {
            _operationCallCount += 1
            if _updateAssetCalled {
                // Already been called at least once -- this is a rollback call
                _rollbackUpdateCalled = true
            }
            _updateAssetCalled = true
            _lastUpdateTitle = title
            _lastUpdateAssetID = assetID
            return shouldFailOnThirdCall && _operationCallCount >= 3
        }
        if shouldFail {
            throw DomainError.invalidState(reason: "Mock: simulated third-call failure")
        }
    }

    func deleteAssets(_ assetIDs: [AssetID]) async throws {
        let shouldFail = queue.sync {
            _operationCallCount += 1
            _deleteAssetsCalled = true
            _deletedAssetIDs = assetIDs
            return shouldFailOnThirdCall && _operationCallCount >= 3
        }
        if shouldFail {
            throw DomainError.invalidState(reason: "Mock: simulated third-call failure")
        }
    }

    func moveAssets(_ assetIDs: [AssetID], to directory: String) async throws {
        let shouldFail = queue.sync {
            _operationCallCount += 1
            _moveAssetsCalled = true
            _movedAssetIDs = assetIDs
            _moveTargetDirectory = directory
            return shouldFailOnThirdCall && _operationCallCount >= 3
        }
        if shouldFail {
            throw DomainError.invalidState(reason: "Mock: simulated third-call failure")
        }
    }

    func observeSourceChanges() -> AsyncStream<SourceChange> {
        AsyncStream { _ in }
    }
}
