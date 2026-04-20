import Foundation

/// Time range for cost tracking queries.
///
/// Used by SettingsViewModel to select the scope of cost summaries
/// displayed in the cost tracking panel.
enum CostTimeRange: Sendable, Equatable {
    /// Current calendar month.
    case month
    /// All time (unbounded).
    case all

    /// Returns the date interval for this time range, or nil for unbounded (.all).
    var dateRange: DateInterval? {
        switch self {
        case .month:
            let calendar = Calendar.current
            let now = Date()
            guard let start = calendar.date(from: calendar.dateComponents([.year, .month], from: now)),
                  let end = calendar.date(byAdding: .month, value: 1, to: start) else {
                return nil
            }
            return DateInterval(start: start, end: end)
        case .all:
            return nil
        }
    }
}
