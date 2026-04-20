import Foundation
import XCTest

@testable import Curator

/// Test double for FolderBookmarkManaging that avoids NSOpenPanel.
struct TestBookmarkManager: FolderBookmarkManaging {
    var mockBookmarkURL: URL?
    var mockHasValidBookmark: Bool = false
    var shouldThrow = false

    var hasValidBookmark: Bool {
        get async { mockHasValidBookmark }
    }

    var currentFolderURL: URL? {
        get async { mockBookmarkURL }
    }

    func selectAndBookmarkFolder() async throws -> URL {
        if shouldThrow {
            throw InfrastructureError.folderAccessDenied(reason: "mock error")
        }
        return mockBookmarkURL!
    }

    func loadBookmark() async throws -> URL? {
        if shouldThrow { return nil }
        return mockBookmarkURL
    }

    func accessBookmark(_ url: URL) -> Bool {
        true
    }

    func releaseBookmark(_ url: URL) {}
}

final class LocalFolderRepositoryTests: XCTestCase {

    private var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("RepoTests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir!, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    // MARK: - Type Contract

    func testLocalFolderRepositoryIsActor() {
        let repo = LocalFolderRepository()
        // Compile-time check: actor type
        let _: any PhotoLibraryRepository = repo
    }

    func testLocalFolderRepositoryCanBeRegisteredInAppDependencies() async {
        await MainActor.run {
            let deps = AppDependencies()
            deps.registerLocalFolderRepository()
            XCTAssertNotNil(deps.photoRepository)
        }
    }

    // MARK: - requestReadAccess

    func testRequestReadAccessReturnsTrueWithValidBookmark() async throws {
        var bookmarkManager = TestBookmarkManager()
        bookmarkManager.mockBookmarkURL = tempDir
        bookmarkManager.mockHasValidBookmark = true

        let repo = LocalFolderRepository(bookmarkManager: bookmarkManager)
        let result = try await repo.requestReadAccess()
        XCTAssertTrue(result)
    }

    func testRequestReadAccessThrowsWhenNoBookmarkAndNoPanel() async {
        var bookmarkManager = TestBookmarkManager()
        bookmarkManager.mockBookmarkURL = nil
        bookmarkManager.shouldThrow = true

        let repo = LocalFolderRepository(bookmarkManager: bookmarkManager)
        do {
            _ = try await repo.requestReadAccess()
            XCTFail("Should have thrown")
        } catch {
            // Expected
        }
    }

    // MARK: - fetchAssets

    func testFetchAssetsReturnsEmptyWhenNoPhotos() async throws {
        let repo = try await makeReadyRepo()
        let page = try await repo.fetchAssets(predicate: .all, pageSize: 100, pageOffset: 0)
        XCTAssertTrue(page.assets.isEmpty)
        XCTAssertFalse(page.hasMore)
    }

    func testFetchAssetsReturnsPhotoAssets() async throws {
        let repo = try await makeReadyRepo()
        try createTestImage(named: "photo1.jpg")
        try createTestImage(named: "photo2.png")

        let page = try await repo.fetchAssets(predicate: .all, pageSize: 100, pageOffset: 0)
        XCTAssertEqual(page.assets.count, 2)
    }

    func testFetchAssetsFiltersBySupportedExtensions() async throws {
        let repo = try await makeReadyRepo()
        try createTestImage(named: "photo.jpg")
        try Data("text".utf8).write(to: tempDir.appendingPathComponent("readme.txt"))
        try Data("text".utf8).write(to: tempDir.appendingPathComponent("notes.md"))

        let page = try await repo.fetchAssets(predicate: .all, pageSize: 100, pageOffset: 0)
        XCTAssertEqual(page.assets.count, 1)
        XCTAssertEqual(page.assets.first?.metadata.fileFormat, .jpeg)
    }

    func testFetchAssetsRespectsPageSize() async throws {
        let repo = try await makeReadyRepo()
        for i in 0..<5 {
            try createTestImage(named: "photo\(i).jpg")
        }

        let page = try await repo.fetchAssets(predicate: .all, pageSize: 2, pageOffset: 0)
        XCTAssertEqual(page.assets.count, 2)
        XCTAssertTrue(page.hasMore)
        XCTAssertEqual(page.nextOffset, 2)
    }

    func testFetchAssetsSupportsPageOffset() async throws {
        let repo = try await makeReadyRepo()
        for i in 0..<5 {
            try createTestImage(named: "photo\(i).jpg")
        }

        // First page
        let page1 = try await repo.fetchAssets(predicate: .all, pageSize: 2, pageOffset: 0)
        XCTAssertEqual(page1.assets.count, 2)

        // Second page
        let page2 = try await repo.fetchAssets(predicate: .all, pageSize: 2, pageOffset: 2)
        XCTAssertEqual(page2.assets.count, 2)

        // Third page
        let page3 = try await repo.fetchAssets(predicate: .all, pageSize: 2, pageOffset: 4)
        XCTAssertEqual(page3.assets.count, 1)
        XCTAssertFalse(page3.hasMore)
    }

    func testFetchAssetsReturnsEmptyPageBeyondRange() async throws {
        let repo = try await makeReadyRepo()
        try createTestImage(named: "photo.jpg")

        let page = try await repo.fetchAssets(predicate: .all, pageSize: 100, pageOffset: 10)
        XCTAssertTrue(page.assets.isEmpty)
        XCTAssertFalse(page.hasMore)
    }

    func testFetchAssetsRecursivelyScansSubdirectories() async throws {
        let repo = try await makeReadyRepo()
        let subDir = tempDir.appendingPathComponent("subdir")
        try FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true)
        try createTestImage(named: "root_photo.jpg")
        try createTestImage(named: "subdir/sub_photo.png", inDir: nil)

        let page = try await repo.fetchAssets(predicate: .all, pageSize: 100, pageOffset: 0)
        XCTAssertEqual(page.assets.count, 2)
    }

    func testFetchAssetsThrowsWithoutAccess() async {
        var bookmarkManager = TestBookmarkManager()
        bookmarkManager.mockBookmarkURL = nil
        let repo = LocalFolderRepository(bookmarkManager: bookmarkManager)

        do {
            _ = try await repo.fetchAssets(predicate: .all, pageSize: 100, pageOffset: 0)
            XCTFail("Should have thrown")
        } catch {
            // Expected: folderAccessDenied
        }
    }

    // MARK: - fetchFullResolutionImage

    func testFetchFullResolutionImageReturnsFileData() async throws {
        let repo = try await makeReadyRepo()
        let imageData = try createTestImage(named: "photo.jpg")

        let result = try await repo.fetchFullResolutionImage(for: AssetID(rawValue: tempDir.appendingPathComponent("photo.jpg").path))
        XCTAssertEqual(result, imageData)
    }

    func testFetchFullResolutionImageThrowsForNonexistentFile() async throws {
        let repo = try await makeReadyRepo()

        do {
            _ = try await repo.fetchFullResolutionImage(for: AssetID(rawValue: "/nonexistent/path.jpg"))
            XCTFail("Should have thrown")
        } catch let error as DomainError {
            if case .assetNotFound(let id) = error {
                XCTAssertTrue(id.rawValue.contains("nonexistent"))
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - fetchThumbnail

    func testFetchThumbnailReturnsData() async throws {
        let repo = try await makeReadyRepo()
        try createTestImage(named: "photo.jpg")

        let result = try await repo.fetchThumbnail(
            for: AssetID(rawValue: tempDir.appendingPathComponent("photo.jpg").path),
            size: CGSize(width: 50, height: 50)
        )
        XCTAssertGreaterThan(result.count, 0)
    }

    func testFetchThumbnailThrowsForNonexistentFile() async throws {
        let repo = try await makeReadyRepo()

        do {
            _ = try await repo.fetchThumbnail(
                for: AssetID(rawValue: "/nonexistent/path.jpg"),
                size: CGSize(width: 50, height: 50)
            )
            XCTFail("Should have thrown")
        } catch {
            // Expected
        }
    }

    // MARK: - Actor Isolation

    func testRepositoryMethodsExecuteWithinActorIsolation() async throws {
        let repo = try await makeReadyRepo()
        try createTestImage(named: "photo1.jpg")
        try createTestImage(named: "photo2.png")

        // Call multiple methods concurrently — actor should serialize them
        async let page1 = repo.fetchAssets(predicate: .all, pageSize: 1, pageOffset: 0)
        async let page2 = repo.fetchAssets(predicate: .all, pageSize: 1, pageOffset: 1)

        let (p1, p2) = try await (page1, page2)
        XCTAssertEqual(p1.assets.count, 1)
        XCTAssertEqual(p2.assets.count, 1)
    }

    // MARK: - Helpers

    private func makeReadyRepo() async throws -> LocalFolderRepository {
        var bookmarkManager = TestBookmarkManager()
        bookmarkManager.mockBookmarkURL = tempDir
        bookmarkManager.mockHasValidBookmark = true

        let repo = LocalFolderRepository(bookmarkManager: bookmarkManager)
        _ = try await repo.requestReadAccess()
        return repo
    }

    @discardableResult
    private func createTestImage(named name: String, inDir dir: URL? = nil) throws -> Data {
        let base = dir ?? tempDir!
        let url = base.appendingPathComponent(name)
        let parentDir = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)

        let size = NSSize(width: 100, height: 100)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.blue.setFill()
        NSBezierPath.fill(NSRect(origin: .zero, size: size))
        image.unlockFocus()

        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            XCTFail("Failed to create test image bitmap")
            return Data()
        }

        let isJpeg = name.hasSuffix(".jpg") || name.hasSuffix(".jpeg")
        let data: Data
        if isJpeg {
            data = bitmap.representation(using: .jpeg, properties: [:])!
        } else {
            data = bitmap.representation(using: .png, properties: [:])!
        }
        try data.write(to: url)
        return data
    }
}
