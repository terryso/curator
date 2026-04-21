import Foundation

/// An item presented to the user for review.
///
/// Initially a generic container; will be extended with typed
/// review data in Epic 4 (operation confirmation) and
/// Epic 5 (dedup review).
struct ReviewItem: Sendable, Identifiable, Equatable {
    let id: UUID
    let title: String
    let description: String
    let requiresConfirmation: Bool
}
