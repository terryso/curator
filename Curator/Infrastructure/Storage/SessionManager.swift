import Foundation
import SwiftData

/// Actor-isolated session manager using SwiftData for persistence.
///
/// All SwiftData operations execute within this actor's isolation context,
/// ensuring thread-safe access to the ModelContext without blocking the MainActor.
/// Consumers interact through the SessionManagerProtocol.
actor SessionManager: SessionManagerProtocol {

    // MARK: - Properties

    /// The SwiftData model context for all persistence operations.
    private let modelContext: ModelContext

    /// In-memory cache of the active session ID for fast access.
    private var activeSessionID: UUID?

    // MARK: - Initialization

    /// Creates a SessionManager with the given SwiftData ModelContext.
    ///
    /// - Parameter modelContext: A ModelContext configured with SessionEntity in the schema.
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - SessionManagerProtocol

    var activeSession: Session? {
        guard let id = activeSessionID else { return nil }
        return loadSessionEntity(id: id)?.toSession()
    }

    func createSession() async -> Session {
        // Auto-save and deactivate current active session
        if let currentID = activeSessionID,
           let entity = loadSessionEntity(id: currentID) {
            entity.isActive = false
            entity.updatedAt = Date()
        }

        let session = Session(
            id: UUID(),
            title: "New Session",
            createdAt: Date(),
            updatedAt: Date(),
            messages: [],
            isActive: true
        )

        let entity = SessionEntity()
        entity.id = session.id
        entity.title = session.title
        entity.createdAt = session.createdAt
        entity.updatedAt = session.updatedAt
        entity.isActive = true
        entity.setMessages([])

        modelContext.insert(entity)

        activeSessionID = session.id
        return session
    }

    func loadSession(_ id: UUID) async throws -> Session {
        guard let entity = loadSessionEntity(id: id) else {
            throw SessionError.sessionNotFound(id: id)
        }
        return entity.toSession()
    }

    func saveSession(_ session: Session) async throws {
        let entity: SessionEntity
        if let existing = loadSessionEntity(id: session.id) {
            entity = existing
        } else {
            entity = SessionEntity()
            entity.id = session.id
            entity.createdAt = session.createdAt
            modelContext.insert(entity)
        }
        entity.update(from: session)
    }

    func listSessions() async throws -> [Session] {
        let descriptor = FetchDescriptor<SessionEntity>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        let entities = try modelContext.fetch(descriptor)
        return entities.map { $0.toSession() }
    }

    func switchToSession(_ id: UUID) async throws -> Session {
        // Deactivate current active session
        if let currentID = activeSessionID,
           let currentEntity = loadSessionEntity(id: currentID) {
            currentEntity.isActive = false
            currentEntity.updatedAt = Date()
        }

        // Activate target session
        guard let targetEntity = loadSessionEntity(id: id) else {
            throw SessionError.sessionNotFound(id: id)
        }
        targetEntity.isActive = true
        targetEntity.updatedAt = Date()

        activeSessionID = id
        return targetEntity.toSession()
    }

    func deleteSession(_ id: UUID) async throws {
        guard let entity = loadSessionEntity(id: id) else { return }
        modelContext.delete(entity)

        if activeSessionID == id {
            activeSessionID = nil
        }
    }

    // MARK: - Private Helpers

    /// Loads a SessionEntity by UUID from SwiftData.
    private func loadSessionEntity(id: UUID) -> SessionEntity? {
        let descriptor = FetchDescriptor<SessionEntity>(
            predicate: #Predicate<SessionEntity> { $0.id == id }
        )
        return try? modelContext.fetch(descriptor).first
    }
}
