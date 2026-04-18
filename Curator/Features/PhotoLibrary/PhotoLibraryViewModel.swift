import Foundation

/// ViewModel for the photo library browsing grid.
///
/// Manages photo loading state, pagination, and selection for the grid view.
/// Marked @MainActor for safe use with SwiftUI views.
/// Uses PhotoLibraryRepository protocol for dependency injection (no direct PhotoKit calls).
@MainActor
final class PhotoLibraryViewModel: ObservableObject {

    // MARK: - Published State

    /// All loaded photo assets across pages.
    @Published private(set) var photos: [PhotoAsset] = []

    /// Current loading state for the photo library.
    @Published private(set) var loadingState: LoadingState<[PhotoAsset]> = .idle

    /// The currently selected photo for detail view. Nil when no sheet is shown.
    @Published var selectedPhoto: PhotoAsset?

    // MARK: - Dependencies

    /// Photo library repository for data fetching. Nil = graceful degradation.
    private var repository: (any PhotoLibraryRepository)?

    /// Tracks the next page offset for pagination.
    private var nextOffset: Int?

    /// Indicates whether more pages are available.
    private var _hasMorePages: Bool = false

    /// Prevents concurrent page loads.
    private var isLoadingPage: Bool = false

    /// Non-blocking pagination error — the grid stays visible with loaded photos
    /// while this signals the user that a page failed to load.
    @Published private(set) var paginationError: DomainError?

    /// Default page size for asset fetching.
    private let pageSize: Int = 50

    // MARK: - Initialization

    /// Creates a PhotoLibraryViewModel with the given repository.
    ///
    /// - Parameter repository: The photo library repository for data access.
    ///                         Nil results in failed state on load attempts.
    init(repository: (any PhotoLibraryRepository)? = nil) {
        self.repository = repository
    }

    // MARK: - Computed Properties

    /// Whether more pages are available for loading.
    var hasMorePages: Bool {
        _hasMorePages
    }

    /// Whether the photo list is empty (includes idle state).
    var isEmpty: Bool {
        photos.isEmpty
    }

    // MARK: - Repository Updates

    /// Updates the repository reference (used after PhotoKit registration).
    ///
    /// Triggers initial page load when state is idle or failed (e.g. from a
    /// previous attempt before the repository was available).
    /// Transitions state to loading immediately to prevent duplicate load triggers.
    func updateRepository(_ repository: any PhotoLibraryRepository) {
        self.repository = repository
        let shouldLoad: Bool
        if case .idle = loadingState { shouldLoad = true }
        else if case .failed = loadingState { shouldLoad = true }
        else { shouldLoad = false }

        if shouldLoad {
            loadingState = .loading
            Task {
                await self.loadInitialPage()
            }
        }
    }

    // MARK: - Data Loading

    /// Loads the initial page of photos.
    ///
    /// Transitions state: idle -> loading -> loaded/failed.
    /// Requests photo permission if not already granted before fetching.
    /// Resets pagination state (photos, offset) before fetching.
    func loadInitialPage() async {
        guard let repository = repository else {
            loadingState = .failed(.invalidState(reason: "No photo repository available"))
            return
        }

        // Reset state for fresh load
        loadingState = .loading
        nextOffset = nil
        _hasMorePages = false
        isLoadingPage = false

        do {
            // Ensure permission is granted before fetching
            _ = try await repository.requestReadAccess()

            let page = try await repository.fetchAssets(
                predicate: .all,
                pageSize: pageSize,
                pageOffset: 0
            )
            photos = page.assets
            _hasMorePages = page.hasMore
            nextOffset = page.nextOffset
            loadingState = .loaded(page.assets)
        } catch let error as DomainError {
            loadingState = .failed(error)
        } catch {
            loadingState = .failed(.invalidState(reason: error.localizedDescription))
        }
    }

    /// Loads the next page of photos and appends to existing data.
    ///
    /// Does nothing if: no more pages, currently loading, or no repository.
    /// On error, preserves already-loaded photos but signals failure via ``loadingState``.
    func loadNextPage() async {
        guard let repository = repository else { return }
        guard _hasMorePages else { return }
        guard !isLoadingPage else { return }

        isLoadingPage = true

        do {
            let offset = nextOffset ?? photos.count
            let page = try await repository.fetchAssets(
                predicate: .all,
                pageSize: pageSize,
                pageOffset: offset
            )
            photos.append(contentsOf: page.assets)
            _hasMorePages = page.hasMore
            nextOffset = page.nextOffset
            loadingState = .loaded(photos)
            paginationError = nil
        } catch let error as DomainError {
            paginationError = error
        } catch {
            paginationError = .invalidState(reason: error.localizedDescription)
        }

        isLoadingPage = false
    }

    // MARK: - Thumbnail Loading

    /// Thumbnail size in points (matches PhotoThumbnailView).
    let thumbnailSize: CGFloat = 120

    /// Loads a thumbnail for the given photo and updates the photos array.
    ///
    /// No-op if thumbnail is already loaded or repository is unavailable.
    func loadThumbnail(for photo: PhotoAsset) async {
        guard photo.thumbnailData == nil else { return }
        guard let repository = repository else { return }

        do {
            let data = try await repository.fetchThumbnail(
                for: photo.id,
                size: CGSize(width: thumbnailSize, height: thumbnailSize)
            )
            // Update the matching photo in the array
            if let index = photos.firstIndex(where: { $0.id == photo.id }) {
                photos[index].thumbnailData = data
            }
        } catch {
            // Silently fail — placeholder remains visible
        }
    }

    /// Loads a larger preview image for the detail sheet.
    func loadPreview(for photo: PhotoAsset) async -> Data? {
        guard let repository = repository else { return nil }
        do {
            return try await repository.fetchThumbnail(
                for: photo.id,
                size: CGSize(width: 400, height: 400)
            )
        } catch {
            return nil
        }
    }

    // MARK: - Selection

    /// Selects a photo for the detail sheet view.
    func selectPhoto(_ photo: PhotoAsset) {
        selectedPhoto = photo
    }

    /// Deselects the current photo, dismissing the detail sheet.
    func deselectPhoto() {
        selectedPhoto = nil
    }
}
