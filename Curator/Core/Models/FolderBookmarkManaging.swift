import Foundation

/// Protocol for managing security-scoped folder bookmarks.
///
/// Defined in the Domain layer to support test-time injection of mock
/// implementations that don't trigger NSOpenPanel dialogs.
protocol FolderBookmarkManaging: Sendable {
    /// Whether a valid folder bookmark currently exists.
    var hasValidBookmark: Bool { get async }

    /// The URL of the currently bookmarked folder, if any.
    var currentFolderURL: URL? { get async }

    /// Whether write access has been explicitly granted by the user.
    ///
    /// The bookmark itself carries read-write capability (via entitlements),
    /// but the app tracks whether the user has consented to write operations.
    var hasWriteAccess: Bool { get async }

    /// Presents NSOpenPanel for folder selection and creates a security-scoped bookmark.
    func selectAndBookmarkFolder() async throws -> URL

    /// Loads a previously stored bookmark and restores access.
    func loadBookmark() async throws -> URL?

    /// Begins accessing a bookmark-protected folder.
    func accessBookmark(_ url: URL) -> Bool

    /// Stops accessing a bookmark-protected folder.
    func releaseBookmark(_ url: URL)

    /// Grants write access after user consent.
    ///
    /// Does not re-present NSOpenPanel. The bookmark already carries read-write
    /// capability from entitlements; this merely records user consent.
    func grantWriteAccess() async

    /// Revokes write access, returning to read-only mode.
    func revokeWriteAccess() async

    /// Requests write consent from the user and returns whether access was granted.
    ///
    /// In production, always grants access (the bookmark already has read-write
    /// capability via entitlements). Test doubles can override to simulate refusal.
    func requestWriteConsent() async -> Bool
}
