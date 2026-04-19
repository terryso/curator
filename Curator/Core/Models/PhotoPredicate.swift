import Foundation

/// A predicate for filtering photo assets in library queries.
///
/// Supports filtering by date ranges and file format types.
/// The `.all` predicate returns all photos without filtering.
struct PhotoPredicate: Sendable, Equatable {
    let rawValue: String

    /// Optional date range filter — only return photos created within this range.
    let dateRange: DateRange?

    /// Optional file format filter.
    let fileFormat: FileFormatFilter

    /// A predicate that matches all photos (no filtering).
    static var all: PhotoPredicate {
        PhotoPredicate(rawValue: "", dateRange: nil, fileFormat: .all)
    }

    /// Creates a predicate with a date range filter.
    static func dateRange(from: Date, to: Date) -> PhotoPredicate {
        PhotoPredicate(
            rawValue: "dateRange:\(from.timeIntervalSince1970)-\(to.timeIntervalSince1970)",
            dateRange: DateRange(from: from, to: to),
            fileFormat: .all
        )
    }

    /// Creates a predicate with a file format filter.
    static func filter(fileFormat: FileFormatFilter) -> PhotoPredicate {
        PhotoPredicate(rawValue: "fileFormat:\(fileFormat)", dateRange: nil, fileFormat: fileFormat)
    }
}

/// A closed date range for filtering photos.
struct DateRange: Sendable, Equatable {
    let from: Date
    let to: Date
}

/// File format filter for photo queries.
enum FileFormatFilter: String, Sendable, Equatable {
    case all
    case images    // JPEG, PNG, HEIC, TIFF, RAW
    case heic
    case raw
}
