import Foundation

/// User decision for a duplicate group during review.
///
/// This state is independent of `DuplicateGroup.status` (which tracks the
/// analysis pipeline status). The review state represents the user's decision
/// during the UI review flow, to be consumed by Story 5.5 batch operations.
enum DuplicateGroupReviewState: Sendable, Equatable {
    /// Not yet reviewed by the user.
    case pending
    /// User chose to keep all photos in this group.
    case keep
    /// User chose to mark duplicates for removal.
    case remove
}

/// ViewModel managing the deduplication review flow.
///
/// Tracks user review decisions (keep/remove) for each duplicate group
/// independently from the analysis pipeline's `DuplicateGroup.status`.
/// Designed for SwiftUI consumption via `@Observable` on `@MainActor`.
///
/// Data flow:
/// ```
/// AgentJob (.review state, carrying DuplicateGroup[])
///     -> MainWorkspaceView extracts groups
///     -> DeduplicationViewModel.loadGroups(groups)
///     -> DuplicateReviewView renders via ViewModel
///     -> User reviews -> ViewModel tracks decisions
///     -> Story 5.5: assetsToRemove() feeds batch operation
/// ```
@MainActor
@Observable
final class DeduplicationViewModel {

    // MARK: - Observable State

    /// All duplicate groups loaded for review.
    /// Read-only externally — mutations must go through loadGroups().
    private(set) var groups: [DuplicateGroup] = []

    /// Review decision for each group, keyed by group UUID.
    /// Read-only externally — mutations must go through markAsKeep/markAsRemove/toggleReviewState.
    private(set) var reviewStates: [UUID: DuplicateGroupReviewState] = [:]

    // MARK: - Computed Properties

    /// Groups not yet reviewed by the user.
    var pendingGroups: [DuplicateGroup] {
        groups.filter { reviewStates[$0.id] == .pending || reviewStates[$0.id] == nil }
    }

    /// Number of groups that have been reviewed (keep or remove).
    var reviewedCount: Int {
        groups.filter { state in
            let reviewState = reviewStates[state.id] ?? .pending
            return reviewState != .pending
        }.count
    }

    /// Total number of groups loaded for review.
    var totalGroups: Int {
        groups.count
    }

    /// Number of groups marked for removal.
    var markedForRemovalCount: Int {
        groups.filter { reviewStates[$0.id] == .remove }.count
    }

    /// Whether all groups have been reviewed.
    var allReviewed: Bool {
        guard !groups.isEmpty else { return false }
        return groups.allSatisfy { state in
            let reviewState = reviewStates[state.id] ?? .pending
            return reviewState != .pending
        }
    }

    // MARK: - Public Methods

    /// Loads duplicate groups for review, resetting any previous review state.
    ///
    /// All groups start with `.pending` review state.
    func loadGroups(_ groups: [DuplicateGroup]) {
        self.groups = groups
        self.reviewStates = [:]
        for group in groups {
            reviewStates[group.id] = .pending
        }
    }

    /// Marks a group as "keep" (user wants to retain all photos).
    func markAsKeep(groupID: UUID) {
        guard groups.contains(where: { $0.id == groupID }) else { return }
        reviewStates[groupID] = .keep
    }

    /// Marks a group as "remove" (user wants to remove duplicate photos).
    func markAsRemove(groupID: UUID) {
        guard groups.contains(where: { $0.id == groupID }) else { return }
        reviewStates[groupID] = .remove
    }

    /// Cycles the review state for a group: pending -> keep -> remove -> pending.
    func toggleReviewState(groupID: UUID) {
        guard groups.contains(where: { $0.id == groupID }) else { return }
        let current = reviewStates[groupID] ?? .pending
        switch current {
        case .pending:
            reviewStates[groupID] = .keep
        case .keep:
            reviewStates[groupID] = .remove
        case .remove:
            reviewStates[groupID] = .pending
        }
    }

    /// Returns the asset IDs of photos marked for removal.
    ///
    /// For each group marked as `.remove`, returns all asset IDs in that group.
    /// Used by Story 5.5 to feed the batch deletion operation.
    func assetsToRemove() -> [AssetID] {
        groups
            .filter { reviewStates[$0.id] == .remove }
            .flatMap(\.assets)
            .map(\.id)
    }

    // MARK: - Batch Operations (Story 5.5)

    /// Marks all pending (unreviewed) groups as `.keep`.
    ///
    /// Already-reviewed groups are not affected — only pending groups are updated.
    func markAllAsKeep() {
        for group in groups where reviewStates[group.id] == .pending {
            reviewStates[group.id] = .keep
        }
    }

    /// Marks all pending (unreviewed) groups as `.remove`.
    ///
    /// Already-reviewed groups are not affected — only pending groups are updated.
    func markAllAsRemove() {
        for group in groups where reviewStates[group.id] == .pending {
            reviewStates[group.id] = .remove
        }
    }

    /// Converts groups marked for removal into PlannedOperation list.
    ///
    /// Each asset in a `.remove`-marked group produces a `.delete` PlannedOperation.
    /// Groups marked as `.keep` or `.pending` are excluded.
    /// Used to bridge review decisions to the confirmation workflow (AC4).
    func toDeleteOperations() -> [PlannedOperation] {
        assetsToRemove().map { assetID in
            PlannedOperation(
                operationType: .delete,
                assetID: assetID,
                parameters: .delete
            )
        }
    }
}
