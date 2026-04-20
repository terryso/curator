import SwiftUI

/// Third onboarding screen: folder selection.
///
/// Explains why folder access is needed and provides a "Select Photo Folder"
/// button that triggers NSOpenPanel via the ViewModel.
struct FolderSelectionView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    /// Action called when the user taps "Back".
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "folder.badge.plus")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            Text("Select Photo Folder")
                .font(.title)
                .fontWeight(.bold)

            Text("Choose the folder containing your photos. Curator will scan it and organize your library.")
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

                Button("Select Photo Folder") {
                    viewModel.selectPhotoFolder()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
                .accessibilityLabel("Select a photo folder to scan")
            }
            .padding(.horizontal, 40)
        }
        .padding(.vertical, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

#Preview("FolderSelectionView - Light") {
    FolderSelectionView(
        viewModel: OnboardingViewModel(repository: nil),
        onBack: {}
    )
    .frame(width: 600, height: 500)
}

#Preview("FolderSelectionView - Dark") {
    FolderSelectionView(
        viewModel: OnboardingViewModel(repository: nil),
        onBack: {}
    )
    .frame(width: 600, height: 500)
    .preferredColorScheme(.dark)
}
