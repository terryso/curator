import AppKit
import Foundation

/// Manages security-scoped folder bookmarks for photo library access.
///
/// Handles folder selection via NSOpenPanel, bookmark persistence to UserDefaults,
/// and security-scoped resource access lifecycle.
struct FolderBookmarkManager: FolderBookmarkManaging, @unchecked Sendable {
    private let bookmarkKey = "curator.folderBookmark"

    var hasValidBookmark: Bool {
        get async {
            guard let data = UserDefaults.standard.data(forKey: bookmarkKey) else { return false }
            var stale = false
            do {
                _ = try URL(
                    resolvingBookmarkData: data,
                    options: .withSecurityScope,
                    relativeTo: nil,
                    bookmarkDataIsStale: &stale
                )
                return !stale
            } catch {
                return false
            }
        }
    }

    var currentFolderURL: URL? {
        get async {
            guard let data = UserDefaults.standard.data(forKey: bookmarkKey) else { return nil }
            var stale = false
            do {
                let url = try URL(
                    resolvingBookmarkData: data,
                    options: .withSecurityScope,
                    relativeTo: nil,
                    bookmarkDataIsStale: &stale
                )
                return stale ? nil : url
            } catch {
                return nil
            }
        }
    }

    @MainActor
    func selectAndBookmarkFolder() async throws -> URL {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "选择照片文件夹"

        let response = await panel.beginSheetModal(for: NSApp.keyWindow ?? NSWindow())
        guard response == .OK, let url = panel.url else {
            throw InfrastructureError.folderAccessDenied(reason: "用户取消了文件夹选择")
        }

        let bookmarkData = try url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        UserDefaults.standard.set(bookmarkData, forKey: bookmarkKey)
        return url
    }

    func loadBookmark() async throws -> URL? {
        guard let data = UserDefaults.standard.data(forKey: bookmarkKey) else { return nil }
        var stale = false
        let url = try URL(
            resolvingBookmarkData: data,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &stale
        )
        if stale {
            UserDefaults.standard.removeObject(forKey: bookmarkKey)
            return nil
        }
        return url
    }

    func accessBookmark(_ url: URL) -> Bool {
        url.startAccessingSecurityScopedResource()
    }

    func releaseBookmark(_ url: URL) {
        url.stopAccessingSecurityScopedResource()
    }
}
