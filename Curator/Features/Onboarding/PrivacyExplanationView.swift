import SwiftUI

/// Second onboarding screen: privacy explanation.
///
/// Displays privacy commitments with SF Symbol icons for clarity:
/// - Photos are analyzed only during the session
/// - Sent to LLM API for understanding photo content
/// - Never uploaded or stored on any server
///
/// Provides "Next" and "Back" navigation buttons.
struct PrivacyExplanationView: View {
    /// Action called when the user taps "Next".
    let onNext: () -> Void
    /// Action called when the user taps "Back".
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("Your Privacy Matters")
                .font(.title)
                .fontWeight(.bold)

            VStack(alignment: .leading, spacing: 20) {
                privacyRow(
                    icon: "eye.slash",
                    color: .blue,
                    title: "Local Analysis Only",
                    description: "Photos are analyzed only during your session."
                )
                privacyRow(
                    icon: "brain",
                    color: .purple,
                    title: "AI Understanding",
                    description: "Sent to LLM API to understand photo content."
                )
                privacyRow(
                    icon: "lock.shield",
                    color: .green,
                    title: "Never Stored",
                    description: "Photos are never uploaded or stored on any server."
                )
            }
            .padding(.horizontal, 40)

            Spacer()

            HStack(spacing: 16) {
                Button("Back") {
                    onBack()
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .accessibilityLabel("Go back to welcome")

                Spacer()

                Button("Next") {
                    onNext()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
                .accessibilityLabel("Next step")
            }
            .padding(.horizontal, 40)
        }
        .padding(.vertical, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func privacyRow(
        icon: String,
        color: Color,
        title: String,
        description: String
    ) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 32)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview("PrivacyExplanationView - Light") {
    PrivacyExplanationView(onNext: {}, onBack: {})
        .frame(width: 600, height: 500)
}

#Preview("PrivacyExplanationView - Dark") {
    PrivacyExplanationView(onNext: {}, onBack: {})
        .frame(width: 600, height: 500)
        .preferredColorScheme(.dark)
}
