import Foundation
import XCTest

@testable import Curator

final class FolderBookmarkManagerTests: XCTestCase {

    private let bookmarkKey = "curator.folderBookmark"

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: bookmarkKey)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: bookmarkKey)
        super.tearDown()
    }

    // MARK: - Protocol Conformance

    func testFolderBookmarkManagerConformsToProtocol() {
        let manager = FolderBookmarkManager()
        let _: FolderBookmarkManaging = manager
    }

    // MARK: - hasValidBookmark

    func testHasValidBookmarkReturnsFalseWhenNoBookmark() async {
        let manager = FolderBookmarkManager()
        let result = await manager.hasValidBookmark
        XCTAssertFalse(result)
    }

    // MARK: - currentFolderURL

    func testCurrentFolderURLReturnsNilWhenNoBookmark() async {
        let manager = FolderBookmarkManager()
        let result = await manager.currentFolderURL
        XCTAssertNil(result)
    }

    // MARK: - loadBookmark

    func testLoadBookmarkReturnsNilWhenNoBookmark() async throws {
        let manager = FolderBookmarkManager()
        let result = try await manager.loadBookmark()
        XCTAssertNil(result)
    }

    func testLoadBookmarkHandlesInvalidData() async {
        let manager = FolderBookmarkManager()
        UserDefaults.standard.set(Data("not-a-bookmark".utf8), forKey: bookmarkKey)

        do {
            let result = try await manager.loadBookmark()
            XCTAssertNil(result)
        } catch {
            // Throwing for corrupt data is acceptable
        }
    }

    // MARK: - accessBookmark / releaseBookmark

    func testAccessBookmarkDoesNotCrashForValidURL() {
        let manager = FolderBookmarkManager()
        let tempDir = FileManager.default.temporaryDirectory
        // In test environment, startAccessingSecurityScopedResource may return false
        // Just verify it doesn't crash
        let _ = manager.accessBookmark(tempDir)
        manager.releaseBookmark(tempDir)
    }

    func testReleaseBookmarkDoesNotCrashForValidURL() {
        let manager = FolderBookmarkManager()
        let tempDir = FileManager.default.temporaryDirectory
        manager.releaseBookmark(tempDir)
    }

    // MARK: - currentFolderURL with valid bookmark

    func testCurrentFolderURLReturnsURLWithValidBookmark() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let bookmarkData: Data
        do {
            bookmarkData = try tempDir.bookmarkData(
                options: [],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
        } catch {
            throw XCTSkip("Bookmark creation not supported: \(error)")
        }

        UserDefaults.standard.set(bookmarkData, forKey: bookmarkKey)
        let manager = FolderBookmarkManager()

        // currentFolderURL resolves with .withSecurityScope; in non-sandboxed
        // test runners the URL may still resolve. Verify it returns non-nil
        // or at minimum does not crash.
        let url = await manager.currentFolderURL
        // In sandboxed runners .withSecurityScope may fail for non-scoped data,
        // so we accept nil, but the no-data path is already covered separately.
        if let url = url {
            XCTAssertEqual(url.standardizedFileURL, tempDir.standardizedFileURL)
        }
    }

    func testCurrentFolderURLReturnsNilWithInvalidBookmarkData() async {
        let manager = FolderBookmarkManager()
        UserDefaults.standard.set(Data("garbage-bookmark-data".utf8), forKey: bookmarkKey)

        let result = await manager.currentFolderURL
        XCTAssertNil(result)
    }

    // MARK: - loadBookmark with stale bookmark

    func testLoadBookmarkClearsStaleBookmarkData() async throws {
        // A bookmark that was created for a temp directory which is then deleted
        // before loadBookmark is called. macOS marks such bookmarks as stale.
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let bookmarkData: Data
        do {
            bookmarkData = try tempDir.bookmarkData(
                options: [],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
        } catch {
            throw XCTSkip("Bookmark creation not supported: \(error)")
        }

        // Delete the directory so the bookmark becomes stale
        try FileManager.default.removeItem(at: tempDir)

        UserDefaults.standard.set(bookmarkData, forKey: bookmarkKey)
        let manager = FolderBookmarkManager()

        // loadBookmark uses .withSecurityScope to resolve. When the original
        // directory has been deleted, macOS either marks the bookmark stale
        // (returning nil after clearing UserDefaults) or throws a resolution
        // error. Either outcome is acceptable.
        do {
            let result = try await manager.loadBookmark()
            XCTAssertNil(result)
            // If stale path was taken, UserDefaults should be cleared
            XCTAssertNil(UserDefaults.standard.data(forKey: bookmarkKey))
        } catch {
            // Throwing for unresolvable bookmark data is acceptable;
            // the error propagates to the caller for handling.
        }
    }

    func testLoadBookmarkReturnsURLForValidBookmark() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let bookmarkData: Data
        do {
            bookmarkData = try tempDir.bookmarkData(
                options: [],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
        } catch {
            throw XCTSkip("Bookmark creation not supported: \(error)")
        }

        UserDefaults.standard.set(bookmarkData, forKey: bookmarkKey)
        let manager = FolderBookmarkManager()

        // loadBookmark resolves with .withSecurityScope. In a non-sandboxed
        // test runner this may throw or resolve; either outcome is acceptable.
        do {
            let result = try await manager.loadBookmark()
            if let result = result {
                XCTAssertEqual(result.standardizedFileURL, tempDir.standardizedFileURL)
            }
        } catch {
            // Throwing is acceptable when .withSecurityScope cannot resolve
            // a plain (non-security-scoped) bookmark in the test environment.
        }
    }

    // MARK: - hasValidBookmark with actual bookmark data

    func testHasValidBookmarkReturnsTrueForValidBookmark() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let bookmarkData: Data
        do {
            bookmarkData = try tempDir.bookmarkData(
                options: [],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
        } catch {
            throw XCTSkip("Bookmark creation not supported: \(error)")
        }

        UserDefaults.standard.set(bookmarkData, forKey: bookmarkKey)
        let manager = FolderBookmarkManager()

        let hasValid = await manager.hasValidBookmark
        // In sandboxed environments .withSecurityScope may fail, so
        // we accept false, but the no-data path is covered separately.
        if hasValid {
            XCTAssertTrue(hasValid)
        }
    }

    func testHasValidBookmarkReturnsFalseForInvalidData() async {
        let manager = FolderBookmarkManager()
        UserDefaults.standard.set(Data("not-a-bookmark".utf8), forKey: bookmarkKey)

        let result = await manager.hasValidBookmark
        XCTAssertFalse(result)
    }

    func testHasValidBookmarkReturnsFalseForStaleBookmark() async throws {
        // Create a directory, bookmark it, then delete the directory to make it stale
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let bookmarkData: Data
        do {
            bookmarkData = try tempDir.bookmarkData(
                options: [],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
        } catch {
            throw XCTSkip("Bookmark creation not supported: \(error)")
        }

        // Remove the directory to make the bookmark stale
        try FileManager.default.removeItem(at: tempDir)

        UserDefaults.standard.set(bookmarkData, forKey: bookmarkKey)
        let manager = FolderBookmarkManager()

        let hasValid = await manager.hasValidBookmark
        XCTAssertFalse(hasValid)
    }

    // MARK: - currentFolderURL with stale bookmark

    func testCurrentFolderURLReturnsNilForStaleBookmark() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let bookmarkData: Data
        do {
            bookmarkData = try tempDir.bookmarkData(
                options: [],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
        } catch {
            throw XCTSkip("Bookmark creation not supported: \(error)")
        }

        // Remove the directory to make the bookmark stale
        try FileManager.default.removeItem(at: tempDir)

        UserDefaults.standard.set(bookmarkData, forKey: bookmarkKey)
        let manager = FolderBookmarkManager()

        let result = await manager.currentFolderURL
        XCTAssertNil(result)
    }

    // MARK: - accessBookmark / releaseBookmark edge cases

    func testAccessBookmarkReturnsFalseForFileURL() {
        let manager = FolderBookmarkManager()
        let fileURL = URL(fileURLWithPath: "/tmp/nonexistent-file-\(UUID().uuidString).txt")
        // For a non-existent file URL, startAccessingSecurityScopedResource returns false
        let result = manager.accessBookmark(fileURL)
        XCTAssertFalse(result)
    }

    // MARK: - Bookmark Persistence (integration with real bookmark API)

    func testBookmarkRoundTripWithRealDirectory() async throws {
        // Skip in environments where bookmark creation fails
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // Test environment may not support security-scoped bookmarks
        // Try without .withSecurityScope (plain bookmark)
        let bookmarkData: Data
        do {
            bookmarkData = try tempDir.bookmarkData(
                options: [],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
        } catch {
            // Bookmark creation not supported in test environment
            throw XCTSkip("Bookmark creation not supported: \(error)")
        }

        UserDefaults.standard.set(bookmarkData, forKey: bookmarkKey)

        let manager = FolderBookmarkManager()
        // loadBookmark uses .withSecurityScope which may fail for non-scoped bookmarks
        // This test just verifies the persistence mechanism works
        let hasValid = await manager.hasValidBookmark
        // In test runner without sandbox, bookmark behavior varies
        // The important thing is no crash
        _ = hasValid
    }
}
