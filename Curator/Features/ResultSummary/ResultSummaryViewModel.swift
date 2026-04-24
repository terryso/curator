import AppKit
import SwiftData

/// Protocol for undo capability, allowing test mocks to replace UndoManagerViewModel.
///
/// UndoManagerViewModel is `final`, so tests implement this protocol instead
/// of subclassing. Marked @MainActor to match UndoManagerViewModel's isolation.
@MainActor
protocol UndoCapability {
    /// Whether an undo/redo action is available.
    var canPerformAction: Bool { get }

    /// Performs the undo/redo action.
    @discardableResult
    func performUndoAction() async -> Bool
}

/// Make UndoManagerViewModel conform to UndoCapability.
extension UndoManagerViewModel: UndoCapability {}

/// ViewModel managing the deduplication result summary state.
///
/// Computes and displays statistics from ExecutionResult and DuplicateGroup data
/// after a batch dedup operation completes. Provides celebration animation state,
/// undo support, and history persistence.
///
/// Data flow:
/// ```
/// ConfirmationViewModel.executionResult set after batch execution
///     -> ResultSummaryViewModel.populateFrom(result, groups, reviewStates, ...)
///     -> AgentResultSummaryView renders stats cards + celebration + undo/done buttons
///     -> User clicks "Done" -> saveToHistory() -> return to Agent input state
/// ```
@MainActor
@Observable
final class ResultSummaryViewModel {

    // MARK: - Observable State

    /// Number of photos removed in the dedup operation.
    var removedCount: Int = 0

    /// Total number of duplicate groups processed.
    var totalGroups: Int = 0

    /// Estimated disk space saved, formatted as user-friendly string (e.g., "1.2 GB").
    var savedSpace: String = "0 bytes"

    /// Raw bytes of saved disk space.
    var savedSpaceBytes: Int64 = 0

    /// Duration of the dedup operation in seconds.
    var duration: TimeInterval = 0.0

    /// Date when the result was generated.
    var date: Date?

    /// Whether the celebration animation should be shown.
    var showCelebration: Bool = false

    // MARK: - Dependencies

    /// Undo capability provider for rollback support.
    /// Uses a protocol so tests can provide a mock without subclassing the final class.
    private var undoProvider: (any UndoCapability)?

    /// SwiftData ModelContext for persisting history records.
    /// Nil in tests — saveToHistory() returns the value type without persistence.
    private var modelContext: ModelContext?

    // MARK: - Private State

    /// ByteCountFormatter for formatting saved space display.
    private let byteFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter
    }()

    /// Injectable reduce-motion check for testing. Defaults to NSWorkspace.
    /// Tests can set this to `false` to simulate normal motion preferences.
    internal(set) var reduceMotionOverride: Bool?

    // MARK: - Initialization

    init(undoManager: (any UndoCapability)? = nil, modelContext: ModelContext? = nil) {
        self.undoProvider = undoManager
        self.modelContext = modelContext
    }

    /// Convenience initializer accepting an UndoManagerViewModel directly.
    convenience init(undoManager: UndoManagerViewModel?, modelContext: ModelContext? = nil) {
        self.init(undoManager: undoManager as (any UndoCapability)?, modelContext: modelContext)
    }

    // MARK: - Public Interface

    /// Populates the ViewModel with data from a completed dedup operation.
    ///
    /// Computes removed count from ExecutionResult, total groups from the groups array,
    /// and saved space from the asset sizes of removed groups. Triggers celebration
    /// animation when the result is a full success.
    ///
    /// - Parameters:
    ///   - result: Execution result from the batch operation.
    ///   - groups: All duplicate groups that were processed.
    ///   - reviewStates: User's review decisions for each group.
    ///   - removedAssetSizes: File sizes keyed by AssetID for removed assets.
    ///   - duration: Duration of the operation in seconds.
    func populateFrom(
        result: ExecutionResult,
        groups: [DuplicateGroup],
        reviewStates: [UUID: DuplicateGroupReviewState],
        removedAssetSizes: [AssetID: Int64],
        duration: TimeInterval
    ) {
        self.removedCount = result.successCount
        self.totalGroups = groups.count
        self.duration = duration
        self.date = Date()

        // Calculate saved space: sum file sizes of assets in groups marked for removal
        let removedGroupAssetIDs = groups
            .filter { reviewStates[$0.id] == .remove }
            .flatMap(\.assets)
            .map(\.id)

        let savedBytes = removedGroupAssetIDs
            .compactMap { removedAssetSizes[$0] }
            .reduce(Int64(0), +)

        self.savedSpaceBytes = savedBytes
        self.savedSpace = byteFormatter.string(fromByteCount: savedBytes)

        // Trigger celebration only on full success with at least one removal
        if result.isFullSuccess && result.successCount > 0 {
            triggerCelebration()
        } else {
            showCelebration = false
        }
    }

    /// Triggers the celebration animation with auto-reset after 1.5 seconds.
    ///
    /// Respects the system "Reduce Motion" accessibility setting. When enabled,
    /// the celebration is skipped entirely.
    func triggerCelebration() {
        let isReduceMotion = reduceMotionOverride ?? NSWorkspace.shared.isReduceMotionEnabled
        guard !isReduceMotion else {
            showCelebration = false
            return
        }

        showCelebration = true

        // Auto-reset after 1.5 seconds
        _Concurrency.Task { @MainActor in
            try? await _Concurrency.Task.sleep(for: .milliseconds(1500))
            self.showCelebration = false
        }
    }

    /// Whether an undo action is currently available.
    var canUndo: Bool {
        undoProvider?.canPerformAction ?? false
    }

    /// Performs the undo (rollback) action.
    ///
    /// Delegates to the undo provider's performUndoAction() which rolls back
    /// the last batch operation.
    ///
    /// - Returns: `true` if undo succeeded, `false` otherwise.
    @discardableResult
    func performUndo() async -> Bool {
        guard let provider = undoProvider else { return false }
        return await provider.performUndoAction()
    }

    /// Creates and persists a history record from the current result data.
    ///
    /// When a ModelContext is available, the record is inserted and saved to SwiftData.
    /// Otherwise, returns the value type without persistence (test-friendly).
    /// Should be called when the user clicks "Done" on the result summary.
    ///
    /// - Returns: A DeduplicationResult containing the operation summary.
    @discardableResult
    func saveToHistory() -> DeduplicationResult {
        let record = DeduplicationResult(
            id: UUID(),
            date: date ?? Date(),
            removedCount: removedCount,
            totalGroups: totalGroups,
            savedSpaceBytes: savedSpaceBytes,
            durationSeconds: duration
        )

        // Persist to SwiftData when a ModelContext is available
        if let context = modelContext {
            let entity = DeduplicationResultEntity.from(record)
            context.insert(entity)
            try? context.save()
        }

        return record
    }
}

// MARK: - NSWorkspace Reduce Motion Helper

extension NSWorkspace {
    /// Checks whether the user has enabled "Reduce motion" in System Settings.
    ///
    /// On macOS 15+, this checks `accessibilityDisplayShouldReduceMotion`.
    var isReduceMotionEnabled: Bool {
        accessibilityDisplayShouldReduceMotion
    }
}
