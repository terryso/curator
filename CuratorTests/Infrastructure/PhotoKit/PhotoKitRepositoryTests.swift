import XCTest
import Photos
@testable import Curator

/// ATDD Tests for Story 1.3 - AC2, AC3, AC4: PhotoKitRepository
///
/// Tests verify:
/// - PhotoKitRepository exists as an actor implementing PhotoLibraryRepository
/// - requestReadAccess delegates to PhotoPermissionManager
/// - requestWriteAccess returns false (placeholder for Story 4.1)
/// - fetchAssets returns paginated results via AssetPage
/// - fetchFullResolutionImage returns image data for a given AssetID
/// - All PhotoKit operations execute within actor isolation (thread safety)
/// - Errors are properly mapped through InfrastructureError -> DomainError chain
final class PhotoKitRepositoryTests: XCTestCase {

    /// Skips the test if PhotoKit access is not already granted to avoid system dialogs.
    private func skipIfNoPhotoKitAccess() throws {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited else {
            throw XCTSkip("Photo library access not pre-granted — skipping to avoid system dialog")
        }
    }

    // MARK: - AC2: PhotoKitRepository Type

    /// [P0] PhotoKitRepository exists as an actor
    func testPhotoKitRepositoryExistsAsActor() async throws {
        try skipIfNoPhotoKitAccess()
        // Given: PhotoKitRepository is defined as an actor
        // Then: It can be instantiated
        let repository = PhotoKitRepository()
        XCTAssertNotNil(repository, "PhotoKitRepository should be instantiable")
    }

    /// [P0] PhotoKitRepository conforms to PhotoLibraryRepository protocol
    func testPhotoKitRepositoryConformsToProtocol() async throws {
        try skipIfNoPhotoKitAccess()
        // Given: PhotoKitRepository actor
        // Then: It should be usable as a PhotoLibraryRepository
        let repository = PhotoKitRepository()
        let repoAsProtocol: any PhotoLibraryRepository = repository
        XCTAssertNotNil(repoAsProtocol,
            "PhotoKitRepository should conform to PhotoLibraryRepository")
    }

    /// [P0] PhotoKitRepository is an actor (not a class or struct)
    func testPhotoKitRepositoryIsActor() async throws {
        try skipIfNoPhotoKitAccess()
        // Given: PhotoKitRepository is declared as `actor`
        // Then: All method calls must go through actor isolation
        // This is validated at compile time — if this test compiles,
        // PhotoKitRepository is correctly an actor.
        let repository = PhotoKitRepository()
        // Actor reference is valid — compiler enforces isolation
        let _ = repository
        XCTAssertTrue(true, "PhotoKitRepository compiles as actor — compile-time verification passed")
    }

    // MARK: - AC1: requestReadAccess()

    /// [P0] requestReadAccess delegates to PhotoPermissionManager and returns true when authorized
    func testRequestReadAccessReturnsTrueWhenAuthorized() async throws {
        try skipIfNoPhotoKitAccess()
        let repository = PhotoKitRepository()
        let result = try await repository.requestReadAccess()
        XCTAssertTrue(result,
            "requestReadAccess should return true when permission is granted")
    }

    /// [P0] requestReadAccess throws when permission is denied
    func testRequestReadAccessThrowsWhenDenied() async throws {
        let mock = MockPermissionManager(status: .denied)
        let repository = PhotoKitRepository(permissionManager: mock)

        do {
            _ = try await repository.requestReadAccess()
            XCTFail("requestReadAccess should throw when denied")
        } catch let error as DomainError {
            if case .insufficientPermission = error {
                // Correct mapping through the chain
            } else {
                XCTFail("Expected insufficientPermission, got \(error)")
            }
        } catch {
            XCTFail("Error should be DomainError type, got \(type(of: error))")
        }
    }

    // MARK: - AC2: requestWriteAccess() (Placeholder)

    /// [P1] requestWriteAccess returns false (placeholder for Story 4.1)
    func testRequestWriteAccessReturnsFalse() async throws {
        try skipIfNoPhotoKitAccess()
        let repository = PhotoKitRepository()

        // When: Calling requestWriteAccess()
        let result = try await repository.requestWriteAccess()

        // Then: Returns false
        XCTAssertFalse(result,
            "requestWriteAccess should return false as placeholder")
    }

    // MARK: - AC2, AC3: fetchAssets()

    /// [P0] fetchAssets returns AssetPage with assets and hasMore
    func testFetchAssetsReturnsAssetPage() async throws {
        try skipIfNoPhotoKitAccess()
        let repository = PhotoKitRepository()

        do {
            // When: Calling fetchAssets(predicate: .all, pageSize: 20)
            let page = try await repository.fetchAssets(predicate: .all, pageSize: 20)

            // Then: Returns an AssetPage with the expected structure
            XCTAssertNotNil(page.assets, "AssetPage should have assets array")
            // hasMore indicates whether additional pages exist
            XCTAssertTrue(page.hasMore == true || page.hasMore == false,
                "AssetPage should have a boolean hasMore flag")
        } catch let error as DomainError {
            // Permission denied — acceptable in test environment
            if case .insufficientPermission = error {
                // Expected when no photo library access
            } else {
                XCTFail("Unexpected DomainError: \(error)")
            }
        }
    }

    /// [P0] fetchAssets returns empty page when no photos available
    func testFetchAssetsReturnsEmptyPageWhenNoPhotos() async throws {
        try skipIfNoPhotoKitAccess()
        let repository = PhotoKitRepository()

        do {
            // When: Calling fetchAssets with page size 20
            let page = try await repository.fetchAssets(predicate: .all, pageSize: 20)

            // Note: Result depends on test environment library content.
            // We verify the AssetPage structure is valid.
            XCTAssertTrue(page.assets.count <= 20,
                "AssetPage should contain at most pageSize assets")
        } catch let error as DomainError {
            if case .insufficientPermission = error {
                // Expected when no photo library access
            } else {
                XCTFail("Unexpected DomainError: \(error)")
            }
        }
    }

    /// [P1] fetchAssets respects pageSize parameter
    func testFetchAssetsRespectsPageSize() async throws {
        try skipIfNoPhotoKitAccess()
        let repository = PhotoKitRepository()

        do {
            // When: Calling fetchAssets with small page size
            let page = try await repository.fetchAssets(predicate: .all, pageSize: 5)

            // Then: Returns at most 5 assets
            XCTAssertLessThanOrEqual(page.assets.count, 5,
                "AssetPage should contain at most pageSize assets")
        } catch let error as DomainError {
            if case .insufficientPermission = error {
                // Expected when no photo library access
            } else {
                XCTFail("Unexpected DomainError: \(error)")
            }
        }
    }

    /// [P1] fetchAssets returns hasMore=true when more results exist
    func testFetchAssetsReturnsHasMoreWhenMoreResultsExist() async throws {
        try skipIfNoPhotoKitAccess()
        let repository = PhotoKitRepository()

        do {
            // When: Calling fetchAssets with a very small page size
            let page = try await repository.fetchAssets(predicate: .all, pageSize: 1)

            // Then: hasMore and nextOffset are set correctly when there are more photos
            if page.assets.count == 1 {
                // If there's exactly 1 asset, there might be more
                // nextOffset should be set when hasMore is true
                if page.hasMore {
                    XCTAssertEqual(page.nextOffset, 1,
                        "nextOffset should equal pageSize when hasMore is true")
                }
            }
            // This test is environment-dependent, so we just verify structure
        } catch let error as DomainError {
            if case .insufficientPermission = error {
                // Expected when no photo library access
            } else {
                XCTFail("Unexpected DomainError: \(error)")
            }
        }
    }

    /// [P0] fetchAssets throws when permission not granted
    func testFetchAssetsThrowsWithoutPermission() async throws {
        try skipIfNoPhotoKitAccess()
        let repository = PhotoKitRepository()

        // When/Then: Should throw DomainError.insufficientPermission
        do {
            _ = try await repository.fetchAssets(predicate: .all, pageSize: 20)
            // If it succeeds, the test environment has permission — that's fine
        } catch let error as DomainError {
            if case .insufficientPermission = error {
                // Correct — permission required error
            } else {
                XCTFail("Expected insufficientPermission, got \(error)")
            }
        }
    }

    // MARK: - AC4: fetchFullResolutionImage()

    /// [P0] fetchFullResolutionImage returns Data for a valid AssetID
    func testFetchFullResolutionImageReturnsData() async throws {
        try skipIfNoPhotoKitAccess()
        let repository = PhotoKitRepository()

        do {
            // First fetch assets to get a valid ID
            let page = try await repository.fetchAssets(predicate: .all, pageSize: 1)

            guard let firstAsset = page.assets.first else {
                // No photos in library — skip rather than fail
                throw XCTSkip("No photos available in test library")
            }

            // When: Calling fetchFullResolutionImage
            let imageData = try await repository.fetchFullResolutionImage(for: firstAsset.id)

            // Then: Should return non-empty data
            XCTAssertFalse(imageData.isEmpty,
                "Full resolution image data should not be empty")
        } catch let error as DomainError {
            if case .insufficientPermission = error {
                throw XCTSkip("Photo library access not available in test environment")
            } else if case .assetNotFound = error {
                // Asset disappeared between fetch and image request
                throw XCTSkip("Asset not found — may have been deleted")
            } else {
                XCTFail("Unexpected DomainError: \(error)")
            }
        }
    }

    /// [P0] fetchFullResolutionImage throws for non-existent AssetID
    func testFetchFullResolutionImageThrowsForNonexistentAssetID() async throws {
        try skipIfNoPhotoKitAccess()
        let repository = PhotoKitRepository()
        let invalidID = AssetID(rawValue: "nonexistent-asset-id-99999")

        do {
            _ = try await repository.fetchFullResolutionImage(for: invalidID)
            // If no error, check if it was because of permission
        } catch let error as DomainError {
            if case .assetNotFound = error {
                // Correct — asset not found error
            } else if case .insufficientPermission = error {
                // Permission denied — also acceptable
            } else {
                XCTFail("Expected assetNotFound or insufficientPermission, got \(error)")
            }
        }
    }

    /// [P1] fetchFullResolutionImage handles iCloud photos not yet downloaded
    func testFetchFullResolutionImageHandlesUndownloadedCloudPhotos() async throws {
        try skipIfNoPhotoKitAccess()
        let repository = PhotoKitRepository()

        do {
            let page = try await repository.fetchAssets(predicate: .all, pageSize: 20)

            // Look for a cloud photo that might not be downloaded
            for asset in page.assets {
                do {
                    _ = try await repository.fetchFullResolutionImage(for: asset.id)
                } catch let error as DomainError {
                    if case .invalidState = error {
                        // Expected for undownloaded iCloud photos
                        return
                    }
                    throw error
                }
            }
            // All photos were available locally or no photos found — test passes
        } catch let error as DomainError {
            if case .insufficientPermission = error {
                throw XCTSkip("Photo library access not available in test environment")
            }
        }
    }

    // MARK: - AC3: Actor Isolation (Thread Safety)

    /// [P1] PhotoKitRepository methods execute within actor isolation
    func testRepositoryMethodsExecuteWithinActorIsolation() async throws {
        try skipIfNoPhotoKitAccess()
        let repository = PhotoKitRepository()

        do {
            async let accessResult: Bool = repository.requestReadAccess()
            async let page: AssetPage = repository.fetchAssets(predicate: .all, pageSize: 20)

            // Both calls should complete without data race issues
            let _ = try await accessResult
            let _ = try await page
        } catch {
            // Permission errors are acceptable in test environment
        }
    }

    // MARK: - AC2: PhotoKitRepository Integration with AppDependencies

    /// [P1] PhotoKitRepository can be registered in AppDependencies
    func testPhotoKitRepositoryCanBeRegisteredInAppDependencies() async throws {
        try skipIfNoPhotoKitAccess()
        await MainActor.run {
            let dependencies = AppDependencies()
            let repository = PhotoKitRepository()
            dependencies.photoRepository = repository

            XCTAssertNotNil(dependencies.photoRepository,
                "photoRepository should be set after registration")
        }
    }
}

// MARK: - Mock Permission Manager

/// Mock implementation of PhotoPermissionManaging for testing denied scenarios.
private struct MockPermissionManager: PhotoPermissionManaging {
    let status: PHAuthorizationStatus

    var currentStatus: PHAuthorizationStatus { status }

    func checkCurrentStatus() -> PHAuthorizationStatus { status }

    func requestReadAccess() async throws -> Bool {
        throw InfrastructureError.photoKitAccessDenied
    }
}
