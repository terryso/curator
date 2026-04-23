import Foundation

/// A saved set of planned operations for deferred execution.
///
/// When a user in read-only mode declines write permission during confirmation,
/// the current operations are serialized into a `SavedOperationSet` and persisted
/// to UserDefaults. The user can re-execute them after granting write access.
///
/// Conforms to `Sendable, Codable, Identifiable` for safe concurrency,
/// serialization to JSON, and use in SwiftUI Lists.
struct SavedOperationSet: Sendable, Codable, Identifiable, Equatable {
    /// Unique identifier for this saved operation set.
    let id: UUID

    /// Timestamp when the operations were saved.
    let createdAt: Date

    /// Human-readable summary of the operations.
    let summary: String

    /// The planned operations awaiting execution.
    let operations: [PlannedOperation]

    /// Creates a new saved operation set with a generated UUID and current date.
    ///
    /// - Parameters:
    ///   - operations: The planned operations to save.
    ///   - summary: Human-readable summary of the operations.
    init(operations: [PlannedOperation], summary: String) {
        self.id = UUID()
        self.createdAt = Date()
        self.summary = summary
        self.operations = operations
    }
}
