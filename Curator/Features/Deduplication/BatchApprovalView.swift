import SwiftUI

/// Batch approval action bar for the duplicate review interface.
///
/// Displays "Keep All" (secondary, bordered) and "Remove All" (danger, red)
/// buttons when groups are not all reviewed. Once all groups are reviewed,
/// shows an "Execute Deletion" button that routes through the confirmation
/// workflow. After execution, displays the result summary with undo option.
///
/// Follows UX-DR17: at most one primary button per interface, dangerous
/// operations require second confirmation via ConfirmationViewModel.
struct BatchApprovalView: View {

    /// The deduplication ViewModel providing review state and batch methods.
    let viewModel: DeduplicationViewModel

    /// The confirmation ViewModel for presenting the destructive confirmation flow.
    let confirmationViewModel: ConfirmationViewModel?

    /// The undo manager ViewModel for rollback support after execution.
    let undoManager: UndoManagerViewModel?

    var body: some View {
        VStack(spacing: 0) {
            Divider()

            if let result = confirmationViewModel?.executionResult {
                // AC2: Execution result summary
                resultSummary(result)
            } else if !viewModel.allReviewed {
                // AC1: Batch action buttons (UX-DR17: max one primary)
                batchActionButtons
            } else {
                // All reviewed — show execute button if there are removals
                executeSection
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
    }

    // MARK: - Batch Action Buttons

    /// "Keep All" and "Remove All" buttons for unreviewed groups.
    @ViewBuilder
    private var batchActionButtons: some View {
        HStack {
            // Pending count label
            Text("\(viewModel.pendingGroups.count) groups pending")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            // "Keep All" — secondary style (bordered), UX-DR17
            Button {
                viewModel.markAllAsKeep()
            } label: {
                Label(
                    "Keep All (\(viewModel.pendingGroups.count))",
                    systemImage: "hand.thumbsup"
                )
                .font(.callout)
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            .disabled(viewModel.pendingGroups.isEmpty)

            // "Remove All" — danger style (red), UX-DR17
            Button(role: .destructive) {
                markAllForRemoval()
            } label: {
                Label(
                    "Remove All (\(viewModel.pendingGroups.count))",
                    systemImage: "trash"
                )
                .font(.callout)
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            .tint(.red)
            .disabled(viewModel.pendingGroups.isEmpty)
        }
    }

    // MARK: - Execute Section

    /// Execute deletion button shown when all groups are reviewed.
    @ViewBuilder
    private var executeSection: some View {
        HStack {
            if viewModel.markedForRemovalCount > 0 {
                Text("\(viewModel.markedForRemovalCount) groups marked for removal")
                    .font(.caption)
                    .foregroundStyle(.red)

                Spacer()

                Button {
                    executeBatchRemoval()
                } label: {
                    Label(
                        "Execute Deletion (\(viewModel.assetsToRemove().count) photos)",
                        systemImage: "trash.fill"
                    )
                    .font(.callout)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .tint(.red)
            } else {
                Text("All groups marked as keep")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()
            }
        }
    }

    // MARK: - Result Summary

    /// Execution result display with success/failure counts and undo button.
    @ViewBuilder
    private func resultSummary(_ result: ExecutionResult) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                if result.isFullSuccess {
                    Label(
                        "Completed: \(result.successCount) operations succeeded",
                        systemImage: "checkmark.circle.fill"
                    )
                    .font(.callout)
                    .foregroundStyle(.green)
                } else {
                    Label(
                        "Completed: \(result.successCount) succeeded, \(result.failureCount) failed",
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .font(.callout)
                    .foregroundStyle(.orange)
                }
            }

            Spacer()

            // AC2: Undo option
            if let undoMgr = undoManager, undoMgr.canPerformAction {
                Button {
                    _Concurrency.Task {
                        await undoMgr.performUndoAction()
                        confirmationViewModel?.cancel()
                    }
                } label: {
                    Label("Undo", systemImage: "arrow.uturn.backward")
                        .font(.callout)
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
            }

            Button("Dismiss") {
                confirmationViewModel?.cancel()
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
        }
    }

    // MARK: - Actions

    /// Marks all pending groups for removal.
    ///
    /// After marking, the view transitions to the executeSection where the user
    /// can review the decision and explicitly trigger execution. This two-step
    /// flow ensures the user can cancel without losing their previous review state.
    private func markAllForRemoval() {
        viewModel.markAllAsRemove()
    }

    /// Creates PlannedOperations from removal decisions and presents confirmation.
    private func executeBatchRemoval() {
        guard let confirmationVM = confirmationViewModel else { return }

        let operations = viewModel.toDeleteOperations()
        guard !operations.isEmpty else { return }

        let request = ConfirmationRequest(
            operations: operations,
            confirmationLevel: .forOperations(operations),
            summary: "Delete \(operations.count) duplicate photos"
        )

        confirmationVM.presentConfirmation(request: request)
    }
}

// MARK: - Preview

#Preview("Pending Groups") {
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
            ],
            similarityScore: 0.95,
            reason: "Test",
            status: .pending
        ),
    ]
    vm.loadGroups(groups)
    return BatchApprovalView(
        viewModel: vm,
        confirmationViewModel: nil,
        undoManager: nil
    )
    .frame(width: 500)
}

#Preview("All Reviewed") {
    let vm = DeduplicationViewModel()
    let groupID = UUID()
    let groups = [
        DuplicateGroup(
            id: groupID,
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
            ],
            similarityScore: 0.95,
            reason: nil,
            status: .pending
        ),
    ]
    vm.loadGroups(groups)
    vm.markAsRemove(groupID: groupID)
    return BatchApprovalView(
        viewModel: vm,
        confirmationViewModel: nil,
        undoManager: nil
    )
    .frame(width: 500)
}
