import SwiftUI

/// Detail sheet for viewing photo metadata.
///
/// Displays the photo thumbnail (enlarged) along with all available metadata:
/// creation date, title, description, keywords, and location.
/// Missing fields show a dash placeholder for clarity.
struct PhotoDetailSheet: View {

    /// The photo asset whose details are displayed.
    let photo: PhotoAsset

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Thumbnail image (enlarged)
            if let data = photo.thumbnailData, let nsImage = NSImage(data: data) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Rectangle()
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .frame(height: 200)
                    .overlay(
                        Image(systemName: "photo")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            // Metadata fields
            VStack(alignment: .leading, spacing: 10) {
                MetadataRow(label: String(localized: "Date"), value: formattedDate)
                MetadataRow(label: String(localized: "Title"), value: photo.metadata.title ?? "-")
                MetadataRow(label: String(localized: "Description"), value: photo.metadata.description ?? "-")
                MetadataRow(label: String(localized: "Keywords"), value: formattedKeywords)
                MetadataRow(label: String(localized: "Location"), value: formattedLocation)
            }

            Spacer()
        }
        .padding(24)
        .frame(minWidth: 400, minHeight: 450)
    }

    // MARK: - Formatted Values

    private var formattedDate: String {
        guard let date = photo.metadata.creationDate else { return "-" }
        return Self.dateFormatter.string(from: date)
    }

    /// Shared DateFormatter to avoid expensive per-view-body creation.
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        return formatter
    }()

    private var formattedKeywords: String {
        let keywords = photo.metadata.keywords
        return keywords.isEmpty ? "-" : keywords.joined(separator: ", ")
    }

    private var formattedLocation: String {
        guard let location = photo.metadata.location else { return "-" }
        return String(format: "%.4f, %.4f", location.latitude, location.longitude)
    }
}

/// A single row in the metadata display.
private struct MetadataRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .trailing)
            Text(value)
                .font(.body)
            Spacer()
        }
    }
}
