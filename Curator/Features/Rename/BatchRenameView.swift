import SwiftUI

/// Batch rename action bar for the rename review interface.
///
/// Displays "Accept All" (secondary, bordered) and "Reject All" (secondary, bordered)
/// buttons when suggestions are not all reviewed. Once all suggestions are reviewed,
/// shows an "Execute Rename" button that routes through the confirmation workflow.
/// After execution, displays the result summary with undo option.
///
/// Follows UX-DR17: at most one primary button per interface. Rename operations use
/// `.standard` confirmation level (non-destructive, fully recoverable via rollback).
struct BatchRenameView: View {

    /// The rename ViewModel providing review state and batch methods.
    let viewModel: RenameViewModel

    /// The confirmation ViewModel for presenting the confirmation flow.
    let confirmationViewModel: ConfirmationViewModel?

    /// The undo manager ViewModel for rollback support after execution.
    let undoManager: UndoManagerViewModel?

    var body: some View {
        VStack(spacing: 0) {
            Divider()

            if let result = confirmationViewModel?.executionResult {
                // AC3: Execution result summary
                resultSummary(result)
            } else if !viewModel.allReviewed {
                // AC1: Batch action buttons (UX-DR17: max one primary)
                batchActionButtons
            } else {
                // All reviewed — show execute button if there are accepted items
                executeSection
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
    }

    // MARK: - Batch Action Buttons

    /// "Accept All" and "Reject All" buttons for unreviewed suggestions.
    @ViewBuilder
    private var batchActionButtons: some View {
        HStack {
            // Pending count label
            Text("\(viewModel.pendingSuggestions.count) pending")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            // "Accept All" — secondary style (bordered), UX-DR17
            Button {
                viewModel.markAllAsAccept()
            } label: {
                Label(
                    "Accept All (\(viewModel.pendingSuggestions.count))",
                    systemImage: "hand.thumbsup"
                )
                .font(.callout)
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            .disabled(viewModel.pendingSuggestions.isEmpty)

            // "Reject All" — secondary style (bordered), UX-DR17
            Button {
                viewModel.markAllAsReject()
            } label: {
                Label(
                    "Reject All (\(viewModel.pendingSuggestions.count))",
                    systemImage: "hand.thumbsdown"
                )
                .font(.callout)
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            .disabled(viewModel.pendingSuggestions.isEmpty)
        }
    }

    // MARK: - Execute Section

    /// Execute rename button shown when all suggestions are reviewed.
    @ViewBuilder
    private var executeSection: some View {
        HStack {
            if viewModel.acceptedCount > 0 {
                Text("\(viewModel.acceptedCount) photos to rename")
                    .font(.caption)
                    .foregroundStyle(Color.accentColor)

                Spacer()

                Button {
                    executeBatchRename()
                } label: {
                    Label(
                        "Execute Rename (\(viewModel.acceptedCount))",
                        systemImage: "pencil.line"
                    )
                    .font(.callout)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
            } else {
                Text("All suggestions rejected")
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
                        "Completed: \(result.successCount) photos renamed",
                        systemImage: "checkmark.circle.fill"
                    )
                    .font(.callout)
                    .foregroundStyle(.green)
                } else {
                    Label(
                        "Completed: \(result.successCount) renamed, \(result.failureCount) failed",
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .font(.callout)
                    .foregroundStyle(.orange)
                }
            }

            Spacer()

            // AC4: Undo option
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

    /// Creates PlannedOperations from rename decisions and presents confirmation.
    private func executeBatchRename() {
        guard let confirmationVM = confirmationViewModel else { return }

        let operations = viewModel.toRenameOperations()
        guard !operations.isEmpty else { return }

        let request = ConfirmationRequest(
            operations: operations,
            confirmationLevel: .forOperations(operations),
            summary: "Rename \(operations.count) photos"
        )

        confirmationVM.presentConfirmation(request: request)
    }
}

// MARK: - Preview

#Preview("Pending Suggestions") {
    let vm = RenameViewModel()
    let suggestions = [
        RenameSuggestion(
            assetID: AssetID(rawValue: "a1"),
            originalFileName: "IMG_001.jpg",
            suggestedName: "sunset-beach.jpg",
            confidence: 0.92
        ),
        RenameSuggestion(
            assetID: AssetID(rawValue: "a2"),
            originalFileName: "IMG_002.jpg",
            suggestedName: "mountain-sunrise.jpg",
            confidence: 0.85
        ),
    ]
    vm.loadSuggestions(suggestions)
    return BatchRenameView(
        viewModel: vm,
        confirmationViewModel: nil,
        undoManager: nil
    )
    .frame(width: 500)
}

#Preview("All Reviewed") {
    let vm = RenameViewModel()
    let suggestionID = UUID()
    let suggestions = [
        RenameSuggestion(
            id: suggestionID,
            assetID: AssetID(rawValue: "a1"),
            originalFileName: "IMG_001.jpg",
            suggestedName: "sunset-beach.jpg",
            confidence: 0.92
        ),
    ]
    vm.loadSuggestions(suggestions)
    vm.accept(suggestionID: suggestionID)
    return BatchRenameView(
        viewModel: vm,
        confirmationViewModel: nil,
        undoManager: nil
    )
    .frame(width: 500)
}
