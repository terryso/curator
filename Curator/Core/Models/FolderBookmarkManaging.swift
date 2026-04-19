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

    /// Presents NSOpenPanel for folder selection and creates a security-scoped bookmark.
    func selectAndBookmarkFolder() async throws -> URL

    /// Loads a previously stored bookmark and restores access.
    func loadBookmark() async throws -> URL?

    /// Begins accessing a bookmark-protected folder.
    func accessBookmark(_ url: URL) throws -> Bool

    /// Stops accessing a bookmark-protected folder.
    func releaseBookmark(_ url: URL)
}
