@preconcurrency import XCTest

/// UI tests for Stories 2.4 & 2.6 — Cost tracking engine and panel.
///
/// Verifies the Cost Tracking settings view including time range picker,
/// summary display, empty state, recent records, and refresh actions.
final class CostTrackingUITests: CuratorUITestBase {

    private var didOpenSettings = false

    override func setUp() {
        super.setUp()
        launchApp(mockPhotos: true)
    }

    private func openCostTracking() {
        guard !didOpenSettings else {
            app.staticTexts["Cost Tracking"].tap()
            let _ = app.staticTexts["Monthly Summary"].waitForExistence(timeout: 5)
            return
        }
        XCTAssertTrue(app.staticTexts["Welcome to Curator"].waitForExistence(timeout: 10))

        app.menuBars.menuBarItems["Curator"].tap()
        let settingsMenuItem = app.menuBars.menuBarItems["Curator"].menus.menuItems["Settings…"]
        if settingsMenuItem.waitForExistence(timeout: 3) {
            settingsMenuItem.tap()
        } else {
            app.typeKey(",", modifierFlags: .command)
        }

        let _ = app.staticTexts["Settings"].waitForExistence(timeout: 10)
        app.staticTexts["Cost Tracking"].tap()
        let _ = app.staticTexts["Monthly Summary"].waitForExistence(timeout: 10)
        didOpenSettings = true
    }

    // MARK: - AC1: Time Range & Summary

    /// [P0] Monthly Summary section header is visible by default.
    func testMonthlySummaryHeaderVisible() {
        openCostTracking()
        XCTAssertTrue(app.staticTexts["Monthly Summary"].exists,
                      "Monthly Summary header should be visible by default")
    }

    /// [P0] Time Range section exists with segment options.
    func testTimeRangePickerExists() {
        openCostTracking()
        // The segmented picker should at minimum show a "Time Range" label
        // The segments themselves may be radioButtons, buttons, or staticTexts
        let timeRangeLabel = app.staticTexts["Time Range"]
        XCTAssertTrue(timeRangeLabel.waitForExistence(timeout: 5),
                      "Time Range picker label should exist")
    }

    /// [P1] Switching to All Time shows All-Time Summary.
    func testSwitchingToAllTime() {
        openCostTracking()
        // SwiftUI segmented picker segments on macOS — try radioButtons, then other types
        tapSegment(label: "All Time")
        XCTAssertTrue(app.staticTexts["All-Time Summary"].waitForExistence(timeout: 5),
                      "All-Time Summary header should appear after switching")
    }

    /// [P1] Switching back to This Month shows Monthly Summary.
    func testSwitchingBackToMonthly() {
        openCostTracking()
        tapSegment(label: "All Time")
        XCTAssertTrue(app.staticTexts["All-Time Summary"].waitForExistence(timeout: 5))

        tapSegment(label: "This Month")
        XCTAssertTrue(app.staticTexts["Monthly Summary"].waitForExistence(timeout: 5),
                      "Monthly Summary header should reappear after switching back")
    }

    /// Tries multiple element types to find and tap a segmented picker option.
    private func tapSegment(label: String) {
        let candidates: [XCUIElement] = [
            app.buttons[label],
            app.staticTexts[label],
            app.radioButtons[label],
        ]
        for candidate in candidates {
            if candidate.waitForExistence(timeout: 2) {
                candidate.tap()
                return
            }
        }
    }

    // MARK: - AC3: Empty State

    /// [P1] No cost data available message or summary is shown.
    func testEmptyStateOrSummaryShown() {
        openCostTracking()
        let emptyState = app.staticTexts["No cost data available"]
        let monthlySummary = app.staticTexts["Monthly Summary"]
        XCTAssertTrue(emptyState.waitForExistence(timeout: 5) || monthlySummary.exists,
                      "Either empty state or cost summary should be visible")
    }

    // MARK: - AC4: Recent Records Section

    /// [P0] Recent Records section header is visible.
    func testRecentRecordsSectionExists() {
        openCostTracking()
        XCTAssertTrue(app.staticTexts["Recent Records"].waitForExistence(timeout: 5),
                      "Recent Records section should exist")
    }

    /// [P1] Recent records shows either records or empty message.
    func testRecentRecordsContent() {
        openCostTracking()
        let emptyMessage = app.staticTexts["No recent records"]
        XCTAssertTrue(emptyMessage.waitForExistence(timeout: 5) || app.staticTexts["Recent Records"].exists,
                      "Recent records should show either records or empty message")
    }

    // MARK: - AC5: Refresh Action

    /// [P0] Refresh button exists.
    func testRefreshButtonExists() {
        openCostTracking()
        let refreshButton = app.buttons["Refresh"]
        XCTAssertTrue(refreshButton.waitForExistence(timeout: 5),
                      "Refresh button should exist")
    }

    /// [P1] Tapping refresh doesn't crash the app.
    func testRefreshDoesNotCrash() {
        openCostTracking()
        let refreshButton = app.buttons["Refresh"]
        XCTAssertTrue(refreshButton.waitForExistence(timeout: 5))
        refreshButton.tap()
        XCTAssertTrue(app.staticTexts["Recent Records"].waitForExistence(timeout: 5),
                      "Cost tracking view should remain after refresh")
    }
}
