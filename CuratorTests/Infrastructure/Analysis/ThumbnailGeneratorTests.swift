import Foundation
import XCTest

@testable import Curator

/// ATDD Tests for Story 5.2 — Thumbnail Generator
///
/// Tests verify:
/// - AC2: Thumbnail generation for duplicate groups
/// - AC6: Memory control via size-limited output
/// - NFR23: Corrupt image handling without crash
///
/// TDD RED PHASE: All tests use XCTSkipIf(true) to skip until
/// the feature is implemented. Remove skips one-by-one during implementation.
final class ThumbnailGeneratorTests: XCTestCase {

    // MARK: - AC2: Thumbnail Generation (FR21)

    /// [P0] ThumbnailGenerator generates thumbnails of the correct target size.
    ///
    /// AC2: Given an image asset,
    /// When generating a thumbnail at 200x200,
    /// Then the result is JPEG-compressed data at the specified dimensions.
    func testGenerateThumbnailReturnsJPEGData() async throws {

        // Given: A ThumbnailGenerator and a valid image asset
        let generator = ThumbnailGenerator()
        let asset = PhotoAsset(
            id: AssetID(rawValue: "/photos/thumbnail_test.jpg"),
            metadata: AssetMetadata(
                fileName: "thumbnail_test.jpg",
                fileSize: 2048,
                creationDate: nil,
                cameraModel: nil,
                imageWidth: 800,
                imageHeight: 600,
                gpsLocation: nil,
                fileFormat: .jpeg
            ),
            thumbnailData: nil
        )
        let mockRepo = MockThumbnailTestRepository()
        let targetSize = CGSize(width: 200, height: 200)

        // When: Generating a thumbnail
        let thumbnailData = try await generator.generateThumbnail(
            for: asset.id,
            repository: mockRepo,
            targetSize: targetSize
        )

        // Then: Returns non-empty JPEG data
        XCTAssertGreaterThan(thumbnailData.count, 0, "Thumbnail should be non-empty")
        XCTAssertTrue(thumbnailData.starts(with: [0xFF, 0xD8, 0xFF]),
            "Thumbnail should be JPEG data (starts with FFD8FF)")
    }

    /// [P0] Batch thumbnail generation produces data for all assets.
    ///
    /// AC2: Given multiple assets,
    /// When generating thumbnails in batch,
    /// Then all assets receive thumbnail data.
    func testBatchGenerateThumbnailsForMultipleAssets() async throws {

        // Given: Multiple assets
        let assets = (0..<5).map { i in
            PhotoAsset(
                id: AssetID(rawValue: "/photos/thumb_batch_\(i).jpg"),
                metadata: AssetMetadata(
                    fileName: "thumb_batch_\(i).jpg",
                    fileSize: 1024,
                    creationDate: nil,
                    cameraModel: nil,
                    imageWidth: 100,
                    imageHeight: 100,
                    gpsLocation: nil,
                    fileFormat: .jpeg
                ),
                thumbnailData: nil
            )
        }
        let generator = ThumbnailGenerator()
        let mockRepo = MockThumbnailTestRepository()
        let targetSize = CGSize(width: 200, height: 200)

        // When: Generating thumbnails for all assets
        let thumbnails = await generator.generateThumbnails(
            for: assets,
            repository: mockRepo,
            targetSize: targetSize
        )

        // Then: All assets have thumbnail data
        XCTAssertEqual(thumbnails.count, 5, "Should generate thumbnails for all 5 assets")
        for asset in assets {
            XCTAssertNotNil(thumbnails[asset.id], "Asset \(asset.id.rawValue) should have thumbnail data")
        }
    }

    /// [P0] Thumbnails are compressed to reasonable size (memory control).
    ///
    /// AC6/NFR6: Thumbnails should be small enough to keep total memory under budget.
    /// 200x200 JPEG at quality 0.7 should be roughly 5-30KB each.
    func testThumbnailSizeIsReasonable() async throws {

        // Given: An image asset with a large source image
        let generator = ThumbnailGenerator()
        let asset = PhotoAsset(
            id: AssetID(rawValue: "/photos/large_photo.jpg"),
            metadata: AssetMetadata(
                fileName: "large_photo.jpg",
                fileSize: 5_000_000,
                creationDate: nil,
                cameraModel: nil,
                imageWidth: 4000,
                imageHeight: 3000,
                gpsLocation: nil,
                fileFormat: .jpeg
            ),
            thumbnailData: nil
        )
        let mockRepo = MockThumbnailTestRepository()
        let targetSize = CGSize(width: 200, height: 200)

        // When: Generating a thumbnail from a large image
        let thumbnailData = try await generator.generateThumbnail(
            for: asset.id,
            repository: mockRepo,
            targetSize: targetSize
        )

        // Then: Thumbnail is small (< 100KB for 200x200 JPEG)
        let maxExpectedSize = 100 * 1024 // 100KB
        XCTAssertLessThan(thumbnailData.count, maxExpectedSize,
            "Thumbnail should be under 100KB for 200x200 JPEG, got \(thumbnailData.count) bytes")
    }

    // MARK: - NFR23: Error Handling and Fault Tolerance

    /// [P1] Corrupt image does not crash thumbnail generation.
    ///
    /// NFR23: Given an image that cannot be decoded,
    /// When attempting to generate its thumbnail,
    /// Then the error is mapped to DomainError.analysisFailed,
    /// And the process does not crash.
    func testThumbnailGenerationHandlesCorruptImage() async throws {

        // Given: An asset with corrupt image data
        let generator = ThumbnailGenerator()
        let asset = PhotoAsset(
            id: AssetID(rawValue: "/photos/corrupt.jpg"),
            metadata: AssetMetadata(
                fileName: "corrupt.jpg",
                fileSize: 100,
                creationDate: nil,
                cameraModel: nil,
                imageWidth: 100,
                imageHeight: 100,
                gpsLocation: nil,
                fileFormat: .jpeg
            ),
            thumbnailData: nil
        )
        let mockRepo = MockThumbnailCorruptRepository()

        // When/Then: Should throw DomainError.analysisFailed, not crash
        do {
            _ = try await generator.generateThumbnail(
                for: asset.id,
                repository: mockRepo,
                targetSize: CGSize(width: 200, height: 200)
            )
            XCTFail("Should throw DomainError.analysisFailed for corrupt image data")
        } catch let error as DomainError {
            if case .analysisFailed(let reason) = error {
                XCTAssertTrue(reason.count > 0, "Error should include a descriptive reason")
            } else {
                XCTFail("Should be analysisFailed, got: \(error)")
            }
        }
    }

    /// [P1] Batch thumbnail generation skips corrupt images without failing the batch.
    ///
    /// NFR23: In batch mode, individual failures do not prevent other thumbnails from generating.
    func testBatchThumbnailGenerationSkipsCorruptImages() async throws {

        // Given: Assets where one returns corrupt data
        let goodAsset = PhotoAsset(
            id: AssetID(rawValue: "/photos/good.jpg"),
            metadata: AssetMetadata(
                fileName: "good.jpg",
                fileSize: 1024,
                creationDate: nil,
                cameraModel: nil,
                imageWidth: 100,
                imageHeight: 100,
                gpsLocation: nil,
                fileFormat: .jpeg
            ),
            thumbnailData: nil
        )
        let badAsset = PhotoAsset(
            id: AssetID(rawValue: "/photos/corrupt.jpg"),
            metadata: AssetMetadata(
                fileName: "corrupt.jpg",
                fileSize: 50,
                creationDate: nil,
                cameraModel: nil,
                imageWidth: 100,
                imageHeight: 100,
                gpsLocation: nil,
                fileFormat: .jpeg
            ),
            thumbnailData: nil
        )
        let generator = ThumbnailGenerator()
        let mockRepo = MockThumbnailMixedRepository(
            corruptAssetIDs: [badAsset.id]
        )

        // When: Generating thumbnails for mixed assets
        let thumbnails = await generator.generateThumbnails(
            for: [goodAsset, badAsset],
            repository: mockRepo,
            targetSize: CGSize(width: 200, height: 200)
        )

        // Then: Good asset has thumbnail, bad asset is skipped
        XCTAssertNotNil(thumbnails[goodAsset.id],
            "Valid asset should still get a thumbnail")
    }
}

// MARK: - Mock: Repository returning valid images

private final class MockThumbnailTestRepository: PhotoLibraryRepository, @unchecked Sendable {

    func currentBasePath() async -> String? { nil }
    func requestReadAccess() async throws -> Bool { true }
    func requestWriteAccess() async throws -> Bool { true }

    func fetchAssets(predicate: PhotoPredicate, pageSize: Int, pageOffset: Int) async throws -> AssetPage {
        AssetPage(assets: [], hasMore: false)
    }

    func fetchFullResolutionImage(for assetID: AssetID) async throws -> Data {
        let size = NSSize(width: 100, height: 100)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.green.setFill()
        NSBezierPath.fill(NSRect(origin: .zero, size: size))
        image.unlockFocus()

        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            throw DomainError.analysisFailed(reason: "Failed to create mock image")
        }

        return bitmap.representation(using: .jpeg, properties: [:])!
    }

    func fetchThumbnail(for assetID: AssetID, size: CGSize) async throws -> Data { Data() }

    func metadata(for assetID: AssetID) async throws -> AssetMetadata {
        AssetMetadata(fileName: "", fileSize: nil, creationDate: nil, cameraModel: nil,
                       imageWidth: nil, imageHeight: nil, gpsLocation: nil, fileFormat: nil)
    }

    func updateAsset(_ assetID: AssetID, title: String?) async throws {}
    func deleteAssets(_ assetIDs: [AssetID]) async throws {}
    func moveAssets(_ assetIDs: [AssetID], to directory: String) async throws {}
    func observeSourceChanges() -> AsyncStream<SourceChange> {
        AsyncStream { $0.finish() }
    }
}

// MARK: - Mock: Repository returning corrupt image data

private final class MockThumbnailCorruptRepository: PhotoLibraryRepository, @unchecked Sendable {

    func currentBasePath() async -> String? { nil }
    func requestReadAccess() async throws -> Bool { true }
    func requestWriteAccess() async throws -> Bool { true }

    func fetchAssets(predicate: PhotoPredicate, pageSize: Int, pageOffset: Int) async throws -> AssetPage {
        AssetPage(assets: [], hasMore: false)
    }

    func fetchFullResolutionImage(for assetID: AssetID) async throws -> Data {
        Data("this is not valid image data at all".utf8)
    }

    func fetchThumbnail(for assetID: AssetID, size: CGSize) async throws -> Data { Data() }

    func metadata(for assetID: AssetID) async throws -> AssetMetadata {
        AssetMetadata(fileName: "", fileSize: nil, creationDate: nil, cameraModel: nil,
                       imageWidth: nil, imageHeight: nil, gpsLocation: nil, fileFormat: nil)
    }

    func updateAsset(_ assetID: AssetID, title: String?) async throws {}
    func deleteAssets(_ assetIDs: [AssetID]) async throws {}
    func moveAssets(_ assetIDs: [AssetID], to directory: String) async throws {}
    func observeSourceChanges() -> AsyncStream<SourceChange> {
        AsyncStream { $0.finish() }
    }
}

// MARK: - Mock: Repository with mixed valid/corrupt images

private final class MockThumbnailMixedRepository: PhotoLibraryRepository, @unchecked Sendable {

    private let corruptAssetIDs: Set<AssetID>

    init(corruptAssetIDs: [AssetID]) {
        self.corruptAssetIDs = Set(corruptAssetIDs)
    }

    func currentBasePath() async -> String? { nil }
    func requestReadAccess() async throws -> Bool { true }
    func requestWriteAccess() async throws -> Bool { true }

    func fetchAssets(predicate: PhotoPredicate, pageSize: Int, pageOffset: Int) async throws -> AssetPage {
        AssetPage(assets: [], hasMore: false)
    }

    func fetchFullResolutionImage(for assetID: AssetID) async throws -> Data {
        if corruptAssetIDs.contains(assetID) {
            return Data("corrupt data".utf8)
        }

        let size = NSSize(width: 100, height: 100)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.red.setFill()
        NSBezierPath.fill(NSRect(origin: .zero, size: size))
        image.unlockFocus()

        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            throw DomainError.analysisFailed(reason: "Failed to create mock image")
        }

        return bitmap.representation(using: .jpeg, properties: [:])!
    }

    func fetchThumbnail(for assetID: AssetID, size: CGSize) async throws -> Data { Data() }

    func metadata(for assetID: AssetID) async throws -> AssetMetadata {
        AssetMetadata(fileName: "", fileSize: nil, creationDate: nil, cameraModel: nil,
                       imageWidth: nil, imageHeight: nil, gpsLocation: nil, fileFormat: nil)
    }

    func updateAsset(_ assetID: AssetID, title: String?) async throws {}
    func deleteAssets(_ assetIDs: [AssetID]) async throws {}
    func moveAssets(_ assetIDs: [AssetID], to directory: String) async throws {}
    func observeSourceChanges() -> AsyncStream<SourceChange> {
        AsyncStream { $0.finish() }
    }
}
