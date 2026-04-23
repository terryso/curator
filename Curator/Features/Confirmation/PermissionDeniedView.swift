import SwiftUI

/// View shown when the user denies write permission during confirmation.
///
/// Displays a "save results for later" suggestion as required by AC5,
/// and a dismiss button to close the overlay.
struct PermissionDeniedView: View {

    /// Callback when the user dismisses the view.
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Label {
                Text("写入权限未授予")
                    .font(.headline)
            } icon: {
                Image(systemName: "lock.fill")
                    .foregroundStyle(.secondary)
            }

            Text("操作已取消。可保存当前结果，待授权写入后重新执行。")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("知道了") {
                onDismiss()
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
        }
        .padding(20)
        .frame(maxWidth: 320)
    }
}
