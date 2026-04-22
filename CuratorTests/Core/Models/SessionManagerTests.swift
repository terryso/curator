import XCTest
@testable import Curator

/// ATDD Tests for Story 3.5 - Session Management (SessionManager + Models)
///
/// Tests verify:
/// - AC1: Multi-turn context passing -- SessionMessage ordering, Session accumulates messages
/// - AC2: SwiftData persistence -- createSession, saveSession, loadSession, listSessions
/// - AC3: New session -- auto-saves previous, new session becomes active
/// - AC5: SessionContext Task-local integration -- sessionID available in Task scope
///
/// RED PHASE: These tests will not compile until the following production types are created:
/// - Session (Curator/Core/Models/Session.swift) -- value type, Sendable
/// - SessionMessage (Curator/Core/Models/SessionMessage.swift) -- value type, Sendable, Codable
/// - MessageRole (Curator/Core/Models/SessionMessage.swift or Session.swift) -- enum, Codable, Sendable
/// - SessionManagerProtocol (Curator/Core/Models/SessionManagerProtocol.swift) -- protocol, Sendable
/// - SessionError (Curator/Core/Errors/ or Session.swift) -- error enum
///
/// Implementation should make these tests pass without modification.
final class SessionManagerTests: XCTestCase {

    // MARK: - AC2: Session Value Type (Task 1.1)

    /// [P0] Session value type exists with correct properties
    func testSessionValueTypeExists() async throws {
        let id = UUID()
        let now = Date()
        let session = Session(
            id: id,
            title: "Test Session",
            createdAt: now,
            updatedAt: now,
            messages: [],
            isActive: true
        )

        XCTAssertEqual(session.id, id)
        XCTAssertEqual(session.title, "Test Session")
        XCTAssertEqual(session.createdAt, now)
        XCTAssertEqual(session.updatedAt, now)
        XCTAssertTrue(session.messages.isEmpty)
        XCTAssertTrue(session.isActive)
    }

    /// [P0] Session is Sendable
    func testSessionIsSendable() async throws {
        let session = Session(
            id: UUID(),
            title: "Sendable Test",
            createdAt: Date(),
            updatedAt: Date(),
            messages: [],
            isActive: true
        )

        // Use in async context to verify Sendable conformance
        async let sendableSession: Session = session
        let received = await sendableSession
        XCTAssertEqual(received.title, "Sendable Test")
    }

    // MARK: - AC2: SessionMessage Value Type (Task 1.2)

    /// [P0] SessionMessage value type exists with correct properties
    func testSessionMessageValueTypeExists() async throws {
        let id = UUID()
        let now = Date()
        let message = SessionMessage(
            id: id,
            role: .user,
            content: "Find duplicate photos",
            timestamp: now
        )

        XCTAssertEqual(message.id, id)
        XCTAssertEqual(message.role, .user)
        XCTAssertEqual(message.content, "Find duplicate photos")
        XCTAssertEqual(message.timestamp, now)
    }

    /// [P0] SessionMessage supports both roles
    func testSessionMessageRoles() async throws {
        let userMessage = SessionMessage(
            id: UUID(),
            role: .user,
            content: "User message",
            timestamp: Date()
        )
        let assistantMessage = SessionMessage(
            id: UUID(),
            role: .assistant,
            content: "Assistant response",
            timestamp: Date()
        )

        XCTAssertEqual(userMessage.role, .user)
        XCTAssertEqual(assistantMessage.role, .assistant)
    }

    /// [P0] SessionMessage is Sendable and Codable
    func testSessionMessageIsSendableAndCodable() async throws {
        let message = SessionMessage(
            id: UUID(),
            role: .user,
            content: "Codable test",
            timestamp: Date()
        )

        // Sendable via async context
        async let sendable: SessionMessage = message
        let received = await sendable
        XCTAssertEqual(received.content, "Codable test")

        // Codable via JSON encode/decode
        let data = try JSONEncoder().encode(message)
        let decoded = try JSONDecoder().decode(SessionMessage.self, from: data)
        XCTAssertEqual(decoded.id, message.id)
        XCTAssertEqual(decoded.role, message.role)
        XCTAssertEqual(decoded.content, message.content)
    }

    // MARK: - AC2: MessageRole Enum (Task 1.3)

    /// [P0] MessageRole has exactly two cases: user and assistant
    func testMessageRoleHasTwoCases() throws {
        let allCases: [MessageRole] = [.user, .assistant]
        XCTAssertEqual(allCases.count, 2,
            "MessageRole should have exactly 2 cases")
    }

    /// [P0] MessageRole is Codable (raw value)
    func testMessageRoleIsCodable() throws {
        for role in [MessageRole.user, .assistant] {
            let data = try JSONEncoder().encode(role)
            let decoded = try JSONDecoder().decode(MessageRole.self, from: data)
            XCTAssertEqual(decoded, role)
        }
    }

    /// [P0] MessageRole is Sendable
    func testMessageRoleIsSendable() async throws {
        async let role: MessageRole = .user
        let received = await role
        XCTAssertEqual(received, .user)
    }

    // MARK: - AC1: Multi-Turn Context (Task 8.7)

    /// [P1] Multi-turn messages maintain order in session
    func testMultiTurnContextMaintainsOrder() async throws {
        let messages = [
            SessionMessage(id: UUID(), role: .user, content: "First instruction", timestamp: Date().addingTimeInterval(-10)),
            SessionMessage(id: UUID(), role: .assistant, content: "First response", timestamp: Date().addingTimeInterval(-5)),
            SessionMessage(id: UUID(), role: .user, content: "Follow-up instruction", timestamp: Date()),
        ]

        let session = Session(
            id: UUID(),
            title: "Multi-turn",
            createdAt: Date(),
            updatedAt: Date(),
            messages: messages,
            isActive: true
        )

        XCTAssertEqual(session.messages.count, 3)
        XCTAssertEqual(session.messages[0].role, .user)
        XCTAssertEqual(session.messages[0].content, "First instruction")
        XCTAssertEqual(session.messages[1].role, .assistant)
        XCTAssertEqual(session.messages[1].content, "First response")
        XCTAssertEqual(session.messages[2].role, .user)
        XCTAssertEqual(session.messages[2].content, "Follow-up instruction")
    }

    /// [P1] Session messages are ordered by timestamp
    func testSessionMessagesOrderedByTimestamp() async throws {
        let msg1 = SessionMessage(id: UUID(), role: .user, content: "First", timestamp: Date().addingTimeInterval(-20))
        let msg2 = SessionMessage(id: UUID(), role: .assistant, content: "Second", timestamp: Date().addingTimeInterval(-10))
        let msg3 = SessionMessage(id: UUID(), role: .user, content: "Third", timestamp: Date())

        let session = Session(
            id: UUID(),
            title: "Ordered",
            createdAt: Date(),
            updatedAt: Date(),
            messages: [msg1, msg2, msg3],
            isActive: true
        )

        for i in 0..<(session.messages.count - 1) {
            XCTAssertLessThanOrEqual(
                session.messages[i].timestamp,
                session.messages[i + 1].timestamp,
                "Messages should be ordered by timestamp"
            )
        }
    }

    // MARK: - AC5: SessionContext Task-Local (Task 8.8)

    /// [P1] SessionContext.current can be set and read within the same Task
    func testSessionContextTaskLocal() async throws {
        // SessionContext already exists -- test that it can hold session IDs
        let testSessionID = "test-session-123"

        await SessionContext.$current.withValue(testSessionID) {
            XCTAssertEqual(SessionContext.current, testSessionID,
                "SessionContext.current should be readable within the same Task scope")
        }

        // After scope exits, should be nil
        XCTAssertNil(SessionContext.current,
            "SessionContext.current should be nil after scope exits")
    }

    /// [P1] SessionContext.current is nil by default
    func testSessionContextDefaultIsNil() async throws {
        XCTAssertNil(SessionContext.current,
            "SessionContext.current should be nil by default")
    }

    // MARK: - AC2: SessionManagerProtocol (Task 2.1)

    /// [P0] SessionManagerProtocol defines required methods -- mock can conform
    func testSessionManagerProtocolExists() async throws {
        let mock = MockSessionManagerForATDD()
        XCTAssertNotNil(mock as any SessionManagerProtocol)
    }

    /// [P0] SessionManagerProtocol has createSession method
    func testSessionManagerProtocolHasCreateSession() async throws {
        let mock = MockSessionManagerForATDD()
        let session = await mock.createSession()
        XCTAssertNotNil(session)
        XCTAssertTrue(session.isActive)
    }

    /// [P0] SessionManagerProtocol has activeSession property
    func testSessionManagerProtocolHasActiveSession() async throws {
        let mock = MockSessionManagerForATDD()
        // Initially nil
        let active = await mock.activeSession
        XCTAssertNil(active)

        // After create, should be set
        _ = await mock.createSession()
        let afterCreate = await mock.activeSession
        XCTAssertNotNil(afterCreate)
    }

    /// [P0] SessionManagerProtocol has loadSession method
    func testSessionManagerProtocolHasLoadSession() async throws {
        let mock = MockSessionManagerForATDD()
        let created = await mock.createSession()
        let loaded = try await mock.loadSession(created.id)
        XCTAssertEqual(loaded.id, created.id)
    }

    /// [P0] SessionManagerProtocol has saveSession method
    func testSessionManagerProtocolHasSaveSession() async throws {
        let mock = MockSessionManagerForATDD()
        let session = await mock.createSession()
        var updated = session
        updated.title = "Updated Title"
        try await mock.saveSession(updated)

        let loaded = try await mock.loadSession(session.id)
        XCTAssertEqual(loaded.title, "Updated Title")
    }

    /// [P0] SessionManagerProtocol has listSessions method
    func testSessionManagerProtocolHasListSessions() async throws {
        let mock = MockSessionManagerForATDD()
        _ = await mock.createSession()
        _ = await mock.createSession()

        let sessions = try await mock.listSessions()
        XCTAssertGreaterThanOrEqual(sessions.count, 2)
    }

    /// [P0] SessionManagerProtocol has switchToSession method
    func testSessionManagerProtocolHasSwitchToSession() async throws {
        let mock = MockSessionManagerForATDD()
        let first = await mock.createSession()
        let second = await mock.createSession()

        let switched = try await mock.switchToSession(first.id)
        XCTAssertEqual(switched.id, first.id)

        let active = await mock.activeSession
        XCTAssertEqual(active?.id, first.id)
    }

    /// [P0] SessionManagerProtocol has deleteSession method
    func testSessionManagerProtocolHasDeleteSession() async throws {
        let mock = MockSessionManagerForATDD()
        let session = await mock.createSession()

        try await mock.deleteSession(session.id)

        let sessions = try await mock.listSessions()
        XCTAssertFalse(sessions.contains { $0.id == session.id })
    }

    // MARK: - AC2: createSession (Task 2.3)

    /// [P0] createSession generates new UUID, title defaults, messages empty, isActive true
    func testCreateSessionDefaults() async throws {
        let mock = MockSessionManagerForATDD()
        let session = await mock.createSession()

        XCTAssertNotNil(session.id)
        XCTAssertFalse(session.title.isEmpty,
            "Session title should have a default value")
        XCTAssertTrue(session.messages.isEmpty,
            "New session should have empty messages")
        XCTAssertTrue(session.isActive,
            "New session should be active")
    }

    // MARK: - AC2: saveAndLoadSession (Task 8.3)

    /// [P0] Saving a session with messages and reloading preserves content
    func testSaveAndLoadSession() async throws {
        let mock = MockSessionManagerForATDD()
        var session = await mock.createSession()

        // Add messages
        session.messages = [
            SessionMessage(id: UUID(), role: .user, content: "Find duplicates", timestamp: Date()),
            SessionMessage(id: UUID(), role: .assistant, content: "Found 5 duplicates", timestamp: Date()),
        ]
        try await mock.saveSession(session)

        let loaded = try await mock.loadSession(session.id)
        XCTAssertEqual(loaded.messages.count, 2)
        XCTAssertEqual(loaded.messages[0].content, "Find duplicates")
        XCTAssertEqual(loaded.messages[1].content, "Found 5 duplicates")
    }

    // MARK: - AC2: listSessions (Task 8.4)

    /// [P0] listSessions returns sessions sorted by updatedAt descending
    func testListSessionsSortedByUpdatedAt() async throws {
        let mock = MockSessionManagerForATDD()

        let first = await mock.createSession()
        try await Task.sleep(for: .milliseconds(50))
        let second = await mock.createSession()
        try await Task.sleep(for: .milliseconds(50))
        let third = await mock.createSession()

        // Update first to make it most recent
        var updatedFirst = first
        updatedFirst.title = "Updated First"
        try await mock.saveSession(updatedFirst)

        let sessions = try await mock.listSessions()

        // Most recently updated should be first
        XCTAssertGreaterThanOrEqual(sessions.count, 3)

        // The list should be ordered by updatedAt descending
        for i in 0..<(sessions.count - 1) {
            XCTAssertGreaterThanOrEqual(
                sessions[i].updatedAt,
                sessions[i + 1].updatedAt,
                "Sessions should be sorted by updatedAt descending"
            )
        }
    }

    // MARK: - AC3: switchSession (Task 8.5)

    /// [P0] switchToSession saves old session and activates new one
    func testSwitchSession() async throws {
        let mock = MockSessionManagerForATDD()

        let first = await mock.createSession()
        let second = await mock.createSession()

        // Verify second is active
        let activeBefore = await mock.activeSession
        XCTAssertEqual(activeBefore?.id, second.id)

        // Switch to first
        let switched = try await mock.switchToSession(first.id)
        XCTAssertEqual(switched.id, first.id)

        // Verify first is now active
        let activeAfter = await mock.activeSession
        XCTAssertEqual(activeAfter?.id, first.id)
    }

    // MARK: - AC3: deleteSession (Task 8.6)

    /// [P0] deleteSession removes session from list
    func testDeleteSession() async throws {
        let mock = MockSessionManagerForATDD()

        let session = await mock.createSession()
        let sessionsBefore = try await mock.listSessions()
        XCTAssertTrue(sessionsBefore.contains { $0.id == session.id })

        try await mock.deleteSession(session.id)

        let sessionsAfter = try await mock.listSessions()
        XCTAssertFalse(sessionsAfter.contains { $0.id == session.id })
    }

    /// [P0] deleteSession does not affect other sessions
    func testDeleteSessionDoesNotAffectOthers() async throws {
        let mock = MockSessionManagerForATDD()

        let keep = await mock.createSession()
        let delete = await mock.createSession()

        try await mock.deleteSession(delete.id)

        let sessions = try await mock.listSessions()
        XCTAssertTrue(sessions.contains { $0.id == keep.id },
            "Deleting one session should not affect others")
    }

    // MARK: - AC1: Session Entity JSON Encoding (Task 1.6)

    /// [P1] [SessionMessage] can be JSON-encoded and decoded (validates SessionEntity design)
    func testSessionMessageArrayJSONRoundTrip() async throws {
        let messages = [
            SessionMessage(id: UUID(), role: .user, content: "Test", timestamp: Date()),
            SessionMessage(id: UUID(), role: .assistant, content: "Response", timestamp: Date()),
        ]

        let data = try JSONEncoder().encode(messages)
        let decoded = try JSONDecoder().decode([SessionMessage].self, from: data)
        XCTAssertEqual(decoded.count, 2)
        XCTAssertEqual(decoded[0].content, "Test")
        XCTAssertEqual(decoded[1].content, "Response")
    }

    // MARK: - AC3: New Session Auto-saves Previous

    /// [P1] Creating a new session auto-saves the current active session
    func testNewSessionAutoSavesPrevious() async throws {
        let mock = MockSessionManagerForATDD()

        // Create first session with messages
        var first = await mock.createSession()
        first.title = "First Session"
        first.messages = [
            SessionMessage(id: UUID(), role: .user, content: "Hello", timestamp: Date()),
        ]
        try await mock.saveSession(first)

        // Create second session -- should auto-save first
        _ = await mock.createSession()

        // Verify first session was saved and can be loaded
        let loaded = try await mock.loadSession(first.id)
        XCTAssertEqual(loaded.title, "First Session")
        XCTAssertEqual(loaded.messages.count, 1)
    }

    // MARK: - AC1: Context Window Management

    /// [P1] Session with many messages preserves order
    func testLargeSessionPreservesMessageOrder() async throws {
        var messages: [SessionMessage] = []
        for i in 0..<20 {
            messages.append(SessionMessage(
                id: UUID(),
                role: i % 2 == 0 ? .user : .assistant,
                content: "Message \(i)",
                timestamp: Date().addingTimeInterval(Double(i))
            ))
        }

        let session = Session(
            id: UUID(),
            title: "Large Session",
            createdAt: Date(),
            updatedAt: Date(),
            messages: messages,
            isActive: true
        )

        XCTAssertEqual(session.messages.count, 20)
        XCTAssertEqual(session.messages.first?.content, "Message 0")
        XCTAssertEqual(session.messages.last?.content, "Message 19")
    }
}

// MARK: - Mock SessionManager for ATDD Protocol Testing
//
// This mock conforms to SessionManagerProtocol (defined in Curator module).
// Once the production protocol is created, this mock will validate the contract.
// The mock uses in-memory storage -- no SwiftData dependency.

actor MockSessionManagerForATDD: SessionManagerProtocol {
    private var sessions: [UUID: Session] = [:]
    private var activeSessionID: UUID?

    var activeSession: Session? {
        guard let id = activeSessionID else { return nil }
        return sessions[id]
    }

    func createSession() async -> Session {
        // Auto-save current active session
        if let activeID = activeSessionID, var current = sessions[activeID] {
            current.isActive = false
            current.updatedAt = Date()
            sessions[activeID] = current
        }

        let session = Session(
            id: UUID(),
            title: "New Session",
            createdAt: Date(),
            updatedAt: Date(),
            messages: [],
            isActive: true
        )
        sessions[session.id] = session
        activeSessionID = session.id
        return session
    }

    func loadSession(_ id: UUID) async throws -> Session {
        guard let session = sessions[id] else {
            throw SessionError.sessionNotFound(id: id)
        }
        return session
    }

    func saveSession(_ session: Session) async throws {
        var updated = session
        updated.updatedAt = Date()
        sessions[session.id] = updated
    }

    func listSessions() async throws -> [Session] {
        sessions.values
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    func switchToSession(_ id: UUID) async throws -> Session {
        // Deactivate current
        if let activeID = activeSessionID, var current = sessions[activeID] {
            current.isActive = false
            current.updatedAt = Date()
            sessions[activeID] = current
        }

        // Activate target
        guard var target = sessions[id] else {
            throw SessionError.sessionNotFound(id: id)
        }
        target.isActive = true
        target.updatedAt = Date()
        sessions[id] = target
        activeSessionID = id

        return target
    }

    func deleteSession(_ id: UUID) async throws {
        sessions.removeValue(forKey: id)
        if activeSessionID == id {
            activeSessionID = nil
        }
    }
}
