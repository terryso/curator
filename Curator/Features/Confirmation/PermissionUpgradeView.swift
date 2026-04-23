import SwiftUI

/// Permission upgrade intercept view shown before write operation confirmation.
///
/// Displayed when a write operation is requested but no write permission exists.
/// Reuses the WritePermissionPromptView pattern as a pre-step in the
/// confirmation flow.
struct PermissionUpgradeView: View {

    /// Callback when permission is granted.
    let onGrant: () -> Void

    /// Callback when permission is denied.
    let onDeny: () -> Void

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

            Text("如不想授权，可保存结果供稍后执行。")
                .font(.caption)
                .foregroundStyle(.tertiary)

            HStack(spacing: 12) {
                Button("取消") {
                    onDeny()
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
