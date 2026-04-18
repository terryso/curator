import Foundation

/// A predicate for filtering photo assets in library queries.
///
/// Placeholder type for Story 1.2 — will be expanded in
/// Story 1.3 (PhotoKit Read Service) with actual filter criteria.
struct PhotoPredicate: Sendable {
    let rawValue: String

    static var all: PhotoPredicate {
        PhotoPredicate(rawValue: "")
    }
}
