import SwiftUI

/// Active panel in the main workspace.
///
/// Defines which content area is currently focused.
/// CaseIterable for iteration in toolbar / navigation scenarios.
enum ActivePanel: String, CaseIterable, Sendable {
    case agentWorkspace
    case photoLibrary
}

/// Navigation state manager for the main workspace.
///
/// Manages sidebar visibility, active panel state, and window dimension persistence.
/// Marked @MainActor for safe use with SwiftUI views.
/// Window state is persisted via @AppStorage (UserDefaults).
@MainActor
final class NavigationModel: ObservableObject {

    // MARK: - Published State

    @Published var sidebarVisible: Bool

    @Published var activePanel: ActivePanel = .agentWorkspace

    @Published var columnVisibility: NavigationSplitViewVisibility

    @AppStorage("windowWidth") var windowWidth: Double = 1200.0
    @AppStorage("windowHeight") var windowHeight: Double = 800.0
    @AppStorage("sidebarCollapsed") var sidebarCollapsed: Bool = false

    // MARK: - Initialization

    init() {
        // Read persisted sidebar collapsed state to initialize sidebarVisible
        let collapsed = UserDefaults.standard.bool(forKey: "sidebarCollapsed")
        self.sidebarVisible = !collapsed
        self.columnVisibility = collapsed ? .detailOnly : .all
    }

    // MARK: - Sidebar Visibility

    /// Current NavigationSplitViewVisibility derived from sidebarVisible state.
    var sidebarVisibility: NavigationSplitViewVisibility {
        sidebarVisible ? .all : .detailOnly
    }

    // MARK: - Minimum Dimensions

    let minimumWindowWidth: Double = 900.0
    let minimumWindowHeight: Double = 600.0

    /// Effective window width, clamped to minimum.
    var effectiveWindowWidth: Double {
        max(windowWidth, minimumWindowWidth)
    }

    /// Effective window height, clamped to minimum.
    var effectiveWindowHeight: Double {
        max(windowHeight, minimumWindowHeight)
    }

    // MARK: - Sidebar Actions

    /// Toggle sidebar visibility.
    func toggleSidebar() {
        sidebarVisible.toggle()
        sidebarCollapsed = !sidebarVisible
        columnVisibility = sidebarVisible ? .all : .detailOnly
    }

    /// Show the sidebar.
    func showSidebar() {
        sidebarVisible = true
        sidebarCollapsed = false
        columnVisibility = .all
    }

    /// Hide the sidebar.
    func hideSidebar() {
        sidebarVisible = false
        sidebarCollapsed = true
        columnVisibility = .detailOnly
    }

    // MARK: - Panel Actions

    /// Set the currently active panel.
    func setActivePanel(_ panel: ActivePanel) {
        activePanel = panel
    }

    // MARK: - Toolbar Actions (Placeholders)

    /// Create a new session (placeholder for Cmd+N).
    /// Story 3.5 will implement actual session management.
    func newSession() {
        // Placeholder — no-op
    }

    /// Request to open Settings window (placeholder for Cmd+,).
    /// Opens via NSApp.sendAction for Settings scene.
    func requestOpenSettings() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }
}
