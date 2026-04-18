import SwiftUI

/// First onboarding screen: product introduction.
///
/// Displays the app name, icon, and a brief description.
/// A primary "Next" button advances to the privacy step.
/// Follows macOS native visual language with system background and
/// automatic Light/Dark mode adaptation.
struct WelcomeView: View {
    /// Action called when the user taps "Next".
    let onNext: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
                .accessibilityLabel("Curator app icon")

            Text("Curator")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("AI-powered photo management assistant")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()

            Button("Next") {
                onNext()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
            .accessibilityLabel("Next step")
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

#Preview("WelcomeView - Light") {
    WelcomeView(onNext: {})
        .frame(width: 600, height: 500)
}

#Preview("WelcomeView - Dark") {
    WelcomeView(onNext: {})
        .frame(width: 600, height: 500)
        .preferredColorScheme(.dark)
}
