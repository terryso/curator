import SwiftUI

/// Third onboarding screen: photo permission explanation.
///
/// Explains why photo access is needed and provides a "Next" button
/// to proceed to the LLM configuration step.
struct PermissionRequestView: View {
    /// Whether a permission request is currently in progress.
    let isRequesting: Bool
    /// Action called when the user taps "Next".
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
                .accessibilityLabel("Go back to privacy")

                Spacer()

                Button("Next") {
                    onRequestPermission()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
                .accessibilityLabel("Continue to next step")
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
