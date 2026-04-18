import SwiftUI

/// Calculates adaptive grid column layout for the photo library browser.
///
/// Implements UX-DR13: minimum column width 120pt, spacing 4pt.
/// Formula: columns = max(1, floor(availableWidth / (minColumnWidth + spacing)))
struct GridColumnCalculator: Sendable {

    /// Minimum column width in points (UX-DR13).
    static let minColumnWidth: CGFloat = 120

    /// Spacing between columns in points (UX-DR13).
    static let spacing: CGFloat = 4

    /// Calculates the number of columns for a given available width.
    ///
    /// - Parameter availableWidth: The total width available for the grid.
    /// - Returns: The number of columns, guaranteed to be at least 1.
    static func columnCount(for availableWidth: CGFloat) -> Int {
        let totalUnitWidth = minColumnWidth + spacing
        return max(1, Int(availableWidth / totalUnitWidth))
    }

    /// Creates an array of GridItem for use with LazyVGrid.
    ///
    /// - Parameter availableWidth: The total width available for the grid.
    /// - Returns: An array of flexible GridItems with the calculated column count.
    static func gridItems(for availableWidth: CGFloat) -> [GridItem] {
        let count = columnCount(for: availableWidth)
        return Array(
            repeating: GridItem(.flexible(minimum: minColumnWidth), spacing: spacing),
            count: count
        )
    }
}
