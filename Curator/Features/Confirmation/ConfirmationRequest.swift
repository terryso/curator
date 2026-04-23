import Foundation

/// A request to present a confirmation UI for planned operations.
///
/// Value type carrying all information needed to render the confirmation
/// workflow: the operations, confirmation level, summary text, and
/// affected asset IDs for thumbnail preview.
struct ConfirmationRequest: Sendable, Equatable {
    /// The planned operations awaiting confirmation.
    let operations: [PlannedOperation]

    /// The confirmation level determining which UI flow to use.
    let confirmationLevel: ConfirmationLevel

    /// Human-readable summary of the operations.
    let summary: String

    /// IDs of assets affected by the operations (for thumbnail preview).
    var affectedAssetIDs: [AssetID] {
        operations.map(\.assetID)
    }

    /// Description of the undo path shown to the user.
    var undoDescription: String {
        "此操作可通过 ⌘Z 撤销"
    }
}
