import SwiftUI

/// Main panel view for Agent execution progress and results.
///
/// Orchestrates StepCardView list, progress summary, reasoning bubbles,
/// and state-dependent rendering based on `ExecutionDisplayState`.
///
/// Implements AC1-AC5: step card rendering, reasoning bubbles, real-time updates,
/// ViewModel state management, and MainWorkspaceView integration.
struct AgentExecutionPanel: View {

    /// The ViewModel providing execution state.
    @Bindable var viewModel: AgentExecutionViewModel

    /// Whether the app is in read-only mode (passed to StepCardView for annotations).
    var isReadOnlyMode: Bool = false

    /// Deduplication review ViewModel for review state display.
    var deduplicationViewModel: DeduplicationViewModel?

    /// Confirmation ViewModel for batch operation workflow.
    var confirmationViewModel: ConfirmationViewModel?

    /// Undo manager ViewModel for rollback support.
    var undoManager: UndoManagerViewModel?

    /// Result summary ViewModel for displaying full result summary after execution.
    var resultSummaryViewModel: ResultSummaryViewModel?

    /// Whether to show the full result summary instead of the step list.
    var showResultSummary: Bool = false

    /// Callback when the user clicks "Done" on the result summary.
    var onResultSummaryDone: (() -> Void)?

    /// Callback when the user clicks "Undo" on the result summary.
    var onResultSummaryUndo: (() -> Void)?

    /// Whether the user prefers reduced motion.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            // Main content area
            mainContent

            Divider()

            // Bottom summary area
            summaryArea
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Main Content

    /// State-dependent main content area.
    @ViewBuilder
    private var mainContent: some View {
        if showResultSummary, let summaryVM = resultSummaryViewModel {
            // AC6: Full AgentResultSummaryView replaces step list
            ScrollView {
                AgentResultSummaryView(
                    viewModel: summaryVM,
                    onDone: { onResultSummaryDone?() },
                    onUndo: { onResultSummaryUndo?() }
                )
            }
        } else {
            stateDependentContent
        }
    }

    /// State-dependent content for non-summary states.
    @ViewBuilder
    private var stateDependentContent: some View {
        switch viewModel.displayState {
        case .empty:
            Spacer()

        case .executing:
            stepList

        case .review:
            if let dedupVM = deduplicationViewModel, !dedupVM.groups.isEmpty {
                DuplicateReviewView(
                    viewModel: dedupVM,
                    confirmationViewModel: confirmationViewModel,
                    undoManager: undoManager
                )
            } else {
                stepList
            }

        case .completed, .failed, .cancelled:
            stepList
        }
    }

    // MARK: - Step List

    /// Scrollable list of step cards with auto-scroll to latest step.
    @ViewBuilder
    private var stepList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(viewModel.steps) { step in
                        StepCardView(step: step, isReadOnlyMode: isReadOnlyMode)
                            .id(step.id)
                            .transition(
                                .asymmetric(
                                    insertion: .opacity.combined(with: .move(edge: .bottom)),
                                    removal: .opacity
                                )
                            )
                    }
                }
                .padding()
            }
            .onChange(of: viewModel.steps.count) { _, _ in
                scrollToLatestStep(proxy: proxy)
            }
            .onChange(of: reasoningMessageCount) { _, _ in
                scrollToLatestStep(proxy: proxy)
            }
        }
    }

    /// Total count of reasoning messages across all steps, used to trigger
    /// auto-scroll when new streaming reasoning content arrives.
    private var reasoningMessageCount: Int {
        viewModel.steps.reduce(0) { $0 + $1.reasoningMessages.count }
    }

    /// Scrolls to the latest (last) step in the list.
    private func scrollToLatestStep(proxy: ScrollViewProxy) {
        if let lastStep = viewModel.steps.last {
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.3)) {
                proxy.scrollTo(lastStep.id, anchor: .bottom)
            }
        }
    }

    // MARK: - Summary Area

    /// Bottom summary area showing progress or result information.
    @ViewBuilder
    private var summaryArea: some View {
        VStack(spacing: 8) {
            switch viewModel.displayState {
            case .executing:
                executingSummary

            case .completed:
                completedSummary

            case .failed:
                failedSummary

            case .cancelled:
                cancelledSummary

            case .review:
                reviewSummary

            case .empty:
                EmptyView()
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.bar)
    }

    @ViewBuilder
    private var executingSummary: some View {
        let completed = viewModel.steps.filter { $0.status == .completed }.count
        let total = viewModel.steps.count
        HStack {
            ProgressView()
                .controlSize(.small)
            Text("Processing step \(completed)/\(total)")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var completedSummary: some View {
        VStack(spacing: 4) {
            if let summary = viewModel.formattedSummary {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text(summary)
                        .font(.callout)
                }
            }
            if let duration = viewModel.formattedDuration {
                Text("Duration: \(duration)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var failedSummary: some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
                Text(viewModel.errorMessage ?? "Execution failed. Please try again.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var cancelledSummary: some View {
        HStack(spacing: 6) {
            Image(systemName: "pause.circle.fill")
                .foregroundStyle(.secondary)
            Text("Execution cancelled.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var reviewSummary: some View {
        HStack(spacing: 6) {
            Image(systemName: "eye.fill")
                .foregroundStyle(Color.accentColor)
            if let dedupVM = deduplicationViewModel, !dedupVM.groups.isEmpty {
                Text("Review \(dedupVM.totalGroups) duplicate groups — \(dedupVM.reviewedCount) reviewed")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                Text("Review results before applying.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview("Executing") {
    let vm = AgentExecutionViewModel()
    let job = AgentJob()
    job.start()
    job.emit(.planGenerated(steps: [
        AgentStep(id: UUID(), title: "Scan Library", status: .completed,
                  completedCount: 15000, totalCount: 15000, reasoningMessages: []),
        AgentStep(id: UUID(), title: "Find Duplicates", status: .running,
                  completedCount: 1200, totalCount: 15000,
                  reasoningMessages: ["Comparing visual features..."]),
    ]))
    vm.agentJob = job
    return AgentExecutionPanel(viewModel: vm, deduplicationViewModel: nil)
        .frame(width: 500, height: 400)
}

#Preview("Completed") {
    let vm = AgentExecutionViewModel()
    let job = AgentJob()
    job.start()
    job.emit(.planGenerated(steps: [
        AgentStep(id: UUID(), title: "Scan Library", status: .completed,
                  completedCount: 15000, totalCount: 15000, reasoningMessages: []),
    ]))
    job.emit(.executionCompleted(summary: ExecutionSummary(
        totalSteps: 1, completedSteps: 1, failedSteps: 0,
        duration: 45.0, message: "Found 120 duplicates"
    )))
    vm.agentJob = job
    return AgentExecutionPanel(viewModel: vm, deduplicationViewModel: nil)
        .frame(width: 500, height: 400)
}
