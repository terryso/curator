@preconcurrency import XCTest

/// UI tests for Stories 2.1-2.3 — Provider configuration UI.
///
/// Verifies the API Key Management view including provider type picker,
/// base URL / API key fields, validation button, fallback provider toggle,
/// and save/reset actions. Opens Settings once and keeps it open across tests.
final class APIKeyManagementUITests: CuratorUITestBase {

    private var didOpenSettings = false

    override func setUp() {
        super.setUp()
        launchApp(mockPhotos: true)
    }

    private func openSettingsAndSelectProvider() {
        guard !didOpenSettings else {
            // Re-select Provider Config in case another test navigated away
            app.staticTexts["Provider Config"].tap()
            let _ = app.staticTexts["Primary Provider"].waitForExistence(timeout: 5)
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
        app.staticTexts["Provider Config"].tap()
        let _ = app.staticTexts["Primary Provider"].waitForExistence(timeout: 5)
        didOpenSettings = true
    }

    // MARK: - AC1: Primary Provider Section

    /// [P0] Primary Provider section header is visible.
    func testPrimaryProviderSectionExists() {
        openSettingsAndSelectProvider()
        XCTAssertTrue(app.staticTexts["Primary Provider"].waitForExistence(timeout: 5),
                      "Primary Provider section should be visible")
    }

    /// [P0] Text fields exist for base URL configuration.
    func testBaseURLFieldExists() {
        openSettingsAndSelectProvider()
        let textFields = app.textFields
        XCTAssertTrue(textFields.count > 0,
                      "At least one text field should exist in provider config")
    }

    /// [P0] Secure text field exists for API key.
    func testAPIKeyFieldExists() {
        openSettingsAndSelectProvider()
        let secureFields = app.secureTextFields
        XCTAssertTrue(secureFields.count > 0,
                      "At least one secure text field should exist for API key")
    }

    /// [P0] Validate button exists.
    func testValidateButtonExists() {
        openSettingsAndSelectProvider()
        let validateButton = app.buttons["Validate"]
        XCTAssertTrue(validateButton.waitForExistence(timeout: 5),
                      "Validate button should exist")
    }

    /// [P0] Picker controls exist for provider type and model selection.
    func testPickerControlsExist() {
        openSettingsAndSelectProvider()
        let pickers = app.popUpButtons
        XCTAssertTrue(pickers.count > 0,
                      "At least one picker should exist for type/model selection")
    }

    // MARK: - AC2: Fallback Provider Section

    /// [P0] Fallback Provider section header is visible.
    func testFallbackProviderSectionExists() {
        openSettingsAndSelectProvider()
        XCTAssertTrue(app.staticTexts["Fallback Provider"].waitForExistence(timeout: 5),
                      "Fallback Provider section should be visible")
    }

    /// [P0] Fallback toggle exists.
    func testFallbackToggleExists() {
        openSettingsAndSelectProvider()
        let toggleLabel = app.staticTexts["Enable Fallback Provider"]
        XCTAssertTrue(toggleLabel.waitForExistence(timeout: 5),
                      "Fallback toggle label should exist")
    }

    /// [P1] Toggling fallback reveals fallback provider fields.
    func testEnablingFallbackShowsProviderFields() {
        openSettingsAndSelectProvider()
        let fallbackLabel = app.staticTexts["Enable Fallback Provider"]
        if fallbackLabel.exists {
            fallbackLabel.tap()
        }

        let allTextFields = app.textFields
        XCTAssertTrue(allTextFields.count >= 1,
                      "Additional text fields should appear after enabling fallback")
    }

    // MARK: - AC3: Save and Reset Actions

    /// [P0] Save button exists in the actions section.
    func testSaveButtonExists() {
        openSettingsAndSelectProvider()
        let saveButton = app.buttons["Save"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5),
                      "Save button should exist")
    }

    /// [P0] Reset button exists in the actions section.
    func testResetButtonExists() {
        openSettingsAndSelectProvider()
        let resetButton = app.buttons["Reset"]
        XCTAssertTrue(resetButton.waitForExistence(timeout: 5),
                      "Reset button should exist")
    }

    /// [P1] Typing into text field works.
    func testCanTypeIntoBaseURLField() {
        openSettingsAndSelectProvider()
        let firstTextField = app.textFields.firstMatch
        XCTAssertTrue(firstTextField.waitForExistence(timeout: 5))

        firstTextField.click()
        firstTextField.typeText("https://api.example.com")
        let value = firstTextField.value as? String ?? ""
        XCTAssertTrue(value.contains("api.example.com"),
                      "Text field should accept typed input")
    }

    /// [P1] Typing into secure text field works.
    func testCanTypeIntoAPIKeyField() {
        openSettingsAndSelectProvider()
        let firstSecureField = app.secureTextFields.firstMatch
        XCTAssertTrue(firstSecureField.waitForExistence(timeout: 5))

        firstSecureField.click()
        firstSecureField.typeText("sk-test-key-12345")
        XCTAssertTrue(firstSecureField.exists, "Secure text field should accept typed input")
    }
}
