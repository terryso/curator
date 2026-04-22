import Foundation

/// Error types for session management operations.
enum SessionError: Error, Sendable, Equatable {
    case sessionNotFound(id: UUID)
    case saveFailed(reason: String)
}

/// A conversation session with the Agent.
///
/// Value type representing a complete multi-turn dialogue session.
/// Sessions are persisted via SwiftData through the SessionEntity bridge.
/// Sendable for safe transfer across actor boundaries (SessionManager is an actor).
struct Session: Sendable, Equatable {
    var id: UUID
    var title: String
    var createdAt: Date
    var updatedAt: Date
    var messages: [SessionMessage]
    var isActive: Bool
}
