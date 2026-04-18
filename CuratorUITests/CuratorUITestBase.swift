import XCTest

/// Base class for all Curator UI tests.
///
/// Provides app launch helpers with state reset via launch arguments,
/// and common element waiting utilities.
class CuratorUITestBase: XCTestCase {

    var app: XCUIApplication!

    /// Launches the app with optional state reset and mock photos.
    func launchApp(resetOnboarding: Bool = false, mockPhotos: Bool = false) {
        app = XCUIApplication()
        if resetOnboarding {
            app.launchArguments.append("--uitest-reset-onboarding")
        }
        if mockPhotos {
            app.launchArguments.append("--uitest-mock-photos")
        }
        app.launch()
    }

    /// Waits for an element to exist.
    @discardableResult
    func waitForExistence(of element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        element.waitForExistence(timeout: timeout)
    }

    /// Finds and waits for a button with the given accessibility label.
    func button(label: String) -> XCUIElement {
        let btn = app.buttons[label]
        waitForExistence(of: btn)
        return btn
    }

    /// Finds and waits for a static text matching the given string.
    func text(_ value: String) -> XCUIElement {
        let txt = app.staticTexts[value]
        waitForExistence(of: txt)
        return txt
    }

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }
}
