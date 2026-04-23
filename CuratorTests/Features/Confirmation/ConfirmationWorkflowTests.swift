import Foundation
import XCTest

@testable import Curator

/// ATDD Tests for Story 4.4 — Confirmation Workflow UI
///
/// Tests verify:
/// - AC1: Read-only operations skip confirmation (UX-DR11, FR33)
/// - AC2: Write operations show batch confirmation summary (UX-DR11, FR33)
/// - AC3: Destructive operations require second confirmation (UX-DR11, FR33)
/// - AC4: Confirmation flow integrates with OperationManager (FR35, FR36)
/// - AC5: Permission check runs before confirmation (FR6, UX-DR9)
@MainActor
final class ConfirmationWorkflowTests: XCTestCase {

    // MARK: - AC1: Read-Only Operations Skip Confirmation (UX-DR11, FR33)

    /// [P0] Read-only operations (metadataChange only) skip confirmation entirely.
    ///
    /// AC1: Given Agent completed a read-only analysis task,
    /// When presenting results, Then no user confirmation is needed.
    func testReadOnlyOperationsSkipConfirmation() async throws {
        let viewModel = ConfirmationViewModel(
            operationManager: MockConfirmationOperationManager(),
            permissionState: PermissionState()
        )

        // Read-only operations (metadataChange only)
        let operations = [
            PlannedOperation(
                operationType: .metadataChange,
                assetID: AssetID(rawValue: "/photos/scan_001.jpg"),
                parameters: .metadataChange
            ),
            PlannedOperation(
                operationType: .metadataChange,
                assetID: AssetID(rawValue: "/photos/scan_002.jpg"),
                parameters: .metadataChange
            ),
        ]

        let request = ConfirmationRequest(
            operations: operations,
            confirmationLevel: .none,
            summary: "Scanned 2 photos"
        )

        viewModel.presentConfirmation(request: request)

        // Read-only operations trigger immediate execution (no UI confirmation)
        // After execution completes, request is cleared
        try await Task.sleep(for: .milliseconds(200))

        XCTAssertFalse(viewModel.showSecondConfirmation, "No second confirmation for read-only")
        XCTAssertFalse(viewModel.needsPermissionUpgrade, "No permission upgrade for read-only")
    }

    // MARK: - AC2: Write Operations Show Batch Confirmation Summary (UX-DR11, FR33)

    /// [P0] Write operations (rename, move) show batch confirmation with operation count.
    ///
    /// AC2: Given Agent requests write operations,
    /// When presenting batch confirmation summary,
    /// Then it includes operation count and thumbnail preview,
    /// And shows "Execute" button (primary style) and "Cancel" button (secondary style),
    /// And shows undo path and time window explanation.
    func testWriteOperationsShowBatchConfirmation() async throws {
        let viewModel = ConfirmationViewModel(
            operationManager: MockConfirmationOperationManager(),
            permissionState: PermissionState()
        )

        let operations = [
            PlannedOperation(
                operationType: .rename,
                assetID: AssetID(rawValue: "/photos/sunset.jpg"),
                parameters: .rename(newTitle: "golden_hour")
            ),
            PlannedOperation(
                operationType: .move,
                assetID: AssetID(rawValue: "/photos/beach.jpg"),
                parameters: .move(targetDirectory: "/photos/vacation")
            ),
        ]

        let request = ConfirmationRequest(
            operations: operations,
            confirmationLevel: .standard,
            summary: "Rename 1 photo, move 1 photo"
        )

        // Without write permission, should route to permission upgrade first
        viewModel.presentConfirmation(request: request)
        XCTAssertTrue(viewModel.needsPermissionUpgrade,
            "Write operations without permission should show permission upgrade")

        // After granting permission, re-present with granted state
        viewModel.cancel()
        let grantedPermissionState = await createGrantedPermissionState()
        let viewModel2 = ConfirmationViewModel(
            operationManager: MockConfirmationOperationManager(),
            permissionState: grantedPermissionState
        )
        viewModel2.presentConfirmation(request: request)

        // Now batch confirmation should be presented
        XCTAssertNotNil(viewModel2.request, "Write operations should present confirmation request")
        XCTAssertEqual(viewModel2.request?.confirmationLevel, .standard,
            "Confirmation level should be .standard for write operations")
        XCTAssertEqual(viewModel2.request?.operations.count, 2,
            "Confirmation should show 2 operations")
        XCTAssertFalse(viewModel2.showSecondConfirmation,
            "Standard write operations should NOT show second confirmation")
        XCTAssertFalse(viewModel2.needsPermissionUpgrade,
            "Should not need permission upgrade when already granted")
    }

    // MARK: - AC3: Destructive Operations Show Second Confirmation (UX-DR11, FR33)

    /// [P0] Destructive operations (delete) require a second confirmation sheet.
    ///
    /// AC3: Given Agent requests destructive operations (delete),
    /// When presenting confirmation, Then first show batch confirmation summary
    /// with "Execute" button (danger style, red),
    /// Then after clicking "Execute", show second confirmation Sheet
    /// with operation summary and "Confirm Execute" button.
    func testDestructiveOperationsShowSecondConfirmation() async throws {
        let permissionState = await createGrantedPermissionState()
        let viewModel = ConfirmationViewModel(
            operationManager: MockConfirmationOperationManager(),
            permissionState: permissionState
        )

        let operations = [
            PlannedOperation(
                operationType: .delete,
                assetID: AssetID(rawValue: "/photos/duplicate_001.jpg"),
                parameters: .delete
            ),
            PlannedOperation(
                operationType: .delete,
                assetID: AssetID(rawValue: "/photos/duplicate_002.jpg"),
                parameters: .delete
            ),
        ]

        let request = ConfirmationRequest(
            operations: operations,
            confirmationLevel: .destructive,
            summary: "Delete 2 duplicate photos"
        )

        viewModel.presentConfirmation(request: request)

        // First: batch confirmation is shown
        XCTAssertNotNil(viewModel.request, "Destructive operations should present confirmation")
        XCTAssertEqual(viewModel.request?.confirmationLevel, .destructive,
            "Confirmation level should be .destructive for delete operations")

        // User clicks "Execute" -> second confirmation shown
        viewModel.confirm()

        XCTAssertTrue(viewModel.showSecondConfirmation,
            "Destructive operations should show second confirmation after 'Execute' click")
        XCTAssertFalse(viewModel.isExecuting,
            "Should NOT execute immediately — waiting for second confirmation")
    }

    // MARK: - AC4: Confirmation Flow Integrates with OperationManager (FR35, FR36)

    /// [P0] Confirmation executes through OperationManager.beginBatch + executeBatch.
    ///
    /// AC4: Given user clicks "Execute" on confirmation,
    /// When confirmation flow begins execution,
    /// Then OperationManager.beginBatch() creates a snapshot,
    /// And OperationManager.executeBatch() executes operations,
    /// And execution progress is shown (current/total),
    /// And execution result summary shows success/failure counts.
    func testConfirmationCallsBeginBatchThenExecuteBatch() async throws {
        let mockManager = MockConfirmationOperationManager()
        let permissionState = await createGrantedPermissionState()
        let viewModel = ConfirmationViewModel(
            operationManager: mockManager,
            permissionState: permissionState
        )

        let operations = [
            PlannedOperation(
                operationType: .rename,
                assetID: AssetID(rawValue: "/photos/sunset.jpg"),
                parameters: .rename(newTitle: "golden_hour")
            ),
        ]

        let request = ConfirmationRequest(
            operations: operations,
            confirmationLevel: .standard,
            summary: "Rename 1 photo"
        )

        viewModel.presentConfirmation(request: request)

        // User confirms execution
        viewModel.confirm()

        // Wait for async execution to complete
        try await Task.sleep(for: .milliseconds(200))

        // Verify OperationManager.beginBatch was called
        XCTAssertTrue(mockManager.beginBatchCalled,
            "beginBatch should be called when user confirms execution")

        // Verify OperationManager.executeBatch was called
        XCTAssertTrue(mockManager.executeBatchCalled,
            "executeBatch should be called after beginBatch")

        // Verify progress was updated during execution
        XCTAssertNotNil(viewModel.executionProgress,
            "Execution progress should be available during execution")

        // Verify result summary
        XCTAssertNotNil(viewModel.executionResult,
            "Execution result should be available after execution completes")
    }

    // MARK: - AC5: Permission Check Before Confirmation (FR6, UX-DR9)

    /// [P0] Write operations check permission before showing confirmation.
    ///
    /// AC5: Given Agent requests write operations,
    /// When confirmation UI is about to be shown,
    /// Then check PermissionState.hasWriteAccess,
    /// And if no write permission, show permission upgrade prompt first.
    func testPermissionCheckBeforeConfirmation() async throws {
        // Create PermissionState without write access
        let permissionState = PermissionState()

        let viewModel = ConfirmationViewModel(
            operationManager: MockConfirmationOperationManager(),
            permissionState: permissionState
        )

        let operations = [
            PlannedOperation(
                operationType: .rename,
                assetID: AssetID(rawValue: "/photos/sunset.jpg"),
                parameters: .rename(newTitle: "golden_hour")
            ),
        ]

        let request = ConfirmationRequest(
            operations: operations,
            confirmationLevel: .standard,
            summary: "Rename 1 photo"
        )

        viewModel.presentConfirmation(request: request)

        // Without write permission, should trigger permission upgrade
        XCTAssertTrue(viewModel.needsPermissionUpgrade,
            "Should show permission upgrade when write access is not granted")
        XCTAssertFalse(viewModel.isExecuting,
            "Should NOT execute without write permission")
    }

    /// [P0] Permission denied cancels the operation.
    ///
    /// AC5: Given user denies write permission,
    /// When permission upgrade is rejected,
    /// Then the operation is cancelled and user sees "save results for later" suggestion.
    func testPermissionDeniedCancelsOperation() async throws {
        let permissionState = PermissionState()
        let viewModel = ConfirmationViewModel(
            operationManager: MockConfirmationOperationManager(),
            permissionState: permissionState
        )

        let operations = [
            PlannedOperation(
                operationType: .rename,
                assetID: AssetID(rawValue: "/photos/sunset.jpg"),
                parameters: .rename(newTitle: "golden_hour")
            ),
        ]

        let request = ConfirmationRequest(
            operations: operations,
            confirmationLevel: .standard,
            summary: "Rename 1 photo"
        )

        viewModel.presentConfirmation(request: request)

        // Simulate user denying permission
        viewModel.permissionDenied()

        // Operation should be cancelled
        XCTAssertNil(viewModel.request,
            "Request should be nil after permission denied")
        XCTAssertFalse(viewModel.needsPermissionUpgrade,
            "Permission upgrade flag should be reset after denial")
        XCTAssertFalse(viewModel.isExecuting,
            "Should not be executing after permission denial")
        XCTAssertTrue(viewModel.showPermissionDenied,
            "showPermissionDenied should be true to display save-for-later suggestion")
    }

    // MARK: - P1: Execution Progress Updates

    /// [P1] Execution progress updates correctly during batch execution.
    ///
    /// AC4: During execution, progress shows current/total counts.
    func testExecutionProgressUpdates() async throws {
        let mockManager = MockConfirmationOperationManager()
        mockManager.simulatedProgressSteps = [
            (completed: 1, total: 3),
            (completed: 2, total: 3),
            (completed: 3, total: 3),
        ]

        let permissionState = await createGrantedPermissionState()
        let viewModel = ConfirmationViewModel(
            operationManager: mockManager,
            permissionState: permissionState
        )

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

        let request = ConfirmationRequest(
            operations: operations,
            confirmationLevel: .standard,
            summary: "Rename 3 photos"
        )

        viewModel.presentConfirmation(request: request)
        viewModel.confirm()

        // Wait for async execution to complete
        try await Task.sleep(for: .milliseconds(200))

        // After execution completes, final progress should show all done
        let progress = viewModel.executionProgress
        XCTAssertNotNil(progress, "Progress should be available after execution")
        XCTAssertEqual(progress?.completed, 3, "All 3 operations should be completed")
        XCTAssertEqual(progress?.total, 3, "Total should be 3")
    }

    // MARK: - P1: Execution Result Shows Success and Failure

    /// [P1] Execution result shows success and failure counts.
    ///
    /// AC4: After execution, result summary shows success and failure numbers.
    func testExecutionResultShowsSuccessAndFailure() async throws {
        let mockManager = MockConfirmationOperationManager()
        mockManager.simulatePartialFailure = true

        let permissionState = await createGrantedPermissionState()
        let viewModel = ConfirmationViewModel(
            operationManager: mockManager,
            permissionState: permissionState
        )

        let operations = [
            PlannedOperation(
                operationType: .rename,
                assetID: AssetID(rawValue: "/photos/a.jpg"),
                parameters: .rename(newTitle: "renamed_a")
            ),
            PlannedOperation(
                operationType: .delete,
                assetID: AssetID(rawValue: "/photos/b.jpg"),
                parameters: .delete
            ),
        ]

        let request = ConfirmationRequest(
            operations: operations,
            confirmationLevel: .destructive,
            summary: "Rename 1 photo, delete 1 photo"
        )

        viewModel.presentConfirmation(request: request)
        viewModel.confirm() // First confirmation (destructive)
        viewModel.confirmDestructive() // Second confirmation

        // Wait for async execution to complete
        try await Task.sleep(for: .milliseconds(200))

        let result = viewModel.executionResult
        XCTAssertNotNil(result, "Execution result should be available after execution")
        XCTAssertEqual(result?.failureCount, 2, "All operations should fail when executeBatch throws")
        XCTAssertEqual(result?.successCount, 0, "No operations should succeed when executeBatch throws early")
    }

    // MARK: - P1: Cancel Resets State

    /// [P1] Cancel resets all confirmation state.
    ///
    /// Given user is on the confirmation screen,
    /// When user clicks "Cancel",
    /// Then all state is reset and confirmation UI is dismissed.
    func testCancelResetsState() async throws {
        let permissionState = await createGrantedPermissionState()
        let viewModel = ConfirmationViewModel(
            operationManager: MockConfirmationOperationManager(),
            permissionState: permissionState
        )

        let operations = [
            PlannedOperation(
                operationType: .rename,
                assetID: AssetID(rawValue: "/photos/sunset.jpg"),
                parameters: .rename(newTitle: "golden_hour")
            ),
        ]

        let request = ConfirmationRequest(
            operations: operations,
            confirmationLevel: .standard,
            summary: "Rename 1 photo"
        )

        viewModel.presentConfirmation(request: request)
        XCTAssertNotNil(viewModel.request, "Request should be set after presentConfirmation")

        // Cancel the confirmation
        viewModel.cancel()

        // All state should be reset
        XCTAssertNil(viewModel.request, "Request should be nil after cancel")
        XCTAssertFalse(viewModel.isExecuting, "isExecuting should be false after cancel")
        XCTAssertFalse(viewModel.showSecondConfirmation, "showSecondConfirmation should be false after cancel")
        XCTAssertFalse(viewModel.needsPermissionUpgrade, "needsPermissionUpgrade should be false after cancel")
        XCTAssertNil(viewModel.executionProgress, "executionProgress should be nil after cancel")
        XCTAssertNil(viewModel.executionResult, "executionResult should be nil after cancel")
    }

    // MARK: - P1: Undo Path Displayed

    /// [P1] Confirmation UI shows undo path explanation.
    ///
    /// AC2/AC3: All write operations display undo path and time window.
    /// The confirmation view should include text about undo availability.
    func testUndoPathDisplayed() async throws {
        let permissionState = await createGrantedPermissionState()
        let viewModel = ConfirmationViewModel(
            operationManager: MockConfirmationOperationManager(),
            permissionState: permissionState
        )

        let operations = [
            PlannedOperation(
                operationType: .rename,
                assetID: AssetID(rawValue: "/photos/sunset.jpg"),
                parameters: .rename(newTitle: "golden_hour")
            ),
        ]

        let request = ConfirmationRequest(
            operations: operations,
            confirmationLevel: .standard,
            summary: "Rename 1 photo"
        )

        viewModel.presentConfirmation(request: request)

        // The request should contain undo path information
        XCTAssertNotNil(viewModel.request, "Request should be set")
        XCTAssertNotNil(viewModel.request?.undoDescription,
            "Request should include undo description for user visibility")
    }

    // MARK: - ConfirmationLevel Unit Tests

    /// [P0] ConfirmationLevel.forOperations returns .none for metadata-only operations.
    func testConfirmationLevelNoneForReadOnly() async throws {
        let operations = [
            PlannedOperation(
                operationType: .metadataChange,
                assetID: AssetID(rawValue: "/photos/a.jpg"),
                parameters: .metadataChange
            ),
        ]

        let level = ConfirmationLevel.forOperations(operations)
        XCTAssertEqual(level, .none,
            "Metadata-only operations should have .none confirmation level")
    }

    /// [P0] ConfirmationLevel.forOperations returns .standard for write operations.
    func testConfirmationLevelStandardForWrite() async throws {
        let operations = [
            PlannedOperation(
                operationType: .rename,
                assetID: AssetID(rawValue: "/photos/a.jpg"),
                parameters: .rename(newTitle: "renamed")
            ),
        ]

        let level = ConfirmationLevel.forOperations(operations)
        XCTAssertEqual(level, .standard,
            "Rename operations should have .standard confirmation level")
    }

    /// [P0] ConfirmationLevel.forOperations returns .destructive when any operation is delete.
    func testConfirmationLevelDestructiveForDelete() async throws {
        let operations = [
            PlannedOperation(
                operationType: .rename,
                assetID: AssetID(rawValue: "/photos/a.jpg"),
                parameters: .rename(newTitle: "renamed")
            ),
            PlannedOperation(
                operationType: .delete,
                assetID: AssetID(rawValue: "/photos/b.jpg"),
                parameters: .delete
            ),
        ]

        let level = ConfirmationLevel.forOperations(operations)
        XCTAssertEqual(level, .destructive,
            "Mixed operations with any delete should be .destructive")
    }

    // MARK: - Test Helpers

    /// Creates a PermissionState with write access pre-granted for testing.
    /// Must be called in an async context to await permission grant.
    private func createGrantedPermissionState() async -> PermissionState {
        let mockRepo = MockWriteGrantedRepository()
        let state = PermissionState(repository: mockRepo)
        // Pre-grant write access by calling requestWritePermission
        _ = try? await state.requestWritePermission()
        return state
    }
}

// MARK: - Mock OperationManager for Confirmation Tests

/// Mock implementation of OperationManaging for Story 4.4 confirmation workflow tests.
/// Tracks method calls and simulates batch execution behavior without real file operations.
private final class MockConfirmationOperationManager: OperationManaging, @unchecked Sendable {

    private let queue = DispatchQueue(label: "MockConfirmationOpManager")

    // Tracking
    private var _beginBatchCalled = false
    private var _executeBatchCalled = false
    private var _lastOperations: [PlannedOperation]?

    /// Simulated progress steps for execution progress tests.
    var simulatedProgressSteps: [(completed: Int, total: Int)] = []

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
            throw DomainError.invalidState(reason: "Mock: simulated partial failure")
        }
    }

    func rollbackBatch(_ batchID: OperationManaging.BatchID, repository: PhotoLibraryRepository) async throws {
        // No-op for confirmation tests
    }

    func rollbackLastBatch(repository: PhotoLibraryRepository) async throws {
        // No-op for confirmation tests
    }

    func detectIncompleteBatches() async throws -> [BatchOperation] {
        []
    }

    func getBatchHistory(limit: Int) async throws -> [BatchOperation] {
        []
    }

    func reexecuteLastRolledBackBatch(repository: PhotoLibraryRepository) async throws {
        // No-op for confirmation tests
    }
}

// MARK: - Mock Repository that grants write access

/// Mock repository that always grants write access, used for tests
/// that need permissionState.hasWriteAccess == true.
private struct MockWriteGrantedRepository: PhotoLibraryRepository, Sendable {
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
