import XCTest
@testable import Curator

/// ATDD Tests for Story 1.2 - AC2: 领域模型
///
/// Tests verify:
/// - PhotoAsset value type exists (Sendable, Identifiable)
/// - AssetMetadata value type exists (Sendable)
/// - LoadingState<T> generic enum exists
/// - AssetID type exists (Sendable, Hashable, Codable)
/// - LocationData type exists (Sendable)
/// - All value types conform to Sendable for Swift 6 strict concurrency
final class CoreModelsTests: XCTestCase {

    // MARK: - AC2: AssetID

    /// [P0] AssetID exists with rawValue string
    func testAssetIDExistsWithRawValue() throws {
        let id = AssetID(rawValue: "PHAsset://local-identifier-001")

        XCTAssertEqual(id.rawValue, "PHAsset://local-identifier-001",
            "AssetID should wrap a rawValue string")
    }

    /// [P0] AssetID is Hashable (usable as dictionary key)
    func testAssetIDIsHashable() throws {
        let id1 = AssetID(rawValue: "id-1")
        let id2 = AssetID(rawValue: "id-2")
        let id1Copy = AssetID(rawValue: "id-1")

        XCTAssertEqual(id1, id1Copy, "Same rawValue AssetIDs should be equal")
        XCTAssertNotEqual(id1, id2, "Different rawValue AssetIDs should not be equal")

        // Usable as Set element and Dictionary key
        let set: Set<AssetID> = [id1, id2, id1Copy]
        XCTAssertEqual(set.count, 2, "Set should deduplicate equal AssetIDs")
    }

    /// [P1] AssetID is Codable (serializable)
    func testAssetIDIsCodable() throws {
        let id = AssetID(rawValue: "test-id-for-coding")
        let encoded = try JSONEncoder().encode(id)
        let decoded = try JSONDecoder().decode(AssetID.self, from: encoded)

        XCTAssertEqual(decoded, id,
            "AssetID should round-trip through JSON encoding/decoding")
    }

    // MARK: - AC2: LocationData

    /// [P1] LocationData exists with latitude and longitude
    func testLocationDataExistsWithCoordinates() throws {
        let location = LocationData(latitude: 37.7749, longitude: -122.4194)

        XCTAssertEqual(location.latitude, 37.7749, accuracy: 0.0001,
            "LocationData should store latitude")
        XCTAssertEqual(location.longitude, -122.4194, accuracy: 0.0001,
            "LocationData should store longitude")
    }

    // MARK: - AC2: AssetMetadata

    /// [P0] AssetMetadata exists with all required fields
    func testAssetMetadataExistsWithAllFields() throws {
        let location = LocationData(latitude: 40.7128, longitude: -74.0060)
        let metadata = AssetMetadata(
            creationDate: Date(timeIntervalSince1970: 1700000000),
            title: "Sunset Photo",
            description: "A beautiful sunset over the ocean",
            keywords: ["sunset", "ocean", "landscape"],
            location: location
        )

        XCTAssertNotNil(metadata.creationDate,
            "AssetMetadata should have a creationDate")
        XCTAssertEqual(metadata.title, "Sunset Photo",
            "AssetMetadata should have a title")
        XCTAssertEqual(metadata.description, "A beautiful sunset over the ocean",
            "AssetMetadata should have a description")
        XCTAssertEqual(metadata.keywords, ["sunset", "ocean", "landscape"],
            "AssetMetadata should have keywords")
        XCTAssertNotNil(metadata.location,
            "AssetMetadata should have a location")
        XCTAssertEqual(metadata.location?.latitude, 40.7128)
    }

    /// [P1] AssetMetadata allows nil optional fields
    func testAssetMetadataAllowsNilOptionals() throws {
        let metadata = AssetMetadata(
            creationDate: nil,
            title: nil,
            description: nil,
            keywords: [],
            location: nil
        )

        XCTAssertNil(metadata.creationDate,
            "creationDate should be optional")
        XCTAssertNil(metadata.title,
            "title should be optional")
        XCTAssertNil(metadata.description,
            "description should be optional")
        XCTAssertTrue(metadata.keywords.isEmpty,
            "keywords should default to empty array")
        XCTAssertNil(metadata.location,
            "location should be optional")
    }

    // MARK: - AC2: PhotoAsset

    /// [P0] PhotoAsset exists as value type (Sendable, Identifiable)
    func testPhotoAssetExistsAsValueType() throws {
        let id = AssetID(rawValue: "test-asset-id")
        let metadata = AssetMetadata(
            creationDate: nil,
            title: nil,
            description: nil,
            keywords: [],
            location: nil
        )
        let asset = PhotoAsset(id: id, metadata: metadata, thumbnailData: nil)

        XCTAssertEqual(asset.id, id,
            "PhotoAsset should have the provided id")
        XCTAssertEqual(asset.metadata.title, metadata.title,
            "PhotoAsset should have the provided metadata")
        XCTAssertNil(asset.thumbnailData,
            "PhotoAsset thumbnailData should be optional")
    }

    /// [P0] PhotoAsset is Identifiable
    func testPhotoAssetIsIdentifiable() throws {
        let id = AssetID(rawValue: "identifiable-test")
        let metadata = AssetMetadata(
            creationDate: nil, title: nil, description: nil,
            keywords: [], location: nil
        )
        let asset = PhotoAsset(id: id, metadata: metadata, thumbnailData: nil)

        XCTAssertEqual(asset.id, id,
            "PhotoAsset.id should match the provided AssetID")
    }

    /// [P1] PhotoAsset supports thumbnail data
    func testPhotoAssetSupportsThumbnailData() throws {
        let id = AssetID(rawValue: "thumb-test")
        let metadata = AssetMetadata(
            creationDate: nil, title: nil, description: nil,
            keywords: [], location: nil
        )
        let thumbnailData = Data("fake-thumbnail".utf8)
        let asset = PhotoAsset(id: id, metadata: metadata, thumbnailData: thumbnailData)

        XCTAssertEqual(asset.thumbnailData, thumbnailData,
            "PhotoAsset should carry thumbnail data when provided")
    }

    // MARK: - AC2: LoadingState<T>

    /// [P0] LoadingState has idle case
    func testLoadingStateIdleCase() throws {
        let state: LoadingState<String> = .idle

        if case .idle = state {
            // Expected
        } else {
            XCTFail("LoadingState should have an .idle case")
        }
    }

    /// [P0] LoadingState has loading case
    func testLoadingStateLoadingCase() throws {
        let state: LoadingState<String> = .loading

        if case .loading = state {
            // Expected
        } else {
            XCTFail("LoadingState should have a .loading case")
        }
    }

    /// [P0] LoadingState has loaded case with associated value
    func testLoadingStateLoadedCase() throws {
        let state: LoadingState<String> = .loaded("test-data")

        if case .loaded(let value) = state {
            XCTAssertEqual(value, "test-data",
                "LoadingState.loaded should carry the associated value")
        } else {
            XCTFail("LoadingState should have a .loaded(T) case")
        }
    }

    /// [P0] LoadingState has failed case with DomainError
    func testLoadingStateFailedCase() throws {
        let domainError = DomainError.analysisFailed(reason: "test failure")
        let state: LoadingState<String> = .failed(domainError)

        if case .failed(let error) = state {
            if case .analysisFailed(let reason) = error {
                XCTAssertEqual(reason, "test failure")
            } else {
                XCTFail("LoadingState.failed should carry the DomainError")
            }
        } else {
            XCTFail("LoadingState should have a .failed(DomainError) case")
        }
    }

    /// [P1] LoadingState works with different generic types
    func testLoadingStateGenericOverDifferentTypes() throws {
        // Array of PhotoAsset
        let arrayState: LoadingState<[PhotoAsset]> = .loaded([])
        if case .loaded(let assets) = arrayState {
            XCTAssertTrue(assets.isEmpty)
        } else {
            XCTFail("LoadingState should work with [PhotoAsset]")
        }

        // Optional Int
        let optionalState: LoadingState<Int?> = .loaded(nil)
        if case .loaded(let value) = optionalState {
            XCTAssertNil(value)
        } else {
            XCTFail("LoadingState should work with Optional<Int>")
        }
    }
}
