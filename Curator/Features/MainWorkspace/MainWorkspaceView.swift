import SwiftUI

/// Agent workspace main view with NavigationSplitView three-column layout.
///
/// Implements UX-DR1 (three-column layout): sidebar (photo library) +
/// detail (Agent execution area) + bottom input area.
/// Uses NavigationSplitView for sidebar collapse/expand control.
/// Window state is persisted via @AppStorage through NavigationModel.
struct MainWorkspaceView: View {

    /// Photo library ViewModel providing photo grid data.
    @ObservedObject var photoViewModel: PhotoLibraryViewModel

    /// Application dependencies container.
    @ObservedObject var dependencies: AppDependencies

    /// Navigation state manager for sidebar visibility and active panel.
    @ObservedObject var navigationModel: NavigationModel

    /// Chat input ViewModel managing Agent instruction submission and execution state.
    @State private var chatInputViewModel: ChatInputViewModel

    /// Execution ViewModel observing AgentJob state for the execution panel.
    @State private var executionViewModel: AgentExecutionViewModel = AgentExecutionViewModel()

    /// Whether the session history sheet is visible.
    @State private var showSessionHistory = false

    init(
        photoViewModel: PhotoLibraryViewModel,
        dependencies: AppDependencies,
        navigationModel: NavigationModel
    ) {
        self.photoViewModel = photoViewModel
        self.dependencies = dependencies
        self.navigationModel = navigationModel
        // Initialize ChatInputViewModel with AppDependencies
        _chatInputViewModel = State(
            initialValue: ChatInputViewModel(dependencies: dependencies)
        )
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $navigationModel.columnVisibility) {
            // Sidebar: Photo library panel (collapsible)
            PhotoGridView(viewModel: photoViewModel)
                .navigationTitle("Photo Library")
        } detail: {
            // Detail: Agent execution area + bottom input bar
            VStack(spacing: 0) {
                // Main content area -- Quick commands or Agent execution panel
                if chatInputViewModel.quickCommandsVisible {
                    Spacer()
                    QuickCommandSuggestions(viewModel: chatInputViewModel)
                    Spacer()
                } else if chatInputViewModel.agentJob != nil {
                    AgentExecutionPanel(viewModel: executionViewModel)
                } else {
                    Spacer()
                }

                // Bottom fixed input bar
                AgentInputBar(viewModel: chatInputViewModel)
            }
            .navigationTitle("Curator")
        }
        .navigationSplitViewColumnWidth(
            min: 250, ideal: 350, max: 500
        )
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                // Photo library toggle -- sidebar visibility
                Button {
                    navigationModel.toggleSidebar()
                } label: {
                    Label("Photo Library", systemImage: "sidebar.leading")
                }

                // Session history button
                Button {
                    showSessionHistory = true
                } label: {
                    Label("Session History", systemImage: "clock.arrow.circlepath")
                }

                // Settings entry
                Button {
                    navigationModel.requestOpenSettings()
                } label: {
                    Label("Settings", systemImage: "gear")
                }
            }
        }
        .frame(
            minWidth: navigationModel.minimumWindowWidth,
            minHeight: navigationModel.minimumWindowHeight
        )
        .onAppear {
            executionViewModel.agentJob = chatInputViewModel.agentJob
            // Connect new session callback
            navigationModel.onNewSession = { [chatInputViewModel] in
                chatInputViewModel.createNewSession()
            }
        }
        .onChange(of: chatInputViewModel.agentJob) { _, _ in
            executionViewModel.agentJob = chatInputViewModel.agentJob
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResizeNotification)) { notification in
            guard let window = notification.object as? NSWindow else { return }
            navigationModel.windowWidth = Double(window.frame.width)
            navigationModel.windowHeight = Double(window.frame.height)
        }
        .onReceive(NotificationCenter.default.publisher(for: .newSessionRequested)) { _ in
            chatInputViewModel.createNewSession()
        }
        .sheet(isPresented: $showSessionHistory) {
            if let sessionManager = dependencies.sessionManager {
                SessionHistorySheet(
                    sessionManager: sessionManager,
                    onSessionSelected: { session in
                        showSessionHistory = false
                        // Restore session through SessionManager to update active state
                        _Concurrency.Task {
                            if let current = chatInputViewModel.currentSession {
                                try? await sessionManager.saveSession(current)
                            }
                            _ = try? await sessionManager.switchToSession(session.id)
                        }
                        chatInputViewModel.currentSession = session
                        chatInputViewModel.agentJob = nil
                        chatInputViewModel.isSubmitting = false
                    }
                )
            }
        }
    }
}

#Preview {
    MainWorkspaceView(
        photoViewModel: PhotoLibraryViewModel(repository: nil),
        dependencies: AppDependencies(),
        navigationModel: NavigationModel()
    )
}
