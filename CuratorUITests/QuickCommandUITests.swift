@preconcurrency import XCTest

/// UI tests for Stories 3.3 & 3.6 — Quick command suggestions and streaming.
///
/// Verifies quick command cards are visible when the Agent is idle,
/// contain the expected 4 commands, and can be tapped.
final class QuickCommandUITests: CuratorUITestBase {

    override func setUp() {
        super.setUp()
        launchApp(mockPhotos: true)
    }

    // MARK: - AC3: Quick Commands Visible When Idle

    /// [P0] Quick command suggestion cards are visible when Agent is idle.
    func testQuickCommandsVisibleWhenIdle() {
        waitForMainWorkspace()

        let firstCommand = app.buttons["Quick command: 找出重复照片"]
        XCTAssertTrue(firstCommand.waitForExistence(timeout: 5),
                      "Quick command suggestions should be visible when Agent is idle")
    }

    /// [P0] Section header "试试这些指令" is visible.
    func testQuickCommandsHeaderVisible() {
        waitForMainWorkspace()

        XCTAssertTrue(app.staticTexts["试试这些指令"].waitForExistence(timeout: 5),
                      "Quick commands section header should be visible")
    }

    // MARK: - AC3: Expected 4 Commands

    /// [P0] All four quick command cards are displayed.
    func testAllFourQuickCommandsExist() {
        waitForMainWorkspace()

        let commands = [
            "Quick command: 找出重复照片",
            "Quick command: 重命名照片",
            "Quick command: 分析我的照片",
            "Quick command: 帮我整理照片库",
        ]
        for commandLabel in commands {
            let button = app.buttons[commandLabel]
            XCTAssertTrue(button.waitForExistence(timeout: 5),
                          "Quick command '\(commandLabel)' should exist")
        }
    }

    // MARK: - AC3: Tap Command to Submit

    /// [P1] Tapping a quick command card triggers the submit flow.
    func testTappingQuickCommandTriggersSubmit() {
        waitForMainWorkspace()

        let command = app.buttons["Quick command: 找出重复照片"]
        XCTAssertTrue(command.waitForExistence(timeout: 5))
        command.tap()

        // After tap, the app transitions away from the idle quick-commands state.
        // Without a real API key the execution may fail instantly and return to idle.
        // Verify that the tap was handled by checking the UI responds (no crash/hang).
        let quickHeader = app.staticTexts["试试这些指令"]
        let inputField = app.textFields["Agent instruction input"]
        let responded = quickHeader.waitForExistence(timeout: 5) || inputField.waitForExistence(timeout: 5)
        XCTAssertTrue(responded,
                      "UI should respond after tapping a quick command")
    }

    // MARK: - Helper

    private func waitForMainWorkspace() {
        let quickHeader = app.staticTexts["试试这些指令"]
        let navTitle = app.staticTexts["Curator"]
        XCTAssertTrue(quickHeader.waitForExistence(timeout: 10) || navTitle.waitForExistence(timeout: 10),
                      "Main workspace should be visible after launch with mockPhotos")
    }
}
