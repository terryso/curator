import SwiftUI

/// Displays progress and results of a batch rollback/re-execute operation.
///
/// Shows an inline progress indicator during the operation and
/// a result summary (success/failure) upon completion.
struct RollbackProgressView: View {

    /// The undo manager providing state for this view.
    @Bindable var undoManager: UndoManagerViewModel

    var body: some View {
        if undoManager.isProcessing {
            progressContent
        } else if let error = undoManager.lastError {
            errorContent(error)
        }
    }

    // MARK: - Progress

    private var progressContent: some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)
            Text(undoManager.progressDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
    }

    // MARK: - Error

    private func errorContent(_ error: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
            Text(error)
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("重试") {
                _Concurrency.Task {
                    await undoManager.performUndoAction()
                }
            }
            .buttonStyle(.borderless)
            .font(.caption)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
    }
}

#Preview {
    VStack(spacing: 16) {
        RollbackProgressView(
            undoManager: {
                let vm = UndoManagerViewModel(operationManager: nil)
                vm.isProcessing = true
                vm.progressDescription = "正在撤销..."
                return vm
            }()
        )
        RollbackProgressView(
            undoManager: {
                let vm = UndoManagerViewModel(operationManager: nil)
                vm.lastError = "文件未找到"
                return vm
            }()
        )
    }
    .padding()
}
