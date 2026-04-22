import Foundation

/// User-visible errors for presentation in the UI layer.
///
/// These errors never expose technical details (HTTP codes, error domains, etc.).
/// They are produced by mapping DomainError through `toUserFacingError()`.
enum UserFacingError: Sendable {
    case readOnly(title: String, message: String)
    case retryable(title: String, message: String)
    case permissionRequired(title: String, action: String)
    case writePermissionRequired(title: String, message: String, action: String)
}
