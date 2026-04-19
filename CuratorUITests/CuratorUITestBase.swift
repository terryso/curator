import XCTest

/// Base class for all Curator UI tests.
///
/// Provides app launch helpers with state reset via launch arguments,
/// common element waiting utilities, and automatic dismissal of
/// system permission dialogs (photo library, input method).
class CuratorUITestBase: XCTestCase {

    var app: XCUIApplication!

    /// Monitor handle for system permission dialogs.
    private var interruptionMonitor: NSObjectProtocol?

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        installInterruptionMonitors()
    }

    override func tearDown() {
        removeInterruptionMonitors()
        super.tearDown()
    }

    // MARK: - Interruption Monitors

    /// Installs monitors to auto-dismiss system dialogs during UI tests.
    private func installInterruptionMonitors() {
        let monitor = addUIInterruptionMonitor(withDescription: "System Permission Dialogs") { alert in
            // Photo library permission: "OK" (English)
            if alert.buttons["OK"].exists {
                alert.buttons["OK"].tap()
                return true
            }
            // Photo library permission: "好" (Chinese)
            if alert.buttons["好"].exists {
                alert.buttons["好"].tap()
                return true
            }
            // Input method / Keychain access: "允许" (Chinese)
            if alert.buttons["允许"].exists {
                alert.buttons["允许"].tap()
                return true
            }
            // Input method / Keychain access: "Allow" (English)
            if alert.buttons["Allow"].exists {
                alert.buttons["Allow"].tap()
                return true
            }
            // Keychain: "始终允许" (Always Allow - Chinese)
            if alert.buttons["始终允许"].exists {
                alert.buttons["始终允许"].tap()
                return true
            }
            // Keychain: "Always Allow" (English)
            if alert.buttons["Always Allow"].exists {
                alert.buttons["Always Allow"].tap()
                return true
            }
            // System auth: "好" as confirm button in Chinese dialogs
            if alert.buttons["好"].exists {
                alert.buttons["好"].tap()
                return true
            }
            // Developer tools: "Don't Allow" dismissal fallback
            if alert.buttons["Don't Allow"].exists {
                alert.buttons["Don't Allow"].tap()
                return true
            }
            return false
        }
        interruptionMonitor = monitor
    }

    private func removeInterruptionMonitors() {
        if let monitor = interruptionMonitor {
            removeUIInterruptionMonitor(monitor)
            interruptionMonitor = nil
        }
    }

    /// Triggers the interruption monitor to handle any pending system dialogs.
    /// Uses multiple passes with increasing delays to catch stacked dialogs.
    private func handleSystemDialogs() {
        // Multiple passes to handle stacked dialogs
        for attempt in 0..<3 {
            Thread.sleep(forTimeInterval: 1.0 + Double(attempt) * 0.5)
            let coordinate = app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            coordinate.tap()
        }
    }

    // MARK: - App Launch

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
        handleSystemDialogs()
    }

    // MARK: - Element Helpers

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
}
