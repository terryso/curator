import SwiftUI

/// View displaying an Agent reasoning message in a styled bubble.
///
/// Implements UX-DR10: reasoning content shown in indigo-tinted card with
/// italic/secondary text, brain icon, and expand/collapse interaction.
///
/// Supports streaming mode where a blinking cursor is shown at the end of text
/// to indicate the Agent is actively generating reasoning content. When
/// `isStreaming` is true, the text is displayed without line limits so the
/// full accumulated content is visible.
///
/// Default state shows first 2 lines; tap to expand full content.
struct ReasoningBubbleView: View {

    /// The reasoning message text to display.
    let message: String

    /// Whether the Agent is actively streaming reasoning text.
    ///
    /// When true, a blinking cursor is appended to the text and the view
    /// expands to show all content (no line limit).
    var isStreaming: Bool = false

    /// Whether the bubble is expanded to show full content.
    @State private var isExpanded = false

    /// Drives the blinking cursor animation when streaming.
    @State private var cursorVisible = true

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

                HStack(spacing: 0) {
                    Text(message)
                        .font(.body.italic())
                        .foregroundStyle(.secondary)
                        .lineLimit(isStreaming || isExpanded ? nil : 2)
                        .multilineTextAlignment(.leading)

                    if isStreaming && !reduceMotion {
                        Text("|")
                            .font(.body.monospaced().italic())
                            .foregroundStyle(.secondary)
                            .opacity(cursorVisible ? 1 : 0)
                            .onAppear {
                                withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                                    cursorVisible = false
                                }
                            }
                    }
                }
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
        .accessibilityLabel(accessibilityText)
    }

    /// Adaptive opacity for indigo background based on color scheme.
    private var colorOpacity: Double {
        colorScheme == .dark ? 0.2 : 0.08
    }

    /// Combined accessibility label for the bubble.
    private var accessibilityText: String {
        var label = "Agent reasoning: \(messagePrefix)"
        if isStreaming {
            label += ", generating"
        }
        return label
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
        ReasoningBubbleView(message: "Analyzing photo metadata and comparing visual features across the library", isStreaming: true)
    }
    .padding()
    .frame(width: 400)
}
