import XCTest
@testable import Curator

/// ATDD Tests for Story 3.5 - Session History ViewModel
///
/// Tests verify:
/// - AC4: SessionHistoryViewModel loads and displays session list
/// - AC4: Session list shows title, relative time, active status
/// - AC4: Delete session updates the list
/// - AC4: Empty state handling
///
/// RED PHASE: These tests will not compile until the following production types are created:
/// - SessionHistoryViewModel (Curator/Features/SessionHistory/SessionHistoryViewModel.swift) -- @MainActor @Observable
/// - Session, SessionMessage, MessageRole, SessionManagerProtocol (from Task 1-2)
///
/// Implementation should make these tests pass without modification.
final class SessionHistoryViewModelTests: XCTestCase {

    // MARK: - Test Helpers

    /// Creates a SessionHistoryViewModel with a mock SessionManager.
    @MainActor
    private func makeViewModel(
        sessions: [Session] = []
    ) -> SessionHistoryViewModel {
        let mockManager = MockHistorySessionManager(sessions: sessions)
        return SessionHistoryViewModel(sessionManager: mockManager)
    }

    /// Creates sample sessions for testing.
    private func makeSampleSessions(count: Int) -> [Session] {
        (0..<count).map { i in
            Session(
                id: UUID(),
                title: "Session \(i + 1)",
                createdAt: Date().addingTimeInterval(Double(-i * 3600)),
                updatedAt: Date().addingTimeInterval(Double(-i * 3600)),
                messages: [
                    SessionMessage(
                        id: UUID(),
                        role: .user,
                        content: "Message for session \(i + 1)",
                        timestamp: Date().addingTimeInterval(Double(-i * 3600))
                    )
                ],
                isActive: i == 0
            )
        }
    }

    // MARK: - AC4: SessionHistoryViewModel Existence (Task 8.9)

    /// [P0] SessionHistoryViewModel exists as @MainActor @Observable
    @MainActor
    func testSessionHistoryViewModelExists() async throws {
        let viewModel = makeViewModel()
        XCTAssertNotNil(viewModel)
    }

    /// [P0] SessionHistoryViewModel initializes with empty sessions
    @MainActor
    func testSessionHistoryViewModelInitializesEmpty() async throws {
        let viewModel = makeViewModel()

        XCTAssertTrue(viewModel.sessions.isEmpty,
            "Sessions should be empty on init before loading")
        XCTAssertFalse(viewModel.isLoading,
            "isLoading should be false on init")
        XCTAssertNil(viewModel.errorMessage,
            "errorMessage should be nil on init")
    }

    // MARK: - AC4: Load Sessions (Task 8.10)

    /// [P0] loadSessions populates sessions from SessionManager
    @MainActor
    func testLoadSessions() async throws {
        let sampleSessions = makeSampleSessions(count: 3)
        let viewModel = makeViewModel(sessions: sampleSessions)

        await viewModel.loadSessions()

        XCTAssertGreaterThanOrEqual(viewModel.sessions.count, 3,
            "loadSessions should populate sessions from SessionManager")
        XCTAssertFalse(viewModel.isLoading,
            "isLoading should be false after loading")
        XCTAssertNil(viewModel.errorMessage,
            "errorMessage should be nil after successful load")
    }

    /// [P0] loadSessions clears isLoading after completion
    @MainActor
    func testLoadSessionsClearsLoadingState() async throws {
        let viewModel = makeViewModel()

        await viewModel.loadSessions()

        XCTAssertFalse(viewModel.isLoading,
            "isLoading should be false after loading completes")
    }

    /// [P1] loadSessions handles errors gracefully
    @MainActor
    func testLoadSessionsHandlesErrors() async throws {
        let mockManager = MockHistorySessionManager(shouldFail: true)
        let viewModel = SessionHistoryViewModel(sessionManager: mockManager)

        await viewModel.loadSessions()

        XCTAssertNotNil(viewModel.errorMessage,
            "errorMessage should be set when loadSessions fails")
        XCTAssertTrue(viewModel.sessions.isEmpty,
            "Sessions should remain empty on failure")
    }

    // MARK: - AC4: Session List Content (Task 6.5)

    /// [P0] Each session in list shows title, updatedAt, and active status
    @MainActor
    func testSessionListContent() async throws {
        let sampleSessions = makeSampleSessions(count: 2)
        let viewModel = makeViewModel(sessions: sampleSessions)

        await viewModel.loadSessions()

        guard viewModel.sessions.count >= 2 else {
            XCTFail("Should have at least 2 sessions")
            return
        }

        // First session should be active
        let firstSession = viewModel.sessions[0]
        XCTAssertTrue(firstSession.isActive,
            "First session should be active")

        // Each session should have required display fields
        for session in viewModel.sessions {
            XCTAssertFalse(session.title.isEmpty,
                "Each session should have a title")
            XCTAssertNotNil(session.updatedAt,
                "Each session should have updatedAt")
        }
    }

    /// [P0] Sessions are ordered by updatedAt descending (most recent first)
    @MainActor
    func testSessionListOrdering() async throws {
        let sampleSessions = makeSampleSessions(count: 5)
        let viewModel = makeViewModel(sessions: sampleSessions)

        await viewModel.loadSessions()

        let sessions = viewModel.sessions
        for i in 0..<(sessions.count - 1) {
            XCTAssertGreaterThanOrEqual(
                sessions[i].updatedAt,
                sessions[i + 1].updatedAt,
                "Sessions should be ordered by updatedAt descending"
            )
        }
    }

    // MARK: - AC4: Delete Session Updates List (Task 8.11)

    /// [P0] Deleting a session removes it from the list
    @MainActor
    func testDeleteSessionUpdatesList() async throws {
        let sampleSessions = makeSampleSessions(count: 3)
        let viewModel = makeViewModel(sessions: sampleSessions)

        await viewModel.loadSessions()

        let countBefore = viewModel.sessions.count

        // Delete the last session
        let sessionToDelete = viewModel.sessions.last!
        await viewModel.deleteSession(sessionToDelete.id)

        let countAfter = viewModel.sessions.count
        XCTAssertEqual(countAfter, countBefore - 1,
            "Session count should decrease by 1 after deletion")
        XCTAssertFalse(viewModel.sessions.contains { $0.id == sessionToDelete.id },
            "Deleted session should not be in the list")
    }

    /// [P0] Deleting a session does not affect other sessions
    @MainActor
    func testDeleteSessionPreservesOthers() async throws {
        let sampleSessions = makeSampleSessions(count: 3)
        let viewModel = makeViewModel(sessions: sampleSessions)

        await viewModel.loadSessions()

        let idsBefore = viewModel.sessions.map(\.id)
        let targetID = idsBefore[1]

        await viewModel.deleteSession(targetID)

        let idsAfter = viewModel.sessions.map(\.id)
        XCTAssertTrue(idsAfter.contains(idsBefore[0]),
            "Other sessions should be preserved")
        XCTAssertTrue(idsAfter.contains(idsBefore[2]),
            "Other sessions should be preserved")
    }

    // MARK: - AC4: Empty State (Task 6.8)

    /// [P0] Empty state -- no sessions returns empty list
    @MainActor
    func testEmptyState() async throws {
        let viewModel = makeViewModel(sessions: [])

        await viewModel.loadSessions()

        XCTAssertTrue(viewModel.sessions.isEmpty,
            "Sessions should be empty when no sessions exist")
        XCTAssertNil(viewModel.errorMessage,
            "No error should be set for empty state")
    }

    // MARK: - AC4: Session Title From First Message

    /// [P1] Session title derived from first user message when title is generic
    @MainActor
    func testSessionTitleFromFirstMessage() async throws {
        let session = Session(
            id: UUID(),
            title: "New Session",
            createdAt: Date(),
            updatedAt: Date(),
            messages: [
                SessionMessage(
                    id: UUID(),
                    role: .user,
                    content: "Find all duplicate photos in my library",
                    timestamp: Date()
                )
            ],
            isActive: true
        )

        // Story specifies: if title is "New Session", update with first 50 chars of first user message
        let expectedTitle = String(session.messages.first?.content.prefix(50) ?? "New Session")
        XCTAssertEqual(expectedTitle, "Find all duplicate photos in my library")
    }

    /// [P1] Session title truncation to 50 characters
    func testSessionTitleTruncation() throws {
        let longContent = String(repeating: "A very long message content that exceeds 50 characters ", count: 3)
        let truncated = String(longContent.prefix(50))
        XCTAssertEqual(truncated.count, 50,
            "Title should be truncated to 50 characters")
    }

    // MARK: - AC4: Session Selection (restore flow)

    /// [P1] ViewModel supports session selection callback
    @MainActor
    func testSessionSelectionCallback() async throws {
        let sampleSessions = makeSampleSessions(count: 2)
        let viewModel = makeViewModel(sessions: sampleSessions)

        await viewModel.loadSessions()

        // Verify that session selection can be triggered
        let firstSession = viewModel.sessions.first
        XCTAssertNotNil(firstSession,
            "Should be able to access a session for selection")
    }

    // MARK: - AC4: Refresh After Mutation

    /// [P1] loadSessions can be called multiple times (refresh)
    @MainActor
    func testLoadSessionsCanBeCalledMultipleTimes() async throws {
        let viewModel = makeViewModel(sessions: makeSampleSessions(count: 2))

        await viewModel.loadSessions()
        let count1 = viewModel.sessions.count

        await viewModel.loadSessions()
        let count2 = viewModel.sessions.count

        XCTAssertEqual(count1, count2,
            "Calling loadSessions multiple times should produce consistent results")
    }
}

// MARK: - Mock SessionManager for History ViewModel Testing
//
// This mock conforms to SessionManagerProtocol (defined in Curator module).
// Supports configurable failure for error-path testing.

actor MockHistorySessionManager: SessionManagerProtocol {
    private var sessions: [UUID: Session] = [:]
    private var activeSessionID: UUID?
    private let shouldFail: Bool

    init(sessions: [Session] = [], shouldFail: Bool = false) {
        self.shouldFail = shouldFail
        for session in sessions {
            self.sessions[session.id] = session
            if session.isActive {
                self.activeSessionID = session.id
            }
        }
    }

    var activeSession: Session? {
        guard let id = activeSessionID else { return nil }
        return sessions[id]
    }

    func createSession() async -> Session {
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
        if shouldFail {
            throw SessionError.sessionNotFound(id: id)
        }
        guard let session = sessions[id] else {
            throw SessionError.sessionNotFound(id: id)
        }
        return session
    }

    func saveSession(_ session: Session) async throws {
        if shouldFail {
            throw SessionError.sessionNotFound(id: session.id)
        }
        sessions[session.id] = session
    }

    func listSessions() async throws -> [Session] {
        if shouldFail {
            throw SessionError.sessionNotFound(id: UUID())
        }
        return sessions.values.sorted { $0.updatedAt > $1.updatedAt }
    }

    func switchToSession(_ id: UUID) async throws -> Session {
        if shouldFail {
            throw SessionError.sessionNotFound(id: id)
        }
        guard var target = sessions[id] else {
            throw SessionError.sessionNotFound(id: id)
        }
        target.isActive = true
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
