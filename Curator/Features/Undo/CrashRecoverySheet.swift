import SwiftUI

/// Sheet shown on app startup when incomplete batch operations are detected.
///
/// Detects batches left in `.executing` status (from a crash) and offers
/// the user the choice to roll back or ignore them (NFR17).
struct CrashRecoverySheet: View {

    /// The undo manager providing incomplete batch data.
    @Bindable var undoManager: UndoManagerViewModel

    var body: some View {
        VStack(spacing: 20) {
            // Header
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundStyle(.yellow)

            Text("发现未完成的操作")
                .font(.headline)

            Text("上次应用意外退出时，有 \(undoManager.incompleteBatches.count) 个批量操作未完成。您可以撤销这些操作以恢复文件状态。")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            // Batch details
            if undoManager.incompleteBatches.count > 1 {
                Text("\(undoManager.incompleteBatches.count) 个未完成的批量操作")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            // Progress indicator
            if undoManager.isProcessing {
                RollbackProgressView(undoManager: undoManager)
            }

            // Error display
            if let error = undoManager.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            // Action buttons
            HStack(spacing: 16) {
                Button("忽略") {
                    _Concurrency.Task {
                        await undoManager.dismissCrashRecovery()
                    }
                }
                .keyboardShortcut(.cancelAction)

                Button("撤销未完成的操作") {
                    _Concurrency.Task {
                        for batch in undoManager.incompleteBatches {
                            _ = await undoManager.rollbackIncompleteBatch(batch)
                        }
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(undoManager.isProcessing)
            }
        }
        .padding(24)
        .frame(width: 400)
    }
}

#Preview {
    CrashRecoverySheet(
        undoManager: {
            let vm = UndoManagerViewModel(operationManager: nil)
            // Simulate incomplete batches for preview
            return vm
        }()
    )
}
