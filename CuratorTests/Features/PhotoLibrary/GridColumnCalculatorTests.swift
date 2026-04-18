import XCTest
@testable import Curator

/// ATDD Tests for Story 1.4 - Grid Column Calculation (UX-DR13)
///
/// Tests verify the adaptive grid column calculation logic:
/// - Minimum column width: 120pt
/// - Spacing: 4pt
/// - Formula: columns = floor(availableWidth / (minColumnWidth + spacing))
/// - Minimum 1 column regardless of width
///
/// These are pure calculation tests that can run without SwiftUI rendering.
final class GridColumnCalculatorTests: XCTestCase {

    // MARK: - AC1: Adaptive Grid Layout (UX-DR13)

    /// [P0] Grid column calculation for narrow width produces 1 column
    func testGridColumnCountNarrowWidth() {
        // Given: Available width of 124pt (exactly 1 column: 120 + 4)
        let width: CGFloat = 124

        // When: Calculating column count
        let columns = GridColumnCalculator.columnCount(for: width)

        // Then: Should produce 1 column
        XCTAssertEqual(columns, 1, "124pt should produce exactly 1 column")
    }

    /// [P0] Grid column calculation for 800pt width
    func testGridColumnCount800Width() {
        // Given: Available width of 800pt
        // Expected: floor(800 / 124) = 6
        let width: CGFloat = 800

        // When: Calculating column count
        let columns = GridColumnCalculator.columnCount(for: width)

        // Then: Should produce 6 columns
        XCTAssertEqual(columns, 6, "800pt should produce 6 columns")
    }

    /// [P0] Grid column calculation minimum is 1
    func testGridColumnCountMinimumOne() {
        // Given: Available width of 0pt
        let width: CGFloat = 0

        // When: Calculating column count
        let columns = GridColumnCalculator.columnCount(for: width)

        // Then: Should produce at least 1 column
        XCTAssertGreaterThanOrEqual(columns, 1, "Minimum 1 column")
    }

    /// [P1] Grid column calculation for very small width
    func testGridColumnCountVerySmallWidth() {
        // Given: Available width of 50pt (less than min column width)
        let width: CGFloat = 50

        // When: Calculating column count
        let columns = GridColumnCalculator.columnCount(for: width)

        // Then: Should produce 1 column (floor(50/124) = 0 -> clamp to 1)
        XCTAssertEqual(columns, 1, "Very small width should still produce 1 column")
    }

    /// [P1] Grid column calculation for wide display
    func testGridColumnCountWideDisplay() {
        // Given: Available width of 1920pt
        // Expected: floor(1920 / 124) = 15
        let width: CGFloat = 1920

        // When: Calculating column count
        let columns = GridColumnCalculator.columnCount(for: width)

        // Then: Should produce 15 columns
        XCTAssertEqual(columns, 15, "1920pt should produce 15 columns")
    }

    /// [P1] Grid column calculation produces correct GridItem array
    func testGridColumnsProducesCorrectGridItemArray() {
        // Given: Available width of 620pt
        // Expected: floor(620 / 124) = 5
        let width: CGFloat = 620

        // When: Getting GridItem array
        let items = GridColumnCalculator.gridItems(for: width)

        // Then: Should produce 5 GridItems with flexible(minimum: 120)
        XCTAssertEqual(items.count, 5, "620pt should produce 5 GridItems")
    }

    /// [P1] Grid column calculation spacing is 4pt
    func testGridColumnsSpacingIs4pt() {
        // Given: Any width
        // When: Getting GridItem array
        let items = GridColumnCalculator.gridItems(for: 800)

        // Then: Spacing should be 4pt
        for item in items {
            XCTAssertEqual(item.spacing, 4, "Grid spacing should be 4pt")
        }
    }

    /// [P2] Grid column calculation handles edge case of exactly 2 columns
    func testGridColumnCountExactlyTwoColumns() {
        // Given: Available width of 248pt (exactly 2 * (120 + 4))
        let width: CGFloat = 248

        // When: Calculating column count
        let columns = GridColumnCalculator.columnCount(for: width)

        // Then: Should produce 2 columns
        XCTAssertEqual(columns, 2, "248pt should produce exactly 2 columns")
    }

    /// [P2] Grid column calculation handles fractional column boundary
    func testGridColumnCountFractionalBoundary() {
        // Given: Available width of 371pt (2.99 columns)
        // floor(371 / 124) = 2
        let width: CGFloat = 371

        // When: Calculating column count
        let columns = GridColumnCalculator.columnCount(for: width)

        // Then: Should produce 2 columns (floor truncates)
        XCTAssertEqual(columns, 2, "371pt should produce 2 columns (floor)")
    }
}
