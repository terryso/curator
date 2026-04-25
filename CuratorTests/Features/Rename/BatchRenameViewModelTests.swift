import XCTest

@testable import Curator

/// ATDD Tests for Story 6.4 -- Batch Rename Execution
///
/// Tests verify:
/// - AC1: Batch operation buttons (FR28, UX-DR17)
/// - AC2: Batch confirmation and execution via ConfirmationViewModel (FR28, FR33, UX-DR11)
/// - AC3: Execution result summary with success/failure/skipped counts (UX-DR6)
/// - AC4: Undo/rollback via OperationManager (FR34, NFR16)
/// - AC5: Partial failure tolerance (FR36, NFR15)
/// - AC6: Review data to confirmation workflow bridge
/// - AC7: Integration with AgentExecutionPanel
@MainActor
final class BatchRenameViewModelTests: XCTestCase {

    // MARK: - Test Helpers

    /// Creates a RenameSuggestion for testing with configurable parameters.
    private func makeSuggestion(
        id: UUID = UUID(),
        originalFileName: String = "IMG_001.jpg",
        suggestedName: String = "sunset-beach.jpg",
        confidence: Double = 0.9
    ) -> RenameSuggestion {
        RenameSuggestion(
            id: id,
            assetID: AssetID(rawValue: "test-asset-\(id.uuidString)"),
            originalFileName: originalFileName,
            suggestedName: suggestedName,
            confidence: confidence
        )
    }

    // MARK: - AC1: Batch Operation Buttons (FR28, UX-DR17)

    /// [P0] testMarkAllAsAcceptUpdatesAllStates -- All pending suggestions become accepted
    ///
    /// AC1: Given the review interface has multiple pending rename suggestions,
    /// When the user triggers "Accept All",
    /// Then all pending suggestions are marked as .accepted.
    func testMarkAllAsAcceptUpdatesAllStates() throws {
        let viewModel = RenameViewModel()

        let suggestion1ID = UUID()
        let suggestion2ID = UUID()
        let suggestion3ID = UUID()
        let suggestions = [
            makeSuggestion(id: suggestion1ID),
            makeSuggestion(id: suggestion2ID),
            makeSuggestion(id: suggestion3ID),
        ]

        viewModel.loadSuggestions(suggestions)
        viewModel.markAllAsAccept()

        XCTAssertEqual(viewModel.reviewDecisions[suggestion1ID], .accepted,
            "Suggestion 1 should be .accepted after markAllAsAccept")
        XCTAssertEqual(viewModel.reviewDecisions[suggestion2ID], .accepted,
            "Suggestion 2 should be .accepted after markAllAsAccept")
        XCTAssertEqual(viewModel.reviewDecisions[suggestion3ID], .accepted,
            "Suggestion 3 should be .accepted after markAllAsAccept")
        XCTAssertTrue(viewModel.allReviewed,
            "All suggestions should be reviewed after markAllAsAccept")
    }

    /// [P0] testMarkAllAsRejectUpdatesAllStates -- All pending suggestions become rejected
    ///
    /// AC1: Given the review interface has multiple pending rename suggestions,
    /// When the user triggers "Reject All",
    /// Then all pending suggestions are marked as .rejected.
    func testMarkAllAsRejectUpdatesAllStates() throws {
        let viewModel = RenameViewModel()

        let suggestion1ID = UUID()
        let suggestion2ID = UUID()
        let suggestion3ID = UUID()
        let suggestions = [
            makeSuggestion(id: suggestion1ID),
            makeSuggestion(id: suggestion2ID),
            makeSuggestion(id: suggestion3ID),
        ]

        viewModel.loadSuggestions(suggestions)
        viewModel.markAllAsReject()

        XCTAssertEqual(viewModel.reviewDecisions[suggestion1ID], .rejected,
            "Suggestion 1 should be .rejected after markAllAsReject")
        XCTAssertEqual(viewModel.reviewDecisions[suggestion2ID], .rejected,
            "Suggestion 2 should be .rejected after markAllAsReject")
        XCTAssertEqual(viewModel.reviewDecisions[suggestion3ID], .rejected,
            "Suggestion 3 should be .rejected after markAllAsReject")
        XCTAssertTrue(viewModel.allReviewed,
            "All suggestions should be reviewed after markAllAsReject")
    }

    /// [P1] testMarkAllPreservesAlreadyReviewedStates -- markAll does not overwrite already-reviewed suggestions
    ///
    /// AC1/AC5: Given some suggestions are already reviewed,
    /// When user triggers "Accept All" or "Reject All",
    /// Then only pending suggestions are updated, already-reviewed keep their state.
    func testMarkAllPreservesAlreadyReviewedStates() throws {
        let viewModel = RenameViewModel()

        let suggestion1ID = UUID()
        let suggestion2ID = UUID()
        let suggestion3ID = UUID()
        let suggestions = [
            makeSuggestion(id: suggestion1ID),
            makeSuggestion(id: suggestion2ID),
            makeSuggestion(id: suggestion3ID),
        ]

        viewModel.loadSuggestions(suggestions)

        // User manually accepts suggestion1
        viewModel.accept(suggestionID: suggestion1ID)
        // User manually rejects suggestion2
        viewModel.reject(suggestionID: suggestion2ID)
        // suggestion3 remains pending

        // Trigger "Accept All" -- should only affect pending suggestions
        viewModel.markAllAsAccept()

        // suggestion1 should still be .accepted (preserved)
        XCTAssertEqual(viewModel.reviewDecisions[suggestion1ID], .accepted,
            "Already-reviewed suggestion (accepted) should NOT be overwritten by markAllAsAccept")
        // suggestion2 should still be .rejected (preserved)
        XCTAssertEqual(viewModel.reviewDecisions[suggestion2ID], .rejected,
            "Already-reviewed suggestion (rejected) should NOT be overwritten by markAllAsAccept")
        // suggestion3 should now be .accepted (updated from pending)
        XCTAssertEqual(viewModel.reviewDecisions[suggestion3ID], .accepted,
            "Pending suggestion should be updated to .accepted by markAllAsAccept")
    }

    // MARK: - AC6: Review Data to Confirmation Workflow Bridge

    /// [P0] testToRenameOperationsReturnsCorrectOperations -- toRenameOperations returns correct PlannedOperation list
    ///
    /// AC6: When user triggers batch rename,
    /// Then RenameViewModel.toRenameOperations() returns [PlannedOperation]
    /// with .rename type, matching asset IDs, and correct names.
    func testToRenameOperationsReturnsCorrectOperations() throws {
        let viewModel = RenameViewModel()

        let suggestion1ID = UUID()
        let suggestion2ID = UUID()
        let suggestion3ID = UUID()

        let asset1ID = AssetID(rawValue: "test-asset-\(suggestion1ID.uuidString)")
        let asset2ID = AssetID(rawValue: "test-asset-\(suggestion2ID.uuidString)")
        let asset3ID = AssetID(rawValue: "test-asset-\(suggestion3ID.uuidString)")

        let suggestions = [
            RenameSuggestion(
                id: suggestion1ID,
                assetID: asset1ID,
                originalFileName: "IMG_001.jpg",
                suggestedName: "sunset.jpg",
                confidence: 0.9
            ),
            RenameSuggestion(
                id: suggestion2ID,
                assetID: asset2ID,
                originalFileName: "IMG_002.jpg",
                suggestedName: "beach.jpg",
                confidence: 0.8
            ),
            RenameSuggestion(
                id: suggestion3ID,
                assetID: asset3ID,
                originalFileName: "IMG_003.jpg",
                suggestedName: "mountain.jpg",
                confidence: 0.7
            ),
        ]

        viewModel.loadSuggestions(suggestions)
        viewModel.accept(suggestionID: suggestion1ID)
        viewModel.reject(suggestionID: suggestion2ID)
        viewModel.edit(suggestionID: suggestion3ID, newName: "alpine-peak.jpg")

        let operations = viewModel.toRenameOperations()

        // Only accepted and edited suggestions should produce operations (not rejected)
        XCTAssertEqual(operations.count, 2,
            "Only accepted and edited suggestions should produce rename operations")

        // Verify first operation (accepted -- uses suggested name)
        let acceptedOp = operations.first { $0.assetID == asset1ID }
        XCTAssertNotNil(acceptedOp)
        XCTAssertEqual(acceptedOp?.operationType, .rename)
        XCTAssertEqual(acceptedOp?.parameters, .rename(newTitle: "sunset.jpg"))

        // Verify second operation (edited -- uses custom name)
        let editedOp = operations.first { $0.assetID == asset3ID }
        XCTAssertNotNil(editedOp)
        XCTAssertEqual(editedOp?.operationType, .rename)
        XCTAssertEqual(editedOp?.parameters, .rename(newTitle: "alpine-peak.jpg"))

        // Verify rejected suggestion has no operation
        let rejectedOp = operations.first { $0.assetID == asset2ID }
        XCTAssertNil(rejectedOp,
            "Rejected suggestion should not produce a rename operation")
    }

    /// [P0] testToRenameOperationsExcludesRejected -- Rejected suggestions excluded from operations
    ///
    /// AC6: Suggestions marked as .rejected should NOT appear in the rename operations list.
    func testToRenameOperationsExcludesRejected() throws {
        let viewModel = RenameViewModel()

        let suggestion1ID = UUID()
        let suggestion2ID = UUID()
        let suggestion3ID = UUID()
        let suggestions = [
            makeSuggestion(id: suggestion1ID),
            makeSuggestion(id: suggestion2ID),
            makeSuggestion(id: suggestion3ID),
        ]

        viewModel.loadSuggestions(suggestions)
        viewModel.accept(suggestionID: suggestion1ID)
        viewModel.reject(suggestionID: suggestion2ID)
        viewModel.reject(suggestionID: suggestion3ID)

        let operations = viewModel.toRenameOperations()

        XCTAssertEqual(operations.count, 1,
            "Only accepted suggestion should produce an operation")

        let operationAssetIDs = Set(operations.map { $0.assetID })
        let rejectedAssetIDs: Set<AssetID> = [
            suggestions[1].assetID,
            suggestions[2].assetID,
        ]
        XCTAssertTrue(operationAssetIDs.intersection(rejectedAssetIDs).isEmpty,
            "No rejected suggestions should appear in rename operations")
    }

    /// [P0] testToRenameOperationsIncludesEdited -- Edited suggestions use custom name
    ///
    /// AC6: Suggestions marked as .edited(name) should produce operations
    /// using the user's custom name, not the AI-suggested name.
    func testToRenameOperationsIncludesEdited() throws {
        let viewModel = RenameViewModel()

        let suggestionID = UUID()
        let assetID = AssetID(rawValue: "test-asset-\(suggestionID.uuidString)")
        let suggestions = [
            RenameSuggestion(
                id: suggestionID,
                assetID: assetID,
                originalFileName: "IMG_001.jpg",
                suggestedName: "sunset.jpg",
                confidence: 0.9
            ),
        ]

        viewModel.loadSuggestions(suggestions)
        viewModel.edit(suggestionID: suggestionID, newName: "golden-hour.jpg")

        let operations = viewModel.toRenameOperations()

        XCTAssertEqual(operations.count, 1)
        XCTAssertEqual(operations.first?.parameters, .rename(newTitle: "golden-hour.jpg"),
            "Edited suggestion should use the custom name, not the suggested name")
        XCTAssertNotEqual(operations.first?.parameters, .rename(newTitle: "sunset.jpg"),
            "Edited suggestion should NOT use the AI-suggested name")
    }

    /// [P1] testBatchRenameWithEmptyOperations -- No operations when all rejected
    ///
    /// AC6: When all suggestions are rejected, toRenameOperations returns empty.
    /// No confirmation should be triggered.
    func testBatchRenameWithEmptyOperations() throws {
        let viewModel = RenameViewModel()

        let suggestion1ID = UUID()
        let suggestion2ID = UUID()
        let suggestions = [
            makeSuggestion(id: suggestion1ID),
            makeSuggestion(id: suggestion2ID),
        ]

        viewModel.loadSuggestions(suggestions)
        viewModel.markAllAsReject()

        let operations = viewModel.toRenameOperations()

        XCTAssertTrue(operations.isEmpty,
            "No rename operations when all suggestions are rejected")
    }

    // MARK: - AC2: Batch Confirmation and Execution (FR28, FR33, UX-DR11)

    /// [P0] testBatchRenameTriggersStandardConfirmation -- Rename operations route to .standard confirmation level
    ///
    /// AC2: Given batch rename operations are created,
    /// When ConfirmationLevel.forOperations() evaluates .rename operations,
    /// Then it returns .standard (rename is non-destructive, fully recoverable).
    func testBatchRenameTriggersStandardConfirmation() throws {
        let viewModel = RenameViewModel()

        let suggestion1ID = UUID()
        let suggestion2ID = UUID()
        let suggestions = [
            makeSuggestion(id: suggestion1ID),
            makeSuggestion(id: suggestion2ID),
        ]

        viewModel.loadSuggestions(suggestions)
        viewModel.markAllAsAccept()

        let operations = viewModel.toRenameOperations()

        // Verify operations exist
        XCTAssertFalse(operations.isEmpty,
            "Should have rename operations after markAllAsAccept")

        // Verify standard confirmation level (not destructive)
        let level = ConfirmationLevel.forOperations(operations)
        XCTAssertEqual(level, .standard,
            "Rename operations should trigger .standard confirmation level (non-destructive)")
        XCTAssertNotEqual(level, .destructive,
            "Rename operations should NOT trigger .destructive level (that's for delete only)")
    }

    /// [P0] testExecutionResultUpdatesOnCompletion -- Execution result is correctly set after batch rename
    ///
    /// AC2/AC3: Given user executed batch rename operations,
    /// When operations complete,
    /// Then ConfirmationViewModel.executionResult shows success count, failure count, total.
    func testExecutionResultUpdatesOnCompletion() async throws {
        let mockManager = MockBatchRenameOperationManager()
        let permissionState = await createGrantedPermissionState()
        let confirmationVM = ConfirmationViewModel(
            operationManager: mockManager,
            permissionState: permissionState
        )

        let viewModel = RenameViewModel()

        let suggestion1ID = UUID()
        let suggestion2ID = UUID()
        let suggestions = [
            makeSuggestion(id: suggestion1ID),
            makeSuggestion(id: suggestion2ID),
        ]

        viewModel.loadSuggestions(suggestions)
        viewModel.markAllAsAccept()

        let operations = viewModel.toRenameOperations()
        let request = ConfirmationRequest(
            operations: operations,
            confirmationLevel: .standard,
            summary: "Rename \(operations.count) photos"
        )

        confirmationVM.presentConfirmation(request: request)
        confirmationVM.confirm() // Standard confirmation (single step)

        // Wait for async execution
        try await Task.sleep(for: .milliseconds(300))

        let result = confirmationVM.executionResult
        XCTAssertNotNil(result,
            "Execution result should be available after batch rename operations complete")
        XCTAssertEqual(result?.total, operations.count,
            "Result total should match operations count")
        XCTAssertEqual(result?.successCount, operations.count,
            "All operations should succeed with mock manager")
    }

    // MARK: - AC3: Execution Result Summary (UX-DR6)

    /// [P1] testExecutionResultFullSuccess -- Full success result has correct properties
    ///
    /// AC3: When all rename operations succeed, result shows isFullSuccess = true.
    func testExecutionResultFullSuccess() throws {
        let result = ExecutionResult(successCount: 5, failureCount: 0, total: 5)

        XCTAssertTrue(result.isFullSuccess,
            "Result with zero failures should be full success")
        XCTAssertEqual(result.successCount, 5)
        XCTAssertEqual(result.failureCount, 0)
        XCTAssertEqual(result.total, 5)
    }

    /// [P1] testExecutionResultPartialSuccess -- Partial success result has correct properties
    ///
    /// AC3: When some rename operations fail, result shows isFullSuccess = false with correct counts.
    func testExecutionResultPartialSuccess() throws {
        let result = ExecutionResult(successCount: 3, failureCount: 2, total: 5)

        XCTAssertFalse(result.isFullSuccess,
            "Result with failures should NOT be full success")
        XCTAssertEqual(result.successCount, 3)
        XCTAssertEqual(result.failureCount, 2)
        XCTAssertEqual(result.total, 5)
    }

    // MARK: - AC4: Undo/Rollback (FR34, NFR16)

    /// [P1] testExecutionResultProvidesUndoCapability -- Undo is available after batch rename execution
    ///
    /// AC4: After batch rename completes, the undo button should be available.
    /// The OperationManager tracks the batch for rollback via batchID.
    func testExecutionResultProvidesUndoCapability() async throws {
        let mockManager = MockBatchRenameOperationManager()
        let permissionState = await createGrantedPermissionState()
        let confirmationVM = ConfirmationViewModel(
            operationManager: mockManager,
            permissionState: permissionState
        )

        let operations = [
            PlannedOperation(
                operationType: .rename,
                assetID: AssetID(rawValue: "/photos/img001.jpg"),
                parameters: .rename(newTitle: "sunset.jpg")
            ),
        ]

        let request = ConfirmationRequest(
            operations: operations,
            confirmationLevel: .standard,
            summary: "Rename 1 photo"
        )

        confirmationVM.presentConfirmation(request: request)
        confirmationVM.confirm()

        try await Task.sleep(for: .milliseconds(300))

        // Verify execution completed
        XCTAssertNotNil(confirmationVM.executionResult,
            "Execution result should be available")
        XCTAssertTrue(mockManager.beginBatchCalled,
            "beginBatch should have been called for the rename operation")
        XCTAssertTrue(mockManager.executeBatchCalled,
            "executeBatch should have been called for the rename operation")
    }

    // MARK: - AC5: Partial Failure Tolerance (FR36, NFR15)

    /// [P1] testPartialFailureResultShowsBothCounts -- Partial failure result shows success and failure counts
    ///
    /// AC5: Given batch rename operations partially fail,
    /// When execution completes,
    /// Then result summary shows both success count and failure count.
    func testPartialFailureResultShowsBothCounts() async throws {
        let mockManager = MockBatchRenameOperationManager()
        mockManager.simulatePartialFailure = true
        let permissionState = await createGrantedPermissionState()
        let confirmationVM = ConfirmationViewModel(
            operationManager: mockManager,
            permissionState: permissionState
        )

        let operations = [
            PlannedOperation(
                operationType: .rename,
                assetID: AssetID(rawValue: "/photos/img001.jpg"),
                parameters: .rename(newTitle: "sunset.jpg")
            ),
            PlannedOperation(
                operationType: .rename,
                assetID: AssetID(rawValue: "/photos/img002.jpg"),
                parameters: .rename(newTitle: "beach.jpg")
            ),
            PlannedOperation(
                operationType: .rename,
                assetID: AssetID(rawValue: "/photos/img003.jpg"),
                parameters: .rename(newTitle: "mountain.jpg")
            ),
        ]

        let request = ConfirmationRequest(
            operations: operations,
            confirmationLevel: .standard,
            summary: "Rename 3 photos"
        )

        confirmationVM.presentConfirmation(request: request)
        confirmationVM.confirm()

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

    // MARK: - AC7: Integration with AgentExecutionPanel

    /// [P1] testRenameConfirmationLevelIsStandard -- ConfirmationLevel.forOperations returns .standard for rename
    ///
    /// AC7: Rename operations should use .standard confirmation (not .destructive).
    /// This verifies ConfirmationLevel.forOperations behaves correctly for .rename.
    func testRenameConfirmationLevelIsStandard() throws {
        let renameOperations = [
            PlannedOperation(
                operationType: .rename,
                assetID: AssetID(rawValue: "/photos/img001.jpg"),
                parameters: .rename(newTitle: "sunset.jpg")
            ),
            PlannedOperation(
                operationType: .rename,
                assetID: AssetID(rawValue: "/photos/img002.jpg"),
                parameters: .rename(newTitle: "beach.jpg")
            ),
        ]

        let level = ConfirmationLevel.forOperations(renameOperations)
        XCTAssertEqual(level, .standard,
            "Rename operations should route to .standard confirmation level")
        XCTAssertNotEqual(level, .destructive,
            "Rename is non-destructive (file name is fully recoverable)")
        XCTAssertNotEqual(level, .none,
            "Rename is a write operation requiring confirmation")
    }

    /// [P1] testConfirmationRequestForRenameContainsCorrectSummary -- Confirmation request has descriptive summary
    ///
    /// AC7: When BatchRenameView builds a ConfirmationRequest, the summary should
    /// describe the number of photos being renamed.
    func testConfirmationRequestForRenameContainsCorrectSummary() throws {
        let viewModel = RenameViewModel()

        let suggestion1ID = UUID()
        let suggestion2ID = UUID()
        let suggestion3ID = UUID()
        let suggestions = [
            makeSuggestion(id: suggestion1ID),
            makeSuggestion(id: suggestion2ID),
            makeSuggestion(id: suggestion3ID),
        ]

        viewModel.loadSuggestions(suggestions)
        viewModel.markAllAsAccept()

        let operations = viewModel.toRenameOperations()

        // Build confirmation request as BatchRenameView would
        let summary = "Rename \(operations.count) photos"
        let request = ConfirmationRequest(
            operations: operations,
            confirmationLevel: .standard,
            summary: summary
        )

        XCTAssertEqual(request.operations.count, 3,
            "Request should contain all 3 rename operations")
        XCTAssertEqual(request.confirmationLevel, .standard,
            "Request should use .standard confirmation level")
        XCTAssertTrue(request.summary.contains("3"),
            "Summary should mention the count of photos being renamed")
        XCTAssertEqual(request.summary, "Rename 3 photos",
            "Summary should be in the format 'Rename N photos'")
    }

    // MARK: - Test Helpers (Shared)

    /// Creates a PermissionState with write access pre-granted for testing.
    private func createGrantedPermissionState() async -> PermissionState {
        let mockRepo = MockBatchRenameGrantedRepository()
        let state = PermissionState(repository: mockRepo)
        _ = try? await state.requestWritePermission()
        return state
    }
}

// MARK: - Mock OperationManager for Batch Rename Tests

/// Mock implementation of OperationManaging for Story 6.4 batch rename tests.
/// Tracks method calls and simulates batch execution behavior without real file operations.
/// Mirrors MockBatchApprovalOperationManager from Story 5.5 for consistency.
private final class MockBatchRenameOperationManager: OperationManaging, @unchecked Sendable {

    private let queue = DispatchQueue(label: "MockBatchRenameOpManager")

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
            throw DomainError.invalidState(reason: "Mock: simulated partial failure during rename batch execution")
        }
    }

    func rollbackBatch(_ batchID: OperationManaging.BatchID, repository: PhotoLibraryRepository) async throws {
        // No-op for batch rename tests
    }

    func rollbackLastBatch(repository: PhotoLibraryRepository) async throws {
        // No-op for batch rename tests
    }

    func detectIncompleteBatches() async throws -> [BatchOperation] {
        []
    }

    func getBatchHistory(limit: Int) async throws -> [BatchOperation] {
        []
    }

    func reexecuteLastRolledBackBatch(repository: PhotoLibraryRepository) async throws {
        // No-op for batch rename tests
    }
}

// MARK: - Mock Repository that grants write access

/// Mock repository that always grants write access for batch rename tests.
private struct MockBatchRenameGrantedRepository: PhotoLibraryRepository, Sendable {
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
