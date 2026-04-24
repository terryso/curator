import SwiftUI

/// A card component displaying two duplicate photos side-by-side with
/// comparison metadata and keep/remove actions.
///
/// Implements UX-DR4: two photos side-by-side, match reason, similarity score,
/// and keep/remove action buttons.
struct PhotoComparisonCard: View {

    /// The duplicate group to display.
    let group: DuplicateGroup

    /// Current review state for this group.
    let reviewState: DuplicateGroupReviewState

    /// Callback when user marks the group as "keep".
    let onKeep: () -> Void

    /// Callback when user marks the group as "remove".
    let onRemove: () -> Void

    /// Whether the user prefers reduced motion.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Whether the full-screen image preview is shown.
    @State private var previewAssetIndex: Int? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Photo comparison area
            photoComparisonArea

            // AI match reason
            if let reason = group.reason {
                reasonLabel(reason)
            }

            // Similarity score
            similarityScoreLabel

            // Action buttons
            actionButtons
        }
        .padding(12)
        .background(cardBackground)
        .overlay(cardBorder)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityText)
    }

    // MARK: - Photo Comparison Area

    /// Side-by-side photo thumbnails (max 2 shown).
    @ViewBuilder
    private var photoComparisonArea: some View {
        HStack(spacing: 8) {
            ForEach(Array(group.assets.prefix(2).enumerated()), id: \.element.id) { index, asset in
                thumbnailView(for: asset, index: index)
            }
        }
        .frame(height: 140)
    }

    /// Generates a thumbnail view for a single asset.
    @ViewBuilder
    private func thumbnailView(for asset: PhotoAsset, index: Int) -> some View {
        let thumbnailData = group.thumbnails[asset.id]

        Group {
            if let data = thumbnailData, let nsImage = NSImage(data: data) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else if let data = asset.thumbnailData, let nsImage = NSImage(data: data) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Rectangle()
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .overlay(
                        Image(systemName: "photo")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    )
            }
        }
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .contentShape(Rectangle())
        .onTapGesture {
            previewAssetIndex = index
        }
        .accessibilityLabel("Photo \(index + 1): \(asset.metadata.fileName)")
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Reason Label

    /// AI explanation label showing the match reason.
    @ViewBuilder
    private func reasonLabel(_ reason: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "sparkles")
                .font(.caption2)
            Text(reason)
                .font(.caption)
                .lineLimit(2)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.indigo.opacity(0.8))
        )
    }

    // MARK: - Similarity Score

    /// Formatted similarity score display.
    @ViewBuilder
    private var similarityScoreLabel: some View {
        HStack(spacing: 4) {
            Image(systemName: "chart.bar.fill")
                .font(.caption2)
            Text("Similarity: \(Int(group.similarityScore * 100))%")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Action Buttons

    /// Keep (secondary style) and Remove (danger style) action buttons.
    @ViewBuilder
    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button {
                onKeep()
            } label: {
                Label("Keep", systemImage: "hand.thumbsup")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(reviewState == .keep)

            Button(role: .destructive) {
                onRemove()
            } label: {
                Label("Remove", systemImage: "trash")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .tint(.red)
            .disabled(reviewState == .remove)
        }
        .padding(.top, 4)
    }

    // MARK: - Card Styling

    /// Card background based on review state.
    @ViewBuilder
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(Color(nsColor: .controlBackgroundColor))
    }

    /// Border overlay indicating review state.
    @ViewBuilder
    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: 10)
            .strokeBorder(borderColor, lineWidth: borderWidth)
    }

    /// Border color: green for keep, red for remove, transparent for pending.
    private var borderColor: Color {
        switch reviewState {
        case .pending: return Color(nsColor: .separatorColor)
        case .keep: return .green
        case .remove: return .red
        }
    }

    /// Border width: thicker for reviewed states.
    private var borderWidth: CGFloat {
        switch reviewState {
        case .pending: return 0.5
        case .keep, .remove: return 2
        }
    }

    // MARK: - Accessibility

    /// Combined accessibility label for the card.
    private var accessibilityText: String {
        let stateDescription: String
        switch reviewState {
        case .pending: stateDescription = "Not reviewed"
        case .keep: stateDescription = "Marked as keep"
        case .remove: stateDescription = "Marked for removal"
        }
        let similarity = Int(group.similarityScore * 100)
        var parts = [
            "Duplicate group, \(group.assets.count) photos",
            "Similarity \(similarity) percent",
            stateDescription
        ]
        if let reason = group.reason {
            parts.append("Reason: \(reason)")
        }
        return parts.joined(separator: ", ")
    }
}

// MARK: - Preview

#Preview("Pending") {
    let group = DuplicateGroup(
        assets: [
            PhotoAsset(
                id: AssetID(rawValue: "photo1"),
                metadata: AssetMetadata(
                    fileName: "IMG_001.jpg",
                    fileSize: 2_000_000,
                    creationDate: Date(),
                    cameraModel: "iPhone 16",
                    imageWidth: 4000,
                    imageHeight: 3000,
                    gpsLocation: nil,
                    fileFormat: .jpeg
                ),
                thumbnailData: nil
            ),
            PhotoAsset(
                id: AssetID(rawValue: "photo2"),
                metadata: AssetMetadata(
                    fileName: "IMG_002.jpg",
                    fileSize: 2_100_000,
                    creationDate: Date().addingTimeInterval(-60),
                    cameraModel: "iPhone 16",
                    imageWidth: 4000,
                    imageHeight: 3000,
                    gpsLocation: nil,
                    fileFormat: .jpeg
                ),
                thumbnailData: nil
            )
        ],
        similarityScore: 0.95,
        reason: "Same scene, different exposure",
        status: .pending
    )
    PhotoComparisonCard(
        group: group,
        reviewState: .pending,
        onKeep: {},
        onRemove: {}
    )
    .frame(width: 400)
    .padding()
}

#Preview("Reviewed - Keep") {
    let group = DuplicateGroup(
        assets: [
            PhotoAsset(
                id: AssetID(rawValue: "photo1"),
                metadata: AssetMetadata(
                    fileName: "IMG_001.jpg", fileSize: nil, creationDate: nil,
                    cameraModel: nil, imageWidth: nil, imageHeight: nil,
                    gpsLocation: nil, fileFormat: nil
                ),
                thumbnailData: nil
            ),
            PhotoAsset(
                id: AssetID(rawValue: "photo2"),
                metadata: AssetMetadata(
                    fileName: "IMG_002.jpg", fileSize: nil, creationDate: nil,
                    cameraModel: nil, imageWidth: nil, imageHeight: nil,
                    gpsLocation: nil, fileFormat: nil
                ),
                thumbnailData: nil
            )
        ],
        similarityScore: 0.88,
        reason: "Burst mode sequence",
        status: .confirmed
    )
    PhotoComparisonCard(
        group: group,
        reviewState: .keep,
        onKeep: {},
        onRemove: {}
    )
    .frame(width: 400)
    .padding()
}
