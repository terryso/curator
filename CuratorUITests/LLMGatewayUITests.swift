@preconcurrency import XCTest

/// UI tests for Story 2.1 — LLM Gateway Core integration.
///
/// Verifies that the app launches and functions correctly with the
/// LLM Gateway registered in the dependency container. The gateway
/// is registered on app launch; these tests confirm the infrastructure
/// doesn't break any existing UI flows.
final class LLMGatewayUITests: CuratorUITestBase {

    override func setUp() {
        super.setUp()
        launchApp(mockPhotos: true)
    }

    // MARK: - Happy-path: App launches with LLM Gateway registered

    func testAppLaunchesWithLLMGateway() throws {
        // The main workspace should appear after onboarding (mock photos skips it).
        // LLM Gateway is registered during .task — if it crashes, this fails.
        let welcomeText = app.staticTexts["Welcome to Curator"]
        XCTAssertTrue(welcomeText.waitForExistence(timeout: 10),
                      "Main workspace should appear after LLM Gateway registration")
    }

    // MARK: - Settings still accessible with LLM infrastructure

    func testSettingsOpensWithLLMGateway() throws {
        app.typeKey(",", modifierFlags: .command)
        let settingsText = app.staticTexts["Settings"]
        XCTAssertTrue(settingsText.waitForExistence(timeout: 5),
                      "Settings should open with LLM Gateway infrastructure loaded")
    }
}
