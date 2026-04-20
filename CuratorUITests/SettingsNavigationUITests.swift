@preconcurrency import XCTest

/// UI tests for Story 2.5 — Settings window with NavigationSplitView layout.
///
/// Verifies sidebar category navigation between Provider Config,
/// Model Selection, and Cost Tracking detail views.
final class SettingsNavigationUITests: CuratorUITestBase {

    private var didOpenSettings = false

    override func setUp() {
        super.setUp()
        launchApp(mockPhotos: true)
    }

    private func openSettingsIfNeeded() {
        guard !didOpenSettings else { return }
        XCTAssertTrue(app.staticTexts["Welcome to Curator"].waitForExistence(timeout: 10))

        app.menuBars.menuBarItems["Curator"].tap()
        let settingsMenuItem = app.menuBars.menuBarItems["Curator"].menus.menuItems["Settings…"]
        if settingsMenuItem.waitForExistence(timeout: 3) {
            settingsMenuItem.tap()
        } else {
            app.typeKey(",", modifierFlags: .command)
        }
        let _ = app.staticTexts["Settings"].waitForExistence(timeout: 10)
        didOpenSettings = true
    }

    // MARK: - Sidebar Categories

    /// [P0] Provider Config category is selectable in sidebar.
    func testProviderConfigCategoryExists() {
        openSettingsIfNeeded()
        XCTAssertTrue(app.staticTexts["Provider Config"].waitForExistence(timeout: 5),
                      "Provider Config sidebar item should exist")
    }

    /// [P0] Model Selection category is selectable in sidebar.
    func testModelSelectionCategoryExists() {
        openSettingsIfNeeded()
        XCTAssertTrue(app.staticTexts["Model Selection"].waitForExistence(timeout: 5),
                      "Model Selection sidebar item should exist")
    }

    /// [P0] Cost Tracking category is selectable in sidebar.
    func testCostTrackingCategoryExists() {
        openSettingsIfNeeded()
        XCTAssertTrue(app.staticTexts["Cost Tracking"].waitForExistence(timeout: 5),
                      "Cost Tracking sidebar item should exist")
    }

    /// [P1] Tapping Model Selection shows model detail view.
    func testTappingModelSelectionShowsModelView() {
        openSettingsIfNeeded()
        app.staticTexts["Model Selection"].tap()
        XCTAssertTrue(app.staticTexts["Available Models & Pricing"].waitForExistence(timeout: 5),
                      "Model Selection detail should show pricing section")
    }

    /// [P1] Tapping Cost Tracking shows cost tracking panel.
    func testTappingCostTrackingShowsCostPanel() {
        openSettingsIfNeeded()
        app.staticTexts["Cost Tracking"].tap()
        XCTAssertTrue(app.staticTexts["Monthly Summary"].waitForExistence(timeout: 10),
                      "Cost Tracking detail should show monthly summary section")
    }

    /// [P1] Tapping Provider Config shows provider form.
    func testTappingProviderConfigShowsProviderForm() {
        openSettingsIfNeeded()
        app.staticTexts["Provider Config"].tap()
        XCTAssertTrue(app.staticTexts["Primary Provider"].waitForExistence(timeout: 5),
                      "Provider Config detail should show primary provider section")
    }
}
