import Foundation
import Observation

/// ViewModel for the Session History sheet.
///
/// Manages loading, displaying, and deleting sessions from the history list.
/// Marked @MainActor for safe use with SwiftUI views.
/// Uses @Observable macro (macOS 15+) for efficient view updates.
@MainActor
@Observable
final class SessionHistoryViewModel {

    // MARK: - Observable State

    /// Loaded sessions, sorted by updatedAt descending.
    var sessions: [Session] = []

    /// Whether a load operation is in progress.
    var isLoading: Bool = false

    /// Error message to display, if any.
    var errorMessage: String?

    // MARK: - Dependencies

    /// The session manager providing data access.
    private let sessionManager: SessionManagerProtocol

    // MARK: - Initialization

    /// Creates a SessionHistoryViewModel with the given session manager.
    ///
    /// - Parameter sessionManager: The SessionManagerProtocol implementation for data access.
    init(sessionManager: SessionManagerProtocol) {
        self.sessionManager = sessionManager
    }

    // MARK: - Actions

    /// Loads all sessions from the session manager.
    ///
    /// Updates `sessions` sorted by updatedAt descending.
    /// Sets `isLoading` during the operation and `errorMessage` on failure.
    func loadSessions() async {
        isLoading = true
        errorMessage = nil

        do {
            let loaded = try await sessionManager.listSessions()
            sessions = loaded
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    /// Deletes a session by ID and refreshes the list.
    ///
    /// - Parameter id: The UUID of the session to delete.
    func deleteSession(_ id: UUID) async {
        do {
            try await sessionManager.deleteSession(id)
            sessions.removeAll { $0.id == id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
