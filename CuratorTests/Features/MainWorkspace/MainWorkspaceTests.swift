import XCTest
@testable import Curator

/// ATDD Tests for Story 1.6 - Main UI Framework and Window Management
///
/// Tests verify:
/// - NavigationModel manages sidebar visibility state correctly (toggle, @AppStorage)
/// - NavigationModel manages active panel state correctly (ActivePanel enum)
/// - NavigationModel is @MainActor + ObservableObject
/// - @AppStorage persistence for window dimensions and sidebar state
/// - Toolbar action methods exist and modify state
/// - NavigationSplitView visibility raw value round-trips
/// - Minimum window width constraint (900pt)
///
/// All tests are unit-level (no UI rendering, no real PhotoKit calls).
/// RED PHASE: Tests compile against stubs and fail until NavigationModel is implemented.
final class MainWorkspaceTests: XCTestCase {

    // MARK: - Test Helpers

    /// Creates a fresh NavigationModel instance for testing.
    /// Clears any @AppStorage values before each test to ensure isolation.
    @MainActor
    private func makeNavigationModel() -> NavigationModel {
        NavigationModel()
    }

    /// Clears all @AppStorage keys used by MainWorkspace features.
    private func clearAppStorage() {
        UserDefaults.standard.removeObject(forKey: "windowWidth")
        UserDefaults.standard.removeObject(forKey: "windowHeight")
        UserDefaults.standard.removeObject(forKey: "sidebarCollapsed")
        UserDefaults.standard.removeObject(forKey: "sidebarVisibility")
    }

    override func setUp() {
        super.setUp()
        clearAppStorage()
    }

    override func tearDown() {
        clearAppStorage()
        super.tearDown()
    }

    // MARK: - AC1: NavigationSplitView Three-Column Layout

    /// [P0] NavigationModel exists as @MainActor ObservableObject
    @MainActor
    func testNavigationModelExists() async throws {
        let model = makeNavigationModel()
        XCTAssertNotNil(model)

        // Verify ObservableObject conformance
        let _ = model.objectWillChange
    }

    /// [P0] NavigationModel initializes with sidebar visible
    @MainActor
    func testNavigationModelInitializesWithSidebarVisible() async throws {
        let model = makeNavigationModel()

        XCTAssertTrue(model.sidebarVisible,
            "NavigationModel should initialize with sidebar visible")
    }

    /// [P0] ActivePanel enum exists with required cases
    @MainActor
    func testActivePanelEnumHasRequiredCases() async throws {
        // ActivePanel should have at least: agentWorkspace, photoLibrary
        let _: ActivePanel = .agentWorkspace
        let _: ActivePanel = .photoLibrary

        // Verify CaseIterable for iteration
        XCTAssertGreaterThanOrEqual(ActivePanel.allCases.count, 2,
            "ActivePanel should have at least 2 cases")
    }

    /// [P0] NavigationModel initializes with agentWorkspace as active panel
    @MainActor
    func testNavigationModelInitializesWithAgentWorkspaceActive() async throws {
        let model = makeNavigationModel()

        XCTAssertEqual(model.activePanel, .agentWorkspace,
            "NavigationModel should initialize with agentWorkspace as active panel")
    }

    // MARK: - AC1: Sidebar Toggle

    /// [P0] toggleSidebar flips sidebarVisible from true to false
    @MainActor
    func testToggleSidebarFromVisibleToHidden() async throws {
        let model = makeNavigationModel()
        XCTAssertTrue(model.sidebarVisible)

        model.toggleSidebar()

        XCTAssertFalse(model.sidebarVisible,
            "toggleSidebar should flip sidebarVisible to false")
    }

    /// [P0] toggleSidebar flips sidebarVisible from false to true
    @MainActor
    func testToggleSidebarFromHiddenToVisible() async throws {
        let model = makeNavigationModel()
        model.toggleSidebar() // now hidden
        XCTAssertFalse(model.sidebarVisible)

        model.toggleSidebar()

        XCTAssertTrue(model.sidebarVisible,
            "toggleSidebar should flip sidebarVisible back to true")
    }

    /// [P1] showSidebar sets sidebarVisible to true
    @MainActor
    func testShowSidebarSetsVisibleToTrue() async throws {
        let model = makeNavigationModel()
        model.toggleSidebar() // now hidden
        XCTAssertFalse(model.sidebarVisible)

        model.showSidebar()

        XCTAssertTrue(model.sidebarVisible,
            "showSidebar should set sidebarVisible to true")
    }

    /// [P1] hideSidebar sets sidebarVisible to false
    @MainActor
    func testHideSidebarSetsVisibleToFalse() async throws {
        let model = makeNavigationModel()
        XCTAssertTrue(model.sidebarVisible)

        model.hideSidebar()

        XCTAssertFalse(model.sidebarVisible,
            "hideSidebar should set sidebarVisible to false")
    }

    /// [P1] showSidebar is idempotent (calling when already visible is no-op)
    @MainActor
    func testShowSidebarIsIdempotent() async throws {
        let model = makeNavigationModel()
        XCTAssertTrue(model.sidebarVisible)

        model.showSidebar()

        XCTAssertTrue(model.sidebarVisible,
            "showSidebar should remain true when already visible")
    }

    // MARK: - AC1: Active Panel Switching

    /// [P0] setActivePanel changes the active panel state
    @MainActor
    func testSetActivePanelChangesState() async throws {
        let model = makeNavigationModel()
        XCTAssertEqual(model.activePanel, .agentWorkspace)

        model.setActivePanel(.photoLibrary)

        XCTAssertEqual(model.activePanel, .photoLibrary,
            "setActivePanel should change to photoLibrary")
    }

    /// [P1] setActivePanel to same panel is no-op
    @MainActor
    func testSetActivePanelToSameIsNoOp() async throws {
        let model = makeNavigationModel()
        XCTAssertEqual(model.activePanel, .agentWorkspace)

        model.setActivePanel(.agentWorkspace)

        XCTAssertEqual(model.activePanel, .agentWorkspace,
            "Setting same panel should be no-op")
    }

    // MARK: - AC2: Window State Persistence via @AppStorage

    /// [P0] NavigationModel reads windowWidth from @AppStorage
    @MainActor
    func testNavigationModelReadsWindowWidthFromAppStorage() async throws {
        UserDefaults.standard.set(1400.0, forKey: "windowWidth")

        let model = makeNavigationModel()

        XCTAssertEqual(model.windowWidth, 1400.0,
            "NavigationModel should read windowWidth from @AppStorage")
    }

    /// [P0] NavigationModel reads windowHeight from @AppStorage
    @MainActor
    func testNavigationModelReadsWindowHeightFromAppStorage() async throws {
        UserDefaults.standard.set(900.0, forKey: "windowHeight")

        let model = makeNavigationModel()

        XCTAssertEqual(model.windowHeight, 900.0,
            "NavigationModel should read windowHeight from @AppStorage")
    }

    /// [P0] NavigationModel defaults window dimensions when no @AppStorage values
    @MainActor
    func testNavigationModelDefaultsWindowDimensions() async throws {
        // clearAppStorage already called in setUp
        let model = makeNavigationModel()

        XCTAssertEqual(model.windowWidth, 1200.0,
            "Default windowWidth should be 1200")
        XCTAssertEqual(model.windowHeight, 800.0,
            "Default windowHeight should be 800")
    }

    /// [P0] Updating windowWidth persists to UserDefaults
    @MainActor
    func testUpdatingWindowWidthPersistsToUserDefaults() async throws {
        let model = makeNavigationModel()

        model.windowWidth = 1500.0

        XCTAssertEqual(UserDefaults.standard.double(forKey: "windowWidth"), 1500.0,
            "windowWidth should persist to UserDefaults")
    }

    /// [P0] Updating windowHeight persists to UserDefaults
    @MainActor
    func testUpdatingWindowHeightPersistsToUserDefaults() async throws {
        let model = makeNavigationModel()

        model.windowHeight = 950.0

        XCTAssertEqual(UserDefaults.standard.double(forKey: "windowHeight"), 950.0,
            "windowHeight should persist to UserDefaults")
    }

    /// [P0] Sidebar collapsed state persists to @AppStorage
    @MainActor
    func testSidebarCollapsedStatePersistsToAppStorage() async throws {
        let model = makeNavigationModel()
        XCTAssertTrue(model.sidebarVisible)

        model.toggleSidebar() // collapse

        // The sidebarCollapsed key should reflect the collapsed state
        let collapsed = UserDefaults.standard.bool(forKey: "sidebarCollapsed")
        XCTAssertTrue(collapsed,
            "sidebarCollapsed should be true after toggling sidebar off")
    }

    /// [P1] Sidebar state restored from @AppStorage on init
    @MainActor
    func testSidebarStateRestoredFromAppStorageOnInit() async throws {
        // Pre-set collapsed state
        UserDefaults.standard.set(true, forKey: "sidebarCollapsed")

        let model = makeNavigationModel()

        XCTAssertFalse(model.sidebarVisible,
            "NavigationModel should restore sidebar hidden from @AppStorage")
    }

    /// [P1] Window dimensions restored across NavigationModel instances
    @MainActor
    func testWindowDimensionsRestoredAcrossInstances() async throws {
        let model1 = makeNavigationModel()
        model1.windowWidth = 1100.0
        model1.windowHeight = 750.0

        // Create a new instance -- should read persisted values
        let model2 = makeNavigationModel()

        XCTAssertEqual(model2.windowWidth, 1100.0,
            "New instance should restore persisted windowWidth")
        XCTAssertEqual(model2.windowHeight, 750.0,
            "New instance should restore persisted windowHeight")
    }

    // MARK: - AC2: NavigationSplitViewVisibility Raw Value

    /// [P1] NavigationSplitViewVisibility raw value round-trips correctly
    @MainActor
    func testSidebarVisibilityRawValueRoundTrip() async throws {
        let model = makeNavigationModel()

        // Initial visibility should be .automatic or .all
        let initialVisibility = model.sidebarVisibility
        XCTAssertNotNil(initialVisibility,
            "NavigationModel should expose sidebarVisibility")

        // After toggling sidebar off, visibility should reflect hidden state
        model.hideSidebar()
        let hiddenVisibility = model.sidebarVisibility

        // After showing sidebar, visibility should reflect visible state
        model.showSidebar()
        let shownVisibility = model.sidebarVisibility

        XCTAssertNotEqual(hiddenVisibility, shownVisibility,
            "Visibility should change when toggling sidebar")
    }

    // MARK: - AC3: Toolbar Actions

    /// [P0] toggleSidebar is exposed as a public method for toolbar button
    @MainActor
    func testToggleSidebarMethodExists() async throws {
        let model = makeNavigationModel()

        // Should be callable without error
        model.toggleSidebar()
        model.toggleSidebar()
    }

    /// [P1] newSession action exists (placeholder for Cmd+N)
    @MainActor
    func testNewSessionActionExists() async throws {
        let model = makeNavigationModel()

        // Should be callable without error (placeholder)
        model.newSession()
    }

    /// [P1] openSettings action exists (placeholder for Cmd+,)
    @MainActor
    func testOpenSettingsActionExists() async throws {
        let model = makeNavigationModel()

        // Should be callable without error (placeholder)
        // This opens Settings scene -- cannot easily verify in unit test
        model.requestOpenSettings()
    }

    // MARK: - AC3: Minimum Window Width

    /// [P0] minimumWindowWidth is 900pt
    @MainActor
    func testMinimumWindowWidthIs900() async throws {
        let model = makeNavigationModel()

        XCTAssertEqual(model.minimumWindowWidth, 900.0,
            "Minimum window width should be 900pt")
    }

    /// [P1] minimumWindowHeight is 600pt
    @MainActor
    func testMinimumWindowHeightIs600() async throws {
        let model = makeNavigationModel()

        XCTAssertEqual(model.minimumWindowHeight, 600.0,
            "Minimum window height should be 600pt")
    }

    // MARK: - Concurrency Safety

    /// [P0] NavigationModel is @MainActor (verified by compilation)
    @MainActor
    func testNavigationModelIsMainActor() async throws {
        let model = makeNavigationModel()

        // All property accesses are safe on @MainActor
        _ = model.sidebarVisible
        _ = model.activePanel
        _ = model.windowWidth
        _ = model.windowHeight
        _ = model.sidebarVisibility
        _ = model.minimumWindowWidth
        _ = model.minimumWindowHeight

        // All mutations are safe on @MainActor
        model.toggleSidebar()
        model.showSidebar()
        model.hideSidebar()
        model.setActivePanel(.photoLibrary)
        model.windowWidth = 1000.0
        model.windowHeight = 700.0
    }

    // MARK: - Edge Cases

    /// [P1] Window width clamped to minimum (900pt)
    @MainActor
    func testWindowWidthClampedToMinimum() async throws {
        let model = makeNavigationModel()

        model.windowWidth = 500.0

        XCTAssertGreaterThanOrEqual(model.effectiveWindowWidth, 900.0,
            "Effective window width should be clamped to minimum 900pt")
    }

    /// [P1] Window height clamped to minimum (600pt)
    @MainActor
    func testWindowHeightClampedToMinimum() async throws {
        let model = makeNavigationModel()

        model.windowHeight = 400.0

        XCTAssertGreaterThanOrEqual(model.effectiveWindowHeight, 600.0,
            "Effective window height should be clamped to minimum 600pt")
    }

    /// [P1] Rapid sidebar toggle maintains consistent state
    @MainActor
    func testRapidSidebarToggleMaintainsConsistentState() async throws {
        let model = makeNavigationModel()
        XCTAssertTrue(model.sidebarVisible)

        // Rapid toggle 10 times
        for _ in 0..<10 {
            model.toggleSidebar()
        }

        // After even number of toggles, should be back to visible
        XCTAssertTrue(model.sidebarVisible,
            "After even number of toggles, sidebar should be visible")
    }
}
