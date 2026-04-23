import SwiftUI

/// Result summary view shown after batch execution completes.
///
/// Displays success count, failure count (if any), and an undo button.
struct ExecutionResultView: View {

    /// The execution result to display.
    let result: ExecutionResult

    /// Callback when the user clicks "Undo".
    let onUndo: () -> Void

    /// Callback when the user dismisses the result view.
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            if result.isFullSuccess {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("成功执行 \(result.successCount) 项操作")
                        .font(.callout)
                }
            } else {
                VStack(spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("执行完成：\(result.successCount) 成功，\(result.failureCount) 失败")
                            .font(.callout)
                    }
                }
            }

            HStack(spacing: 12) {
                Button("撤销") {
                    onUndo()
                }

                Button("完成") {
                    onDismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(16)
    }
}
