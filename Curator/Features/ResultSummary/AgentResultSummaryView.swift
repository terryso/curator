import SwiftUI

/// Full result summary view displayed after dedup batch operations complete.
///
/// Shows statistics cards (removed count, groups, saved space, duration),
/// celebration animation on full success, and undo/done action buttons.
/// Designed as a standalone component that replaces BatchApprovalView's
/// brief result summary when the user clicks "Dismiss".
///
/// Follows UX-DR6 (AgentResultSummary), UX-DR14 (accessibility),
/// and UX-DR17 (button hierarchy: max one primary button per interface).
struct AgentResultSummaryView: View {

    /// The ViewModel providing result summary state.
    let viewModel: ResultSummaryViewModel

    /// Callback when the user clicks "Done".
    let onDone: () -> Void

    /// Callback when the user clicks "Undo".
    let onUndo: () -> Void

    /// Whether user prefers reduced motion.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Animation state for the checkmark icon.
    @State private var showCheckmark = false

    /// Animation state for stats cards staggered appearance.
    @State private var showStats = false

    var body: some View {
        VStack(spacing: 20) {
            // Header with celebration
            headerSection

            // Statistics cards
            statsGrid

            // Action buttons
            actionButtons
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(.background)
        .onAppear {
            performAppearAnimations()
        }
    }

    // MARK: - Header Section

    /// Header with success/failure icon and celebration animation.
    @ViewBuilder
    private var headerSection: some View {
        VStack(spacing: 8) {
            // Checkmark or warning icon
            if viewModel.removedCount > 0 {
                celebrationIcon
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
            }

            Text(headerTitle)
                .font(.title2)
                .fontWeight(.semibold)

            if viewModel.savedSpaceBytes > 0 {
                Text("Saved \(viewModel.savedSpace)")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// The icon with celebration animation on full success.
    @ViewBuilder
    private var celebrationIcon: some View {
        ZStack {
            // Background glow for celebration
            if viewModel.showCelebration && !reduceMotion {
                Circle()
                    .fill(Color.green.opacity(0.15))
                    .frame(width: 80, height: 80)
                    .scaleEffect(showCheckmark ? 1.0 : 0.0)
            }

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)
                .scaleEffect(showCheckmark ? 1.0 : 0.5)
                .opacity(showCheckmark ? 1.0 : 0.0)
                .animation(
                    reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.6),
                    value: showCheckmark
                )
        }
        .accessibilityLabel("Deduplication complete")
        .accessibilityHint(viewModel.showCelebration ? "Successful operation" : "")
    }

    /// Header title based on result success level.
    private var headerTitle: String {
        if viewModel.removedCount == 0 {
            return "No Changes Made"
        }
        return viewModel.showCelebration ? "Deduplication Complete!" : "Deduplication Complete"
    }

    // MARK: - Statistics Grid

    /// Grid of statistics cards showing key metrics.
    @ViewBuilder
    private var statsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
        ], spacing: 12) {
            StatCardView(
                icon: "trash",
                value: "\(viewModel.removedCount)",
                label: "Photos Removed",
                color: viewModel.removedCount > 0 ? .red : .secondary
            )

            StatCardView(
                icon: "square.on.square",
                value: "\(viewModel.totalGroups)",
                label: "Groups Processed",
                color: .accentColor
            )

            StatCardView(
                icon: "internaldrive",
                value: viewModel.savedSpace,
                label: "Space Saved",
                color: .green
            )

            StatCardView(
                icon: "clock",
                value: formatDuration(viewModel.duration),
                label: "Duration",
                color: .secondary
            )
        }
        .opacity(showStats ? 1.0 : 0.0)
        .offset(y: showStats ? 0 : 10)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.4), value: showStats)
    }

    // MARK: - Action Buttons

    /// Undo and Done action buttons following UX-DR17 button hierarchy.
    @ViewBuilder
    private var actionButtons: some View {
        HStack {
            // Undo button -- secondary style (bordered), UX-DR17
            if viewModel.canUndo {
                Button {
                    onUndo()
                } label: {
                    Label("Undo", systemImage: "arrow.uturn.backward")
                        .font(.callout)
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .accessibilityLabel("Undo deduplication")
                .accessibilityHint("Restore removed photos from Trash")
            }

            Spacer()

            // Done button -- primary style (prominent), UX-DR17
            Button {
                onDone()
            } label: {
                Text("Done")
                    .font(.callout)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .accessibilityLabel("Finish")
            .keyboardShortcut(.defaultAction)
        }
    }

    // MARK: - Helpers

    /// Triggers appear animations with staggered timing.
    private func performAppearAnimations() {
        guard !reduceMotion else {
            showCheckmark = true
            showStats = true
            return
        }

        showCheckmark = true
        _Concurrency.Task { @MainActor in
            try? await _Concurrency.Task.sleep(for: .milliseconds(300))
            showStats = true
        }
    }

    /// Formats duration in seconds to a user-friendly string.
    private func formatDuration(_ seconds: TimeInterval) -> String {
        if seconds < 60 {
            return "\(Int(seconds))s"
        } else if seconds < 3600 {
            let minutes = Int(seconds) / 60
            let secs = Int(seconds) % 60
            return "\(minutes)m \(secs)s"
        } else {
            let hours = Int(seconds) / 3600
            let minutes = (Int(seconds) % 3600) / 60
            return "\(hours)h \(minutes)m"
        }
    }
}

// MARK: - Stat Card View

/// Single statistics card showing an icon, value, and label.
///
/// Used in the AgentResultSummaryView stats grid to display
/// individual metrics with visual emphasis.
private struct StatCardView: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)

            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(.primary)

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background(.fill.tertiary)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Preview

#Preview("Full Success") {
    let viewModel = ResultSummaryViewModel()
    let groupID = UUID()
    let groups = [
        DuplicateGroup(
            id: groupID,
            assets: [
                PhotoAsset(
                    id: AssetID(rawValue: "a1"),
                    metadata: AssetMetadata(
                        fileName: "IMG_001.jpg", fileSize: 2_000_000, creationDate: nil,
                        cameraModel: nil, imageWidth: nil, imageHeight: nil,
                        gpsLocation: nil, fileFormat: nil
                    ),
                    thumbnailData: nil
                ),
                PhotoAsset(
                    id: AssetID(rawValue: "a2"),
                    metadata: AssetMetadata(
                        fileName: "IMG_002.jpg", fileSize: 3_000_000, creationDate: nil,
                        cameraModel: nil, imageWidth: nil, imageHeight: nil,
                        gpsLocation: nil, fileFormat: nil
                    ),
                    thumbnailData: nil
                ),
            ],
            similarityScore: 0.95,
            reason: "Same scene",
            status: .pending
        ),
    ]
    viewModel.populateFrom(
        result: ExecutionResult(successCount: 2, failureCount: 0, total: 2),
        groups: groups,
        reviewStates: [groupID: .remove],
        removedAssetSizes: [AssetID(rawValue: "a1"): 2_000_000, AssetID(rawValue: "a2"): 3_000_000],
        duration: 45.0
    )
    return AgentResultSummaryView(
        viewModel: viewModel,
        onDone: {},
        onUndo: {}
    )
    .frame(width: 450)
}

#Preview("Dark Mode") {
    let viewModel = ResultSummaryViewModel()
    let groupID = UUID()
    let groups = [
        DuplicateGroup(
            id: groupID,
            assets: [
                PhotoAsset(
                    id: AssetID(rawValue: "a1"),
                    metadata: AssetMetadata(
                        fileName: "photo.jpg", fileSize: 1_500_000_000, creationDate: nil,
                        cameraModel: nil, imageWidth: nil, imageHeight: nil,
                        gpsLocation: nil, fileFormat: nil
                    ),
                    thumbnailData: nil
                ),
            ],
            similarityScore: 0.99,
            status: .pending
        ),
    ]
    viewModel.populateFrom(
        result: ExecutionResult(successCount: 1, failureCount: 0, total: 1),
        groups: groups,
        reviewStates: [groupID: .remove],
        removedAssetSizes: [AssetID(rawValue: "a1"): 1_500_000_000],
        duration: 120.0
    )
    return AgentResultSummaryView(
        viewModel: viewModel,
        onDone: {},
        onUndo: {}
    )
    .frame(width: 450)
    .preferredColorScheme(.dark)
}
