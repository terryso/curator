import SwiftUI

/// Photo grid view with adaptive columns and infinite scroll.
///
/// Implements UX-DR13 (adaptive grid) and UX-DR15 (empty state).
/// Uses LazyVGrid for virtualized rendering of large photo libraries.
/// Detects scroll to end for automatic pagination.
struct PhotoGridView: View {

    /// The ViewModel providing photo data and loading logic.
    @ObservedObject var viewModel: PhotoLibraryViewModel

    var body: some View {
        GeometryReader { geometry in
            Group {
                switch viewModel.loadingState {
                case .idle:
                    idleView

                case .loading:
                    if viewModel.photos.isEmpty {
                        loadingView
                    } else {
                        gridContent(availableWidth: geometry.size.width)
                    }

                case .loaded:
                    if viewModel.photos.isEmpty {
                        emptyStateView
                    } else {
                        gridContent(availableWidth: geometry.size.width)
                    }

                case .failed(let error):
                    errorView(error: error)
                }
            }
        }
        .sheet(item: $viewModel.selectedPhoto) { photo in
            PhotoDetailSheet(photo: photo, viewModel: viewModel)
        }
    }

    // MARK: - Grid Content

    /// The main photo grid with infinite scroll detection.
    private func gridContent(availableWidth: CGFloat) -> some View {
        let columns = GridColumnCalculator.gridItems(for: availableWidth)

        return ZStack(alignment: .bottom) {
            ScrollView {
                LazyVGrid(columns: columns, spacing: GridColumnCalculator.spacing) {
                    ForEach(viewModel.photos) { photo in
                        PhotoThumbnailView(photo: photo, onTap: {
                            viewModel.selectPhoto(photo)
                        }, viewModel: viewModel)
                        .onAppear {
                            if photo.id == viewModel.photos.last?.id && viewModel.hasMorePages {
                                Task {
                                    await viewModel.loadNextPage()
                                }
                            }
                        }
                    }
                }
                .padding()
            }

            if let error = viewModel.paginationError {
                paginationErrorBanner(error: error)
            }
        }
    }

    /// Non-blocking banner shown at grid bottom when a page fails to load.
    /// The grid remains visible and scrollable behind the banner.
    private func paginationErrorBanner(error: DomainError) -> some View {
        let userError = error.toUserFacingError()
        let message = {
            switch userError {
            case .readOnly(_, let m), .retryable(_, let m):
                return m
            case .permissionRequired(_, let action):
                return action
            }
        }()

        return HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("Retry") {
                Task {
                    await viewModel.loadNextPage()
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .padding(.bottom, 8)
    }

    // MARK: - State Views

    /// Initial idle state with load prompt.
    private var idleView: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Photo Library")
                .font(.title2)
                .fontWeight(.medium)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Loading indicator for initial page fetch.
    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.large)
            Text("Loading photos...")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Empty state view (UX-DR15) with friendly message.
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No photos found")
                .font(.title3)
                .fontWeight(.medium)
            Text("Your photo library appears to be empty. Add photos to your library to see them here.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Error state view showing user-friendly error message.
    private func errorView(error: DomainError) -> some View {
        let userError = error.toUserFacingError()
        let (title, message) = {
            switch userError {
            case .readOnly(let t, let m), .retryable(let t, let m):
                return (t, m)
            case .permissionRequired(let t, let action):
                return (t, action)
            }
        }()

        return VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(.orange)
            Text(title)
                .font(.title3)
                .fontWeight(.medium)
            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
            Button("Retry") {
                Task {
                    await viewModel.loadInitialPage()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
