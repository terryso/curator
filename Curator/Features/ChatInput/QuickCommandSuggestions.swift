import SwiftUI

/// Quick command suggestion cards displayed when Agent is idle.
///
/// AC3: Shows 3-4 quick command suggestion cards with icons.
/// Only visible when AgentJob is nil or in planning state with no history.
/// Each card directly submits its command via the ViewModel.
struct QuickCommandSuggestions: View {

    /// The ViewModel managing input state and Agent execution.
    let viewModel: ChatInputViewModel

    /// Quick command data: title and SF Symbol icon name.
    private static let commands: [(title: String, icon: String)] = [
        ("找出重复照片", "doc.on.doc.fill"),
        ("重命名照片", "pencil.line"),
        ("分析我的照片", "eye.fill"),
        ("帮我整理照片库", "folder.fill.badge.gearshape"),
    ]

    var body: some View {
        if viewModel.quickCommandsVisible {
            VStack(alignment: .leading, spacing: 12) {
                Text("试试这些指令")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12),
                    ],
                    spacing: 12
                ) {
                    ForEach(Self.commands, id: \.title) { command in
                        QuickCommandCard(
                            title: command.title,
                            icon: command.icon
                        ) {
                            viewModel.submitQuickCommand(command.title)
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
    }
}

// MARK: - Quick Command Card

/// A single quick command suggestion card.
///
/// Displays an icon and title in a rounded rectangle card.
/// Highlights on hover for visual feedback.
private struct QuickCommandCard: View {

    let title: String
    let icon: String
    let action: () -> Void

    /// Tracks hover state for highlight effect.
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 24)

                Text(title)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isHovered ? Color.accentColor.opacity(0.1) : Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
        .accessibilityLabel("Quick command: \(title)")
        .accessibilityHint("Tap to submit this instruction to the Agent")
    }
}
