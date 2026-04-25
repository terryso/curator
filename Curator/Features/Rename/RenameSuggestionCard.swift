import SwiftUI

/// A card component displaying a rename suggestion with thumbnail, current name,
/// suggested name, inline editing support, and accept/reject/edit actions.
///
/// Implements UX-DR5: thumbnail + current name -> suggested name (with animation),
/// inline editing, and accept/reject/edit action buttons.
struct RenameSuggestionCard: View {

    /// The rename suggestion to display.
    let suggestion: RenameSuggestion

    /// Current review decision for this suggestion.
    let reviewDecision: RenameReviewDecision

    /// Callback when user accepts the suggestion.
    let onAccept: () -> Void

    /// Callback when user rejects the suggestion.
    let onReject: () -> Void

    /// Callback when user confirms an edited name.
    let onEditConfirm: (String) -> Void

    /// Whether the user prefers reduced motion.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Whether the card is in inline editing mode.
    @State private var isEditing = false

    /// The edited name text.
    @State private var editedName = ""

    /// Whether the edited name is valid.
    private var isEditedNameValid: Bool {
        RenameSuggestion.isValidFileName(editedName)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Thumbnail + names area
            nameTransitionArea

            // AI analysis description
            if let description = suggestion.analysisDescription {
                analysisLabel(description)
            }

            // Confidence score
            confidenceLabel

            // Action buttons or edit controls
            if isEditing {
                editControls
            } else {
                actionButtons
            }
        }
        .padding(12)
        .background(cardBackground)
        .overlay(cardBorder)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityText)
    }

    // MARK: - Name Transition Area

    /// Thumbnail + current name -> suggested name transition.
    @ViewBuilder
    private var nameTransitionArea: some View {
        HStack(spacing: 12) {
            // Thumbnail
            thumbnailView
                .frame(width: 60, height: 60)

            // Names
            VStack(alignment: .leading, spacing: 6) {
                // Original file name
                Text(suggestion.originalFileName)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                // Arrow + suggested/edited name
                if isEditing {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("Enter new name", text: $editedName)
                            .textFieldStyle(.roundedBorder)
                            .font(.body)
                            .onSubmit {
                                confirmEdit()
                            }
                    }
                    // Validation indicator
                    if !editedName.isEmpty {
                        validationIndicator
                    }
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(displayName)
                            .font(.body)
                            .foregroundStyle(Color.accentColor)
                            .lineLimit(1)
                    }
                }
            }
        }
    }

    /// The name to display based on review decision.
    private var displayName: String {
        if case .edited(let name) = reviewDecision {
            return name
        }
        return suggestion.suggestedName
    }

    /// Thumbnail view using NSImage loading pattern.
    @ViewBuilder
    private var thumbnailView: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(Color(nsColor: .controlBackgroundColor))
            .overlay(
                Image(systemName: "photo")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            )
    }

    // MARK: - Analysis Label

    /// AI analysis description label with indigo background.
    @ViewBuilder
    private func analysisLabel(_ description: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "sparkles")
                .font(.caption2)
            Text(description)
                .font(.caption)
                .lineLimit(2)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.indigo.opacity(0.8))
        )
    }

    // MARK: - Confidence Label

    /// Confidence score display with color coding.
    @ViewBuilder
    private var confidenceLabel: some View {
        HStack(spacing: 4) {
            Image(systemName: "chart.bar.fill")
                .font(.caption2)
            Text("Confidence: \(Int(suggestion.confidence * 100))%")
                .font(.caption)
                .foregroundStyle(confidenceColor)
        }
    }

    /// Color based on confidence score: >= 0.8 green, 0.5-0.8 orange, < 0.5 gray.
    private var confidenceColor: Color {
        if suggestion.confidence >= 0.8 {
            return .green
        } else if suggestion.confidence >= 0.5 {
            return .orange
        } else {
            return .secondary
        }
    }

    // MARK: - Action Buttons

    /// Accept (secondary style), Reject (danger style), and Edit action buttons.
    @ViewBuilder
    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button {
                onAccept()
            } label: {
                Label("Accept", systemImage: "hand.thumbsup")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(isReviewedAccepted)

            Button(role: .destructive) {
                onReject()
            } label: {
                Label("Reject", systemImage: "xmark.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .tint(.red)
            .disabled(isReviewedRejected)

            Button {
                startEditing()
            } label: {
                Label("Edit", systemImage: "pencil")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.top, 4)
    }

    /// Whether the suggestion has been accepted (accept button should be disabled).
    private var isReviewedAccepted: Bool {
        if case .accepted = reviewDecision { return true }
        if case .edited = reviewDecision { return true }
        return false
    }

    /// Whether the suggestion has been rejected (reject button should be disabled).
    private var isReviewedRejected: Bool {
        if case .rejected = reviewDecision { return true }
        return false
    }

    // MARK: - Edit Controls

    /// Confirm and Cancel buttons for inline editing mode.
    @ViewBuilder
    private var editControls: some View {
        HStack(spacing: 12) {
            Button {
                confirmEdit()
            } label: {
                Label("Confirm", systemImage: "checkmark")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(!isEditedNameValid)

            Button {
                cancelEdit()
            } label: {
                Label("Cancel", systemImage: "xmark")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.top, 4)
    }

    /// Validation indicator showing whether the edited name is valid.
    @ViewBuilder
    private var validationIndicator: some View {
        HStack(spacing: 4) {
            Image(systemName: isEditedNameValid ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.caption2)
            Text(isEditedNameValid ? "Valid file name" : "Invalid file name")
                .font(.caption2)
        }
        .foregroundStyle(isEditedNameValid ? .green : .red)
    }

    // MARK: - Edit Actions

    /// Starts inline editing mode.
    ///
    /// If the user previously edited and confirmed a custom name, re-opens
    /// with that custom name rather than reverting to the AI suggestion.
    private func startEditing() {
        if case .edited(let name) = reviewDecision {
            editedName = name
        } else {
            editedName = suggestion.suggestedName
        }
        isEditing = true
    }

    /// Confirms the edit and invokes the callback.
    private func confirmEdit() {
        guard isEditedNameValid else { return }
        onEditConfirm(editedName)
        isEditing = false
    }

    /// Cancels inline editing mode.
    private func cancelEdit() {
        isEditing = false
        editedName = ""
    }

    // MARK: - Card Styling

    /// Card background.
    @ViewBuilder
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(Color(nsColor: .controlBackgroundColor))
    }

    /// Border overlay indicating review state.
    @ViewBuilder
    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: 10)
            .strokeBorder(borderColor, lineWidth: borderWidth)
    }

    /// Border color based on review decision.
    private var borderColor: Color {
        if isEditing { return .blue }
        switch reviewDecision {
        case .pending: return Color(nsColor: .separatorColor)
        case .accepted: return .green
        case .rejected: return .red
        case .edited: return .green
        }
    }

    /// Border width: thicker for reviewed states.
    private var borderWidth: CGFloat {
        switch reviewDecision {
        case .pending: return 0.5
        case .accepted, .rejected, .edited: return 2
        }
    }

    // MARK: - Accessibility

    /// Combined accessibility label for the card.
    private var accessibilityText: String {
        let stateDescription: String
        switch reviewDecision {
        case .pending: stateDescription = "Not reviewed"
        case .accepted: stateDescription = "Accepted"
        case .rejected: stateDescription = "Rejected"
        case .edited(let name): stateDescription = "Edited to \(name)"
        }
        let confidence = Int(suggestion.confidence * 100)
        var parts = [
            "Rename suggestion",
            "From \(suggestion.originalFileName) to \(displayName)",
            "Confidence \(confidence) percent",
            stateDescription
        ]
        if let description = suggestion.analysisDescription {
            parts.append("Analysis: \(description)")
        }
        return parts.joined(separator: ", ")
    }
}

// MARK: - Preview

#Preview("Pending") {
    RenameSuggestionCard(
        suggestion: RenameSuggestion(
            assetID: AssetID(rawValue: "test-1"),
            originalFileName: "IMG_0019.jpg",
            suggestedName: "sunset-over-ocean.jpg",
            confidence: 0.92,
            analysisDescription: "Golden sunset over ocean waves"
        ),
        reviewDecision: .pending,
        onAccept: {},
        onReject: {},
        onEditConfirm: { _ in }
    )
    .frame(width: 400)
    .padding()
}

#Preview("Accepted") {
    RenameSuggestionCard(
        suggestion: RenameSuggestion(
            assetID: AssetID(rawValue: "test-2"),
            originalFileName: "IMG_0020.jpg",
            suggestedName: "mountain-sunrise.jpg",
            confidence: 0.85,
            analysisDescription: "Mountain landscape at dawn"
        ),
        reviewDecision: .accepted,
        onAccept: {},
        onReject: {},
        onEditConfirm: { _ in }
    )
    .frame(width: 400)
    .padding()
}
