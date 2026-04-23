import SwiftUI

/// Progress view shown during batch operation execution.
///
/// Displays a progress bar and "Executing... (X/Y)" text.
struct ExecutionProgressView: View {

    /// Current progress (completed, total).
    let progress: ExecutionProgress

    var body: some View {
        VStack(spacing: 8) {
            ProgressView(
                value: Double(progress.completed),
                total: Double(progress.total)
            )

            Text("正在执行... (\(progress.completed)/\(progress.total))")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(16)
    }
}
