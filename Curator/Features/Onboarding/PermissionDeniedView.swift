import SwiftUI

/// Permission denied degradation view (AC3, UX-DR9).
///
/// Shown when the user denies photo access. Displays a clear explanation,
/// a button to open System Settings for re-enabling access, and a
/// secondary "Continue (restricted)" button to proceed with limited functionality.
struct PermissionDeniedView: View {
    /// Action called when the user wants to open System Settings.
    let onOpenSettings: () -> Void
    /// Action called when the user chooses to continue with restricted access.
    let onContinueRestricted: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "photo.badge.exclamationmark")
                .font(.system(size: 48))
                .foregroundStyle(.orange)
                .accessibilityHidden(true)

            Text("Cannot Access Photo Library")
                .font(.title)
                .fontWeight(.bold)

            Text("Curator needs photo library access to manage your photos. You can enable access in System Settings.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)

            Spacer()

            VStack(spacing: 12) {
                Button(action: onOpenSettings) {
                    Label("Open System Settings", systemImage: "gear")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
                .accessibilityLabel("Open System Settings to grant photo access")

                Button("Continue with Limited Features") {
                    onContinueRestricted()
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .accessibilityLabel("Continue without photo access")
            }

            Spacer()
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

#Preview("PermissionDeniedView - Light") {
    PermissionDeniedView(onOpenSettings: {}, onContinueRestricted: {})
        .frame(width: 600, height: 500)
}

#Preview("PermissionDeniedView - Dark") {
    PermissionDeniedView(onOpenSettings: {}, onContinueRestricted: {})
        .frame(width: 600, height: 500)
        .preferredColorScheme(.dark)
}
