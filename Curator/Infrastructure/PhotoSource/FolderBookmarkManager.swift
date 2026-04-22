import AppKit
import Foundation

/// Manages security-scoped folder bookmarks for photo library access.
///
/// Handles folder selection via NSOpenPanel, bookmark persistence to UserDefaults,
/// and security-scoped resource access lifecycle. Write access is tracked as an
/// application-level consent flag; the underlying bookmark already carries read-write
/// capability via the `com.apple.security.files.user-selected.read-write` entitlement.
struct FolderBookmarkManager: FolderBookmarkManaging, @unchecked Sendable {
    private let bookmarkKey = "curator.folderBookmark"
    private let writeAccessKey = "curator.writeAccessGranted"

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

    var hasWriteAccess: Bool {
        get async { UserDefaults.standard.bool(forKey: writeAccessKey) }
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

    func grantWriteAccess() async {
        UserDefaults.standard.set(true, forKey: writeAccessKey)
    }

    func revokeWriteAccess() async {
        UserDefaults.standard.set(false, forKey: writeAccessKey)
    }

    func requestWriteConsent() async -> Bool {
        // In production, the bookmark already carries read-write capability
        // via entitlements. Granting is automatic (the user has already
        // consented by selecting the folder in NSOpenPanel).
        UserDefaults.standard.set(true, forKey: writeAccessKey)
        return true
    }
}
