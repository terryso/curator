import SwiftUI

/// Thumbnail view for a single photo in the grid.
///
/// Displays a 120x120 thumbnail image with a placeholder for nil data.
/// Supports tap gesture for selection and VoiceOver accessibility.
struct PhotoThumbnailView: View {

    /// The photo asset to display.
    let photo: PhotoAsset

    /// Callback when the thumbnail is tapped.
    let onTap: () -> Void

    /// ViewModel for loading thumbnails.
    @ObservedObject var viewModel: PhotoLibraryViewModel

    /// Target thumbnail size.
    private let thumbnailSize: CGFloat = 120

    var body: some View {
        Group {
            if let data = photo.thumbnailData, let nsImage = NSImage(data: data) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Rectangle()
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .overlay(
                        Image(systemName: "photo")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    )
            }
        }
        .frame(width: thumbnailSize, height: thumbnailSize)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .task(id: photo.id) {
            await viewModel.loadThumbnail(for: photo)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(.isButton)
    }

    /// Generates VoiceOver label: "photo, taken on {date}" or "photo" if no date.
    private var accessibilityText: String {
        if let date = photo.metadata.creationDate {
            return String(localized: "photo, taken on \(Self.dateFormatter.string(from: date))")
        }
        return String(localized: "photo")
    }

    /// Shared DateFormatter to avoid expensive per-view-body creation.
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
}
