import Foundation

/// User review decision for a rename suggestion.
///
/// This state is independent of `RenameSuggestion.status` (which tracks the
/// analysis pipeline status). The review decision represents the user's choice
/// during the UI review flow, to be consumed by Story 6.4 batch operations.
enum RenameReviewDecision: Sendable, Equatable {
    /// Not yet reviewed by the user.
    case pending
    /// User accepted the suggested name.
    case accepted
    /// User rejected the suggested name.
    case rejected
    /// User edited the suggested name with a custom replacement.
    case edited(String)
}

/// ViewModel managing the rename review flow.
///
/// Tracks user review decisions (accept/reject/edit) for each rename suggestion
/// independently from the analysis pipeline's `RenameSuggestion.status`.
/// Designed for SwiftUI consumption via `@Observable` on `@MainActor`.
///
/// Data flow:
/// ```
/// AgentJob (.review state, carrying RenameSuggestion[])
///     -> MainWorkspaceView extracts suggestions
///     -> RenameViewModel.loadSuggestions(suggestions)
///     -> RenameReviewView renders via ViewModel
///     -> User reviews -> ViewModel tracks decisions
///     -> Story 6.4: toRenameOperations() feeds batch operation
/// ```
@MainActor
@Observable
final class RenameViewModel {

    // MARK: - Observable State

    /// All rename suggestions loaded for review.
    /// Read-only externally -- mutations must go through loadSuggestions().
    private(set) var suggestions: [RenameSuggestion] = []

    /// Review decision for each suggestion, keyed by suggestion UUID.
    /// Read-only externally -- mutations must go through accept/reject/edit.
    private(set) var reviewDecisions: [UUID: RenameReviewDecision] = [:]

    // MARK: - Computed Properties

    /// Total number of suggestions loaded for review.
    var totalSuggestions: Int {
        suggestions.count
    }

    /// Suggestions not yet reviewed by the user.
    var pendingSuggestions: [RenameSuggestion] {
        suggestions.filter { suggestion in
            let decision = reviewDecisions[suggestion.id] ?? .pending
            return decision == .pending
        }
    }

    /// Number of suggestions that have been reviewed (accepted, rejected, or edited).
    var reviewedCount: Int {
        suggestions.filter { suggestion in
            let decision = reviewDecisions[suggestion.id] ?? .pending
            return decision != .pending
        }.count
    }

    /// Number of suggestions marked as accepted or edited (both imply user wants to rename).
    var acceptedCount: Int {
        suggestions.filter { suggestion in
            let decision = reviewDecisions[suggestion.id] ?? .pending
            if case .accepted = decision { return true }
            if case .edited = decision { return true }
            return false
        }.count
    }

    /// Whether all suggestions have been reviewed.
    var allReviewed: Bool {
        guard !suggestions.isEmpty else { return false }
        return suggestions.allSatisfy { suggestion in
            let decision = reviewDecisions[suggestion.id] ?? .pending
            return decision != .pending
        }
    }

    /// Progress text for UI display in the format "Reviewed X / Y suggestions".
    var progressText: String {
        "Reviewed \(reviewedCount) / \(totalSuggestions) suggestions"
    }

    // MARK: - Public Methods

    /// Loads rename suggestions for review, resetting any previous review state.
    ///
    /// All suggestions start with `.pending` review decision.
    func loadSuggestions(_ suggestions: [RenameSuggestion]) {
        self.suggestions = suggestions
        self.reviewDecisions = [:]
        for suggestion in suggestions {
            reviewDecisions[suggestion.id] = .pending
        }
    }

    /// Marks a suggestion as accepted (user approves the suggested name).
    func accept(suggestionID: UUID) {
        guard suggestions.contains(where: { $0.id == suggestionID }) else { return }
        reviewDecisions[suggestionID] = .accepted
    }

    /// Marks a suggestion as rejected (user does not want to rename).
    func reject(suggestionID: UUID) {
        guard suggestions.contains(where: { $0.id == suggestionID }) else { return }
        reviewDecisions[suggestionID] = .rejected
    }

    /// Edits a suggestion with a custom name.
    ///
    /// Validates the new name using `RenameSuggestion.isValidFileName`.
    /// If the name is invalid, the edit is rejected and the suggestion
    /// retains its previous decision state.
    func edit(suggestionID: UUID, newName: String) {
        guard suggestions.contains(where: { $0.id == suggestionID }) else { return }
        guard RenameSuggestion.isValidFileName(newName) else { return }
        reviewDecisions[suggestionID] = .edited(newName)
    }

    // MARK: - Batch Operations (Story 6.4 Preparation)

    /// Marks all pending (unreviewed) suggestions as accepted.
    ///
    /// Already-reviewed suggestions are not affected -- only pending suggestions are updated.
    func markAllAsAccept() {
        for suggestion in suggestions where reviewDecisions[suggestion.id] == .pending {
            reviewDecisions[suggestion.id] = .accepted
        }
    }

    /// Marks all pending (unreviewed) suggestions as rejected.
    ///
    /// Already-reviewed suggestions are not affected -- only pending suggestions are updated.
    func markAllAsReject() {
        for suggestion in suggestions where reviewDecisions[suggestion.id] == .pending {
            reviewDecisions[suggestion.id] = .rejected
        }
    }

    // MARK: - Conversion (Story 6.4 Preparation)

    /// Converts accepted/edited suggestions into PlannedOperation list.
    ///
    /// Each suggestion with `.accepted` or `.edited` decision produces a
    /// `.rename` PlannedOperation. Rejected and pending suggestions are excluded.
    func toRenameOperations() -> [PlannedOperation] {
        suggestions.compactMap { suggestion in
            let decision = reviewDecisions[suggestion.id] ?? .pending
            switch decision {
            case .accepted:
                return PlannedOperation(
                    operationType: .rename,
                    assetID: suggestion.assetID,
                    parameters: .rename(newTitle: suggestion.suggestedName)
                )
            case .edited(let customName):
                return PlannedOperation(
                    operationType: .rename,
                    assetID: suggestion.assetID,
                    parameters: .rename(newTitle: customName)
                )
            case .pending, .rejected:
                return nil
            }
        }
    }
}
