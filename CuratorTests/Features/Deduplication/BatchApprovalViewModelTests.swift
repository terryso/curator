import XCTest

@testable import Curator

/// ATDD Tests for Story 5.5 -- Batch Approval and Execution
///
/// Tests verify:
/// - AC1: Batch operation buttons (FR23, UX-DR17)
/// - AC2: Execution result summary (FR23)
/// - AC3: Partial failure tolerance (NFR16, FR36)
/// - AC4: Review data to confirmation workflow bridge
/// - AC5: DuplicateGroup data flow
/// - AC6: Integration with existing confirmation workflow
@MainActor
final class BatchApprovalViewModelTests: XCTestCase {

    // MARK: - Test Helpers

    /// Creates a DuplicateGroup for testing with configurable parameters.
    private func makeDuplicateGroup(
        id: UUID = UUID(),
        assetCount: Int = 2,
        similarityScore: Double = 0.95,
        reason: String? = "Same scene, different exposure",
        status: DuplicateGroupStatus = .pending
    ) -> DuplicateGroup {
        let assets = (0..<assetCount).map { i in
            PhotoAsset(
                id: AssetID(rawValue: "asset-\(i)-\(id.uuidString.prefix(4))"),
                metadata: AssetMetadata(
                    fileName: "photo\(i).jpg",
                    fileSize: 1_000_000,
                    creationDate: Date(),
                    cameraModel: nil,
                    imageWidth: 4000,
                    imageHeight: 3000,
                    gpsLocation: nil,
                    fileFormat: .jpeg
                ),
                thumbnailData: nil
            )
        }
        return DuplicateGroup(
            id: id,
            assets: assets,
            similarityScore: similarityScore,
            reason: reason,
            thumbnails: [:],
            status: status
        )
    }

    // MARK: - AC1: Batch Operation Buttons (FR23, UX-DR17)

    /// [P0] testMarkAllAsKeepUpdatesAllStates -- Marking all as keep updates all pending groups
    ///
    /// AC1: Given the review interface has multiple pending duplicate groups,
    /// When the user triggers "Keep All",
    /// Then all pending groups are marked as .keep.
    func testMarkAllAsKeepUpdatesAllStates() {
        let viewModel = DeduplicationViewModel()

        let group1ID = UUID()
        let group2ID = UUID()
        let group3ID = UUID()
        let groups = [
            makeDuplicateGroup(id: group1ID),
            makeDuplicateGroup(id: group2ID),
            makeDuplicateGroup(id: group3ID),
        ]

        viewModel.loadGroups(groups)
        viewModel.markAllAsKeep()

        XCTAssertEqual(viewModel.reviewStates[group1ID], .keep,
            "Group 1 should be .keep after markAllAsKeep")
        XCTAssertEqual(viewModel.reviewStates[group2ID], .keep,
            "Group 2 should be .keep after markAllAsKeep")
        XCTAssertEqual(viewModel.reviewStates[group3ID], .keep,
            "Group 3 should be .keep after markAllAsKeep")
        XCTAssertTrue(viewModel.allReviewed,
            "All groups should be reviewed after markAllAsKeep")
    }

    /// [P0] testMarkAllAsRemoveUpdatesAllStates -- Marking all as remove updates all pending groups
    ///
    /// AC1: Given the review interface has multiple pending duplicate groups,
    /// When the user triggers "Remove All",
    /// Then all pending groups are marked as .remove.
    func testMarkAllAsRemoveUpdatesAllStates() {
        let viewModel = DeduplicationViewModel()

        let group1ID = UUID()
        let group2ID = UUID()
        let group3ID = UUID()
        let groups = [
            makeDuplicateGroup(id: group1ID),
            makeDuplicateGroup(id: group2ID),
            makeDuplicateGroup(id: group3ID),
        ]

        viewModel.loadGroups(groups)
        viewModel.markAllAsRemove()

        XCTAssertEqual(viewModel.reviewStates[group1ID], .remove,
            "Group 1 should be .remove after markAllAsRemove")
        XCTAssertEqual(viewModel.reviewStates[group2ID], .remove,
            "Group 2 should be .remove after markAllAsRemove")
        XCTAssertEqual(viewModel.reviewStates[group3ID], .remove,
            "Group 3 should be .remove after markAllAsRemove")
        XCTAssertTrue(viewModel.allReviewed,
            "All groups should be reviewed after markAllAsRemove")
    }

    // MARK: - AC4: Review Data to Confirmation Workflow Bridge

    /// [P0] testToDeleteOperationsReturnsCorrectOperations -- toDeleteOperations returns correct PlannedOperation list
    ///
    /// AC4: When user triggers batch removal,
    /// Then DeduplicationViewModel.toDeleteOperations() returns [PlannedOperation]
    /// with .delete type and matching asset IDs.
    func testToDeleteOperationsReturnsCorrectOperations() {
        let viewModel = DeduplicationViewModel()

        let group1ID = UUID()
        let group2ID = UUID()
        let groups = [
            makeDuplicateGroup(id: group1ID),
            makeDuplicateGroup(id: group2ID),
        ]

        viewModel.loadGroups(groups)

        // Mark group1 for removal, group2 for keep
        viewModel.markAsRemove(groupID: group1ID)
        viewModel.markAsKeep(groupID: group2ID)

        let operations = viewModel.toDeleteOperations()

        // Should have operations only for group1's assets
        XCTAssertEqual(operations.count, groups[0].assets.count,
            "Should have operations for group1's assets only")

        // All operations should be .delete type
        for operation in operations {
            XCTAssertEqual(operation.operationType, OperationType.delete,
                "All operations should be .delete type")
        }

        // Asset IDs should match group1's assets
        let expectedIDs = Set(groups[0].assets.map { $0.id })
        let actualIDs = Set(operations.map { $0.assetID })
        XCTAssertEqual(actualIDs, expectedIDs,
            "Operation asset IDs should match group1's asset IDs")
    }

    /// [P0] testToDeleteOperationsExcludesKeepGroups -- Groups marked as keep are excluded from delete operations
    ///
    /// AC4: Groups marked as .keep should NOT appear in the delete operations list.
    func testToDeleteOperationsExcludesKeepGroups() {
        let viewModel = DeduplicationViewModel()

        let group1ID = UUID()
        let group2ID = UUID()
        let group3ID = UUID()
        let groups = [
            makeDuplicateGroup(id: group1ID),
            makeDuplicateGroup(id: group2ID),
            makeDuplicateGroup(id: group3ID),
        ]

        viewModel.loadGroups(groups)
        viewModel.markAsKeep(groupID: group1ID)
        viewModel.markAsRemove(groupID: group2ID)
        viewModel.markAsKeep(groupID: group3ID)
        // group2 is the only one marked for removal

        let operations = viewModel.toDeleteOperations()

        // Should only have operations for group2
        let expectedCount = groups[1].assets.count
        XCTAssertEqual(operations.count, expectedCount,
            "Only group2's assets should be in delete operations")

        // Verify no assets from kept groups are included
        let keptAssetIDs = Set(groups[0].assets.map { $0.id })
            .union(Set(groups[2].assets.map { $0.id }))
        let operationAssetIDs = Set(operations.map { $0.assetID })
        let intersection = keptAssetIDs.intersection(operationAssetIDs)
        XCTAssertTrue(intersection.isEmpty,
            "No assets from kept groups should appear in delete operations")
    }

    // MARK: - AC5: DuplicateGroup Data Flow

    /// [P0] testExtractDuplicateGroupsParsesStepResult -- extractDuplicateGroups correctly parses JSON data from StepResult
    ///
    /// AC5: Given AnalyzeDuplicatesTool produces analysis results encoded in StepResult.data,
    /// When extractDuplicateGroups parses the data,
    /// Then it returns the correct [DuplicateGroup] list.
    func testExtractDuplicateGroupsParsesStepResult() {
        let groupID = UUID()
        let assetID = AssetID(rawValue: "/photos/test_photo.jpg")

        // Build JSON matching AnalyzeDuplicatesTool output format
        let groupsJSON: [[String: Any]] = [
            [
                "id": groupID.uuidString,
                "assetIDs": [assetID.rawValue],
                "fileNames": ["test_photo.jpg"],
                "similarityScore": 0.95,
                "reason": "Exact duplicate",
                "assetCount": 1,
                "status": "pending",
            ],
        ]

        let resultJSON: [String: Any] = [
            "groups": groupsJSON,
            "totalGroups": 1,
            "analyzedAssets": 10,
        ]

        let jsonData = try! JSONSerialization.data(
            withJSONObject: resultJSON,
            options: [.prettyPrinted, .sortedKeys]
        )
        let jsonString = String(data: jsonData, encoding: .utf8)!

        let stepResult = StepResult(
            stepID: UUID(),
            message: "Found 1 duplicate groups",
            data: ["duplicateGroups": jsonString]
        )

        let extractedGroups = MainWorkspaceView.extractDuplicateGroupsFromStepResult(stepResult)

        XCTAssertEqual(extractedGroups.count, 1,
            "Should extract 1 duplicate group from StepResult data")
        XCTAssertEqual(extractedGroups.first?.id, groupID,
            "Extracted group ID should match the original")
        XCTAssertEqual(extractedGroups.first?.similarityScore, 0.95,
            "Extracted similarity score should match")
        XCTAssertEqual(extractedGroups.first?.assets.count, 1,
            "Extracted group should have 1 asset")
        XCTAssertEqual(extractedGroups.first?.assets.first?.id, assetID,
            "Extracted asset ID should match")
    }

    /// [P0] testExtractDuplicateGroupsReturnsEmptyForNoData -- No StepResult data returns empty array
    ///
    /// AC5: When StepResult has no "duplicateGroups" key in its data dictionary,
    /// extractDuplicateGroups returns an empty array.
    func testExtractDuplicateGroupsReturnsEmptyForNoData() {
        // StepResult with no duplicateGroups key
        let stepResult = StepResult(
            stepID: UUID(),
            message: "Analysis complete",
            data: [:]
        )

        let extractedGroups = MainWorkspaceView.extractDuplicateGroupsFromStepResult(stepResult)

        XCTAssertTrue(extractedGroups.isEmpty,
            "Should return empty array when no duplicateGroups data present")
    }

    // MARK: - AC6: Integration with Existing Confirmation Workflow

    /// [P1] testBatchApprovalTriggersDestructiveConfirmation -- Batch removal triggers .destructive confirmation level
    ///
    /// AC6: Given batch deletion operations are created,
    /// When ConfirmationLevel.forOperations() detects .delete operations,
    /// Then it automatically routes to .destructive level.
    func testBatchApprovalTriggersDestructiveConfirmation() {
        let viewModel = DeduplicationViewModel()

        let group1ID = UUID()
        let group2ID = UUID()
        let groups = [
            makeDuplicateGroup(id: group1ID),
            makeDuplicateGroup(id: group2ID),
        ]

        viewModel.loadGroups(groups)
        viewModel.markAllAsRemove()

        let operations = viewModel.toDeleteOperations()

        // Verify operations are created (precondition)
        XCTAssertFalse(operations.isEmpty,
            "Should have delete operations after markAllAsRemove")

        // Verify destructive confirmation level
        let level = ConfirmationLevel.forOperations(operations)
        XCTAssertEqual(level, ConfirmationLevel.destructive,
            "Delete operations should trigger .destructive confirmation level")
    }

    /// [P1] testExecutionResultUpdatesOnCompletion -- Execution result is correctly set after completion
    ///
    /// AC2: Given user executed batch operations,
    /// When operations complete,
    /// Then system shows execution result summary (success count, failure count, skipped count).
    func testExecutionResultUpdatesOnCompletion() async throws {
        let mockManager = MockBatchApprovalOperationManager()
        let permissionState = await createGrantedPermissionState()
        let confirmationVM = ConfirmationViewModel(
            operationManager: mockManager,
            permissionState: permissionState
        )

        let viewModel = DeduplicationViewModel()

        let group1ID = UUID()
        let groups = [makeDuplicateGroup(id: group1ID)]
        viewModel.loadGroups(groups)
        viewModel.markAllAsRemove()

        let operations = viewModel.toDeleteOperations()
        let request = ConfirmationRequest(
            operations: operations,
            confirmationLevel: .destructive,
            summary: "Delete \(operations.count) duplicate photos"
        )

        confirmationVM.presentConfirmation(request: request)
        confirmationVM.confirm() // First confirmation
        confirmationVM.confirmDestructive() // Second confirmation

        // Wait for async execution
        try await Task.sleep(for: .milliseconds(300))

        let result = confirmationVM.executionResult
        XCTAssertNotNil(result,
            "Execution result should be available after batch operations complete")
        XCTAssertEqual(result?.total, operations.count,
            "Result total should match operations count")
    }

    // MARK: - AC3: Partial Failure Tolerance

    /// [P1] testMarkAllPreservesAlreadyReviewedStates -- markAll does not overwrite already-reviewed groups
    ///
    /// AC3: Given some groups are already reviewed (keep or remove),
    /// When user triggers "Keep All" or "Remove All",
    /// Then only pending groups are updated, already-reviewed groups keep their state.
    func testMarkAllPreservesAlreadyReviewedStates() {
        let viewModel = DeduplicationViewModel()

        let group1ID = UUID()
        let group2ID = UUID()
        let group3ID = UUID()
        let groups = [
            makeDuplicateGroup(id: group1ID),
            makeDuplicateGroup(id: group2ID),
            makeDuplicateGroup(id: group3ID),
        ]

        viewModel.loadGroups(groups)

        // User manually reviews group1 as keep
        viewModel.markAsKeep(groupID: group1ID)
        // User manually reviews group2 as remove
        viewModel.markAsRemove(groupID: group2ID)
        // group3 remains pending

        // Trigger "Remove All" -- should only affect pending groups
        viewModel.markAllAsRemove()

        // group1 should still be .keep (preserved)
        XCTAssertEqual(viewModel.reviewStates[group1ID], .keep,
            "Already-reviewed group (keep) should NOT be overwritten by markAllAsRemove")
        // group2 should still be .remove (preserved)
        XCTAssertEqual(viewModel.reviewStates[group2ID], .remove,
            "Already-reviewed group (remove) should NOT be overwritten by markAllAsRemove")
        // group3 should now be .remove (updated from pending)
        XCTAssertEqual(viewModel.reviewStates[group3ID], .remove,
            "Pending group should be updated to .remove by markAllAsRemove")
    }

    /// [P1] testPartialFailureResultShowsBothCounts -- Partial failure result shows success and failure counts
    ///
    /// AC3: Given batch operations partially fail,
    /// When execution completes,
    /// Then result summary shows both success count and failure count.
    func testPartialFailureResultShowsBothCounts() async throws {
        let mockManager = MockBatchApprovalOperationManager()
        mockManager.simulatePartialFailure = true
        let permissionState = await createGrantedPermissionState()
        let confirmationVM = ConfirmationViewModel(
            operationManager: mockManager,
            permissionState: permissionState
        )

        let operations = [
            PlannedOperation(
                operationType: .delete,
                assetID: AssetID(rawValue: "/photos/dup1.jpg"),
                parameters: .delete
            ),
            PlannedOperation(
                operationType: .delete,
                assetID: AssetID(rawValue: "/photos/dup2.jpg"),
                parameters: .delete
            ),
            PlannedOperation(
                operationType: .delete,
                assetID: AssetID(rawValue: "/photos/dup3.jpg"),
                parameters: .delete
            ),
        ]

        let request = ConfirmationRequest(
            operations: operations,
            confirmationLevel: .destructive,
            summary: "Delete 3 duplicate photos"
        )

        confirmationVM.presentConfirmation(request: request)
        confirmationVM.confirm()
        confirmationVM.confirmDestructive()

        try await Task.sleep(for: .milliseconds(300))

        let result = confirmationVM.executionResult
        XCTAssertNotNil(result, "Result should be available after execution")
        XCTAssertEqual(result?.failureCount, 3,
            "All 3 operations should fail when executeBatch throws")
        XCTAssertEqual(result?.successCount, 0,
            "No operations should succeed when executeBatch throws early")
        XCTAssertFalse(result?.isFullSuccess ?? true,
            "Result should NOT be full success when there are failures")
    }

    // MARK: - AC2: Execution Result Summary

    /// [P1] testExecutionResultFullSuccess -- Full success result has correct properties
    ///
    /// AC2: When all operations succeed, result shows isFullSuccess = true.
    func testExecutionResultFullSuccess() {
        let result = ExecutionResult(successCount: 5, failureCount: 0, total: 5)

        XCTAssertTrue(result.isFullSuccess,
            "Result with zero failures should be full success")
        XCTAssertEqual(result.successCount, 5)
        XCTAssertEqual(result.failureCount, 0)
        XCTAssertEqual(result.total, 5)
    }

    /// [P1] testExecutionResultPartialSuccess -- Partial success result has correct properties
    ///
    /// AC2: When some operations fail, result shows isFullSuccess = false with correct counts.
    func testExecutionResultPartialSuccess() {
        let result = ExecutionResult(successCount: 3, failureCount: 2, total: 5)

        XCTAssertFalse(result.isFullSuccess,
            "Result with failures should NOT be full success")
        XCTAssertEqual(result.successCount, 3)
        XCTAssertEqual(result.failureCount, 2)
        XCTAssertEqual(result.total, 5)
    }

    // MARK: - AC1: Batch Operations with Empty Groups

    /// [P1] testMarkAllAsKeepWithNoGroups -- markAllAsKeep handles empty group list gracefully
    ///
    /// AC1: When no groups are loaded, batch operations should not crash.
    func testMarkAllAsKeepWithNoGroups() {
        let viewModel = DeduplicationViewModel()
        viewModel.loadGroups([])

        // Should not crash
        viewModel.markAllAsKeep()

        XCTAssertTrue(viewModel.groups.isEmpty)
        XCTAssertEqual(viewModel.reviewedCount, 0)
    }

    /// [P1] testMarkAllAsRemoveWithNoGroups -- markAllAsRemove handles empty group list gracefully
    ///
    /// AC1: When no groups are loaded, batch operations should not crash.
    func testMarkAllAsRemoveWithNoGroups() {
        let viewModel = DeduplicationViewModel()
        viewModel.loadGroups([])

        // Should not crash
        viewModel.markAllAsRemove()

        XCTAssertTrue(viewModel.groups.isEmpty)
        XCTAssertTrue(viewModel.toDeleteOperations().isEmpty,
            "No delete operations when no groups loaded")
    }

    // MARK: - AC4: Bridge to Confirmation - PlannedOperation Construction

    /// [P1] testToDeleteOperationsParametersAreDelete -- toDeleteOperations produces operations with .delete parameters
    ///
    /// AC4: Each PlannedOperation from toDeleteOperations should have .delete parameters.
    func testToDeleteOperationsParametersAreDelete() {
        let viewModel = DeduplicationViewModel()

        let group1ID = UUID()
        let groups = [makeDuplicateGroup(id: group1ID, assetCount: 3)]

        viewModel.loadGroups(groups)
        viewModel.markAllAsRemove()

        let operations = viewModel.toDeleteOperations()

        XCTAssertEqual(operations.count, 3,
            "3 assets in group should produce 3 operations")

        for operation in operations {
            XCTAssertEqual(operation.operationType, OperationType.delete,
                "Operation type should be .delete")
            XCTAssertEqual(operation.parameters, OperationParameters.delete,
                "Operation parameters should be .delete")
        }
    }

    // MARK: - AC5: Data Flow Edge Cases

    /// [P1] testExtractDuplicateGroupsHandlesMalformedJSON -- Malformed JSON returns empty array
    ///
    /// AC5: When StepResult contains malformed JSON, extractDuplicateGroups returns empty gracefully.
    func testExtractDuplicateGroupsHandlesMalformedJSON() {
        let stepResult = StepResult(
            stepID: UUID(),
            message: "Analysis complete",
            data: ["duplicateGroups": "not valid json {{{{"]
        )

        let extractedGroups = MainWorkspaceView.extractDuplicateGroupsFromStepResult(stepResult)

        XCTAssertTrue(extractedGroups.isEmpty,
            "Should return empty array for malformed JSON data")
    }

    /// [P1] testExtractDuplicateGroupsHandlesEmptyGroupsArray -- Empty groups array returns empty list
    ///
    /// AC5: When JSON contains an empty groups array, extractDuplicateGroups returns empty list.
    func testExtractDuplicateGroupsHandlesEmptyGroupsArray() {
        let resultJSON: [String: Any] = [
            "groups": [[String: Any]](),
            "totalGroups": 0,
            "analyzedAssets": 10,
        ]

        let jsonData = try! JSONSerialization.data(
            withJSONObject: resultJSON,
            options: [.prettyPrinted, .sortedKeys]
        )
        let jsonString = String(data: jsonData, encoding: .utf8)!

        let stepResult = StepResult(
            stepID: UUID(),
            message: "No duplicates found",
            data: ["duplicateGroups": jsonString]
        )

        let extractedGroups = MainWorkspaceView.extractDuplicateGroupsFromStepResult(stepResult)

        XCTAssertTrue(extractedGroups.isEmpty,
            "Should return empty array when groups JSON is empty")
    }

    // MARK: - Test Helpers (Shared)

    /// Creates a PermissionState with write access pre-granted for testing.
    private func createGrantedPermissionState() async -> PermissionState {
        let mockRepo = MockBatchApprovalGrantedRepository()
        let state = PermissionState(repository: mockRepo)
        _ = try? await state.requestWritePermission()
        return state
    }
}

// MARK: - Mock OperationManager for Batch Approval Tests

/// Mock implementation of OperationManaging for Story 5.5 batch approval tests.
/// Tracks method calls and simulates batch execution behavior without real file operations.
private final class MockBatchApprovalOperationManager: OperationManaging, @unchecked Sendable {

    private let queue = DispatchQueue(label: "MockBatchApprovalOpManager")

    // Tracking
    private var _beginBatchCalled = false
    private var _executeBatchCalled = false
    private var _lastOperations: [PlannedOperation]?

    /// When true, executeBatch throws to simulate partial failure.
    var simulatePartialFailure = false

    var beginBatchCalled: Bool { queue.sync { _beginBatchCalled } }
    var executeBatchCalled: Bool { queue.sync { _executeBatchCalled } }
    var lastOperations: [PlannedOperation]? { queue.sync { _lastOperations } }

    func beginBatch(operations: [PlannedOperation], repository: PhotoLibraryRepository) async throws -> OperationManaging.BatchID {
        queue.sync {
            _beginBatchCalled = true
            _lastOperations = operations
        }
        return UUID()
    }

    func executeBatch(_ batchID: OperationManaging.BatchID, repository: PhotoLibraryRepository) async throws {
        queue.sync {
            _executeBatchCalled = true
        }
        if simulatePartialFailure {
            throw DomainError.invalidState(reason: "Mock: simulated partial failure during batch execution")
        }
    }

    func rollbackBatch(_ batchID: OperationManaging.BatchID, repository: PhotoLibraryRepository) async throws {
        // No-op for batch approval tests
    }

    func rollbackLastBatch(repository: PhotoLibraryRepository) async throws {
        // No-op for batch approval tests
    }

    func detectIncompleteBatches() async throws -> [BatchOperation] {
        []
    }

    func getBatchHistory(limit: Int) async throws -> [BatchOperation] {
        []
    }

    func reexecuteLastRolledBackBatch(repository: PhotoLibraryRepository) async throws {
        // No-op for batch approval tests
    }
}

// MARK: - Mock Repository that grants write access

/// Mock repository that always grants write access for batch approval tests.
private struct MockBatchApprovalGrantedRepository: PhotoLibraryRepository, Sendable {
    func currentBasePath() async -> String? { nil }
    func requestReadAccess() async throws -> Bool { true }
    func requestWriteAccess() async throws -> Bool { true }
    func fetchAssets(predicate: PhotoPredicate, pageSize: Int, pageOffset: Int) async throws -> AssetPage {
        AssetPage(assets: [], hasMore: false)
    }
    func fetchFullResolutionImage(for assetID: AssetID) async throws -> Data { Data() }
    func fetchThumbnail(for assetID: AssetID, size: CGSize) async throws -> Data { Data() }
    func metadata(for assetID: AssetID) async throws -> AssetMetadata {
        AssetMetadata(fileName: "", fileSize: nil, creationDate: nil, cameraModel: nil, imageWidth: nil, imageHeight: nil, gpsLocation: nil, fileFormat: nil)
    }
    func updateAsset(_ assetID: AssetID, title: String?) async throws {}
    func deleteAssets(_ assetIDs: [AssetID]) async throws {}
    func moveAssets(_ assetIDs: [AssetID], to directory: String) async throws {}
    func observeSourceChanges() -> AsyncStream<SourceChange> {
        AsyncStream { $0.finish() }
    }
}
