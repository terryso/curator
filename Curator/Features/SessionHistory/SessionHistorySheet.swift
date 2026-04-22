import SwiftUI

/// Sheet displaying the list of past conversation sessions.
///
/// Shows sessions sorted by most recent update, with title, relative time,
/// and active status. Supports tap-to-restore and swipe-to-delete.
struct SessionHistorySheet: View {

    /// The ViewModel managing session list state.
    @State private var viewModel: SessionHistoryViewModel

    /// Callback invoked when the user selects a session to restore.
    let onSessionSelected: (Session) -> Void

    /// Environment dismiss action for closing the sheet.
    @Environment(\.dismiss) private var dismiss

    init(
        sessionManager: SessionManagerProtocol,
        onSessionSelected: @escaping (Session) -> Void
    ) {
        _viewModel = State(
            initialValue: SessionHistoryViewModel(sessionManager: sessionManager)
        )
        self.onSessionSelected = onSessionSelected
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            sheetHeader

            Divider()

            // Content
            if viewModel.isLoading {
                ProgressView("Loading sessions...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.sessions.isEmpty {
                emptyStateView
            } else {
                sessionListView
            }

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
            }
        }
        .frame(minWidth: 500, idealWidth: 600, minHeight: 350, idealHeight: 400)
        .task {
            await viewModel.loadSessions()
        }
    }

    // MARK: - Subviews

    private var sheetHeader: some View {
        HStack {
            Text("Session History")
                .font(.headline)
            Spacer()
            Button("Close") {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)
        }
        .padding(16)
    }

    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
            Text("No session history yet")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var sessionListView: some View {
        List {
            ForEach(viewModel.sessions, id: \.id) { session in
                SessionRowView(session: session)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onSessionSelected(session)
                        dismiss()
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            _Concurrency.Task {
                                await viewModel.deleteSession(session.id)
                            }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
        }
        .listStyle(.sidebar)
    }
}

/// A single row in the session history list.
struct SessionRowView: View {
    let session: Session

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(session.title)
                    .font(.headline)
                    .lineLimit(1)
                Text(session.updatedAt, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if session.isActive {
                Text("Active")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.green)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(.green.opacity(0.1), in: Capsule())
            }
        }
        .padding(.vertical, 4)
    }
}
