import Foundation

/// Confirmation level for planned operations.
///
/// Maps operation types to user confirmation requirements:
/// - `.none`: Read-only (metadata-only) operations skip confirmation.
/// - `.standard`: Write operations (rename, move) require batch confirmation.
/// - `.destructive`: Destructive operations (delete) require second confirmation.
enum ConfirmationLevel: Sendable, Equatable {
    case none
    case standard
    case destructive

    /// Determines the confirmation level for a list of planned operations.
    ///
    /// - If any operation is `.delete`, returns `.destructive`.
    /// - If all operations are `.metadataChange`, returns `.none`.
    /// - Otherwise, returns `.standard`.
    static func forOperations(_ operations: [PlannedOperation]) -> ConfirmationLevel {
        if operations.contains(where: { $0.operationType == .delete }) {
            return .destructive
        }
        if operations.allSatisfy({ $0.operationType == .metadataChange }) {
            return .none
        }
        return .standard
    }
}
