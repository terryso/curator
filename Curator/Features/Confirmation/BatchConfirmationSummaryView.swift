import SwiftUI

/// Batch confirmation summary view for write operations.
///
/// Displays operation count, affected asset thumbnails, action type labels,
/// Execute/Cancel buttons (styled by confirmation level), and undo path info.
struct BatchConfirmationSummaryView: View {

    /// The confirmation request to display.
    let request: ConfirmationRequest

    /// Callback when the user clicks "Execute".
    let onExecute: () -> Void

    /// Callback when the user clicks "Cancel".
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            // Operation type label
            Text(operationTypeLabel)
                .font(.headline)

            // Summary text
            Text(request.summary)
                .font(.body)
                .foregroundStyle(.secondary)

            // Affected asset IDs (compact display)
            assetPreviewSection

            // Undo path description
            Text(request.undoDescription)
                .font(.caption)
                .foregroundStyle(.tertiary)

            // Action buttons
            HStack(spacing: 12) {
                Button("取消") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)

                Button("执行") {
                    onExecute()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .tint(request.confirmationLevel == .destructive ? .red : nil)
            }
        }
        .padding(16)
    }

    // MARK: - Computed Properties

    /// Label describing the operation types and count.
    private var operationTypeLabel: String {
        let renameCount = request.operations.filter { $0.operationType == .rename }.count
        let moveCount = request.operations.filter { $0.operationType == .move }.count
        let deleteCount = request.operations.filter { $0.operationType == .delete }.count

        var parts: [String] = []
        if renameCount > 0 { parts.append("重命名 \(renameCount) 张照片") }
        if moveCount > 0 { parts.append("移动 \(moveCount) 张照片") }
        if deleteCount > 0 { parts.append("删除 \(deleteCount) 张照片") }
        return parts.joined(separator: "、")
    }

    /// Compact preview of affected asset file names.
    @ViewBuilder
    private var assetPreviewSection: some View {
        let maxPreview = 6
        let ids = request.affectedAssetIDs
        let previewIDs = Array(ids.prefix(maxPreview))
        let extraCount = max(0, ids.count - maxPreview)

        VStack(alignment: .leading, spacing: 4) {
            ForEach(previewIDs, id: \.self) { assetID in
                HStack(spacing: 4) {
                    Image(systemName: "photo")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                    Text(URL(fileURLWithPath: assetID.rawValue).lastPathComponent)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            if extraCount > 0 {
                Text("+\(extraCount) 更多")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

}
