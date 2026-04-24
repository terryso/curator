import Foundation
import XCTest
import OpenAgentSDK

@testable import Curator

/// ATDD Tests for Story 5.3 -- DeleteAssetsTool (AC3, AC6)
///
/// Tests verify:
/// - AC3: DeleteAssetsTool safely deletes via OperationManager with snapshots (FR22, FR33)
/// - AC6: Error handling returns structured JSON errors (NFR20, NFR23)
final class DeleteAssetsToolTests: XCTestCase {

    // MARK: - AC3: DeleteAssetsTool Creates Snapshot and Executes (FR22, FR33)

    /// [P0] DeleteAssetsTool creates snapshot via OperationManager and executes deletion.
    ///
    /// AC3: Given user has confirmed deletion of duplicate photos,
    /// When Agent calls DeleteAssetsTool,
    /// Then tool calls operationManager.beginBatch() to create snapshot,
    /// And tool calls operationManager.executeBatch() to perform deletion,
    /// And returns JSON with batchID and deletedCount.
    func testDeleteAssetsCreatesSnapshotAndExecutes() async throws {
        // Given: A tracking operation manager and valid asset IDs
        let trackingManager = TrackingMockOperationManager()
        let mockRepo = MockDeleteTestRepository()

        let tool = createDeleteAssetsTool(
            operationManager: trackingManager,
            repository: mockRepo
        )

        // When: Calling the tool with asset IDs
        let result = try await tool.call(
            input: ["assetIDs": ["/photos/dup1.jpg", "/photos/dup2.jpg"]] as [String: Any],
            context: ToolContext(cwd: "/tmp")
        )

        // Then: Snapshot created and batch executed
        XCTAssertFalse(result.isError,
            "DeleteAssetsTool should execute without error")
        let beginCalled = await trackingManager.beginBatchCalled
        let execCalled = await trackingManager.executeBatchCalled
        XCTAssertTrue(beginCalled,
            "Tool should call beginBatch to create snapshot")
        XCTAssertTrue(execCalled,
            "Tool should call executeBatch to perform deletion")
        XCTAssertTrue(result.content.contains("batchID") || result.content.contains("success"),
            "Result should contain batchID or success status")
    }

    /// [P0] DeleteAssetsTool rolls back on execution failure.
    ///
    /// AC3: Given executeBatch fails during deletion,
    /// When DeleteAssetsTool processes the failure,
    /// Then OperationManager auto-rollback is invoked,
    /// And tool returns structured error information.
    func testDeleteAssetsRollsBackOnFailure() async throws {
        // Given: An operation manager that fails on executeBatch
        let failingManager = FailingMockOperationManager()
        let mockRepo = MockDeleteTestRepository()

        let tool = createDeleteAssetsTool(
            operationManager: failingManager,
            repository: mockRepo
        )

        // When: Calling the tool
        let result = try await tool.call(
            input: ["assetIDs": ["/photos/dup1.jpg"]] as [String: Any],
            context: ToolContext(cwd: "/tmp")
        )

        // Then: Error returned (CodableTool catches throws and wraps as isError:true)
        XCTAssertTrue(result.isError,
            "Tool should return error when batch execution fails")
        // CodableTool wraps thrown errors as "Error: <message>"
        let contentLower = result.content.lowercased()
        XCTAssertTrue(contentLower.contains("error"),
            "Error result should contain error information, got: \(result.content)")
    }

    // MARK: - AC3: Tool Properties and Annotations

    /// [P1] DeleteAssetsTool is NOT read-only and has destructive annotations.
    ///
    /// AC3: Tool should have readOnlyHint: false and destructiveHint: true.
    func testDeleteAssetsToolAnnotations() async throws {
        let mockManager = SimpleMockOperationManager()
        let mockRepo = MockDeleteTestRepository()

        let tool = createDeleteAssetsTool(
            operationManager: mockManager,
            repository: mockRepo
        )

        XCTAssertEqual(tool.name, "delete_assets",
            "Tool name should be 'delete_assets'")
        XCTAssertFalse(tool.isReadOnly,
            "DeleteAssetsTool should NOT be marked as read-only")

        if let annotations = tool.annotations {
            XCTAssertFalse(annotations.readOnlyHint,
                "DeleteAssetsTool should have readOnlyHint = false")
            XCTAssertTrue(annotations.destructiveHint,
                "DeleteAssetsTool should have destructiveHint = true")
        }
    }

    // MARK: - AC6: Error Handling (NFR23)

    /// [P1] DeleteAssetsTool handles invalid asset IDs gracefully.
    ///
    /// AC6: Given invalid asset IDs (empty array, malformed),
    /// When Agent calls DeleteAssetsTool,
    /// Then tool returns structured JSON error,
    /// And does not crash the Agent loop.
    func testDeleteAssetsHandlesInvalidAssetIDs() async throws {
        let mockManager = SimpleMockOperationManager()
        let mockRepo = MockDeleteTestRepository()

        let tool = createDeleteAssetsTool(
            operationManager: mockManager,
            repository: mockRepo
        )

        // When: Calling with empty asset IDs array
        let result = try await tool.call(
            input: ["assetIDs": []] as [String: Any],
            context: ToolContext(cwd: "/tmp")
        )

        // Then: Returns error
        XCTAssertTrue(result.isError,
            "Tool should return error for empty asset IDs")
        let contentLower = result.content.lowercased()
        XCTAssertTrue(contentLower.contains("error"),
            "Error result should contain error information, got: \(result.content)")
    }
}

// MARK: - Mock: Tracking OperationManager for Delete Tool Tests

/// OperationManager mock that tracks beginBatch/executeBatch calls.
private actor TrackingMockOperationManager: OperationManaging {
    private(set) var beginBatchCalled = false
    private(set) var executeBatchCalled = false
    private var batchCounter = 0

    func beginBatch(operations: [PlannedOperation], repository: PhotoLibraryRepository) async throws -> OperationManaging.BatchID {
        beginBatchCalled = true
        batchCounter += 1
        return UUID()
    }

    func executeBatch(_ batchID: OperationManaging.BatchID, repository: PhotoLibraryRepository) async throws {
        executeBatchCalled = true
    }

    func rollbackBatch(_ batchID: OperationManaging.BatchID, repository: PhotoLibraryRepository) async throws {}
    func rollbackLastBatch(repository: PhotoLibraryRepository) async throws {}
    func detectIncompleteBatches() async throws -> [BatchOperation] { [] }
    func getBatchHistory(limit: Int) async throws -> [BatchOperation] { [] }
    func reexecuteLastRolledBackBatch(repository: PhotoLibraryRepository) async throws {}
}

// MARK: - Mock: Failing OperationManager for Delete Tool Tests

/// OperationManager mock that succeeds on beginBatch but fails on executeBatch.
private actor FailingMockOperationManager: OperationManaging {
    func beginBatch(operations: [PlannedOperation], repository: PhotoLibraryRepository) async throws -> OperationManaging.BatchID {
        return UUID()
    }

    func executeBatch(_ batchID: OperationManaging.BatchID, repository: PhotoLibraryRepository) async throws {
        throw DomainError.invalidState(reason: "Simulated execution failure for test")
    }

    func rollbackBatch(_ batchID: OperationManaging.BatchID, repository: PhotoLibraryRepository) async throws {}
    func rollbackLastBatch(repository: PhotoLibraryRepository) async throws {}
    func detectIncompleteBatches() async throws -> [BatchOperation] { [] }
    func getBatchHistory(limit: Int) async throws -> [BatchOperation] { [] }
    func reexecuteLastRolledBackBatch(repository: PhotoLibraryRepository) async throws {}
}

// MARK: - Mock: Simple OperationManager for Delete Tool Tests

/// Minimal OperationManager mock for annotation/property tests.
private actor SimpleMockOperationManager: OperationManaging {
    func beginBatch(operations: [PlannedOperation], repository: PhotoLibraryRepository) async throws -> OperationManaging.BatchID {
        UUID()
    }

    func executeBatch(_ batchID: OperationManaging.BatchID, repository: PhotoLibraryRepository) async throws {}
    func rollbackBatch(_ batchID: OperationManaging.BatchID, repository: PhotoLibraryRepository) async throws {}
    func rollbackLastBatch(repository: PhotoLibraryRepository) async throws {}
    func detectIncompleteBatches() async throws -> [BatchOperation] { [] }
    func getBatchHistory(limit: Int) async throws -> [BatchOperation] { [] }
    func reexecuteLastRolledBackBatch(repository: PhotoLibraryRepository) async throws {}
}

// MARK: - Mock: PhotoLibraryRepository for Delete Tool Tests

private final class MockDeleteTestRepository: PhotoLibraryRepository, @unchecked Sendable {
    func currentBasePath() async -> String? { nil }
    func requestReadAccess() async throws -> Bool { true }
    func requestWriteAccess() async throws -> Bool { true }

    func fetchAssets(predicate: PhotoPredicate, pageSize: Int, pageOffset: Int) async throws -> AssetPage {
        AssetPage(assets: [], hasMore: false)
    }

    func fetchFullResolutionImage(for assetID: AssetID) async throws -> Data { Data() }
    func fetchThumbnail(for assetID: AssetID, size: CGSize) async throws -> Data { Data() }
    func metadata(for assetID: AssetID) async throws -> AssetMetadata {
        AssetMetadata(fileName: "mock.jpg", fileSize: nil, creationDate: nil,
                       cameraModel: nil, imageWidth: nil, imageHeight: nil,
                       gpsLocation: nil, fileFormat: nil)
    }
    func updateAsset(_ assetID: AssetID, title: String?) async throws {}
    func deleteAssets(_ assetIDs: [AssetID]) async throws {}
    func moveAssets(_ assetIDs: [AssetID], to directory: String) async throws {}
    func observeSourceChanges() -> AsyncStream<SourceChange> { AsyncStream { $0.finish() } }
}
