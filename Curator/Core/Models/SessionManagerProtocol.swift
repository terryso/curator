import Foundation

/// Protocol defining the session management contract.
///
/// Implementations handle session CRUD operations including creation,
/// persistence, switching, and deletion. The protocol is Sendable so
/// it can be stored in actor-isolated contexts.
///
/// All mutating methods are async to support actor-isolated implementations
/// where SwiftData I/O occurs off the MainActor.
protocol SessionManagerProtocol: Sendable {
    /// The currently active session, if any.
    var activeSession: Session? { get async }

    /// Creates a new session, auto-saving any previously active session.
    /// The new session becomes the active session.
    func createSession() async -> Session

    /// Loads a session by its unique identifier.
    /// - Throws: `SessionError.sessionNotFound` if no session matches.
    func loadSession(_ id: UUID) async throws -> Session

    /// Persists the given session, updating its updatedAt timestamp.
    func saveSession(_ session: Session) async throws

    /// Returns all sessions sorted by updatedAt descending (most recent first).
    func listSessions() async throws -> [Session]

    /// Switches to the specified session, deactivating the current active session.
    /// - Throws: `SessionError.sessionNotFound` if the target session doesn't exist.
    func switchToSession(_ id: UUID) async throws -> Session

    /// Deletes the specified session. No-op if the session doesn't exist.
    func deleteSession(_ id: UUID) async throws
}
