import Foundation
import XCTest

@testable import Curator

/// ATDD Tests for Story 4.1 — 写入权限渐进授权
///
/// Tests verify:
/// - AC1: 只读默认启动 — 应用默认以只读权限启动
/// - AC2: 按需写入权限升级 — 写操作前请求并验证写入权限
/// - AC3: 权限拒绝降级处理 — 拒绝时展示引导说明
/// - AC4: 写操作实现 — updateAsset/deleteAssets/moveAssets 正确执行
/// - AC5: 权限状态 UI 指示 — 只读模式指示器可见
final class WritePermissionTests: XCTestCase {

    private var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("WritePermTests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(
            at: tempDir!, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    // MARK: - Helpers

    @discardableResult
    private func createTestImage(named name: String) throws -> Data {
        let url = tempDir.appendingPathComponent(name)
        let parentDir = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: parentDir, withIntermediateDirectories: true)

        let size = NSSize(width: 100, height: 100)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.blue.setFill()
        NSBezierPath.fill(NSRect(origin: .zero, size: size))
        image.unlockFocus()

        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData)
        else {
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

    // ================================================================
    // AC1: 只读默认启动 (FR37)
    // ================================================================

    /// [P0] AC1 — Application starts in read-only mode by default.
    /// requestWriteAccess returns false when consent is not granted.
    func testReadOnlyDefaultOnStartup() async throws {
        var bookmarkManager = TestBookmarkManager()
        bookmarkManager.mockBookmarkURL = tempDir
        bookmarkManager.mockHasValidBookmark = true
        bookmarkManager.shouldGrantWrite = false

        let repo = LocalFolderRepository(bookmarkManager: bookmarkManager)
        _ = try await repo.requestReadAccess()

        let canWrite = try await repo.requestWriteAccess()
        XCTAssertFalse(canWrite, "Should start in read-only mode by default")
    }

    /// [P1] AC1 — Read-only mode allows analysis operations.
    /// fetchAssets works without write access.
    func testReadOnlyModeAllowsAnalysisOperations() async throws {
        var bookmarkManager = TestBookmarkManager()
        bookmarkManager.mockBookmarkURL = tempDir
        bookmarkManager.mockHasValidBookmark = true

        let repo = LocalFolderRepository(bookmarkManager: bookmarkManager)
        _ = try await repo.requestReadAccess()

        try createTestImage(named: "photo1.jpg")
        try createTestImage(named: "photo2.png")

        let page = try await repo.fetchAssets(
            predicate: .all, pageSize: 100, pageOffset: 0)
        XCTAssertEqual(page.assets.count, 2,
            "Read-only mode should allow reading/analysis operations")
    }

    // ================================================================
    // AC2: 按需写入权限升级 (FR6)
    // ================================================================

    /// [P0] AC2 — requestWriteAccess upgrades from read-only to read-write.
    /// After granting write access at the bookmark manager level,
    /// requestWriteAccess returns true.
    func testRequestWriteAccessUpgradesBookmark() async throws {
        let bookmarkManager = GrantableBookmarkManager(mockBookmarkURL: tempDir)
        let repo = LocalFolderRepository(bookmarkManager: bookmarkManager)
        _ = try await repo.requestReadAccess()

        let beforeGrant = try await repo.requestWriteAccess()
        XCTAssertTrue(beforeGrant,
            "requestWriteAccess should return true after granting consent")
    }

    /// [P0] AC2 — Write operations proceed after write permission is granted.
    /// updateAsset succeeds when write access is available.
    func testWriteOperationSucceedsWithPermission() async throws {
        var bookmarkManager = TestBookmarkManager()
        bookmarkManager.mockBookmarkURL = tempDir
        bookmarkManager.mockHasValidBookmark = true

        let repo = LocalFolderRepository(bookmarkManager: bookmarkManager)
        _ = try await repo.requestReadAccess()
        let writeGranted = try await repo.requestWriteAccess()
        guard writeGranted else {
            XCTFail("Test setup: requestWriteAccess should succeed in this scenario")
            return
        }

        try createTestImage(named: "original.jpg")
        let originalPath = tempDir.appendingPathComponent("original.jpg").path
        let assetID = AssetID(rawValue: originalPath)

        try await repo.updateAsset(assetID, title: "renamed")

        let renamedPath = tempDir.appendingPathComponent("renamed.jpg").path
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: renamedPath),
            "File should be renamed after updateAsset with write permission")
        XCTAssertFalse(
            FileManager.default.fileExists(atPath: originalPath),
            "Original file should no longer exist after rename")
    }

    // ================================================================
    // AC3: 权限拒绝降级处理 (UX-DR9)
    // ================================================================

    /// [P0] AC3 — Write operations throw insufficientPermission(.write)
    /// when write access has not been granted.
    func testWriteOperationWithoutPermissionThrows() async throws {
        var bookmarkManager = TestBookmarkManager()
        bookmarkManager.mockBookmarkURL = tempDir
        bookmarkManager.mockHasValidBookmark = true
        bookmarkManager.shouldGrantWrite = false

        let repo = LocalFolderRepository(bookmarkManager: bookmarkManager)
        _ = try await repo.requestReadAccess()
        // Do NOT grant write permission

        try createTestImage(named: "photo.jpg")
        let assetID = AssetID(
            rawValue: tempDir.appendingPathComponent("photo.jpg").path)

        do {
            try await repo.updateAsset(assetID, title: "newname")
            XCTFail("Should have thrown insufficientPermission for write")
        } catch let error as DomainError {
            if case .insufficientPermission(let level) = error {
                XCTAssertEqual(level, .write,
                    "Should throw insufficientPermission(.write)")
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        }
    }

    /// [P1] AC3 — User refuses write permission; operation degrades gracefully.
    /// requestWriteAccess returns false and subsequent write ops throw.
    func testWritePermissionRefusedReturnsGracefully() async throws {
        var bookmarkManager = TestBookmarkManager()
        bookmarkManager.mockBookmarkURL = tempDir
        bookmarkManager.mockHasValidBookmark = true
        bookmarkManager.shouldGrantWrite = false

        let repo = LocalFolderRepository(bookmarkManager: bookmarkManager)
        _ = try await repo.requestReadAccess()

        let result = try await repo.requestWriteAccess()
        XCTAssertFalse(result, "requestWriteAccess should return false when refused")

        try createTestImage(named: "photo.jpg")
        let assetID = AssetID(
            rawValue: tempDir.appendingPathComponent("photo.jpg").path)

        do {
            try await repo.updateAsset(assetID, title: "renamed")
            XCTFail("Should throw after write permission refusal")
        } catch let error as DomainError {
            if case .insufficientPermission(let level) = error {
                XCTAssertEqual(level, .write)
            } else {
                XCTFail("Expected insufficientPermission, got: \(error)")
            }
        }
    }

    // ================================================================
    // AC4: 写操作实现 (FR38, NFR15)
    // ================================================================

    /// [P0] AC4 — updateAsset renames file (moveItem), does NOT modify pixel data.
    /// Verifies NFR15: zero file corruption.
    func testUpdateAssetRenamesFile() async throws {
        var bookmarkManager = TestBookmarkManager()
        bookmarkManager.mockBookmarkURL = tempDir
        bookmarkManager.mockHasValidBookmark = true

        let repo = LocalFolderRepository(bookmarkManager: bookmarkManager)
        _ = try await repo.requestReadAccess()
        let writeGranted = try await repo.requestWriteAccess()
        guard writeGranted else {
            XCTFail("Test setup: write access needed for this test")
            return
        }

        let originalData = try createTestImage(named: "photo.jpg")
        let assetID = AssetID(
            rawValue: tempDir.appendingPathComponent("photo.jpg").path)
        try await repo.updateAsset(assetID, title: "renamed_photo")

        let renamedURL = tempDir.appendingPathComponent("renamed_photo.jpg")
        XCTAssertTrue(FileManager.default.fileExists(atPath: renamedURL.path),
            "Renamed file should exist")

        let renamedData = try Data(contentsOf: renamedURL)
        XCTAssertEqual(renamedData, originalData,
            "File data must be identical after rename — NFR15 zero corruption")
    }

    /// [P0] AC4 — updateAsset with nil title is a no-op.
    func testUpdateAssetWithNilTitleIsNoOp() async throws {
        var bookmarkManager = TestBookmarkManager()
        bookmarkManager.mockBookmarkURL = tempDir
        bookmarkManager.mockHasValidBookmark = true

        let repo = LocalFolderRepository(bookmarkManager: bookmarkManager)
        _ = try await repo.requestReadAccess()
        let writeGranted = try await repo.requestWriteAccess()
        guard writeGranted else {
            XCTFail("Test setup: write access needed")
            return
        }

        try createTestImage(named: "photo.jpg")
        let originalPath = tempDir.appendingPathComponent("photo.jpg").path
        let assetID = AssetID(rawValue: originalPath)

        try await repo.updateAsset(assetID, title: nil)
        XCTAssertTrue(FileManager.default.fileExists(atPath: originalPath),
            "File should remain unchanged when title is nil")
    }

    /// [P0] AC4 — deleteAssets moves files to trash (not permanent delete).
    func testDeleteAssetsMovesToTrash() async throws {
        var bookmarkManager = TestBookmarkManager()
        bookmarkManager.mockBookmarkURL = tempDir
        bookmarkManager.mockHasValidBookmark = true

        let repo = LocalFolderRepository(bookmarkManager: bookmarkManager)
        _ = try await repo.requestReadAccess()
        let writeGranted = try await repo.requestWriteAccess()
        guard writeGranted else {
            XCTFail("Test setup: write access needed")
            return
        }

        try createTestImage(named: "to_delete.jpg")
        let filePath = tempDir.appendingPathComponent("to_delete.jpg")
        XCTAssertTrue(FileManager.default.fileExists(atPath: filePath.path))

        let assetID = AssetID(rawValue: filePath.path)
        try await repo.deleteAssets([assetID])

        XCTAssertFalse(FileManager.default.fileExists(atPath: filePath.path),
            "File should be removed from original location after trash")
    }

    /// [P0] AC4 — deleteAssets throws fileNotFound for non-existent file.
    func testDeleteAssetsThrowsForNonExistentFile() async throws {
        var bookmarkManager = TestBookmarkManager()
        bookmarkManager.mockBookmarkURL = tempDir
        bookmarkManager.mockHasValidBookmark = true

        let repo = LocalFolderRepository(bookmarkManager: bookmarkManager)
        _ = try await repo.requestReadAccess()
        let writeGranted = try await repo.requestWriteAccess()
        guard writeGranted else {
            XCTFail("Test setup: write access needed")
            return
        }

        let assetID = AssetID(rawValue: "/nonexistent/path/photo.jpg")
        do {
            try await repo.deleteAssets([assetID])
            XCTFail("Should throw for non-existent file")
        } catch let error as DomainError {
            if case .assetNotFound = error {
                // Correct
            } else {
                XCTFail("Expected assetNotFound, got: \(error)")
            }
        }
    }

    /// [P0] AC4 — moveAssets creates destination directory and moves files.
    func testMoveAssetsCreatesDirectoryAndMoves() async throws {
        var bookmarkManager = TestBookmarkManager()
        bookmarkManager.mockBookmarkURL = tempDir
        bookmarkManager.mockHasValidBookmark = true

        let repo = LocalFolderRepository(bookmarkManager: bookmarkManager)
        _ = try await repo.requestReadAccess()
        let writeGranted = try await repo.requestWriteAccess()
        guard writeGranted else {
            XCTFail("Test setup: write access needed")
            return
        }

        let originalData = try createTestImage(named: "photo1.jpg")
        try createTestImage(named: "photo2.jpg")

        let asset1 = AssetID(
            rawValue: tempDir.appendingPathComponent("photo1.jpg").path)
        let asset2 = AssetID(
            rawValue: tempDir.appendingPathComponent("photo2.jpg").path)

        try await repo.moveAssets([asset1, asset2], to: "Sorted")

        let destDir = tempDir.appendingPathComponent("Sorted")
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: destDir.appendingPathComponent("photo1.jpg").path),
            "photo1.jpg should be moved to Sorted/")
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: destDir.appendingPathComponent("photo2.jpg").path),
            "photo2.jpg should be moved to Sorted/")

        let movedData = try Data(
            contentsOf: destDir.appendingPathComponent("photo1.jpg"))
        XCTAssertEqual(movedData, originalData,
            "Moved file data must be identical — NFR15")
    }

    /// [P1] AC4 — deleteAssets without write permission throws.
    func testDeleteAssetsWithoutPermissionThrows() async throws {
        var bookmarkManager = TestBookmarkManager()
        bookmarkManager.mockBookmarkURL = tempDir
        bookmarkManager.mockHasValidBookmark = true
        bookmarkManager.shouldGrantWrite = false

        let repo = LocalFolderRepository(bookmarkManager: bookmarkManager)
        _ = try await repo.requestReadAccess()
        // Do NOT grant write permission

        try createTestImage(named: "photo.jpg")
        let assetID = AssetID(
            rawValue: tempDir.appendingPathComponent("photo.jpg").path)

        do {
            try await repo.deleteAssets([assetID])
            XCTFail("Should throw without write permission")
        } catch let error as DomainError {
            if case .insufficientPermission(let level) = error {
                XCTAssertEqual(level, .write)
            } else {
                XCTFail("Expected insufficientPermission(.write), got: \(error)")
            }
        }
    }

    /// [P1] AC4 — moveAssets without write permission throws.
    func testMoveAssetsWithoutPermissionThrows() async throws {
        var bookmarkManager = TestBookmarkManager()
        bookmarkManager.mockBookmarkURL = tempDir
        bookmarkManager.mockHasValidBookmark = true
        bookmarkManager.shouldGrantWrite = false

        let repo = LocalFolderRepository(bookmarkManager: bookmarkManager)
        _ = try await repo.requestReadAccess()
        // Do NOT grant write permission

        try createTestImage(named: "photo.jpg")
        let assetID = AssetID(
            rawValue: tempDir.appendingPathComponent("photo.jpg").path)

        do {
            try await repo.moveAssets([assetID], to: "SubFolder")
            XCTFail("Should throw without write permission")
        } catch let error as DomainError {
            if case .insufficientPermission(let level) = error {
                XCTAssertEqual(level, .write)
            } else {
                XCTFail("Expected insufficientPermission(.write), got: \(error)")
            }
        }
    }

    // ================================================================
    // AC5: 权限状态 UI 指示 (FR37) — PermissionState model
    // ================================================================

    /// [P1] AC5 — PermissionState starts in read-only mode.
    func testPermissionStateIsReadOnlyByDefault() async throws {
        await MainActor.run {
            let state = PermissionState()
            XCTAssertTrue(state.isReadOnly,
                "PermissionState should start in read-only mode")
        }
    }

    /// [P1] AC5 — PermissionState reflects read-write after granting write.
    func testPermissionStateChangesAfterGrant() async throws {
        let mockRepo = MockPhotoLibraryRepository()
        let state = await MainActor.run { PermissionState(repository: mockRepo) }
        await MainActor.run {
            XCTAssertTrue(state.isReadOnly)
        }

        let granted = try await state.requestWritePermission()
        XCTAssertTrue(granted, "requestWritePermission should return true on grant")
        await MainActor.run {
            XCTAssertFalse(state.isReadOnly,
                "PermissionState should not be read-only after write is granted")
        }
    }

    // ================================================================
    // Error Mapping: Write permission produces distinct UserFacingError
    // ================================================================

    /// [P0] AC3 — DomainError.insufficientPermission(.write) maps to
    /// writePermissionRequired (a distinct case from .read).
    func testWritePermissionErrorMapsDistinctly() throws {
        let writeError = DomainError.insufficientPermission(required: .write)
        let userError = writeError.toUserFacingError()

        if case .writePermissionRequired(let title, _, _) = userError {
            XCTAssertFalse(title.isEmpty,
                "writePermissionRequired should have a non-empty title")
        } else {
            XCTFail(
                "Expected writePermissionRequired case, got: \(userError)")
        }
    }

    /// [P1] AC3 — Read and write permission errors map to different UserFacingError cases.
    func testReadAndWriteErrorsMapDifferently() throws {
        let readError = DomainError.insufficientPermission(required: .read)
        let writeError = DomainError.insufficientPermission(required: .write)

        let readUserError = readError.toUserFacingError()
        let writeUserError = writeError.toUserFacingError()

        switch (readUserError, writeUserError) {
        case (.permissionRequired, .writePermissionRequired):
            break  // Correct: different cases
        default:
            XCTFail(
                "Read and write errors should map to different UserFacingError cases")
        }
    }

    // ================================================================
    // FolderBookmarkManaging protocol: hasWriteAccess
    // ================================================================

    /// [P0] AC2 — FolderBookmarkManaging protocol exposes hasWriteAccess.
    func testFolderBookmarkManagerHasWriteAccessProperty() async throws {
        let manager = FolderBookmarkManager()
        let hasWrite = await manager.hasWriteAccess
        XCTAssertFalse(hasWrite,
            "hasWriteAccess should be false initially")
    }

    /// [P0] AC2 — FolderBookmarkManager hasWriteAccess reflects granted state.
    func testFolderBookmarkManagerWriteAccessAfterGrant() async throws {
        // Clean up any previous state
        let writeAccessKey = "curator.writeAccessGranted"
        UserDefaults.standard.removeObject(forKey: writeAccessKey)

        let manager = FolderBookmarkManager()
        try await manager.grantWriteAccess()
        let hasWrite = await manager.hasWriteAccess
        XCTAssertTrue(hasWrite,
            "hasWriteAccess should be true after granting write access")

        // Clean up
        UserDefaults.standard.removeObject(forKey: writeAccessKey)
    }
}

// MARK: - Test Helpers

/// Bookmark manager that supports granting/revoking write access for tests.
/// Uses a class to allow mutation across actor boundaries.
final class GrantableBookmarkManager: FolderBookmarkManaging, @unchecked Sendable {
    private let queue = DispatchQueue(label: "GrantableBookmarkManager")
    private let _mockBookmarkURL: URL?
    private var _writeAccessGranted = false

    init(mockBookmarkURL: URL?) {
        self._mockBookmarkURL = mockBookmarkURL
    }

    var hasValidBookmark: Bool {
        get async { _mockBookmarkURL != nil }
    }

    var currentFolderURL: URL? {
        get async { _mockBookmarkURL }
    }

    var hasWriteAccess: Bool {
        get async { queue.sync { _writeAccessGranted } }
    }

    func selectAndBookmarkFolder() async throws -> URL {
        _mockBookmarkURL!
    }

    func loadBookmark() async throws -> URL? {
        _mockBookmarkURL
    }

    func accessBookmark(_ url: URL) -> Bool { true }

    func releaseBookmark(_ url: URL) {}

    func grantWriteAccess() async {
        queue.sync { _writeAccessGranted = true }
    }

    func revokeWriteAccess() async {
        queue.sync { _writeAccessGranted = false }
    }

    func requestWriteConsent() async -> Bool {
        queue.sync { _writeAccessGranted = true }
        return true
    }
}
