import SwiftUI

/// Compact banner indicating the app is in read-only mode.
///
/// Displays a lock icon + "只读模式" text and an optional "授权写入" button
/// that triggers the permission upgrade flow. Only shown when the agent is
/// actively executing, to avoid visual noise when idle.
///
/// Design spec (from story 4.5 Dev Notes):
/// - Height: ~28pt
/// - Background: system tertiary background
/// - Left: lock.fill + "只读模式" (.secondary font)
/// - Right: "授权写入" text button (system blue)
struct ReadOnlyBannerView: View {

    /// The read-only mode ViewModel providing state.
    let readOnlyMode: ReadOnlyModeViewModel

    /// Callback when the user taps "授权写入".
    let onRequestWritePermission: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "lock.fill")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("只读模式")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Button {
                onRequestWritePermission()
            } label: {
                Text("授权写入")
                    .font(.caption)
                    .foregroundStyle(.blue)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(nsColor: .controlBackgroundColor))
        .overlay(
            Rectangle()
                .fill(Color(nsColor: .separatorColor).opacity(0.5))
                .frame(height: 0.5),
            alignment: .bottom
        )
    }
}
