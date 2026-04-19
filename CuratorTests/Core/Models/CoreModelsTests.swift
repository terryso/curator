import XCTest
@testable import Curator

/// ATDD Tests for Story 1.2 - AC2: 领域模型
///
/// Tests verify:
/// - PhotoAsset value type exists (Sendable, Identifiable)
/// - AssetMetadata value type with file system / EXIF fields (Sendable)
/// - LoadingState<T> generic enum exists
/// - AssetID type exists (Sendable, Hashable, Codable)
/// - FileFormat enum exists with supported extensions
/// - LocationData type exists (Sendable)
/// - SourceChange enum exists
final class CoreModelsTests: XCTestCase {

    // MARK: - AC2: AssetID

    /// [P0] AssetID exists with rawValue string (file path)
    func testAssetIDExistsWithRawValue() throws {
        let id = AssetID(rawValue: "/Users/mock/Photos/photo_1.jpg")

        XCTAssertEqual(id.rawValue, "/Users/mock/Photos/photo_1.jpg",
            "AssetID should wrap a file path rawValue")
    }

    /// [P0] AssetID is Hashable
    func testAssetIDIsHashable() throws {
        let id1 = AssetID(rawValue: "/path/1.jpg")
        let id2 = AssetID(rawValue: "/path/2.jpg")
        let id1Copy = AssetID(rawValue: "/path/1.jpg")

        XCTAssertEqual(id1, id1Copy)
        XCTAssertNotEqual(id1, id2)

        let set: Set<AssetID> = [id1, id2, id1Copy]
        XCTAssertEqual(set.count, 2)
    }

    /// [P1] AssetID is Codable
    func testAssetIDIsCodable() throws {
        let id = AssetID(rawValue: "/Users/test/photo.jpg")
        let encoded = try JSONEncoder().encode(id)
        let decoded = try JSONDecoder().decode(AssetID.self, from: encoded)

        XCTAssertEqual(decoded, id)
    }

    // MARK: - AC2: LocationData

    /// [P1] LocationData exists with latitude and longitude
    func testLocationDataExistsWithCoordinates() throws {
        let location = LocationData(latitude: 37.7749, longitude: -122.4194)

        XCTAssertEqual(location.latitude, 37.7749, accuracy: 0.0001)
        XCTAssertEqual(location.longitude, -122.4194, accuracy: 0.0001)
    }

    // MARK: - AC2: FileFormat

    /// [P0] FileFormat exists and infers from path extension
    func testFileFormatFromPathExtension() throws {
        XCTAssertEqual(FileFormat.from(pathExtension: "jpg"), .jpeg)
        XCTAssertEqual(FileFormat.from(pathExtension: "JPG"), .jpeg)
        XCTAssertEqual(FileFormat.from(pathExtension: "jpeg"), .jpeg)
        XCTAssertEqual(FileFormat.from(pathExtension: "png"), .png)
        XCTAssertEqual(FileFormat.from(pathExtension: "heic"), .heic)
        XCTAssertEqual(FileFormat.from(pathExtension: "tiff"), .tiff)
        XCTAssertEqual(FileFormat.from(pathExtension: "tif"), .tiff)
        XCTAssertEqual(FileFormat.from(pathExtension: "cr2"), .raw)
        XCTAssertEqual(FileFormat.from(pathExtension: "nef"), .raw)
        XCTAssertEqual(FileFormat.from(pathExtension: "dng"), .raw)
        XCTAssertEqual(FileFormat.from(pathExtension: "xyz"), .unknown)
    }

    /// [P0] FileFormat.supportedExtensions contains expected formats
    func testFileFormatSupportedExtensions() throws {
        let exts = FileFormat.supportedExtensions
        XCTAssertTrue(exts.contains("jpg"))
        XCTAssertTrue(exts.contains("jpeg"))
        XCTAssertTrue(exts.contains("png"))
        XCTAssertTrue(exts.contains("heic"))
        XCTAssertTrue(exts.contains("tiff"))
        XCTAssertTrue(exts.contains("cr2"))
        XCTAssertTrue(exts.contains("nef"))
        XCTAssertTrue(exts.contains("dng"))
    }

    // MARK: - AC2: AssetMetadata (文件系统/EXIF 字段)

    /// [P0] AssetMetadata exists with file system / EXIF fields
    func testAssetMetadataExistsWithAllFields() throws {
        let location = LocationData(latitude: 40.7128, longitude: -74.0060)
        let metadata = AssetMetadata(
            fileName: "DSC_0001.jpg",
            fileSize: 5_242_880,
            creationDate: Date(timeIntervalSince1970: 1_700_000_000),
            cameraModel: "Canon EOS R5",
            imageWidth: 4032,
            imageHeight: 3024,
            gpsLocation: location,
            fileFormat: .jpeg
        )

        XCTAssertEqual(metadata.fileName, "DSC_0001.jpg")
        XCTAssertEqual(metadata.fileSize, 5_242_880)
        XCTAssertNotNil(metadata.creationDate)
        XCTAssertEqual(metadata.cameraModel, "Canon EOS R5")
        XCTAssertEqual(metadata.imageWidth, 4032)
        XCTAssertEqual(metadata.imageHeight, 3024)
        XCTAssertEqual(metadata.gpsLocation?.latitude, 40.7128)
        XCTAssertEqual(metadata.fileFormat, .jpeg)
    }

    /// [P1] AssetMetadata allows nil optional fields
    func testAssetMetadataAllowsNilOptionals() throws {
        let metadata = AssetMetadata(
            fileName: "unknown.dat",
            fileSize: nil,
            creationDate: nil,
            cameraModel: nil,
            imageWidth: nil,
            imageHeight: nil,
            gpsLocation: nil,
            fileFormat: nil
        )

        XCTAssertEqual(metadata.fileName, "unknown.dat")
        XCTAssertNil(metadata.fileSize)
        XCTAssertNil(metadata.creationDate)
        XCTAssertNil(metadata.cameraModel)
        XCTAssertNil(metadata.imageWidth)
        XCTAssertNil(metadata.imageHeight)
        XCTAssertNil(metadata.gpsLocation)
        XCTAssertNil(metadata.fileFormat)
    }

    /// [P1] AssetMetadata is Equatable
    func testAssetMetadataIsEquatable() throws {
        let meta1 = AssetMetadata(
            fileName: "test.jpg", fileSize: 100, creationDate: nil,
            cameraModel: nil, imageWidth: nil, imageHeight: nil,
            gpsLocation: nil, fileFormat: .jpeg
        )
        let meta2 = AssetMetadata(
            fileName: "test.jpg", fileSize: 100, creationDate: nil,
            cameraModel: nil, imageWidth: nil, imageHeight: nil,
            gpsLocation: nil, fileFormat: .jpeg
        )
        let meta3 = AssetMetadata(
            fileName: "other.jpg", fileSize: 100, creationDate: nil,
            cameraModel: nil, imageWidth: nil, imageHeight: nil,
            gpsLocation: nil, fileFormat: .jpeg
        )

        XCTAssertEqual(meta1, meta2)
        XCTAssertNotEqual(meta1, meta3)
    }

    // MARK: - AC2: PhotoAsset

    /// [P0] PhotoAsset exists as value type
    func testPhotoAssetExistsAsValueType() throws {
        let id = AssetID(rawValue: "/Users/test/photo.jpg")
        let metadata = AssetMetadata(
            fileName: "photo.jpg", fileSize: nil, creationDate: nil,
            cameraModel: nil, imageWidth: nil, imageHeight: nil,
            gpsLocation: nil, fileFormat: nil
        )
        let asset = PhotoAsset(id: id, metadata: metadata, thumbnailData: nil)

        XCTAssertEqual(asset.id, id)
        XCTAssertEqual(asset.metadata.fileName, "photo.jpg")
        XCTAssertNil(asset.thumbnailData)
    }

    /// [P0] PhotoAsset is Identifiable
    func testPhotoAssetIsIdentifiable() throws {
        let id = AssetID(rawValue: "/path/photo.jpg")
        let metadata = AssetMetadata(
            fileName: "photo.jpg", fileSize: nil, creationDate: nil,
            cameraModel: nil, imageWidth: nil, imageHeight: nil,
            gpsLocation: nil, fileFormat: nil
        )
        let asset = PhotoAsset(id: id, metadata: metadata, thumbnailData: nil)

        XCTAssertEqual(asset.id, id)
    }

    /// [P1] PhotoAsset supports thumbnail data
    func testPhotoAssetSupportsThumbnailData() throws {
        let id = AssetID(rawValue: "/path/thumb.jpg")
        let metadata = AssetMetadata(
            fileName: "thumb.jpg", fileSize: nil, creationDate: nil,
            cameraModel: nil, imageWidth: nil, imageHeight: nil,
            gpsLocation: nil, fileFormat: nil
        )
        let thumbnailData = Data("fake-thumbnail".utf8)
        let asset = PhotoAsset(id: id, metadata: metadata, thumbnailData: thumbnailData)

        XCTAssertEqual(asset.thumbnailData, thumbnailData)
    }

    // MARK: - AC2: LoadingState<T>

    /// [P0] LoadingState has idle case
    func testLoadingStateIdleCase() throws {
        let state: LoadingState<String> = .idle
        if case .idle = state {} else { XCTFail("Should be .idle") }
    }

    /// [P0] LoadingState has loading case
    func testLoadingStateLoadingCase() throws {
        let state: LoadingState<String> = .loading
        if case .loading = state {} else { XCTFail("Should be .loading") }
    }

    /// [P0] LoadingState has loaded case with associated value
    func testLoadingStateLoadedCase() throws {
        let state: LoadingState<String> = .loaded("test-data")
        if case .loaded(let value) = state {
            XCTAssertEqual(value, "test-data")
        } else { XCTFail("Should be .loaded") }
    }

    /// [P0] LoadingState has failed case with DomainError
    func testLoadingStateFailedCase() throws {
        let domainError = DomainError.analysisFailed(reason: "test failure")
        let state: LoadingState<String> = .failed(domainError)
        if case .failed(let error) = state {
            if case .analysisFailed(let reason) = error {
                XCTAssertEqual(reason, "test failure")
            } else { XCTFail("Should carry DomainError") }
        } else { XCTFail("Should be .failed") }
    }

    /// [P1] LoadingState works with different generic types
    func testLoadingStateGenericOverDifferentTypes() throws {
        let arrayState: LoadingState<[PhotoAsset]> = .loaded([])
        if case .loaded(let assets) = arrayState {
            XCTAssertTrue(assets.isEmpty)
        } else { XCTFail("Should work with [PhotoAsset]") }

        let optionalState: LoadingState<Int?> = .loaded(nil)
        if case .loaded(let value) = optionalState {
            XCTAssertNil(value)
        } else { XCTFail("Should work with Optional<Int>") }
    }

    // MARK: - SourceChange

    /// [P0] SourceChange enum exists with required cases
    func testSourceChangeExistsWithRequiredCases() throws {
        let added = SourceChange.filesAdded([AssetID(rawValue: "/new.jpg")])
        let removed = SourceChange.filesRemoved([AssetID(rawValue: "/old.jpg")])
        let modified = SourceChange.filesModified([AssetID(rawValue: "/changed.jpg")])

        if case .filesAdded(let ids) = added {
            XCTAssertEqual(ids.count, 1)
        } else { XCTFail("Should be .filesAdded") }

        if case .filesRemoved = removed {} else { XCTFail("Should be .filesRemoved") }
        if case .filesModified = modified {} else { XCTFail("Should be .filesModified") }
    }

    /// [P1] SourceChange is Equatable
    func testSourceChangeIsEquatable() throws {
        let id = AssetID(rawValue: "/test.jpg")
        let c1 = SourceChange.filesAdded([id])
        let c2 = SourceChange.filesAdded([id])
        let c3 = SourceChange.filesRemoved([id])

        XCTAssertEqual(c1, c2)
        XCTAssertNotEqual(c1, c3)
    }

    // MARK: - PhotoPredicate

    /// PhotoPredicate.all returns a predicate with empty rawValue
    func testPhotoPredicateAllReturnsEmptyRawValue() throws {
        let predicate = PhotoPredicate.all
        XCTAssertTrue(predicate.rawValue.isEmpty)
    }

    /// [P1] PhotoPredicate.filter with FileFormatFilter
    func testPhotoPredicateFilterByFileFormat() throws {
        let predicate = PhotoPredicate.filter(fileFormat: .heic)
        XCTAssertEqual(predicate.fileFormat, .heic)
    }

    // MARK: - FolderBookmarkManaging

    /// [P0] FolderBookmarkManaging protocol exists and is Sendable
    func testFolderBookmarkManagingProtocolExists() throws {
        // Verify the protocol is defined by checking we can create a mock
        let mock = MockFolderBookmarkManager()
        XCTAssertFalse(mock.hasValidBookmark)
        XCTAssertNil(mock.currentFolderURL)
    }
}

/// Mock implementation of FolderBookmarkManaging for testing.
private struct MockFolderBookmarkManager: FolderBookmarkManaging {
    var hasValidBookmark: Bool { false }
    var currentFolderURL: URL? { nil }
    func selectAndBookmarkFolder() async throws -> URL { URL(fileURLWithPath: "/mock/photos") }
    func loadBookmark() async throws -> URL? { nil }
    func accessBookmark(_ url: URL) throws -> Bool { true }
    func releaseBookmark(_ url: URL) {}
}
