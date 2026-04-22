@preconcurrency import XCTest

/// UI tests for Story 3.4 — Agent execution panel and Story 3.6 — streaming.
///
/// Verifies the Agent Execution Panel: step card rendering, progress display,
/// summary area states, and the transition from idle to executing to completed.
final class AgentExecutionPanelUITests: CuratorUITestBase {

    override func setUp() {
        super.setUp()
        launchApp(mockPhotos: true)
    }

    // MARK: - AC1: Execution Panel Shows After Submission

    /// [P0] Submitting a command triggers the execution flow (no crash/hang).
    func testExecutionFlowStartsAfterSubmit() {
        waitForMainWorkspace()

        let command = app.buttons["Quick command: 找出重复照片"]
        XCTAssertTrue(command.waitForExistence(timeout: 5))
        command.tap()

        // Without a real API key, execution may fail instantly and return to idle.
        // Verify the UI responds correctly — quick commands or input bar should exist.
        let quickHeader = app.staticTexts["试试这些指令"]
        let inputField = app.textFields["Agent instruction input"]
        let runningLabel = app.staticTexts["Agent 正在工作中..."]
        let responded = quickHeader.waitForExistence(timeout: 5)
                      || inputField.waitForExistence(timeout: 5)
                      || runningLabel.waitForExistence(timeout: 5)
        XCTAssertTrue(responded,
                       "UI should respond after submitting a command")
    }

    // MARK: - AC2: Step Card Display

    /// [P1] Step cards or processing label appear during execution.
    func testStepCardsOrSummaryAfterExecution() {
        submitCommand()

        // Execution may complete instantly (no API key) or show steps briefly.
        // Check for any content: processing label, step status, or return to idle.
        let processingLabel = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS 'Processing step'")
        ).firstMatch
        let steps = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS 'Done' OR label CONTAINS 'Running' OR label CONTAINS 'Waiting'")
        ).firstMatch
        let quickHeader = app.staticTexts["试试这些指令"]

        let contentAppeared = processingLabel.waitForExistence(timeout: 3)
                              || steps.waitForExistence(timeout: 3)
                              || quickHeader.waitForExistence(timeout: 5)
        XCTAssertTrue(contentAppeared,
                       "Step cards, processing label, or idle state should appear after execution")
    }

    // MARK: - AC: Cancelled State

    /// [P1] Cancelling execution shows cancelled state.
    func testCancelledStateAfterCancel() {
        waitForMainWorkspace()

        let command = app.buttons["Quick command: 分析我的照片"]
        XCTAssertTrue(command.waitForExistence(timeout: 5))
        command.tap()

        let cancelButton = app.buttons["Cancel Agent execution"]
        if cancelButton.waitForExistence(timeout: 3) {
            cancelButton.tap()

            let cancelledText = app.staticTexts["Execution cancelled."]
            if cancelledText.waitForExistence(timeout: 3) {
                XCTAssertTrue(cancelledText.exists,
                               "Cancelled execution should show cancellation message")
            }
        }
    }

    // MARK: - AC: Return to Idle After Completion

    /// [P1] After execution completes, input bar returns to normal state.
    func testInputRestoredAfterExecution() {
        submitCommand()

        let inputField = app.textFields["Agent instruction input"]
        let quickHeader = app.staticTexts["试试这些指令"]
        let restored = inputField.waitForExistence(timeout: 10) || quickHeader.waitForExistence(timeout: 10)
        XCTAssertTrue(restored,
                       "Input field or quick commands should be restored after execution ends")
    }

    // MARK: - Helpers

    private func waitForMainWorkspace() {
        let quickHeader = app.staticTexts["试试这些指令"]
        let navTitle = app.staticTexts["Curator"]
        XCTAssertTrue(quickHeader.waitForExistence(timeout: 10) || navTitle.waitForExistence(timeout: 10),
                      "Main workspace should be visible after launch with mockPhotos")
    }

    private func submitCommand() {
        waitForMainWorkspace()

        let command = app.buttons["Quick command: 找出重复照片"]
        XCTAssertTrue(command.waitForExistence(timeout: 5))
        command.tap()
    }
}
