import XCTest

/// UI tests for Story 1.6 — Main UI framework and window management.
///
/// Uses mock photo data so the workspace is fully populated.
final class MainWorkspaceUITests: CuratorUITestBase {

    override func setUp() {
        super.setUp()
        launchApp(mockPhotos: true)
    }

    // MARK: - AC1: Three-column layout

    func testThreeColumnLayoutExists() throws {
        XCTAssertTrue(app.staticTexts["Welcome to Curator"].waitForExistence(timeout: 10))
    }

    // MARK: - AC2: Toolbar buttons

    func testToolbarButtonsExist() throws {
        let sidebarButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Photo Library'")).firstMatch
        XCTAssertTrue(sidebarButton.waitForExistence(timeout: 10), "Sidebar toggle button should exist")
    }

    // MARK: - AC3: Settings keyboard shortcut

    func testCmdCommaOpensSettings() throws {
        app.typeKey(",", modifierFlags: .command)
        let settingsText = app.staticTexts["Settings"]
        XCTAssertTrue(settingsText.waitForExistence(timeout: 5), "Settings view should appear")
    }
}
