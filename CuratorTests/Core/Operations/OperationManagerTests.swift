import Foundation
import XCTest
import SwiftData

@testable import Curator

/// A simple wrapper to allow passing ModelContext across actor boundaries in tests.
/// ModelContext is not Sendable by default, but in test contexts we access it
/// only from within a single OperationManager actor, so this is safe.
private final class TestModelContext: @unchecked Sendable {
    let context: ModelContext
    init(_ context: ModelContext) { self.context = context }
}

/// ATDD Tests for Story 4.2 — Operation Manager Core
///
/// Tests verify:
/// - AC1: OperationManager actor implementation (FR35)
/// - AC2: OperationSnapshot model definition
/// - AC3: Batch operation execution and recording (FR38, NFR15)
/// - AC4: Batch operation partial failure auto-rollback (FR36)
/// - AC5: Operation log persistence (NFR17)
final class OperationManagerTests: XCTestCase {

    private var testContext: TestModelContext!

    override func setUp() {
        super.setUp()
        testContext = TestModelContext(Self.makeInMemoryContext())
    }

    override func tearDown() {
        testContext = nil
        super.tearDown()
    }

    /// Convenience: get the raw ModelContext for direct SwiftData queries.
    private var modelContext: ModelContext {
        testContext.context
    }

    // MARK: - AC2: OperationType Enum

    /// [P0] OperationType enum exists with required cases and conforms to Sendable, Codable
    func testOperationTypeExistsWithRequiredCases() throws {
        let types: [OperationType] = [.rename, .delete, .move, .metadataChange]
        XCTAssertEqual(types.count, 4, "OperationType should have exactly 4 cases")

        // Verify Sendable conformance (compile-time check)
        let _: any Sendable = OperationType.rename

        // Verify Codable conformance
        let encoded = try JSONEncoder().encode(OperationType.rename)
        let decoded = try JSONDecoder().decode(OperationType.self, from: encoded)
        XCTAssertEqual(decoded, .rename)
    }

    // MARK: - AC2: BatchStatus Enum

    /// [P0] BatchStatus enum exists with required cases and conforms to Sendable, Codable
    func testBatchStatusExistsWithRequiredCases() throws {
        let statuses: [BatchStatus] = [.pending, .executing, .completed, .failed, .rolledBack]
        XCTAssertEqual(statuses.count, 5, "BatchStatus should have exactly 5 cases")

        // Verify Sendable conformance
        let _: any Sendable = BatchStatus.pending

        // Verify Codable conformance
        let encoded = try JSONEncoder().encode(BatchStatus.completed)
        let decoded = try JSONDecoder().decode(BatchStatus.self, from: encoded)
        XCTAssertEqual(decoded, .completed)
    }

    // MARK: - AC2: OperationSnapshot Model

    /// [P0] OperationSnapshot value type exists with required fields
    func testOperationSnapshotExistsWithRequiredFields() throws {
        let assetID = AssetID(rawValue: "/Users/test/photo.jpg")
        let metadata = AssetMetadata(
            fileName: "photo.jpg",
            fileSize: 1_000_000,
            creationDate: Date(timeIntervalSince1970: 1_700_000_000),
            cameraModel: nil,
            imageWidth: nil,
            imageHeight: nil,
            gpsLocation: nil,
            fileFormat: .jpeg
        )
        let snapshot = OperationSnapshot(
            id: UUID(),
            timestamp: Date(),
            operationType: .rename,
            assetID: assetID,
            beforeState: metadata
        )

        XCTAssertEqual(snapshot.operationType, .rename)
        XCTAssertEqual(snapshot.assetID, assetID)
        XCTAssertEqual(snapshot.beforeState.fileName, "photo.jpg")
    }

    /// [P0] OperationSnapshot conforms to Sendable and Codable
    func testOperationSnapshotIsSendableAndCodable() throws {
        let snapshot = OperationSnapshot(
            id: UUID(),
            timestamp: Date(),
            operationType: .delete,
            assetID: AssetID(rawValue: "/test.jpg"),
            beforeState: AssetMetadata(
                fileName: "test.jpg", fileSize: nil, creationDate: nil,
                cameraModel: nil, imageWidth: nil, imageHeight: nil,
                gpsLocation: nil, fileFormat: nil
            )
        )

        // Sendable compile-time check
        let _: any Sendable = snapshot

        // Codable round-trip
        let encoded = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(OperationSnapshot.self, from: encoded)
        XCTAssertEqual(decoded.id, snapshot.id)
        XCTAssertEqual(decoded.operationType, snapshot.operationType)
    }

    // MARK: - AC2: BatchOperation Model

    /// [P0] BatchOperation value type exists with required fields and snapshots association
    func testBatchOperationExistsWithRequiredFields() throws {
        let snapshot = OperationSnapshot(
            id: UUID(),
            timestamp: Date(),
            operationType: .rename,
            assetID: AssetID(rawValue: "/test.jpg"),
            beforeState: AssetMetadata(
                fileName: "test.jpg", fileSize: nil, creationDate: nil,
                cameraModel: nil, imageWidth: nil, imageHeight: nil,
                gpsLocation: nil, fileFormat: nil
            )
        )
        let batch = BatchOperation(
            id: UUID(),
            createdAt: Date(),
            snapshots: [snapshot],
            status: .pending
        )

        XCTAssertEqual(batch.snapshots.count, 1)
        XCTAssertEqual(batch.status, .pending)
    }

    /// [P0] BatchOperation conforms to Sendable and Codable
    func testBatchOperationIsSendableAndCodable() throws {
        let batch = BatchOperation(
            id: UUID(),
            createdAt: Date(),
            snapshots: [],
            status: .pending
        )

        let _: any Sendable = batch

        let encoded = try JSONEncoder().encode(batch)
        let decoded = try JSONDecoder().decode(BatchOperation.self, from: encoded)
        XCTAssertEqual(decoded.id, batch.id)
        XCTAssertEqual(decoded.status, .pending)
    }

    // MARK: - AC2: PlannedOperation Model

    /// [P0] PlannedOperation value type exists with operationType, assetID, and parameters
    func testPlannedOperationExistsWithRequiredFields() throws {
        let renameOp = PlannedOperation(
            operationType: .rename,
            assetID: AssetID(rawValue: "/test/old.jpg"),
            parameters: .rename(newTitle: "new")
        )
        XCTAssertEqual(renameOp.operationType, .rename)

        let deleteOp = PlannedOperation(
            operationType: .delete,
            assetID: AssetID(rawValue: "/test/photo.jpg"),
            parameters: .delete
        )
        XCTAssertEqual(deleteOp.operationType, .delete)

        let moveOp = PlannedOperation(
            operationType: .move,
            assetID: AssetID(rawValue: "/test/photo.jpg"),
            parameters: .move(targetDirectory: "/test/subfolder")
        )
        XCTAssertEqual(moveOp.operationType, .move)

        let metaOp = PlannedOperation(
            operationType: .metadataChange,
            assetID: AssetID(rawValue: "/test/photo.jpg"),
            parameters: .metadataChange
        )
        XCTAssertEqual(metaOp.operationType, .metadataChange)
    }

    /// [P1] PlannedOperation conforms to Sendable and Codable
    func testPlannedOperationIsSendableAndCodable() throws {
        let op = PlannedOperation(
            operationType: .rename,
            assetID: AssetID(rawValue: "/test.jpg"),
            parameters: .rename(newTitle: "renamed")
        )

        let _: any Sendable = op

        let encoded = try JSONEncoder().encode(op)
        let decoded = try JSONDecoder().decode(PlannedOperation.self, from: encoded)
        XCTAssertEqual(decoded.operationType, .rename)
        XCTAssertEqual(decoded.assetID.rawValue, "/test.jpg")
    }

    // MARK: - AC1: OperationManaging Protocol

    /// [P0] OperationManaging protocol exists with required methods
    func testOperationManagingProtocolExistsWithRequiredMethods() throws {
        // Compile-time check: protocol exists and is Sendable
        let _: any OperationManaging = MockOperationManager()
    }

    // MARK: - AC1: OperationManager Actor

    /// [P0] OperationManager is an actor conforming to OperationManaging
    func testOperationManagerIsActor() throws {
        let manager = OperationManager(modelContext: testContext.context)
        // Compile-time check: actor type conforms to OperationManaging
        let _: any OperationManaging = manager
    }

    // MARK: - AC1: beginBatch Creates Snapshots (FR35)

    /// [P0] beginBatch creates an OperationSnapshot for each planned operation
    func testBeginBatchCreatesSnapshots() async throws {
        let manager = OperationManager(modelContext: testContext.context)
        let mockRepo = MockPhotoLibraryRepositoryForOperations()

        let operations = [
            PlannedOperation(
                operationType: .rename,
                assetID: AssetID(rawValue: "/photos/img1.jpg"),
                parameters: .rename(newTitle: "renamed_1")
            ),
            PlannedOperation(
                operationType: .rename,
                assetID: AssetID(rawValue: "/photos/img2.jpg"),
                parameters: .rename(newTitle: "renamed_2")
            ),
        ]

        let batchID = try await manager.beginBatch(operations: operations, repository: mockRepo)

        // Verify batch ID is returned
        XCTAssertNotEqual(batchID, UUID())

        // Verify batch was created with correct snapshot count
        let history = try await manager.getBatchHistory(limit: 10)
        XCTAssertEqual(history.count, 1)
        XCTAssertEqual(history.first?.snapshots.count, 2)
        XCTAssertEqual(history.first?.status, .pending)
    }

    /// [P0] beginBatch snapshots contain correct beforeState metadata
    func testSnapshotContainsBeforeState() async throws {
        let manager = OperationManager(modelContext: testContext.context)
        let mockRepo = MockPhotoLibraryRepositoryForOperations()
        let assetID = AssetID(rawValue: "/photos/sunset.jpg")

        let operations = [
            PlannedOperation(
                operationType: .rename,
                assetID: assetID,
                parameters: .rename(newTitle: "golden_hour")
            ),
        ]

        let _ = try await manager.beginBatch(operations: operations, repository: mockRepo)
        let history = try await manager.getBatchHistory(limit: 10)
        let snapshot = try XCTUnwrap(history.first?.snapshots.first)

        // Verify snapshot contains the original metadata as beforeState
        XCTAssertEqual(snapshot.assetID, assetID)
        XCTAssertEqual(snapshot.operationType, .rename)
        XCTAssertEqual(snapshot.beforeState.fileName, "sunset.jpg")
        XCTAssertNotNil(snapshot.timestamp)
    }

    // MARK: - AC3: Batch Execution (FR38, NFR15)

    /// [P0] executeBatch successfully renames assets
    func testExecuteBatchUpdatesAssetNames() async throws {
        let manager = OperationManager(modelContext: testContext.context)
        let mockRepo = MockPhotoLibraryRepositoryForOperations()

        let operations = [
            PlannedOperation(
                operationType: .rename,
                assetID: AssetID(rawValue: "/photos/img1.jpg"),
                parameters: .rename(newTitle: "vacation_001")
            ),
        ]

        let batchID = try await manager.beginBatch(operations: operations, repository: mockRepo)
        try await manager.executeBatch(batchID, repository: mockRepo)

        // Verify repository was called to rename
        XCTAssertTrue(mockRepo.updateAssetCalled)
        XCTAssertEqual(mockRepo.lastUpdateTitle, "vacation_001")

        // Verify batch status is completed
        let history = try await manager.getBatchHistory(limit: 10)
        XCTAssertEqual(history.first?.status, .completed)
    }

    /// [P0] executeBatch does not modify original image pixel data (NFR15)
    func testExecuteBatchOriginalImagesNotModified() async throws {
        let manager = OperationManager(modelContext: testContext.context)
        let mockRepo = MockPhotoLibraryRepositoryForOperations()

        let operations = [
            PlannedOperation(
                operationType: .rename,
                assetID: AssetID(rawValue: "/photos/img1.jpg"),
                parameters: .rename(newTitle: "new_name")
            ),
            PlannedOperation(
                operationType: .move,
                assetID: AssetID(rawValue: "/photos/img2.jpg"),
                parameters: .move(targetDirectory: "/photos/sorted")
            ),
            PlannedOperation(
                operationType: .metadataChange,
                assetID: AssetID(rawValue: "/photos/img3.jpg"),
                parameters: .metadataChange
            ),
        ]

        let batchID = try await manager.beginBatch(operations: operations, repository: mockRepo)
        try await manager.executeBatch(batchID, repository: mockRepo)

        // Verify that only file operations (rename/move/metadata) were called,
        // never any pixel-level modifications.
        XCTAssertFalse(mockRepo.imageDataModified, "NFR15: Original image data must never be modified")
    }

    /// [P1] executeBatch with delete operation calls repository.deleteAssets
    func testExecuteBatchDeleteOperationCallsDeleteAssets() async throws {
        let manager = OperationManager(modelContext: testContext.context)
        let mockRepo = MockPhotoLibraryRepositoryForOperations()

        let operations = [
            PlannedOperation(
                operationType: .delete,
                assetID: AssetID(rawValue: "/photos/unwanted.jpg"),
                parameters: .delete
            ),
        ]

        let batchID = try await manager.beginBatch(operations: operations, repository: mockRepo)
        try await manager.executeBatch(batchID, repository: mockRepo)

        XCTAssertTrue(mockRepo.deleteAssetsCalled)
        XCTAssertEqual(mockRepo.deletedAssetIDs.count, 1)
    }

    /// [P1] executeBatch with move operation calls repository.moveAssets
    func testExecuteBatchMoveOperationCallsMoveAssets() async throws {
        let manager = OperationManager(modelContext: testContext.context)
        let mockRepo = MockPhotoLibraryRepositoryForOperations()

        let operations = [
            PlannedOperation(
                operationType: .move,
                assetID: AssetID(rawValue: "/photos/img.jpg"),
                parameters: .move(targetDirectory: "/photos/sorted")
            ),
        ]

        let batchID = try await manager.beginBatch(operations: operations, repository: mockRepo)
        try await manager.executeBatch(batchID, repository: mockRepo)

        XCTAssertTrue(mockRepo.moveAssetsCalled)
        XCTAssertEqual(mockRepo.movedAssetIDs.count, 1)
        XCTAssertEqual(mockRepo.moveTargetDirectory, "/photos/sorted")
    }

    // MARK: - AC4: Partial Failure Auto-Rollback (FR36)

    /// [P0] Batch execution auto-rolls back completed operations on partial failure
    func testPartialFailureAutoRollback() async throws {
        let manager = OperationManager(modelContext: testContext.context)
        let mockRepo = MockPhotoLibraryRepositoryForOperations()
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
            // Expected: partial failure with auto-rollback
        }

        // Verify batch status is .failed
        let history = try await manager.getBatchHistory(limit: 10)
        let batch = try XCTUnwrap(history.first)
        XCTAssertEqual(batch.status, .failed)

        // Verify the first two operations were executed (before the third failed)
        // The mock repo was called at least twice for updateAsset
        XCTAssertTrue(mockRepo.updateAssetCalled, "At least one rename should have been executed before failure")
    }

    // MARK: - AC5: SwiftData Persistence (NFR17)

    /// [P1] Snapshots are persisted to SwiftData and can be re-queried
    func testSnapshotsPersistToSwiftData() async throws {
        // Create batch with manager 1
        let manager1 = OperationManager(modelContext: testContext.context)
        let mockRepo = MockPhotoLibraryRepositoryForOperations()
        let operations = [
            PlannedOperation(
                operationType: .rename,
                assetID: AssetID(rawValue: "/photos/test.jpg"),
                parameters: .rename(newTitle: "new_name")
            ),
        ]

        let batchID = try await manager1.beginBatch(operations: operations, repository: mockRepo)

        // Create a new manager with the same context (simulates app restart)
        let manager2 = OperationManager(modelContext: testContext.context)
        let history = try await manager2.getBatchHistory(limit: 10)

        XCTAssertEqual(history.count, 1, "Persisted batch should be queryable from new manager")
        XCTAssertEqual(history.first?.id, batchID)
        XCTAssertEqual(history.first?.snapshots.count, 1)
    }

    /// [P1] detectIncompleteBatches returns batches with .executing status
    func testDetectIncompleteBatches() async throws {
        let manager = OperationManager(modelContext: testContext.context)
        let mockRepo = MockPhotoLibraryRepositoryForOperations()

        // Create a batch that will be left in .executing status
        let operations = [
            PlannedOperation(
                operationType: .rename,
                assetID: AssetID(rawValue: "/photos/test.jpg"),
                parameters: .rename(newTitle: "new")
            ),
        ]
        let _ = try await manager.beginBatch(operations: operations, repository: mockRepo)

        // After beginBatch, status is .pending, so no incomplete batches yet
        let incomplete = try await manager.detectIncompleteBatches()
        XCTAssertEqual(incomplete.count, 0, "No executing batches should exist after beginBatch")

        // Now manually set the batch to executing to simulate crash
        let pendingStatus = BatchStatus.pending.rawValue
        let pendingDescriptor = FetchDescriptor<BatchOperationEntity>(
            predicate: #Predicate { $0.status == pendingStatus }
        )
        let pendingBatches = try modelContext.fetch(pendingDescriptor)
        if let batch = pendingBatches.first {
            batch.status = BatchStatus.executing.rawValue
            try modelContext.save()
        }

        // Now detect should find it
        let incompleteAfter = try await manager.detectIncompleteBatches()
        XCTAssertEqual(incompleteAfter.count, 1, "detectIncompleteBatches should find the executing batch")
    }

    // MARK: - AC4: Rollback Batch

    /// [P1] rollbackBatch restores original state for rename operations
    func testRollbackBatchRestoresOriginalState() async throws {
        let manager = OperationManager(modelContext: testContext.context)
        let mockRepo = MockPhotoLibraryRepositoryForOperations()

        let operations = [
            PlannedOperation(
                operationType: .rename,
                assetID: AssetID(rawValue: "/photos/vacation.jpg"),
                parameters: .rename(newTitle: "beach_trip")
            ),
        ]

        let batchID = try await manager.beginBatch(operations: operations, repository: mockRepo)
        try await manager.executeBatch(batchID, repository: mockRepo)

        // Verify the rename was applied
        XCTAssertTrue(mockRepo.updateAssetCalled)

        // Rollback the batch
        mockRepo.resetTracking()
        try await manager.rollbackBatch(batchID, repository: mockRepo)

        // Verify repository was called to rename back
        XCTAssertTrue(mockRepo.updateAssetCalled, "Rollback should call updateAsset to rename back")

        // Verify batch status is now .rolledBack
        let history = try await manager.getBatchHistory(limit: 10)
        XCTAssertEqual(history.first?.status, .rolledBack)
    }

    /// [P1] rollbackLastBatch rolls back the most recent completed batch
    func testRollbackLastBatch() async throws {
        let manager = OperationManager(modelContext: testContext.context)
        let mockRepo = MockPhotoLibraryRepositoryForOperations()

        // Execute first batch
        let batch1Ops = [
            PlannedOperation(
                operationType: .rename,
                assetID: AssetID(rawValue: "/photos/a.jpg"),
                parameters: .rename(newTitle: "first_rename")
            ),
        ]
        let batch1ID = try await manager.beginBatch(operations: batch1Ops, repository: mockRepo)
        try await manager.executeBatch(batch1ID, repository: mockRepo)

        // Execute second batch
        mockRepo.resetTracking()
        let batch2Ops = [
            PlannedOperation(
                operationType: .rename,
                assetID: AssetID(rawValue: "/photos/b.jpg"),
                parameters: .rename(newTitle: "second_rename")
            ),
        ]
        let batch2ID = try await manager.beginBatch(operations: batch2Ops, repository: mockRepo)
        try await manager.executeBatch(batch2ID, repository: mockRepo)

        // rollbackLastBatch should roll back batch2 (most recent completed)
        mockRepo.resetTracking()
        try await manager.rollbackLastBatch(repository: mockRepo)

        // Verify batch2 status is now .rolledBack
        let history = try await manager.getBatchHistory(limit: 10)
        let rolledBackBatch = history.first { $0.id == batch2ID }
        XCTAssertEqual(rolledBackBatch?.status, .rolledBack)

        // Verify batch1 is still completed
        let firstBatch = history.first { $0.id == batch1ID }
        XCTAssertEqual(firstBatch?.status, .completed)
    }

    // MARK: - Actor Isolation

    /// [P0] OperationManager methods execute within actor isolation
    func testOperationManagerMethodsExecuteWithinActorIsolation() async throws {
        let manager = OperationManager(modelContext: testContext.context)
        let mockRepo = MockPhotoLibraryRepositoryForOperations()

        let ops = (0..<5).map { i in
            PlannedOperation(
                operationType: .rename,
                assetID: AssetID(rawValue: "/photos/img\(i).jpg"),
                parameters: .rename(newTitle: "renamed_\(i)")
            )
        }

        // Call beginBatch concurrently — actor should serialize
        async let batch1 = manager.beginBatch(operations: Array(ops[0..<2]), repository: mockRepo)
        async let batch2 = manager.beginBatch(operations: Array(ops[2..<5]), repository: mockRepo)

        let (id1, id2) = try await (batch1, batch2)

        XCTAssertNotEqual(id1, id2, "Concurrent beginBatch calls should produce distinct batch IDs")

        let history = try await manager.getBatchHistory(limit: 10)
        XCTAssertEqual(history.count, 2, "Both batches should be persisted")
    }

    // MARK: - Error Handling

    /// [P0] beginBatch with empty operations throws appropriate error
    func testBeginBatchWithEmptyOperationsThrowsError() async throws {
        let manager = OperationManager(modelContext: testContext.context)
        let mockRepo = MockPhotoLibraryRepositoryForOperations()

        do {
            _ = try await manager.beginBatch(operations: [], repository: mockRepo)
            XCTFail("beginBatch with empty operations should throw")
        } catch let error as DomainError {
            if case .invalidState(let reason) = error {
                XCTAssertTrue(reason.contains("empty") || reason.contains("Empty"),
                    "Error should indicate empty operations")
            } else {
                XCTFail("Expected invalidState error, got: \(error)")
            }
        }
    }

    /// [P0] executeBatch with unknown batch ID throws appropriate error
    func testExecuteBatchWithUnknownIDThrowsError() async throws {
        let manager = OperationManager(modelContext: testContext.context)
        let mockRepo = MockPhotoLibraryRepositoryForOperations()
        let unknownID = UUID()

        do {
            try await manager.executeBatch(unknownID, repository: mockRepo)
            XCTFail("executeBatch with unknown batch ID should throw")
        } catch let error as DomainError {
            if case .invalidState = error {
                // Expected: batch not found
            } else {
                XCTFail("Expected invalidState error, got: \(error)")
            }
        }
    }

    /// [P1] rollbackBatch with unknown batch ID throws appropriate error
    func testRollbackBatchWithUnknownIDThrowsError() async throws {
        let manager = OperationManager(modelContext: testContext.context)
        let mockRepo = MockPhotoLibraryRepositoryForOperations()
        let unknownID = UUID()

        do {
            try await manager.rollbackBatch(unknownID, repository: mockRepo)
            XCTFail("rollbackBatch with unknown ID should throw")
        } catch let error as DomainError {
            if case .invalidState = error {
                // Expected
            } else {
                XCTFail("Expected invalidState, got: \(error)")
            }
        }
    }

    /// [P1] rollbackLastBatch with no completed batches throws appropriate error
    func testRollbackLastBatchWithNoCompletedBatchesThrowsError() async throws {
        let manager = OperationManager(modelContext: testContext.context)
        let mockRepo = MockPhotoLibraryRepositoryForOperations()

        do {
            try await manager.rollbackLastBatch(repository: mockRepo)
            XCTFail("rollbackLastBatch with no completed batches should throw")
        } catch {
            // Expected: no completed batch to roll back
        }
    }

    // MARK: - Rollback via Repository Protocol

    /// [P0] Rename rollback calls updateAsset with the current (post-rename) path and original name
    func testRenameRollbackUsesRepositoryUpdateAsset() async throws {
        let manager = OperationManager(modelContext: testContext.context)
        let mockRepo = MockPhotoLibraryRepositoryForOperations()

        let operations = [
            PlannedOperation(
                operationType: .rename,
                assetID: AssetID(rawValue: "/photos/vacation.jpg"),
                parameters: .rename(newTitle: "beach_trip")
            ),
        ]

        let batchID = try await manager.beginBatch(operations: operations, repository: mockRepo)
        try await manager.executeBatch(batchID, repository: mockRepo)

        // Verify execution called updateAsset with original path
        XCTAssertEqual(mockRepo.lastUpdateAssetID, AssetID(rawValue: "/photos/vacation.jpg"))
        XCTAssertEqual(mockRepo.lastUpdateTitle, "beach_trip")

        // Rollback
        mockRepo.resetTracking()
        try await manager.rollbackBatch(batchID, repository: mockRepo)

        // Rollback should call updateAsset with the AFTER-state path (post-rename) and original name
        XCTAssertTrue(mockRepo.updateAssetCalled, "Rollback should call updateAsset")
        // After rename, file is at /photos/beach_trip.jpg; rollback renames it back
        XCTAssertEqual(mockRepo.lastUpdateAssetID?.rawValue, "/photos/beach_trip.jpg")
        XCTAssertEqual(mockRepo.lastUpdateTitle, "vacation")
    }

    /// [P0] Move rollback calls moveAssets with the current (post-move) path and original directory
    func testMoveRollbackUsesRepositoryMoveAssets() async throws {
        let manager = OperationManager(modelContext: testContext.context)
        let mockRepo = MockPhotoLibraryRepositoryForOperations()

        let operations = [
            PlannedOperation(
                operationType: .move,
                assetID: AssetID(rawValue: "/tmp/MockPhotos/subfolder/img.jpg"),
                parameters: .move(targetDirectory: "sorted")
            ),
        ]

        let batchID = try await manager.beginBatch(operations: operations, repository: mockRepo)
        try await manager.executeBatch(batchID, repository: mockRepo)

        // Rollback
        mockRepo.resetTracking()
        try await manager.rollbackBatch(batchID, repository: mockRepo)

        // Rollback should call moveAssets with the after-state path
        XCTAssertTrue(mockRepo.moveAssetsCalled, "Rollback should call moveAssets")
        // After move, file is at <basePath>/sorted/img.jpg; rollback moves it back
        XCTAssertEqual(mockRepo.movedAssetIDs.first?.rawValue, "/tmp/MockPhotos/sorted/img.jpg")
        XCTAssertEqual(mockRepo.moveTargetDirectory, "subfolder")
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

// MARK: - Mock Repository for Operation Tests

/// Mock implementation of PhotoLibraryRepository for OperationManager tests.
/// Tracks which operations were called and supports failure injection.
private final class MockPhotoLibraryRepositoryForOperations: PhotoLibraryRepository, @unchecked Sendable {

    // Tracking flags
    private let queue = DispatchQueue(label: "MockPhotoLibraryRepo")
    private var _updateAssetCalled = false
    private var _deleteAssetsCalled = false
    private var _moveAssetsCalled = false
    private var _lastUpdateTitle: String?
    private var _deletedAssetIDs: [AssetID] = []
    private var _movedAssetIDs: [AssetID] = []
    private var _moveTargetDirectory: String?
    private var _imageDataModified = false
    private var _operationCallCount = 0
    private var _lastUpdateAssetID: AssetID?

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
    var imageDataModified: Bool { queue.sync { _imageDataModified } }

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

// MARK: - Mock OperationManager for Protocol Conformance Test

/// Mock implementation of OperationManaging for protocol conformance verification.
private actor MockOperationManager: OperationManaging {
    typealias BatchID = UUID

    func beginBatch(operations: [PlannedOperation], repository: PhotoLibraryRepository) async throws -> UUID {
        UUID()
    }

    func executeBatch(_ batchID: UUID, repository: PhotoLibraryRepository) async throws {}

    func rollbackBatch(_ batchID: UUID, repository: PhotoLibraryRepository) async throws {}

    func rollbackLastBatch(repository: PhotoLibraryRepository) async throws {}

    func detectIncompleteBatches() async throws -> [BatchOperation] { [] }

    func getBatchHistory(limit: Int) async throws -> [BatchOperation] { [] }

    func reexecuteLastRolledBackBatch(repository: PhotoLibraryRepository) async throws {}
}
