import SwiftUI

/// Filter options for duplicate group display.
enum DuplicateGroupFilter: String, CaseIterable {
    case all = "All"
    case pending = "Pending"
    case markedForRemoval = "Marked for Removal"
}

/// Main review interface for duplicate photo groups.
///
/// Displays a scrollable list of PhotoComparisonCards with review progress
/// statistics and filter controls. Uses LazyVStack for smooth scrolling
/// performance with large duplicate group sets (NFR2: 60fps, NFR6: 500MB).
struct DuplicateReviewView: View {

    /// The ViewModel providing review state.
    let viewModel: DeduplicationViewModel

    /// The confirmation ViewModel for batch operation confirmation workflow.
    let confirmationViewModel: ConfirmationViewModel?

    /// The undo manager ViewModel for rollback support.
    let undoManager: UndoManagerViewModel?

    /// Current filter applied to the group list.
    @State private var filter: DuplicateGroupFilter = .all

    var body: some View {
        VStack(spacing: 0) {
            // Progress header
            progressHeader

            Divider()

            // Filter bar
            filterBar

            Divider()

            // Group list or empty state
            groupList

            // Batch approval bar (AC1, AC4, AC6)
            BatchApprovalView(
                viewModel: viewModel,
                confirmationViewModel: confirmationViewModel,
                undoManager: undoManager
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Progress Header

    /// Header showing review progress statistics.
    @ViewBuilder
    private var progressHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Duplicate Review")
                    .font(.headline)
                Text("Reviewed \(viewModel.reviewedCount) / \(viewModel.totalGroups) groups")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if viewModel.markedForRemovalCount > 0 {
                Label(
                    "\(viewModel.markedForRemovalCount) marked for removal",
                    systemImage: "trash"
                )
                .font(.caption)
                .foregroundStyle(.red)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
    }

    // MARK: - Filter Bar

    /// Filter picker for group display.
    @ViewBuilder
    private var filterBar: some View {
        HStack(spacing: 12) {
            ForEach(DuplicateGroupFilter.allCases, id: \.self) { option in
                Button {
                    filter = option
                } label: {
                    Text(option.rawValue)
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            filter == option
                                ? Color.accentColor.opacity(0.2)
                                : Color.clear
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .foregroundStyle(filter == option ? .primary : .secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
    }

    // MARK: - Group List

    /// Filtered list of PhotoComparisonCards or empty state.
    @ViewBuilder
    private var groupList: some View {
        let filtered = filteredGroups

        if filtered.isEmpty {
            emptyState(hasAnyGroups: !viewModel.groups.isEmpty)
        } else {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(filtered) { group in
                        let reviewState = viewModel.reviewStates[group.id] ?? .pending
                        PhotoComparisonCard(
                            group: group,
                            reviewState: reviewState,
                            onKeep: {
                                viewModel.markAsKeep(groupID: group.id)
                            },
                            onRemove: {
                                viewModel.markAsRemove(groupID: group.id)
                            }
                        )
                        .id(group.id)
                    }
                }
                .padding(16)
            }
        }
    }

    /// Groups filtered by the current filter selection.
    private var filteredGroups: [DuplicateGroup] {
        switch filter {
        case .all:
            viewModel.groups
        case .pending:
            viewModel.pendingGroups
        case .markedForRemoval:
            viewModel.groups.filter { viewModel.reviewStates[$0.id] == .remove }
        }
    }

    // MARK: - Empty State

    /// Empty state view with contextual message.
    @ViewBuilder
    private func emptyState(hasAnyGroups: Bool) -> some View {
        VStack(spacing: 12) {
            Image(systemName: hasAnyGroups ? "checkmark.circle" : "photo.on.rectangle.angled")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)

            Text(hasAnyGroups ? "No groups match the current filter" : "No duplicate groups found")
                .font(.body)
                .foregroundStyle(.secondary)

            if hasAnyGroups {
                Button("Show all groups") {
                    filter = .all
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Preview

#Preview("With Groups") {
    let vm = DeduplicationViewModel()
    let groups = [
        DuplicateGroup(
            id: UUID(),
            assets: [
                PhotoAsset(
                    id: AssetID(rawValue: "a1"),
                    metadata: AssetMetadata(
                        fileName: "IMG_001.jpg", fileSize: nil, creationDate: nil,
                        cameraModel: nil, imageWidth: nil, imageHeight: nil,
                        gpsLocation: nil, fileFormat: nil
                    ),
                    thumbnailData: nil
                ),
                PhotoAsset(
                    id: AssetID(rawValue: "a2"),
                    metadata: AssetMetadata(
                        fileName: "IMG_002.jpg", fileSize: nil, creationDate: nil,
                        cameraModel: nil, imageWidth: nil, imageHeight: nil,
                        gpsLocation: nil, fileFormat: nil
                    ),
                    thumbnailData: nil
                )
            ],
            similarityScore: 0.95,
            reason: "Same scene, different exposure",
            status: .pending
        ),
        DuplicateGroup(
            id: UUID(),
            assets: [
                PhotoAsset(
                    id: AssetID(rawValue: "b1"),
                    metadata: AssetMetadata(
                        fileName: "DSC_010.jpg", fileSize: nil, creationDate: nil,
                        cameraModel: nil, imageWidth: nil, imageHeight: nil,
                        gpsLocation: nil, fileFormat: nil
                    ),
                    thumbnailData: nil
                ),
                PhotoAsset(
                    id: AssetID(rawValue: "b2"),
                    metadata: AssetMetadata(
                        fileName: "DSC_011.jpg", fileSize: nil, creationDate: nil,
                        cameraModel: nil, imageWidth: nil, imageHeight: nil,
                        gpsLocation: nil, fileFormat: nil
                    ),
                    thumbnailData: nil
                )
            ],
            similarityScore: 0.87,
            reason: nil,
            status: .pending
        )
    ]
    vm.loadGroups(groups)
    return DuplicateReviewView(
        viewModel: vm,
        confirmationViewModel: nil,
        undoManager: nil
    )
    .frame(width: 500, height: 600)
}

#Preview("Empty") {
    DuplicateReviewView(
        viewModel: DeduplicationViewModel(),
        confirmationViewModel: nil,
        undoManager: nil
    )
    .frame(width: 500, height: 400)
}
