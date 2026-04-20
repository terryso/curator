import XCTest

/// UI tests for Story 1.5 — First-launch onboarding flow.
final class OnboardingUITests: CuratorUITestBase {

    // MARK: - AC1: 3-screen onboarding flow

    /// [P0] Welcome screen displays on fresh launch.
    func testWelcomeScreenAppearsOnFreshLaunch() {
        launchApp(resetOnboarding: true)

        XCTAssertTrue(app.staticTexts["Curator"].waitForExistence(timeout: 5))
        XCTAssertTrue(button(label: "Next step").exists)
    }

    /// [P0] Privacy screen appears after tapping Next on welcome.
    func testPrivacyScreenAfterWelcome() {
        launchApp(resetOnboarding: true)

        button(label: "Next step").tap()
        XCTAssertTrue(app.staticTexts["Your Privacy Matters"].waitForExistence(timeout: 5))
    }

    /// [P0] Folder selection screen appears after tapping Next on privacy.
    func testFolderSelectionScreenAfterPrivacy() {
        launchApp(resetOnboarding: true)

        button(label: "Next step").tap()
        button(label: "Next step").tap()
        // Verify we reached the folder selection screen by checking the back button and action button
        XCTAssertTrue(button(label: "Go back to privacy").waitForExistence(timeout: 5))
        XCTAssertTrue(button(label: "Select a photo folder to scan").exists)
    }

    // MARK: - AC3: Back navigation

    /// [P1] Back navigation works from permission screen.
    func testBackNavigationFromPermission() {
        launchApp(resetOnboarding: true)

        button(label: "Next step").tap()
        button(label: "Next step").tap()
        button(label: "Go back to privacy").tap()

        XCTAssertTrue(app.staticTexts["Your Privacy Matters"].waitForExistence(timeout: 5))
    }
}
