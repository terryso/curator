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

    /// Whether the write permission prompt is visible.
    @State private var showWritePermissionPrompt = false

    /// Undo manager ViewModel — sourced from AppDependencies.
    var undoManager: UndoManagerViewModel? { dependencies.undoManagerViewModel }

    /// Permission state observing read/write mode — sourced from AppDependencies.
    var permissionState: PermissionState? { dependencies.permissionState }

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

                // Rollback progress indicator (overlaid at bottom)
                if let undoMgr = undoManager, undoMgr.isProcessing || undoMgr.lastError != nil {
                    RollbackProgressView(undoManager: undoMgr)
                        .padding(.bottom, 4)
                }
            }
            .navigationTitle("Curator")
        }
        .navigationSplitViewColumnWidth(
            min: 250, ideal: 350, max: 500
        )
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                // Undo/Redo button (visible when action available)
                if let undoMgr = undoManager, undoMgr.canPerformAction {
                    Button {
                        _Concurrency.Task {
                            await undoMgr.performUndoAction()
                        }
                    } label: {
                        Label(
                            undoMgr.availableAction == .undo ? "撤销" : "重做",
                            systemImage: undoMgr.availableAction == .undo ? "arrow.uturn.backward" : "arrow.uturn.forward"
                        )
                    }
                    .help(undoMgr.availableAction == .undo ? "撤销上次批量操作 (⌘Z)" : "重做上次撤销的操作 (⌘Z)")
                    .disabled(undoMgr.isProcessing)
                }

                // Hidden Cmd+Z shortcut button for keyboard binding
                Button("") {
                    _Concurrency.Task {
                        await undoManager?.performUndoAction()
                    }
                }
                .keyboardShortcut("z", modifiers: .command)
                .hidden()

                // Read-only mode indicator
                if let permState = permissionState, permState.isReadOnly {
                    Button {
                        showWritePermissionPrompt = true
                    } label: {
                        Label("只读模式", systemImage: "lock.fill")
                    }
                    .help("当前为只读模式，点击授权写入")
                    .tint(.secondary)
                }

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
            // Check for incomplete batches on startup (crash recovery, NFR17)
            _Concurrency.Task {
                await undoManager?.checkForIncompleteBatches()
                await undoManager?.refreshAvailableAction()
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
        .sheet(isPresented: $showWritePermissionPrompt) {
            WritePermissionPromptView(
                onGrant: {
                    showWritePermissionPrompt = false
                    _Concurrency.Task { @MainActor in
                        do {
                            _ = try await permissionState?.requestWritePermission()
                        } catch {
                            // Permission request failed — user stays in read-only mode
                            // The lock icon remains visible so they can retry
                        }
                    }
                },
                onCancel: {
                    showWritePermissionPrompt = false
                }
            )
        }
        .sheet(isPresented: Binding<Bool>(
            get: { undoManager?.showCrashRecoverySheet ?? false },
            set: { newValue in
                if !newValue {
                    _Concurrency.Task { await undoManager?.dismissCrashRecovery() }
                }
            }
        )) {
            if let undoMgr = undoManager {
                CrashRecoverySheet(undoManager: undoMgr)
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
