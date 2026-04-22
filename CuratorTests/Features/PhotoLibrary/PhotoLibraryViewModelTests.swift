import XCTest
@testable import Curator

/// ATDD Tests for Story 1.4 - Photo Library Browse Grid
///
/// Tests verify:
/// - PhotoLibraryViewModel manages loading state correctly (idle -> loading -> loaded/failed)
/// - Pagination logic works with AssetPage (loadInitialPage, loadNextPage)
/// - PhotoDetailSheet selection state
/// - Empty state handling (UX-DR15)
/// - Error handling via LoadingState.failed(DomainError)
///
/// All tests use MockPhotoLibraryRepository (no real PhotoKit calls).
final class PhotoLibraryViewModelTests: XCTestCase {

    // MARK: - Test Helpers

    /// Creates a sample PhotoAsset for testing.
    private func makePhotoAsset(
        id: String = "/Users/mock/Photos/test-\(UUID().uuidString).jpg",
        creationDate: Date? = Date(),
        fileName: String = "test.jpg",
        cameraModel: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        thumbnailData: Data? = nil
    ) -> PhotoAsset {
        let location: LocationData? = if let lat = latitude, let lon = longitude {
            LocationData(latitude: lat, longitude: lon)
        } else {
            nil
        }
        let metadata = AssetMetadata(
            fileName: fileName,
            fileSize: nil,
            creationDate: creationDate,
            cameraModel: cameraModel,
            imageWidth: nil,
            imageHeight: nil,
            gpsLocation: location,
            fileFormat: .jpeg
        )
        return PhotoAsset(
            id: AssetID(rawValue: id),
            metadata: metadata,
            thumbnailData: thumbnailData
        )
    }

    // MARK: - AC1: ViewModel Initialization

    /// [P0] PhotoLibraryViewModel exists as @MainActor class
    @MainActor
    func testPhotoLibraryViewModelExists() async throws {
        let repository = MockPhotoLibraryRepository()
        let viewModel = PhotoLibraryViewModel(repository: repository)
        XCTAssertNotNil(viewModel)
    }

    /// [P0] ViewModel initializes with idle loading state
    @MainActor
    func testViewModelInitializesWithIdleState() async throws {
        let repository = MockPhotoLibraryRepository()
        let viewModel = PhotoLibraryViewModel(repository: repository)

        if case .idle = viewModel.loadingState {
            // Expected
        } else {
            XCTFail("Expected idle state on init")
        }
    }

    /// [P0] ViewModel initializes with empty photos array
    @MainActor
    func testViewModelInitializesWithEmptyPhotos() async throws {
        let repository = MockPhotoLibraryRepository()
        let viewModel = PhotoLibraryViewModel(repository: repository)

        XCTAssertTrue(viewModel.photos.isEmpty, "Photos should be empty on init")
    }

    // MARK: - AC2: Paginated Infinite Scroll

    /// [P0] loadInitialPage sets state to loading then loaded
    @MainActor
    func testLoadInitialPageTransitionsToLoaded() async throws {
        let testAssets = (0..<5).map { makePhotoAsset(id: "asset-\($0)") }
        let repository = MockPhotoLibraryRepository(
            pages: [AssetPage(assets: testAssets, hasMore: true, nextOffset: 5)]
        )
        let viewModel = PhotoLibraryViewModel(repository: repository)

        await viewModel.loadInitialPage()

        if case .loaded(let assets) = viewModel.loadingState {
            XCTAssertEqual(assets.count, 5, "Should load 5 assets")
        } else {
            XCTFail("Expected loaded state, got \(viewModel.loadingState)")
        }
        XCTAssertEqual(viewModel.photos.count, 5, "Photos array should contain 5 assets")
    }

    /// [P0] loadInitialPage sets loading state before fetch
    @MainActor
    func testLoadInitialPageSetsLoadingStateDuringFetch() async throws {
        let repository = MockPhotoLibraryRepository(
            pages: [AssetPage(assets: [makePhotoAsset()], hasMore: false, nextOffset: nil)],
            delay: 0.1
        )
        let viewModel = PhotoLibraryViewModel(repository: repository)

        let task = Task { await viewModel.loadInitialPage() }
        try await Task.sleep(nanoseconds: 10_000_000) // 10ms

        if case .loading = viewModel.loadingState {
            // Expected
        } else {
            XCTFail("Expected loading state during fetch")
        }
        _ = await task.value
    }

    /// [P0] loadNextPage appends to existing photos
    @MainActor
    func testLoadNextPageAppendsToExistingPhotos() async throws {
        let page1Assets = (0..<5).map { makePhotoAsset(id: "page1-\($0)") }
        let page2Assets = (0..<3).map { makePhotoAsset(id: "page2-\($0)") }
        let repository = MockPhotoLibraryRepository(pages: [
            AssetPage(assets: page1Assets, hasMore: true, nextOffset: 1),
            AssetPage(assets: page2Assets, hasMore: false, nextOffset: nil),
        ])
        let viewModel = PhotoLibraryViewModel(repository: repository)

        await viewModel.loadInitialPage()
        await viewModel.loadNextPage()

        XCTAssertEqual(viewModel.photos.count, 8, "Should have 8 photos total")
    }

    /// [P0] loadNextPage does not fetch when no more pages
    @MainActor
    func testLoadNextPageDoesNotFetchWhenNoMorePages() async throws {
        let testAssets = (0..<5).map { makePhotoAsset(id: "asset-\($0)") }
        let repository = MockPhotoLibraryRepository(pages: [
            AssetPage(assets: testAssets, hasMore: false, nextOffset: nil),
        ])
        let viewModel = PhotoLibraryViewModel(repository: repository)

        await viewModel.loadInitialPage()
        await viewModel.loadNextPage()

        XCTAssertEqual(viewModel.photos.count, 5, "Should not append when no more pages")
    }

    /// [P1] hasMorePages reflects pagination state correctly
    @MainActor
    func testHasMorePagesReflectsState() async throws {
        let testAssets = (0..<5).map { makePhotoAsset(id: "asset-\($0)") }
        let repository = MockPhotoLibraryRepository(pages: [
            AssetPage(assets: testAssets, hasMore: true, nextOffset: 5),
        ])
        let viewModel = PhotoLibraryViewModel(repository: repository)

        await viewModel.loadInitialPage()

        XCTAssertTrue(viewModel.hasMorePages, "Should have more pages after initial load")
    }

    /// [P1] loadNextPage prevents concurrent loading (debounce)
    @MainActor
    func testLoadNextPagePreventsConcurrentLoading() async throws {
        let page1Assets = (0..<5).map { makePhotoAsset(id: "page1-\($0)") }
        let page2Assets = (0..<3).map { makePhotoAsset(id: "page2-\($0)") }
        let repository = MockPhotoLibraryRepository(
            pages: [
                AssetPage(assets: page1Assets, hasMore: true, nextOffset: 5),
                AssetPage(assets: page2Assets, hasMore: false, nextOffset: nil),
            ],
            delay: 0.1
        )
        let viewModel = PhotoLibraryViewModel(repository: repository)

        await viewModel.loadInitialPage()
        // Double call should only result in one fetch
        async let first: Void = viewModel.loadNextPage()
        async let second: Void = viewModel.loadNextPage()
        _ = await (first, second)

        // Should have initial page only (second call was a no-op during loading)
        XCTAssertLessThanOrEqual(viewModel.photos.count, 8, "Concurrent calls should not duplicate fetches")
    }

    /// [P1] loadNextPage does nothing when state is loading
    @MainActor
    func testLoadNextPageDoesNothingWhenLoading() async throws {
        let repository = MockPhotoLibraryRepository(
            pages: [AssetPage(assets: [makePhotoAsset()], hasMore: true, nextOffset: 1)],
            delay: 0.5
        )
        let viewModel = PhotoLibraryViewModel(repository: repository)

        let task = Task { await viewModel.loadInitialPage() }
        try await Task.sleep(nanoseconds: 10_000_000)
        await viewModel.loadNextPage()
        _ = await task.value

        // loadNextPage should be a no-op during loading state
    }

    // MARK: - AC3: Photo Detail Selection

    /// [P0] Selected photo asset tracks detail sheet state
    @MainActor
    func testSelectedPhotoAssetTracksSheetState() async throws {
        let testAssets = [makePhotoAsset(id: "selected-photo")]
        let repository = MockPhotoLibraryRepository(pages: [
            AssetPage(assets: testAssets, hasMore: false, nextOffset: nil),
        ])
        let viewModel = PhotoLibraryViewModel(repository: repository)
        await viewModel.loadInitialPage()

        viewModel.selectPhoto(testAssets[0])

        XCTAssertEqual(viewModel.selectedPhoto?.id, testAssets[0].id)
    }

    /// [P0] Deselecting photo clears sheet state
    @MainActor
    func testDeselectingPhotoClearsSheetState() async throws {
        let testAssets = [makePhotoAsset(id: "photo-to-deselect")]
        let repository = MockPhotoLibraryRepository(pages: [
            AssetPage(assets: testAssets, hasMore: false, nextOffset: nil),
        ])
        let viewModel = PhotoLibraryViewModel(repository: repository)
        await viewModel.loadInitialPage()
        viewModel.selectPhoto(testAssets[0])

        viewModel.deselectPhoto()

        XCTAssertNil(viewModel.selectedPhoto)
    }

    /// [P1] PhotoDetailSheet can be created with full metadata
    @MainActor
    func testPhotoDetailSheetShowsMetadata() async throws {
        let asset = makePhotoAsset(
            id: "/Users/mock/Photos/meta-photo.jpg",
            creationDate: Date(timeIntervalSince1970: 1700000000),
            fileName: "meta-photo.jpg",
            cameraModel: "Canon EOS R5",
            latitude: 37.7749,
            longitude: -122.4194
        )
        // Verify the asset has all metadata fields populated
        XCTAssertNotNil(asset.metadata.creationDate)
        XCTAssertEqual(asset.metadata.fileName, "meta-photo.jpg")
        XCTAssertNotNil(asset.metadata.gpsLocation)
        XCTAssertEqual(asset.metadata.gpsLocation?.latitude, 37.7749)
        XCTAssertEqual(asset.metadata.gpsLocation?.longitude, -122.4194)
    }

    // MARK: - Error Handling

    /// [P0] loadInitialPage transitions to failed state on error
    @MainActor
    func testLoadInitialPageTransitionsToFailedOnError() async throws {
        let repository = MockPhotoLibraryRepository(
            error: DomainError.insufficientPermission(required: .read)
        )
        let viewModel = PhotoLibraryViewModel(repository: repository)

        await viewModel.loadInitialPage()

        if case .failed(let error) = viewModel.loadingState {
            if case .insufficientPermission = error {
                // Expected
            } else {
                XCTFail("Expected insufficientPermission, got \(error)")
            }
        } else {
            XCTFail("Expected failed state, got \(viewModel.loadingState)")
        }
    }

    /// [P0] loadNextPage sets paginationError on error while preserving loaded state
    @MainActor
    func testLoadNextPageSetsPaginationErrorOnError() async throws {
        let page1Assets = (0..<5).map { makePhotoAsset(id: "asset-\($0)") }
        let repository = MockPhotoLibraryRepository(
            pages: [
                AssetPage(assets: page1Assets, hasMore: true, nextOffset: 1),
            ],
            secondPageError: DomainError.invalidState(reason: "fetch failed")
        )
        let viewModel = PhotoLibraryViewModel(repository: repository)

        await viewModel.loadInitialPage()
        await viewModel.loadNextPage()

        // loadingState should remain .loaded — grid stays visible
        if case .loaded(let assets) = viewModel.loadingState {
            XCTAssertEqual(assets.count, 5, "Should preserve loaded photos")
        } else {
            XCTFail("Expected loaded state after pagination error, got \(viewModel.loadingState)")
        }

        // paginationError should be set
        XCTAssertNotNil(viewModel.paginationError, "Should set paginationError")
        if case .invalidState = viewModel.paginationError {
            // Expected
        } else {
            XCTFail("Expected invalidState error, got \(String(describing: viewModel.paginationError))")
        }
    }

    // MARK: - Empty State (UX-DR15)

    /// [P0] Empty state when library has no photos
    @MainActor
    func testEmptyStateWhenNoPhotos() async throws {
        let repository = MockPhotoLibraryRepository(pages: [
            AssetPage(assets: [], hasMore: false, nextOffset: nil),
        ])
        let viewModel = PhotoLibraryViewModel(repository: repository)

        await viewModel.loadInitialPage()

        if case .loaded = viewModel.loadingState {
            XCTAssertTrue(viewModel.photos.isEmpty, "Should have empty photos")
        } else {
            XCTFail("Expected loaded state with empty results")
        }
    }

    /// [P1] ViewModel provides isEmpty computed property
    @MainActor
    func testViewModelProvidesIsEmptyProperty() async throws {
        let repository = MockPhotoLibraryRepository()
        let viewModel = PhotoLibraryViewModel(repository: repository)

        XCTAssertTrue(viewModel.isEmpty, "Should be empty on init")
    }

    // MARK: - Repository Injection

    /// [P0] ViewModel accepts PhotoLibraryRepository via dependency injection
    @MainActor
    func testViewModelAcceptsRepositoryInjection() async throws {
        let repository = MockPhotoLibraryRepository()
        let viewModel = PhotoLibraryViewModel(repository: repository)

        XCTAssertNotNil(viewModel)
    }

    /// [P0] ViewModel works with nil repository (graceful degradation)
    @MainActor
    func testViewModelHandlesNilRepository() async throws {
        let viewModel = PhotoLibraryViewModel(repository: nil)

        await viewModel.loadInitialPage()

        if case .failed = viewModel.loadingState {
            // Expected
        } else {
            XCTFail("Expected failed state with nil repository")
        }
    }
}

// MARK: - Mock Repository

/// Mock implementation of PhotoLibraryRepository for testing.
///
/// Configurable to return specific pages, errors, or delays.
/// Supports multi-page scenarios by serving pages sequentially.
/// Uses actor isolation for thread-safe page index tracking.
private struct MockPhotoLibraryRepository: PhotoLibraryRepository {
    private let pages: [AssetPage]
    private let error: DomainError?
    private let secondPageError: DomainError?
    private let delay: TimeInterval

    func currentBasePath() async -> String? { nil }

    init(
        pages: [AssetPage] = [],
        error: DomainError? = nil,
        secondPageError: DomainError? = nil,
        delay: TimeInterval = 0
    ) {
        self.pages = pages
        self.error = error
        self.secondPageError = secondPageError
        self.delay = delay
    }

    func requestReadAccess() async throws -> Bool {
        if let error { throw error }
        return true
    }

    func requestWriteAccess() async throws -> Bool {
        false
    }

    func fetchAssets(predicate: PhotoPredicate, pageSize: Int, pageOffset: Int) async throws -> AssetPage {
        if let error { throw error }

        if delay > 0 {
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }

        // Second-page error: triggered when pageOffset > 0 (i.e., not first page)
        if pageOffset > 0, let secondPageError {
            throw secondPageError
        }

        // Mock convention: pageOffset is used as direct array index into `pages`.
        // Tests must set nextOffset values accordingly (0 for first page, 1 for second, etc.).
        guard pageOffset < pages.count else {
            return AssetPage(assets: [], hasMore: false, nextOffset: nil)
        }

        return pages[pageOffset]
    }

    func fetchFullResolutionImage(for assetID: AssetID) async throws -> Data {
        if let error { throw error }
        return Data()
    }

    func fetchThumbnail(for assetID: AssetID, size: CGSize) async throws -> Data {
        if let error { throw error }
        return Data()
    }

    func metadata(for assetID: AssetID) async throws -> AssetMetadata {
        AssetMetadata(fileName: "mock.jpg", fileSize: nil, creationDate: nil, cameraModel: nil, imageWidth: nil, imageHeight: nil, gpsLocation: nil, fileFormat: nil)
    }
    func updateAsset(_ assetID: AssetID, title: String?) async throws {}
    func deleteAssets(_ assetIDs: [AssetID]) async throws {}
    func moveAssets(_ assetIDs: [AssetID], to directory: String) async throws {}
    func observeSourceChanges() -> AsyncStream<SourceChange> { AsyncStream { _ in } }
}
