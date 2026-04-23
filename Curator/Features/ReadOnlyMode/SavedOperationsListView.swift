import SwiftUI

/// Sheet view listing saved operation sets that can be re-executed after write permission is granted.
///
/// Design spec (from story 4.5 Dev Notes):
/// - Presented as a Sheet
/// - Standard List style
/// - Each row: operation summary + creation date + operation count
/// - Right: blue "执行" button (enabled with write access) or gray "需要权限" (disabled)
/// - Bottom: "清除全部" button (secondary style)
struct SavedOperationsListView: View {

    /// The read-only mode ViewModel providing saved operations.
    let readOnlyMode: ReadOnlyModeViewModel

    /// Callback to execute a saved operation set through the confirmation flow.
    let onExecute: (SavedOperationSet) -> Void

    /// Callback to dismiss the sheet.
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            Divider()

            // Content
            if readOnlyMode.savedOperations.isEmpty {
                emptyState
            } else {
                operationsList
            }
        }
        .frame(minWidth: 400, minHeight: 300)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("待执行操作")
                .font(.headline)
            Spacer()
            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "checkmark.circle")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("没有待执行的操作")
                .font(.body)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Operations List

    private var operationsList: some View {
        VStack(spacing: 0) {
            List {
                ForEach(readOnlyMode.savedOperations) { savedSet in
                    savedOperationRow(savedSet)
                }
            }
            .listStyle(.inset)

            Divider()

            // Bottom action
            HStack {
                Button(role: .destructive) {
                    readOnlyMode.clearAllSavedOperations()
                } label: {
                    Text("清除全部")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                Spacer()
            }
            .padding(12)
        }
    }

    // MARK: - Row

    private func savedOperationRow(_ savedSet: SavedOperationSet) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(savedSet.summary)
                    .font(.body)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    Text(savedSet.createdAt, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("\(savedSet.operations.count) 个操作")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if readOnlyMode.hasWriteAccess {
                Button {
                    onExecute(savedSet)
                } label: {
                    Text("执行")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            } else {
                Text("需要权限")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }
}
