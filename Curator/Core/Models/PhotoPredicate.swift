import Foundation

/// A predicate for filtering photo assets in library queries.
///
/// Supports common filter criteria such as date ranges and media types.
/// The `.all` predicate returns all photos without filtering.
struct PhotoPredicate: Sendable, Equatable {
    let rawValue: String

    /// Optional date range filter — only return photos created within this range.
    let dateRange: DateRange?

    /// Optional media type filter.
    let mediaType: MediaType

    /// A predicate that matches all photos (no filtering).
    static var all: PhotoPredicate {
        PhotoPredicate(rawValue: "", dateRange: nil, mediaType: .all)
    }

    /// Creates a predicate with a date range filter.
    /// - Parameter from: Start date (inclusive).
    /// - Parameter to: End date (inclusive).
    /// - Returns: A predicate matching photos within the given date range.
    static func dateRange(from: Date, to: Date) -> PhotoPredicate {
        PhotoPredicate(
            rawValue: "dateRange:\(from.timeIntervalSince1970)-\(to.timeIntervalSince1970)",
            dateRange: DateRange(from: from, to: to),
            mediaType: .all
        )
    }

    /// Creates a predicate with a media type filter.
    /// - Parameter mediaType: The media type to filter by.
    /// - Returns: A predicate matching the given media type.
    static func filter(mediaType: MediaType) -> PhotoPredicate {
        PhotoPredicate(rawValue: "mediaType:\(mediaType)", dateRange: nil, mediaType: mediaType)
    }
}

/// A closed date range for filtering photos.
struct DateRange: Sendable, Equatable {
    let from: Date
    let to: Date
}

/// Media type filter for photo library queries.
enum MediaType: String, Sendable, Equatable {
    case all
    case image
    case video
}
