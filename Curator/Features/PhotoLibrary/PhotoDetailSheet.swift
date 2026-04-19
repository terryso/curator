import SwiftUI

/// Detail sheet for viewing photo metadata.
///
/// Displays the photo thumbnail (enlarged) along with file system and EXIF metadata:
/// file name, creation date, camera model, dimensions, file size, and GPS location.
struct PhotoDetailSheet: View {

    /// The photo asset whose details are displayed.
    let photo: PhotoAsset

    /// ViewModel for loading preview images.
    @ObservedObject var viewModel: PhotoLibraryViewModel

    /// Dismiss action provided by the sheet environment.
    @Environment(\.dismiss) private var dismiss

    /// Loaded preview image data (larger than grid thumbnail).
    @State private var previewData: Data?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Preview image
            if let data = previewData ?? photo.thumbnailData, let nsImage = NSImage(data: data) {
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
                MetadataRow(label: String(localized: "File Name"), value: photo.metadata.fileName)
                MetadataRow(label: String(localized: "Date"), value: formattedDate)
                MetadataRow(label: String(localized: "Camera"), value: photo.metadata.cameraModel ?? "-")
                MetadataRow(label: String(localized: "Dimensions"), value: formattedDimensions)
                MetadataRow(label: String(localized: "File Size"), value: formattedFileSize)
                MetadataRow(label: String(localized: "Location"), value: formattedLocation)
            }

            Spacer()
        }
        .padding(24)
        .frame(minWidth: 400, minHeight: 450)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(String(localized: "Close")) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }
        }
        .task {
            previewData = await viewModel.loadPreview(for: photo)
        }
    }

    // MARK: - Formatted Values

    private var formattedDate: String {
        guard let date = photo.metadata.creationDate else { return "-" }
        return Self.dateFormatter.string(from: date)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        return formatter
    }()

    private var formattedDimensions: String {
        guard let w = photo.metadata.imageWidth, let h = photo.metadata.imageHeight else { return "-" }
        return "\(w) × \(h)"
    }

    private var formattedFileSize: String {
        guard let size = photo.metadata.fileSize else { return "-" }
        return Self.byteCountFormatter.string(fromByteCount: size)
    }

    private static let byteCountFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter
    }()

    private var formattedLocation: String {
        guard let location = photo.metadata.gpsLocation else { return "-" }
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
