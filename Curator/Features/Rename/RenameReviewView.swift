import SwiftUI

/// Filter options for rename suggestion display.
enum RenameSuggestionFilter: String, CaseIterable {
    case all = "All"
    case pending = "Pending"
    case accepted = "Accepted"
    case rejected = "Rejected"
}

/// Main review interface for rename suggestions.
///
/// Displays a scrollable list of RenameSuggestionCards with review progress
/// statistics and filter controls. Uses LazyVStack for smooth scrolling
/// performance (NFR2: 60fps, NFR6: 500MB).
struct RenameReviewView: View {

    /// The ViewModel providing review state.
    let viewModel: RenameViewModel

    /// Current filter applied to the suggestion list.
    @State private var filter: RenameSuggestionFilter = .all

    /// Whether the user prefers reduced motion.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            // Progress header
            progressHeader

            Divider()

            // Filter bar
            filterBar

            Divider()

            // Suggestion list or empty state
            suggestionList
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Progress Header

    /// Header showing review progress statistics.
    @ViewBuilder
    private var progressHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Rename Review")
                    .font(.headline)
                Text(viewModel.progressText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if viewModel.acceptedCount > 0 {
                Label(
                    "\(viewModel.acceptedCount) accepted",
                    systemImage: "checkmark.circle"
                )
                .font(.caption)
                .foregroundStyle(.green)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
    }

    // MARK: - Filter Bar

    /// Filter picker for suggestion display.
    @ViewBuilder
    private var filterBar: some View {
        HStack(spacing: 12) {
            ForEach(RenameSuggestionFilter.allCases, id: \.self) { option in
                Button {
                    filter = option
                } label: {
                    Text(option.rawValue)
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            filter == option
                                ? Color.accentColor.opacity(0.2)
                                : Color.clear
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .foregroundStyle(filter == option ? .primary : .secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
    }

    // MARK: - Suggestion List

    /// Filtered list of RenameSuggestionCards or empty state.
    @ViewBuilder
    private var suggestionList: some View {
        let filtered = filteredSuggestions

        if filtered.isEmpty {
            emptyState(hasAnySuggestions: !viewModel.suggestions.isEmpty)
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(filtered) { suggestion in
                            let decision = viewModel.reviewDecisions[suggestion.id] ?? .pending
                            RenameSuggestionCard(
                                suggestion: suggestion,
                                reviewDecision: decision,
                                onAccept: {
                                    viewModel.accept(suggestionID: suggestion.id)
                                    scrollToNextPending(proxy: proxy, after: suggestion.id)
                                },
                                onReject: {
                                    viewModel.reject(suggestionID: suggestion.id)
                                    scrollToNextPending(proxy: proxy, after: suggestion.id)
                                },
                                onEditConfirm: { newName in
                                    viewModel.edit(suggestionID: suggestion.id, newName: newName)
                                }
                            )
                            .id(suggestion.id)
                        }
                    }
                    .padding(16)
                }
            }
        }
    }

    /// Suggestions filtered by the current filter selection.
    private var filteredSuggestions: [RenameSuggestion] {
        switch filter {
        case .all:
            viewModel.suggestions
        case .pending:
            viewModel.pendingSuggestions
        case .accepted:
            viewModel.suggestions.filter { suggestion in
                let decision = viewModel.reviewDecisions[suggestion.id] ?? .pending
                if case .accepted = decision { return true }
                if case .edited = decision { return true }
                return false
            }
        case .rejected:
            viewModel.suggestions.filter { suggestion in
                let decision = viewModel.reviewDecisions[suggestion.id] ?? .pending
                if case .rejected = decision { return true }
                return false
            }
        }
    }

    /// Scrolls to the next unreviewed suggestion after the current one.
    ///
    /// Finds the first pending suggestion whose index in the full list is after
    /// the just-reviewed item. If no such suggestion exists (e.g., the current
    /// item was the last one), falls back to the first pending suggestion overall.
    private func scrollToNextPending(proxy: ScrollViewProxy, after currentID: UUID) {
        let pending = viewModel.pendingSuggestions
        guard !pending.isEmpty else { return }

        // Find the index of the just-reviewed item in the full list
        let allSuggestions = viewModel.suggestions
        let currentIndex = allSuggestions.firstIndex(where: { $0.id == currentID })

        // Pick the first pending suggestion after the current index
        let next: RenameSuggestion
        if let idx = currentIndex {
            if let afterCurrent = pending.first(where: { suggestion in
                guard let pendingIdx = allSuggestions.firstIndex(where: { $0.id == suggestion.id }) else { return false }
                return pendingIdx > idx
            }) {
                next = afterCurrent
            } else {
                // No pending items after current; wrap to first pending
                next = pending.first!
            }
        } else {
            next = pending.first!
        }

        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.3)) {
            proxy.scrollTo(next.id, anchor: .center)
        }
    }

    // MARK: - Empty State

    /// Empty state view with contextual message.
    @ViewBuilder
    private func emptyState(hasAnySuggestions: Bool) -> some View {
        VStack(spacing: 12) {
            Image(systemName: hasAnySuggestions ? "checkmark.circle" : "textformat.abc")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)

            Text(hasAnySuggestions
                ? "No suggestions match the current filter"
                : "No rename suggestions found")
                .font(.body)
                .foregroundStyle(.secondary)

            if hasAnySuggestions {
                Button("Show all suggestions") {
                    filter = .all
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Preview

#Preview("With Suggestions") {
    let vm = RenameViewModel()
    let suggestions = [
        RenameSuggestion(
            assetID: AssetID(rawValue: "a1"),
            originalFileName: "IMG_0019.jpg",
            suggestedName: "sunset-over-ocean.jpg",
            confidence: 0.92,
            analysisDescription: "Golden sunset over ocean waves"
        ),
        RenameSuggestion(
            assetID: AssetID(rawValue: "a2"),
            originalFileName: "IMG_0020.jpg",
            suggestedName: "mountain-sunrise.jpg",
            confidence: 0.85,
            analysisDescription: "Mountain landscape at dawn"
        ),
        RenameSuggestion(
            assetID: AssetID(rawValue: "a3"),
            originalFileName: "DSC_0042.jpg",
            suggestedName: "city-skyline-night.jpg",
            confidence: 0.78
        ),
    ]
    vm.loadSuggestions(suggestions)
    return RenameReviewView(viewModel: vm)
        .frame(width: 500, height: 600)
}

#Preview("Empty") {
    RenameReviewView(viewModel: RenameViewModel())
        .frame(width: 500, height: 400)
}
