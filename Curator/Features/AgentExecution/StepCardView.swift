import SwiftUI

/// View rendering a single Agent execution step as a card.
///
/// Implements AC1/FR14/UX-DR3: displays step title, status icon with color,
/// progress indicator, and optional reasoning bubbles.
///
/// Status icon mapping:
/// - pending: clock.fill (gray)
/// - running: progress.indicator (accent, spinning)
/// - completed: checkmark.circle.fill (green)
/// - failed: xmark.circle.fill (red)
struct StepCardView: View {

    /// The step to render.
    let step: AgentStep

    /// Whether the app is currently in read-only mode.
    /// When true, steps with write-related keywords display a read-only badge.
    var isReadOnlyMode: Bool = false

    /// Whether the user prefers reduced motion.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header: icon + title + status text
            HStack(spacing: 10) {
                statusIcon

                Text(step.title)
                    .font(.body)
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Read-only badge for write operation steps
                if isReadOnlyMode && step.isWriteOperation {
                    Label("需要写入权限", systemImage: "lock.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }

                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Progress section (only when step has counts)
            if step.totalCount > 0 {
                progressSection
            }

            // Reasoning bubbles
            if !step.reasoningMessages.isEmpty {
                VStack(spacing: 6) {
                    ForEach(Array(step.reasoningMessages.enumerated()), id: \.offset) { index, message in
                        let isLast = index == step.reasoningMessages.count - 1
                        ReasoningBubbleView(
                            message: message,
                            isStreaming: isLast && step.status == .running
                        )
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 0.5)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    // MARK: - Status Icon

    /// SF Symbol icon reflecting current step status.
    @ViewBuilder
    private var statusIcon: some View {
        switch step.status {
        case .pending:
            Image(systemName: "clock.fill")
                .foregroundStyle(.secondary)
        case .running:
            if reduceMotion {
                Image(systemName: "progress.indicator")
                    .foregroundStyle(Color.accentColor)
            } else {
                Image(systemName: "progress.indicator")
                    .foregroundStyle(Color.accentColor)
                    .symbolEffect(.rotate, options: .repeating)
            }
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .failed:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)
        }
    }

    /// Human-readable status text.
    private var statusText: String {
        switch step.status {
        case .pending: return "Waiting"
        case .running: return "Running"
        case .completed: return "Done"
        case .failed: return "Failed"
        }
    }

    // MARK: - Progress Section

    /// Progress indicator with numeric display.
    @ViewBuilder
    private var progressSection: some View {
        VStack(spacing: 4) {
            ProgressView(value: step.progress, total: 1.0)
                .progressViewStyle(.linear)

            Text("Processed \(step.completedCount)/\(step.totalCount)")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Accessibility

    /// Combined accessibility label for the step card.
    private var accessibilityText: String {
        var parts = [step.title, statusText]
        if step.totalCount > 0 {
            parts.append("Processed \(step.completedCount) of \(step.totalCount)")
        }
        return parts.joined(separator: ", ")
    }
}

#Preview("Step Cards") {
    VStack(spacing: 12) {
        StepCardView(step: AgentStep(
            id: UUID(), title: "Scan Library", status: .completed,
            completedCount: 15000, totalCount: 15000, reasoningMessages: []
        ))
        StepCardView(step: AgentStep(
            id: UUID(), title: "Find Duplicates", status: .running,
            completedCount: 1200, totalCount: 15000,
            reasoningMessages: ["Comparing visual features...", "Using perceptual hash"]
        ))
        StepCardView(step: AgentStep(
            id: UUID(), title: "Rename Files", status: .pending,
            completedCount: 0, totalCount: 0, reasoningMessages: []
        ))
        StepCardView(step: AgentStep(
            id: UUID(), title: "Analyze Error", status: .failed,
            completedCount: 5, totalCount: 100, reasoningMessages: []
        ))
    }
    .padding()
    .frame(width: 450)
}
