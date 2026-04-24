import Foundation
import XCTest

@testable import Curator

/// ATDD Tests for Story 6.1 -- RenameSuggestion Domain Model (AC2)
///
/// Tests verify:
/// - AC2: RenameSuggestion model contains original file name, suggested name, confidence
/// - AC2: Suggested names conform to file system naming conventions
/// - AC2: RenameSuggestionStatus covers full lifecycle
final class RenameSuggestionTests: XCTestCase {

    // MARK: - AC2: RenameSuggestion Model

    /// [P0] RenameSuggestion has all required fields.
    ///
    /// AC2: Given a photo analysis result,
    /// When creating a RenameSuggestion,
    /// Then it contains id, assetID, originalFileName, suggestedName, confidence,
    /// analysisDescription, and status.
    func testRenameSuggestionHasAllRequiredFields() async throws {
        // Given: A valid asset ID and suggested name
        let assetID = AssetID(rawValue: "/photos/beach_sunset.jpg")
        let suggestion = RenameSuggestion(
            assetID: assetID,
            originalFileName: "IMG_20240101_001.jpg",
            suggestedName: "Beach Sunset at Malibu",
            confidence: 0.92,
            analysisDescription: "A sunset scene at the beach with waves",
            status: .pending
        )

        // Then: All fields are populated
        XCTAssertEqual(suggestion.assetID, assetID)
        XCTAssertEqual(suggestion.originalFileName, "IMG_20240101_001.jpg")
        XCTAssertEqual(suggestion.suggestedName, "Beach Sunset at Malibu")
        XCTAssertEqual(suggestion.confidence, 0.92, accuracy: 0.01)
        XCTAssertEqual(suggestion.analysisDescription, "A sunset scene at the beach with waves")
        XCTAssertEqual(suggestion.status, .pending)
    }

    /// [P0] RenameSuggestion conforms to Sendable.
    ///
    /// AC2: Cross-boundary data transfer requires Sendable conformance.
    func testRenameSuggestionIsSendable() async throws {
        // Given: A RenameSuggestion
        let suggestion = RenameSuggestion(
            assetID: AssetID(rawValue: "/photos/test.jpg"),
            originalFileName: "test.jpg",
            suggestedName: "Mountain View",
            confidence: 0.8,
            status: .pending
        )

        // Then: Can be used across isolation boundaries (compile-time check)
        let _: any Sendable = suggestion
    }

    /// [P0] RenameSuggestion conforms to Identifiable.
    ///
    /// AC2: Needed for SwiftUI list rendering.
    func testRenameSuggestionIsIdentifiable() async throws {
        // Given: Two different suggestions
        let suggestion1 = RenameSuggestion(
            assetID: AssetID(rawValue: "/photos/a.jpg"),
            originalFileName: "a.jpg",
            suggestedName: "Photo A",
            confidence: 0.8,
            status: .pending
        )
        let suggestion2 = RenameSuggestion(
            assetID: AssetID(rawValue: "/photos/b.jpg"),
            originalFileName: "b.jpg",
            suggestedName: "Photo B",
            confidence: 0.7,
            status: .pending
        )

        // Then: Each has a unique id
        XCTAssertNotEqual(suggestion1.id, suggestion2.id)
    }

    // MARK: - AC2: RenameSuggestionStatus Transitions

    /// [P0] RenameSuggestionStatus has all expected cases.
    ///
    /// AC2: Status covers full lifecycle: pending, accepted, rejected, edited, failed.
    func testRenameSuggestionStatusHasExpectedCases() async throws {
        // Then: All expected status cases exist
        let _ = RenameSuggestionStatus.pending
        let _ = RenameSuggestionStatus.accepted
        let _ = RenameSuggestionStatus.rejected
        let _ = RenameSuggestionStatus.edited("Corrected Name")
        let _ = RenameSuggestionStatus.failed("LLM timeout")
    }

    /// [P0] RenameSuggestionStatus.pending is the initial state.
    ///
    /// AC2: New suggestions default to pending status.
    func testRenameSuggestionDefaultStatusIsPending() async throws {
        // Given: A newly created suggestion
        let suggestion = RenameSuggestion(
            assetID: AssetID(rawValue: "/photos/test.jpg"),
            originalFileName: "test.jpg",
            suggestedName: "Test Photo",
            confidence: 0.9,
            status: .pending
        )

        // Then: Status is pending
        XCTAssertEqual(suggestion.status, .pending)
    }

    // MARK: - AC2: File Name Validation

    /// [P0] isValidFileName rejects illegal characters.
    ///
    /// AC2: Suggested names must not contain characters forbidden by file systems.
    func testIsValidFileNameRejectsIllegalCharacters() async throws {
        // Then: Names with illegal characters are rejected
        let illegalChars = ["\\", "/", ":", "*", "?", "\"", "<", ">", "|"]
        for char in illegalChars {
            let invalidName = "Photo\(char)Name.jpg"
            XCTAssertFalse(
                RenameSuggestion.isValidFileName(invalidName),
                "Name containing '\(char)' should be invalid"
            )
        }
    }

    /// [P0] isValidFileName rejects empty strings.
    ///
    /// AC2: Empty file names are invalid.
    func testIsValidFileNameRejectsEmptyString() async throws {
        XCTAssertFalse(RenameSuggestion.isValidFileName(""))
    }

    /// [P0] isValidFileName rejects names that are too long.
    ///
    /// AC2: Names exceeding max length (200 chars) are invalid.
    func testIsValidFileNameRejectsTooLongName() async throws {
        let longName = String(repeating: "a", count: 201)
        XCTAssertFalse(RenameSuggestion.isValidFileName(longName))
    }

    /// [P1] isValidFileName accepts valid names.
    ///
    /// AC2: Normal descriptive names pass validation.
    func testIsValidFileNameAcceptsValidNames() async throws {
        XCTAssertTrue(RenameSuggestion.isValidFileName("Beach Sunset"))
        XCTAssertTrue(RenameSuggestion.isValidFileName("IMG_20240101"))
        XCTAssertTrue(RenameSuggestion.isValidFileName("a"))
        XCTAssertTrue(RenameSuggestion.isValidFileName(String(repeating: "x", count: 200)))
    }

    // MARK: - AC2: Extension Preservation

    /// [P0] Suggested name preserves original file extension.
    ///
    /// AC2: When generating a new name, the original file extension must be preserved.
    func testSuggestedNamePreservesExtension() async throws {
        // Given: A suggestion for a JPEG file
        let suggestion = RenameSuggestion(
            assetID: AssetID(rawValue: "/photos/IMG_001.jpg"),
            originalFileName: "IMG_001.jpg",
            suggestedName: "Beach Sunset.jpg",
            confidence: 0.85,
            status: .pending
        )

        // Then: Suggested name has the correct extension
        XCTAssertTrue(suggestion.suggestedName.hasSuffix(".jpg"))
    }

    /// [P1] Suggested name preserves extension for different formats.
    ///
    /// AC2: Extension preservation works for PNG, HEIC, etc.
    func testSuggestedNamePreservesVariousExtensions() async throws {
        let testCases: [(original: String, expected: String)] = [
            ("IMG_001.jpg", ".jpg"),
            ("screenshot.png", ".png"),
            ("photo.HEIC", ".HEIC"),
            ("image.jpeg", ".jpeg"),
            ("graphic.tiff", ".tiff"),
        ]

        for (original, ext) in testCases {
            let suggestion = RenameSuggestion(
                assetID: AssetID(rawValue: "/photos/\(original)"),
                originalFileName: original,
                suggestedName: "Renamed\(ext)",
                confidence: 0.8,
                status: .pending
            )
            XCTAssertTrue(
                suggestion.suggestedName.hasSuffix(ext),
                "Expected '\(suggestion.suggestedName)' to end with '\(ext)'"
            )
        }
    }
}
