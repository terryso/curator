import Foundation

/// Progress of a batch execution, tracked as a struct for proper @Observable change detection.
struct ExecutionProgress: Sendable, Equatable {
    let completed: Int
    let total: Int
}

/// Result of a batch execution displayed to the user.
struct ExecutionResult: Sendable, Equatable {
    let successCount: Int
    let failureCount: Int
    let total: Int

    var isFullSuccess: Bool { failureCount == 0 }
}

/// Manages the confirmation workflow state for planned operations.
///
/// Orchestrates permission checks, confirmation level routing, batch execution,
/// and progress/result tracking. Marked `@Observable @MainActor` for SwiftUI
/// reactivity on the main thread.
@MainActor
@Observable
final class ConfirmationViewModel {

    // MARK: - Observable State

    /// The current pending confirmation request. `nil` when no confirmation is active.
    var request: ConfirmationRequest?

    /// Whether operations are currently being executed.
    var isExecuting: Bool = false

    /// Execution progress (completed/total), updated during batch execution.
    var executionProgress: ExecutionProgress?

    /// Execution result summary, available after batch execution completes.
    var executionResult: ExecutionResult?

    /// Whether the second confirmation sheet is shown (destructive operations only).
    var showSecondConfirmation: Bool = false

    /// Whether a write permission upgrade is needed before confirmation.
    var needsPermissionUpgrade: Bool = false

    /// Whether permission was denied (to show "save for later" suggestion).
    var showPermissionDenied: Bool = false

    // MARK: - Dependencies

    /// Operation manager for batch execution.
    private let operationManager: (any OperationManaging)?

    /// Permission state for checking write access.
    private let permissionState: PermissionState?

    /// Repository provider for getting a PhotoLibraryRepository during execution.
    private let repositoryProvider: (any UndoManagerRepositoryProvider)?

    /// Read-only mode ViewModel for saving operations when permission is denied.
    private let readOnlyModeViewModel: ReadOnlyModeViewModel?

    // MARK: - Initialization

    init(
        operationManager: (any OperationManaging)? = nil,
        permissionState: PermissionState? = nil,
        repositoryProvider: (any UndoManagerRepositoryProvider)? = nil,
        readOnlyModeViewModel: ReadOnlyModeViewModel? = nil
    ) {
        self.operationManager = operationManager
        self.permissionState = permissionState
        self.repositoryProvider = repositoryProvider
        self.readOnlyModeViewModel = readOnlyModeViewModel
    }

    // MARK: - Public Interface

    /// Presents a confirmation UI for the given request.
    ///
    /// For `.none` level (read-only), executes immediately without UI.
    /// For `.standard` / `.destructive`, checks write permission first,
    /// then sets the request for the UI to display.
    func presentConfirmation(request: ConfirmationRequest) {
        // Read-only operations: skip confirmation, execute immediately
        if request.confirmationLevel == .none {
            // Store request before calling executeOperations so it can read it
            self.request = request
            executeOperations()
            return
        }

        // Check write permission for write/destructive operations
        let hasPermission = permissionState?.hasWriteAccess ?? false
        if !hasPermission {
            needsPermissionUpgrade = true
            self.request = request
            return
        }

        // Set the request for the UI to display confirmation
        self.request = request
    }

    /// User confirms execution. For destructive operations, shows second confirmation.
    func confirm() {
        guard let request = request else { return }

        if request.confirmationLevel == .destructive {
            // Show second confirmation sheet instead of executing immediately
            showSecondConfirmation = true
            return
        }

        executeOperations()
    }

    /// User confirms a destructive operation after second confirmation.
    func confirmDestructive() {
        showSecondConfirmation = false
        executeOperations()
    }

    /// Permission was granted — request actual OS-level write access then continue.
    func permissionGranted() {
        _Concurrency.Task { @MainActor in
            // Actually request OS-level write permission before continuing
            _ = try? await self.permissionState?.requestWritePermission()

            self.needsPermissionUpgrade = false
            // Re-present confirmation with permission now potentially granted
            if let currentRequest = self.request {
                self.request = nil
                self.presentConfirmation(request: currentRequest)
            }
        }
    }

    /// Permission was denied — save operations for later and show save-for-later suggestion.
    func permissionDenied() {
        // Save operations for later execution if a ReadOnlyModeViewModel is available
        if let currentRequest = request, let readOnlyVM = readOnlyModeViewModel {
            readOnlyVM.saveOperationsForLater(
                currentRequest.operations,
                summary: currentRequest.summary
            )
        }
        needsPermissionUpgrade = false
        showPermissionDenied = true
        request = nil
        isExecuting = false
        showSecondConfirmation = false
    }

    /// Cancels the confirmation and resets all state.
    func cancel() {
        request = nil
        isExecuting = false
        executionProgress = nil
        executionResult = nil
        showSecondConfirmation = false
        needsPermissionUpgrade = false
        showPermissionDenied = false
    }

    // MARK: - Private Execution

    /// Executes the planned operations through OperationManager.
    private func executeOperations() {
        guard let request = request,
              let manager = operationManager else {
            // No operations to execute or no manager available — reset
            self.request = nil
            return
        }

        let operations = request.operations
        let total = operations.count

        isExecuting = true
        executionProgress = ExecutionProgress(completed: 0, total: total)
        executionResult = nil

        // Resolve repository: prefer provider, fall back to no-op for tests
        let repository: any PhotoLibraryRepository = repositoryProvider?.getRepository()
            ?? ConfirmationNoOpRepository()

        _Concurrency.Task { @MainActor in
            do {
                let batchID = try await manager.beginBatch(operations: operations, repository: repository)

                self.executionProgress = ExecutionProgress(completed: 0, total: total)

                try await manager.executeBatch(batchID, repository: repository)

                self.executionProgress = ExecutionProgress(completed: total, total: total)
                self.executionResult = ExecutionResult(
                    successCount: total,
                    failureCount: 0,
                    total: total
                )
                self.isExecuting = false
                self.request = nil
            } catch {
                // On failure, report partial result — at least the batch snapshot was created
                let completed = self.executionProgress?.completed ?? 0
                self.executionResult = ExecutionResult(
                    successCount: completed,
                    failureCount: total - completed,
                    total: total
                )
                self.isExecuting = false
                self.request = nil
            }
        }
    }
}

// MARK: - No-Op Repository for Confirmation Execution

/// A minimal no-op repository used by ConfirmationViewModel when no
/// repository provider is configured.
///
/// In the test suite, `MockConfirmationOperationManager` replaces the entire
/// OperationManager, so this repository's methods are never meaningfully called.
/// In production, a real repository is provided via `UndoManagerRepositoryProvider`.
private struct ConfirmationNoOpRepository: PhotoLibraryRepository, Sendable {
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
