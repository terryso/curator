import Foundation
import SwiftData

/// SwiftData persistent model for session storage.
///
/// Bridges the value-type `Session` with SwiftData persistence.
/// Messages are stored as JSON-encoded Data to avoid SwiftData
/// relationship complexity and support efficient bulk updates.
@Model
final class SessionEntity {
    @Attribute(.unique) var id: UUID
    var title: String
    var createdAt: Date
    var updatedAt: Date
    @Attribute(.externalStorage) var messagesData: Data?
    var isActive: Bool

    init(
        id: UUID = UUID(),
        title: String = "New Session",
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        messagesData: Data? = nil,
        isActive: Bool = false
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.messagesData = messagesData
        self.isActive = isActive
    }

    /// Convenience getter: decodes messagesData into [SessionMessage].
    var messages: [SessionMessage] {
        guard let data = messagesData else { return [] }
        return (try? JSONDecoder().decode([SessionMessage].self, from: data)) ?? []
    }

    /// Convenience setter: encodes [SessionMessage] into messagesData.
    func setMessages(_ messages: [SessionMessage]) {
        messagesData = try? JSONEncoder().encode(messages)
    }

    /// Converts this entity to a Session value type.
    func toSession() -> Session {
        Session(
            id: id,
            title: title,
            createdAt: createdAt,
            updatedAt: updatedAt,
            messages: messages,
            isActive: isActive
        )
    }

    /// Updates this entity's properties from a Session value type.
    func update(from session: Session) {
        title = session.title
        updatedAt = session.updatedAt
        isActive = session.isActive
        setMessages(session.messages)
    }
}
