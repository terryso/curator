import SwiftUI

/// Degradation view shown when the user skips or cancels folder selection (AC3, UX-DR9).
///
/// Displays a clear explanation, a button to retry folder selection,
/// and a secondary "Continue (limited)" button to proceed with restricted functionality.
struct NoFolderSelectedView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    /// Action called when the user chooses to continue with limited features.
    let onContinueRestricted: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "folder.badge.questionmark")
                .font(.system(size: 48))
                .foregroundStyle(.orange)
                .accessibilityHidden(true)

            Text("No Photo Folder Selected")
                .font(.title)
                .fontWeight(.bold)

            Text("Curator needs a photo folder to manage your photos. You can select one later in settings.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)

            Spacer()

            VStack(spacing: 12) {
                Button(action: { viewModel.retryFolderSelection() }) {
                    Label("Select Photo Folder", systemImage: "folder.badge.plus")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
                .accessibilityLabel("Select a photo folder to scan")

                Button("Continue with Limited Features") {
                    onContinueRestricted()
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .accessibilityLabel("Continue without selecting a photo folder")
            }

            Spacer()
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

#Preview("NoFolderSelectedView - Light") {
    NoFolderSelectedView(
        viewModel: OnboardingViewModel(repository: nil),
        onContinueRestricted: {}
    )
    .frame(width: 600, height: 500)
}

#Preview("NoFolderSelectedView - Dark") {
    NoFolderSelectedView(
        viewModel: OnboardingViewModel(repository: nil),
        onContinueRestricted: {}
    )
    .frame(width: 600, height: 500)
    .preferredColorScheme(.dark)
}
