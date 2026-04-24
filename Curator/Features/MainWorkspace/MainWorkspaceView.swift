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

    /// Confirmation ViewModel managing the confirmation workflow for batch operations.
    var confirmationViewModel: ConfirmationViewModel? { dependencies.confirmationViewModel }

    /// Whether the session history sheet is visible.
    @State private var showSessionHistory = false

    /// Whether the write permission prompt is visible.
    @State private var showWritePermissionPrompt = false

    /// Undo manager ViewModel — sourced from AppDependencies.
    var undoManager: UndoManagerViewModel? { dependencies.undoManagerViewModel }

    /// Permission state observing read/write mode — sourced from AppDependencies.
    var permissionState: PermissionState? { dependencies.permissionState }

    /// Read-only mode ViewModel — sourced from AppDependencies.
    var readOnlyMode: ReadOnlyModeViewModel? { dependencies.readOnlyModeViewModel }

    /// Deduplication review ViewModel — sourced from AppDependencies.
    var deduplicationViewModel: DeduplicationViewModel { dependencies.deduplicationViewModel }

    /// Whether the saved operations sheet is visible.
    @State private var showSavedOperations = false

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
                // Read-only banner (shown when read-only and agent is active)
                if let readOnlyVM = readOnlyMode, readOnlyVM.isReadOnly,
                   chatInputViewModel.agentJob != nil {
                    ReadOnlyBannerView(
                        readOnlyMode: readOnlyVM,
                        onRequestWritePermission: {
                            showWritePermissionPrompt = true
                        }
                    )
                }

                // Main content area -- Quick commands or Agent execution panel
                if chatInputViewModel.quickCommandsVisible {
                    Spacer()
                    QuickCommandSuggestions(viewModel: chatInputViewModel)
                    Spacer()
                } else if chatInputViewModel.agentJob != nil {
                    AgentExecutionPanel(
                        viewModel: executionViewModel,
                        isReadOnlyMode: permissionState?.isReadOnly ?? false,
                        deduplicationViewModel: deduplicationViewModel
                    )
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

                // Confirmation workflow overlay
                if let confirmationVM = confirmationViewModel {
                    confirmationOverlay(for: confirmationVM)
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

                // Saved operations button (visible when there are saved operations)
                if let readOnlyVM = readOnlyMode, readOnlyVM.hasSavedOperations {
                    Button {
                        showSavedOperations = true
                    } label: {
                        Label("待执行操作", systemImage: "clock.arrow.circlepath")
                    }
                    .help("查看保存的待执行操作")
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
            // Trigger confirmation workflow when AgentJob enters .confirm state.
            // Note: Planned operations are supplied by the agent tool layer (Epic 5/6).
            // The .confirm state acts as the integration hook; actual operation list
            // will be passed by the tool that triggered the state transition.
        }
        .onChange(of: executionViewModel.displayState) { _, newState in
            // When entering review state with duplicate groups, load them into the dedup ViewModel.
            if newState == .review, let job = chatInputViewModel.agentJob {
                let groups = Self.extractDuplicateGroups(from: job)
                if !groups.isEmpty {
                    deduplicationViewModel.loadGroups(groups)
                }
            }
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
        .sheet(isPresented: $showSavedOperations) {
            if let readOnlyVM = readOnlyMode {
                SavedOperationsListView(
                    readOnlyMode: readOnlyVM,
                    onExecute: { savedSet in
                        showSavedOperations = false
                        // Re-present through confirmation flow
                        if let confirmationVM = confirmationViewModel {
                            let request = ConfirmationRequest(
                                operations: savedSet.operations,
                                confirmationLevel: ConfirmationLevel.forOperations(savedSet.operations),
                                summary: savedSet.summary
                            )
                            confirmationVM.presentConfirmation(request: request)
                        }
                    },
                    onDismiss: {
                        showSavedOperations = false
                    }
                )
            }
        }
        .sheet(isPresented: Binding<Bool>(
            get: { confirmationViewModel?.showSecondConfirmation ?? false },
            set: { _ in }
        )) {
            if let confirmationVM = confirmationViewModel, let request = confirmationVM.request {
                DestructiveConfirmationSheet(
                    request: request,
                    onConfirm: {
                        confirmationVM.confirmDestructive()
                    },
                    onCancel: {
                        confirmationVM.showSecondConfirmation = false
                    }
                )
            }
        }
    }

    // MARK: - Confirmation Overlay

    /// Overlay view for the confirmation workflow states.
    @ViewBuilder
    private func confirmationOverlay(for confirmationVM: ConfirmationViewModel) -> some View {
        if confirmationVM.needsPermissionUpgrade {
            PermissionUpgradeView(
                onGrant: {
                    confirmationVM.permissionGranted()
                },
                onDeny: {
                    confirmationVM.permissionDenied()
                }
            )
            .padding(.bottom, 4)
        } else if confirmationVM.showPermissionDenied {
            PermissionDeniedView(
                onDismiss: {
                    confirmationVM.cancel()
                }
            )
            .padding(.bottom, 4)
        } else if let request = confirmationVM.request {
            BatchConfirmationSummaryView(
                request: request,
                onExecute: {
                    confirmationVM.confirm()
                },
                onCancel: {
                    confirmationVM.cancel()
                }
            )
            .padding(.bottom, 4)
        } else if confirmationVM.isExecuting, let progress = confirmationVM.executionProgress {
            ExecutionProgressView(progress: progress)
                .padding(.bottom, 4)
        } else if let result = confirmationVM.executionResult {
            ExecutionResultView(
                result: result,
                onUndo: {
                    _Concurrency.Task {
                        guard let undoMgr = undoManager else { return }
                        await undoMgr.performUndoAction()
                    }
                    confirmationVM.cancel()
                },
                onDismiss: {
                    confirmationVM.cancel()
                }
            )
            .padding(.bottom, 4)
        }
    }

    // MARK: - Duplicate Group Extraction

    /// Extracts DuplicateGroup data from a completed AgentJob's step results.
    ///
    /// Searches step results for JSON-encoded DuplicateGroup arrays produced by
    /// AnalyzeDuplicatesTool. Returns empty array if no groups are found.
    private static func extractDuplicateGroups(from job: AgentJob) -> [DuplicateGroup] {
        var groups: [DuplicateGroup] = []
        let decoder = JSONDecoder()

        for step in job.steps {
            guard step.status == .completed else { continue }
            // Check step result data for duplicate groups
            // The data dictionary may contain a "duplicateGroups" key with JSON
            if let result = job.executionSummary,
               let message = result.message as String?,
               message.contains("duplicate") {
                // Try to parse groups from the execution summary message
                // This is a best-effort extraction; the primary path is through
                // the tool's stepCompleted event data
            }
        }

        // Primary extraction path: decode from step results if available
        // For now, return empty — actual group data flows through AgentEvent
        // stepCompleted result.data when AnalyzeDuplicatesTool runs.
        // The integration will be completed when AgentEvent carries typed data.
        return groups
    }
}

#Preview {
    MainWorkspaceView(
        photoViewModel: PhotoLibraryViewModel(repository: nil),
        dependencies: AppDependencies(),
        navigationModel: NavigationModel()
    )
}
