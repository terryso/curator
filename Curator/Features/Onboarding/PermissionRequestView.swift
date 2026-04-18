import SwiftUI

/// Third onboarding screen: photo permission request.
///
/// Explains why photo access is needed and provides a primary
/// "Grant Photo Access" button. On success, transitions to scanning.
/// On failure, the container shows PermissionDeniedView.
struct PermissionRequestView: View {
    /// Whether a permission request is currently in progress.
    let isRequesting: Bool
    /// Action called when the user taps "Grant Photo Access".
    let onRequestPermission: () -> Void
    /// Action called when the user taps "Back".
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "photo.badge.checkmark")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            Text("Photo Access")
                .font(.title)
                .fontWeight(.bold)

            Text("Curator needs access to your photo library to help you organize and manage your photos.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)

            Spacer()

            HStack(spacing: 16) {
                Button("Back") {
                    onBack()
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(isRequesting)
                .accessibilityLabel("Go back to privacy")

                Spacer()

                Button(action: onRequestPermission) {
                    HStack(spacing: 8) {
                        if isRequesting {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text(isRequesting ? "Requesting..." : "Grant Photo Access")
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(isRequesting)
                .keyboardShortcut(.defaultAction)
                .accessibilityLabel("Grant photo library access")
            }
            .padding(.horizontal, 40)
        }
        .padding(.vertical, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

#Preview("PermissionRequestView - Light") {
    PermissionRequestView(
        isRequesting: false,
        onRequestPermission: {},
        onBack: {}
    )
    .frame(width: 600, height: 500)
}

#Preview("PermissionRequestView - Dark") {
    PermissionRequestView(
        isRequesting: false,
        onRequestPermission: {},
        onBack: {}
    )
    .frame(width: 600, height: 500)
    .preferredColorScheme(.dark)
}
