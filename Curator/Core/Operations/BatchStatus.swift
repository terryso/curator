import Foundation

/// Status of a batch operation throughout its lifecycle.
///
/// Flow: pending -> executing -> completed
///                \-> failed -> rolledBack
enum BatchStatus: String, Sendable, Codable, Equatable {
    case pending
    case executing
    case completed
    case failed
    case rolledBack
}
