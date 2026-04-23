import Foundation

/// Protocol for providing repository access to UndoManagerViewModel.
protocol UndoManagerRepositoryProvider: Sendable {
    func getRepository() -> any PhotoLibraryRepository
}

/// Manages undo/redo state for batch operations.
///
/// Provides the bridge between the UI layer (Cmd+Z shortcut, undo button)
/// and the OperationManager actor. Tracks whether the next undo action
/// should perform a rollback (undo) or reexecute (redo).
///
/// Usage:
/// - When last batch status is `.completed` -> Cmd+Z triggers undo (rollback)
/// - When last batch status is `.rolledBack` -> Cmd+Z triggers redo (reexecute)
@MainActor
@Observable
final class UndoManagerViewModel {

    /// The last undoable action type available.
    enum UndoAction: Sendable, Equatable {
        case undo
        case redo
        case none
    }

    /// Current action available for Cmd+Z.
    var availableAction: UndoAction = .none

    /// Whether an undo/redo operation is currently in progress.
    var isProcessing: Bool = false

    /// Progress description for the current operation.
    var progressDescription: String = ""

    /// Last error encountered during undo/redo.
    var lastError: String?

    /// Whether the crash recovery sheet should be shown.
    var showCrashRecoverySheet: Bool = false

    /// Incomplete batches detected on startup (for crash recovery).
    var incompleteBatches: [BatchOperation] = []

    /// Reference to the operation manager for executing undo/redo operations.
    private let operationManager: (any OperationManaging)?

    /// Reference to the repository provider for getting a PhotoLibraryRepository.
    private let repositoryProvider: (any UndoManagerRepositoryProvider)?

    init(
        operationManager: (any OperationManaging)?,
        repositoryProvider: (any UndoManagerRepositoryProvider)? = nil
    ) {
        self.operationManager = operationManager
        self.repositoryProvider = repositoryProvider
    }

    // MARK: - Public Interface

    /// Refreshes the available undo/redo action based on current batch history.
    func refreshAvailableAction() async {
        guard let manager = operationManager else {
            availableAction = .none
            return
        }

        do {
            let history = try await manager.getBatchHistory(limit: 1)
            guard let lastBatch = history.first else {
                availableAction = .none
                return
            }

            switch lastBatch.status {
            case .completed:
                availableAction = .undo
            case .rolledBack:
                availableAction = .redo
            default:
                availableAction = .none
            }
        } catch {
            availableAction = .none
        }
    }

    /// Performs the undo/redo action triggered by Cmd+Z or the undo button.
    ///
    /// - Returns: `true` if the action was performed successfully, `false` otherwise.
    @discardableResult
    func performUndoAction() async -> Bool {
        guard let manager = operationManager,
              let provider = repositoryProvider,
              availableAction != .none,
              !isProcessing else {
            return false
        }

        let repository = provider.getRepository()
        isProcessing = true
        lastError = nil
        progressDescription = availableAction == .undo ? "正在撤销..." : "正在重做..."

        do {
            switch availableAction {
            case .undo:
                try await manager.rollbackLastBatch(repository: repository)
            case .redo:
                try await manager.reexecuteLastRolledBackBatch(repository: repository)
            case .none:
                isProcessing = false
                return false
            }

            progressDescription = ""
            await refreshAvailableAction()
            isProcessing = false
            return true
        } catch {
            lastError = error.localizedDescription
            progressDescription = ""
            isProcessing = false
            return false
        }
    }

    /// Checks for incomplete batches on app startup (crash recovery, NFR17).
    ///
    /// If incomplete batches are found, sets `showCrashRecoverySheet = true`
    /// so the UI can display a recovery prompt.
    func checkForIncompleteBatches() async {
        guard let manager = operationManager else { return }

        do {
            let incomplete = try await manager.detectIncompleteBatches()
            if !incomplete.isEmpty {
                incompleteBatches = incomplete
                showCrashRecoverySheet = true
            }
        } catch {
            // Silently ignore -- crash recovery is best-effort
        }
    }

    /// Rolls back a specific incomplete batch (crash recovery action).
    ///
    /// Called when the user chooses to roll back an incomplete batch
    /// from the crash recovery sheet.
    func rollbackIncompleteBatch(_ batch: BatchOperation) async -> Bool {
        guard let manager = operationManager,
              let provider = repositoryProvider else { return false }

        let repository = provider.getRepository()
        isProcessing = true
        progressDescription = "正在恢复未完成的操作..."

        do {
            try await manager.rollbackBatch(batch.id, repository: repository)
            incompleteBatches.removeAll { $0.id == batch.id }
            if incompleteBatches.isEmpty {
                showCrashRecoverySheet = false
            }
            await refreshAvailableAction()
            isProcessing = false
            progressDescription = ""
            return true
        } catch {
            lastError = error.localizedDescription
            isProcessing = false
            progressDescription = ""
            return false
        }
    }

    /// Dismisses the crash recovery sheet and marks incomplete batches as ignored.
    func dismissCrashRecovery() async {
        showCrashRecoverySheet = false
        incompleteBatches = []
    }

    /// Whether an undo/redo action is available (for button visibility).
    var canPerformAction: Bool {
        availableAction != .none && !isProcessing
    }
}
