@preconcurrency import XCTest

/// UI tests for Story 1.4 — Photo library browse grid.
///
/// Uses mock photo data to avoid PhotoKit permission dependencies.
final class PhotoGridUITests: CuratorUITestBase {

    override func setUp() {
        super.setUp()
        launchApp(mockPhotos: true)
    }

    // MARK: - AC1: Photo grid displays

    /// [P0] Photo grid area shows photos when library is accessible.
    func testPhotoGridDisplaysPhotos() throws {
        let photoButtons = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'photo'"))
        let exists = photoButtons.firstMatch.waitForExistence(timeout: 10)
        XCTAssertTrue(exists, "Photo grid should contain at least one photo")
        XCTAssertTrue(photoButtons.count > 0, "Photo grid should contain at least one photo")
    }

    // MARK: - AC2: Photo detail sheet

    /// [P0] Clicking a photo opens the detail sheet with metadata.
    func testClickPhotoOpensDetailSheet() throws {
        let firstPhoto = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'photo'")).firstMatch
        XCTAssertTrue(firstPhoto.waitForExistence(timeout: 10))
        firstPhoto.tap()

        XCTAssertTrue(app.staticTexts["Date"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["File Name"].exists)
        XCTAssertTrue(button(label: "Close").exists)
    }

    /// [P0] Detail sheet can be closed via Close button.
    func testDetailSheetCanBeClosed() throws {
        let firstPhoto = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'photo'")).firstMatch
        XCTAssertTrue(firstPhoto.waitForExistence(timeout: 10))
        firstPhoto.tap()

        XCTAssertTrue(button(label: "Close").waitForExistence(timeout: 5))
        button(label: "Close").tap()

        XCTAssertFalse(app.buttons["Close"].exists)
    }
}
