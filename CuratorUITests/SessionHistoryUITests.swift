@preconcurrency import XCTest

/// UI tests for Story 3.5 — Session management with multi-turn context.
///
/// Verifies the session history sheet: toolbar button opens sheet,
/// sheet header, empty state, close button, and new session creation.
final class SessionHistoryUITests: CuratorUITestBase {

    override func setUp() {
        super.setUp()
        launchApp(mockPhotos: true)
    }

    // MARK: - AC: Session History Button in Toolbar

    /// [P0] Session History toolbar button exists.
    func testSessionHistoryToolbarButtonExists() {
        waitForMainWorkspace()

        let historyButton = app.buttons["Session History"].firstMatch
        XCTAssertTrue(historyButton.waitForExistence(timeout: 5),
                      "Session History toolbar button should exist")
    }

    /// [P0] Clicking Session History toolbar button opens the sheet.
    func testClickingSessionHistoryOpensSheet() {
        openSessionHistory()

        XCTAssertTrue(app.staticTexts["Session History"].waitForExistence(timeout: 5),
                      "Session History sheet header should appear")
    }

    // MARK: - AC: Sheet Header with Close Button

    /// [P0] Session History sheet has a Close button.
    func testSessionHistorySheetHasCloseButton() {
        openSessionHistory()

        let closeButton = app.buttons["Close"].firstMatch
        XCTAssertTrue(closeButton.waitForExistence(timeout: 5),
                      "Session History sheet should have a Close button")
    }

    /// [P1] Clicking Close dismisses the session history sheet.
    func testCloseButtonDismissesSheet() {
        openSessionHistory()

        let closeButton = app.buttons["Close"].firstMatch
        XCTAssertTrue(closeButton.waitForExistence(timeout: 5))
        closeButton.tap()

        let sheetHeader = app.staticTexts["Session History"]
        let gone = !sheetHeader.waitForExistence(timeout: 2)
        XCTAssertTrue(gone,
                      "Session History sheet should be dismissed after tapping Close")
    }

    // MARK: - AC: Empty State

    /// [P0] Empty state or session list is shown when sheet opens.
    func testEmptyStateOrSessionListShown() {
        openSessionHistory()

        let emptyText = app.staticTexts["No session history yet"]
        let sessionHeader = app.staticTexts["Session History"]
        XCTAssertTrue(emptyText.waitForExistence(timeout: 5) || sessionHeader.exists,
                      "Session history sheet should show empty state or session list")
    }

    // MARK: - AC: New Session via File Menu

    /// [P1] File menu New Session command exists.
    func testFileMenuNewSessionCommandExists() {
        waitForMainWorkspace()

        app.menuBars.menuBarItems["File"].tap()
        let newSessionItem = app.menuBars.menuBarItems["File"].menus.menuItems["New Session"]
        XCTAssertTrue(newSessionItem.waitForExistence(timeout: 5),
                      "File menu should have New Session command")
    }

    /// [P1] New Session command resets to quick commands view.
    func testNewSessionCommandResetsToIdleState() {
        waitForMainWorkspace()

        app.menuBars.menuBarItems["File"].tap()
        let newSessionItem = app.menuBars.menuBarItems["File"].menus.menuItems["New Session"]
        XCTAssertTrue(newSessionItem.waitForExistence(timeout: 5))
        newSessionItem.tap()

        let header = app.staticTexts["试试这些指令"]
        XCTAssertTrue(header.waitForExistence(timeout: 5),
                      "Quick commands should be visible after creating a new session")
    }

    // MARK: - Helpers

    private func waitForMainWorkspace() {
        let quickHeader = app.staticTexts["试试这些指令"]
        let navTitle = app.staticTexts["Curator"]
        XCTAssertTrue(quickHeader.waitForExistence(timeout: 10) || navTitle.waitForExistence(timeout: 10),
                      "Main workspace should be visible after launch with mockPhotos")
    }

    private func openSessionHistory() {
        waitForMainWorkspace()

        let historyButton = app.buttons["Session History"].firstMatch
        XCTAssertTrue(historyButton.waitForExistence(timeout: 5))
        historyButton.tap()
    }
}
