import SwiftUI

/// Second confirmation sheet for destructive operations (delete).
///
/// Shows a warning icon, operation summary, and Confirm Execute / Cancel buttons.
/// Includes undo path reminder text.
struct DestructiveConfirmationSheet: View {

    /// The confirmation request being confirmed.
    let request: ConfirmationRequest

    /// Callback when the user clicks "Confirm Execute".
    let onConfirm: () -> Void

    /// Callback when the user clicks "Cancel".
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            // Warning icon
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundStyle(.red)

            // Operation summary
            Text("确定要删除 \(request.operations.count) 张照片？")
                .font(.title3)
                .fontWeight(.semibold)

            Text("删除的照片将移至废纸篓，可通过 ⌘Z 撤销。")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            // Undo path reminder
            Text(request.undoDescription)
                .font(.caption)
                .foregroundStyle(.tertiary)

            // Action buttons
            HStack(spacing: 12) {
                Button("取消") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)

                Button("确认执行") {
                    onConfirm()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }
        }
        .padding(24)
        .frame(width: 360)
    }
}
