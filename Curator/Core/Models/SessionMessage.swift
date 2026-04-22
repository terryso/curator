import Foundation

/// Role of a message within a session conversation.
///
/// Distinguishes between user instructions and agent responses
/// for proper context reconstruction during multi-turn dialogue.
enum MessageRole: String, Codable, Sendable, Equatable {
    case user
    case assistant
}

/// A single message within a session conversation.
///
/// Value type representing one turn in a multi-turn dialogue.
/// Codable for JSON serialization into SwiftData's messagesData field.
/// Sendable for safe transfer across actor boundaries.
struct SessionMessage: Codable, Sendable, Equatable {
    let id: UUID
    let role: MessageRole
    let content: String
    let timestamp: Date
}
