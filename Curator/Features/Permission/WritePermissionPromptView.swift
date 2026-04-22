import SwiftUI

/// Inline prompt for requesting write permission from the user.
///
/// Displayed when the Agent attempts a write operation without write access.
/// Shows a title, explanatory message, and Grant / Cancel buttons.
struct WritePermissionPromptView: View {
    /// Callback invoked when the user taps the grant button.
    let onGrant: () -> Void

    /// Callback invoked when the user dismisses the prompt.
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Label {
                Text("需要写入权限")
                    .font(.headline)
            } icon: {
                Image(systemName: "lock.shield")
                    .foregroundStyle(.secondary)
            }

            Text("此操作需要写入权限才能执行。授权后将立即继续操作。")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                Button("取消") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)

                Button("授权写入") {
                    onGrant()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(maxWidth: 320)
    }
}

#Preview {
    WritePermissionPromptView(
        onGrant: {},
        onCancel: {}
    )
}
