import Foundation

/// Manages the application's read/write permission state.
///
/// Starts in read-only mode. Write access is granted only when the user
/// explicitly consents (e.g., when the Agent requests a write operation).
/// Marked `@Observable @MainActor` so SwiftUI views can bind to it directly.
@Observable
@MainActor
final class PermissionState: Sendable {
    /// The underlying photo library repository used to perform permission upgrades.
    private let repository: (any PhotoLibraryRepository)?

    /// Whether the app currently has write permission.
    private var _writeAccessGranted: Bool = false

    /// `true` when the app is in read-only mode (no write permission granted).
    var isReadOnly: Bool {
        !_writeAccessGranted
    }

    /// Whether write access has been granted.
    var hasWriteAccess: Bool {
        _writeAccessGranted
    }

    init(repository: (any PhotoLibraryRepository)? = nil) {
        self.repository = repository
    }

    /// Requests write permission from the user.
    ///
    /// Calls through to the repository's `requestWriteAccess()` which
    /// triggers the bookmark manager's grant flow.
    /// - Returns: `true` if write access was granted, `false` if refused.
    @discardableResult
    func requestWritePermission() async throws -> Bool {
        guard let repository = repository else { return false }
        let granted = try await repository.requestWriteAccess()
        _writeAccessGranted = granted
        return granted
    }

    /// Revokes write access, returning to read-only mode.
    func revokeWriteAccess() {
        _writeAccessGranted = false
    }
}
