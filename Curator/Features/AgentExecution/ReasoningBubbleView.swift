import SwiftUI

/// View displaying an Agent reasoning message in a styled bubble.
///
/// Implements UX-DR10: reasoning content shown in indigo-tinted card with
/// italic/secondary text, brain icon, and expand/collapse interaction.
///
/// Default state shows first 2 lines; tap to expand full content.
struct ReasoningBubbleView: View {

    /// The reasoning message text to display.
    let message: String

    /// Whether the bubble is expanded to show full content.
    @State private var isExpanded = false

    /// Whether the user prefers reduced motion.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Current color scheme for adaptive opacity.
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button {
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) {
                isExpanded.toggle()
            }
        } label: {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "brain.head.profile")
                    .font(.body)
                    .foregroundStyle(.indigo)
                    .padding(.top, 2)

                Text(message)
                    .font(.body.italic())
                    .foregroundStyle(.secondary)
                    .lineLimit(isExpanded ? nil : 2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.indigo.opacity(colorOpacity))
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Agent reasoning: \(messagePrefix)")
    }

    /// Adaptive opacity for indigo background based on color scheme.
    private var colorOpacity: Double {
        colorScheme == .dark ? 0.2 : 0.08
    }

    /// Prefix of the message for accessibility label.
    private var messagePrefix: String {
        let maxChars = 50
        if message.count > maxChars {
            return String(message.prefix(maxChars)) + "..."
        }
        return message
    }
}

#Preview("Reasoning Bubble") {
    VStack(spacing: 16) {
        ReasoningBubbleView(message: "Found 3 similar photos with matching EXIF timestamps and visual similarity score above 0.95.")
        ReasoningBubbleView(message: "Short reasoning.")
    }
    .padding()
    .frame(width: 400)
}
