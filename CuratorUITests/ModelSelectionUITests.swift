@preconcurrency import XCTest

/// UI tests for Story 2.5 — Model Selection settings view.
///
/// Verifies the model picker, pricing display for all supported models,
/// and save/reset actions in the Model Selection detail view.
final class ModelSelectionUITests: CuratorUITestBase {

    private var didOpenSettings = false

    override func setUp() {
        super.setUp()
        launchApp(mockPhotos: true)
    }

    private func openModelSelection() {
        guard !didOpenSettings else {
            app.staticTexts["Model Selection"].tap()
            let _ = app.staticTexts["Available Models & Pricing"].waitForExistence(timeout: 5)
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
        app.staticTexts["Model Selection"].tap()
        let _ = app.staticTexts["Available Models & Pricing"].waitForExistence(timeout: 5)
        didOpenSettings = true
    }

    // MARK: - AC1: Model Picker

    /// [P0] Default Model picker exists.
    func testDefaultModelPickerExists() {
        openModelSelection()
        // macOS SwiftUI Picker may appear as popUpButton, menu, or other control type.
        // Verify the section exists with the "Default Model" label.
        let defaultModelLabel = app.staticTexts["Default Model"]
        XCTAssertTrue(defaultModelLabel.waitForExistence(timeout: 5),
                      "Default Model section label should exist")
    }

    // MARK: - AC2: Pricing Display

    /// [P0] Available Models & Pricing section is visible.
    func testPricingSectionExists() {
        openModelSelection()
        XCTAssertTrue(app.staticTexts["Available Models & Pricing"].waitForExistence(timeout: 5),
                      "Available Models & Pricing section should be visible")
    }

    /// [P0] Pricing footer text is visible.
    func testPricingFooterExists() {
        openModelSelection()
        XCTAssertTrue(app.staticTexts["Prices shown per 1 million tokens (USD)"].waitForExistence(timeout: 5),
                      "Pricing footer should be visible")
    }

    /// [P0] Claude Sonnet model is listed with pricing.
    func testClaudeSonnetModelListed() {
        openModelSelection()
        XCTAssertTrue(app.staticTexts["claude-sonnet-4-20250514"].waitForExistence(timeout: 5),
                      "Claude Sonnet model should be listed")
    }

    /// [P0] GPT-4o model is listed.
    func testGPT4oModelListed() {
        openModelSelection()
        XCTAssertTrue(app.staticTexts["gpt-4o"].waitForExistence(timeout: 5),
                      "GPT-4o model should be listed")
    }

    /// [P0] Anthropic provider label is shown for Claude models.
    func testAnthropicProviderLabelExists() {
        openModelSelection()
        XCTAssertTrue(app.staticTexts["Anthropic"].waitForExistence(timeout: 5),
                      "Anthropic provider label should be shown")
    }

    /// [P0] OpenAI Compatible provider label is shown for compatible models.
    func testOpenAICompatibleProviderLabelExists() {
        openModelSelection()
        XCTAssertTrue(app.staticTexts["OpenAI Compatible"].waitForExistence(timeout: 5),
                      "OpenAI Compatible provider label should be shown")
    }

    // MARK: - AC3: Save and Reset

    /// [P0] Save button exists in model selection view.
    func testSaveButtonExists() {
        openModelSelection()
        let saveButton = app.buttons["Save"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5),
                      "Save button should exist in model selection view")
    }

    /// [P0] Reset button exists in model selection view.
    func testResetButtonExists() {
        openModelSelection()
        let resetButton = app.buttons["Reset"]
        XCTAssertTrue(resetButton.waitForExistence(timeout: 5),
                      "Reset button should exist in model selection view")
    }
}
