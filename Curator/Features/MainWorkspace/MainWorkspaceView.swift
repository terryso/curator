import SwiftUI

/// Agent workspace main view with NavigationSplitView three-column layout.
///
/// Implements UX-DR1 (three-column layout): sidebar (photo library) +
/// detail (Agent execution area) + bottom input area placeholder.
/// Uses NavigationSplitView for sidebar collapse/expand control.
/// Window state is persisted via @AppStorage through NavigationModel.
struct MainWorkspaceView: View {

    /// Photo library ViewModel providing photo grid data.
    @ObservedObject var photoViewModel: PhotoLibraryViewModel

    /// Application dependencies container.
    @ObservedObject var dependencies: AppDependencies

    /// Navigation state manager for sidebar visibility and active panel.
    @ObservedObject var navigationModel: NavigationModel

    var body: some View {
        NavigationSplitView(columnVisibility: $navigationModel.columnVisibility) {
            // Sidebar: Photo library panel (collapsible)
            PhotoGridView(viewModel: photoViewModel)
                .navigationTitle("Photo Library")
        } detail: {
            // Detail: Agent execution area + bottom input placeholder
            VStack(spacing: 0) {
                // Main content area — Agent execution / result display
                AgentContentAreaPlaceholder()

                Spacer()

                // Bottom fixed input area placeholder
                InputBarPlaceholder()
            }
            .navigationTitle("Curator")
        }
        .navigationSplitViewColumnWidth(
            min: 250, ideal: 350, max: 500
        )
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                // Photo library toggle — sidebar visibility
                Button {
                    navigationModel.toggleSidebar()
                } label: {
                    Label("Photo Library", systemImage: "sidebar.leading")
                }

                // Session history — placeholder (Story 3.5)
                Button {
                    // Placeholder: session history
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
    }
}

/// Bottom input bar placeholder view.
///
/// Simple placeholder for the Agent input area.
/// Story 3.3 will replace this with the full AgentInputBar component.
private struct InputBarPlaceholder: View {
    var body: some View {
        HStack {
            Text("Ask Curator to manage your photos...")
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
    }
}

#Preview {
    MainWorkspaceView(
        photoViewModel: PhotoLibraryViewModel(repository: nil),
        dependencies: AppDependencies(),
        navigationModel: NavigationModel()
    )
}
