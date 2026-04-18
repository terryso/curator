import Foundation

/// Represents the permission level required for an operation.
///
/// Used by DomainError.insufficientPermission to indicate what level of
/// access was needed when a permission check fails.
enum PermissionLevel: Sendable, Equatable {
    case read
    case write
}
