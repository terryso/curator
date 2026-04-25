import XCTest
@testable import Curator

// MARK: - ATDD Tests

/// ATDD Tests for Story 6.3 -- Rename Review UI
///
/// Tests verify:
/// - AC1: RenameReviewView displays rename suggestions (FR26, UX-DR5)
/// - AC2: Inline editing of suggested names (FR27)
/// - AC3: Review one at a time with status tracking
@MainActor
final class RenameViewModelTests: XCTestCase {

    // MARK: - Test Helpers

    /// Creates a RenameSuggestion for testing with configurable parameters.
    private func makeSuggestion(
        id: UUID = UUID(),
        originalFileName: String = "IMG_001.jpg",
        suggestedName: String = "sunset-beach.jpg",
        confidence: Double = 0.9,
        analysisDescription: String? = "Golden sunset over ocean waves",
        status: RenameSuggestionStatus = .pending
    ) -> RenameSuggestion {
        RenameSuggestion(
            id: id,
            assetID: AssetID(rawValue: "test-asset-\(id.uuidString)"),
            originalFileName: originalFileName,
            suggestedName: suggestedName,
            confidence: confidence,
            analysisDescription: analysisDescription,
            status: status
        )
    }

    // MARK: - AC1: RenameViewModel Loading and Display (FR26)

    /// [P0] testLoadSuggestionsSetsCorrectCount -- Loading suggestions sets correct count
    ///
    /// AC1: Given rename review flow is initialized,
    /// When ViewModel receives RenameSuggestion list,
    /// Then suggestions property reflects the loaded list.
    func testLoadSuggestionsSetsCorrectCount() throws {
        let viewModel = RenameViewModel()
        let suggestions = [
            makeSuggestion(),
            makeSuggestion(),
            makeSuggestion(),
        ]

        viewModel.loadSuggestions(suggestions)

        XCTAssertEqual(viewModel.suggestions.count, 3,
            "ViewModel should have 3 suggestions after loading 3 suggestions")
    }

    /// [P0] testLoadSuggestionsResetsPreviousState -- Reloading clears previous review decisions
    ///
    /// AC1/AC3: When loading new suggestions, any previous review decisions are cleared
    /// to avoid stale state from a previous rename review session.
    func testLoadSuggestionsResetsPreviousState() throws {
        let viewModel = RenameViewModel()

        // First load
        let suggestion1ID = UUID()
        viewModel.loadSuggestions([makeSuggestion(id: suggestion1ID)])
        viewModel.accept(suggestionID: suggestion1ID)
        XCTAssertEqual(viewModel.reviewedCount, 1)

        // Second load -- should reset
        let suggestion2ID = UUID()
        let suggestion3ID = UUID()
        viewModel.loadSuggestions([
            makeSuggestion(id: suggestion2ID),
            makeSuggestion(id: suggestion3ID),
        ])

        XCTAssertEqual(viewModel.suggestions.count, 2,
            "Suggestions should be replaced, not appended")
        XCTAssertEqual(viewModel.reviewedCount, 0,
            "Review decisions should be reset after reloading suggestions")
        XCTAssertEqual(viewModel.reviewDecisions[suggestion1ID], nil,
            "Old suggestion decision should be cleared after reloading")
    }

    /// [P1] testLoadEmptySuggestionsHandledGracefully -- Empty suggestion list is handled correctly
    ///
    /// AC1: When no rename suggestions exist, the UI shows an empty state.
    /// ViewModel must handle empty lists without errors.
    func testLoadEmptySuggestionsHandledGracefully() throws {
        let viewModel = RenameViewModel()
        viewModel.loadSuggestions([])

        XCTAssertTrue(viewModel.suggestions.isEmpty)
        XCTAssertEqual(viewModel.totalSuggestions, 0)
        XCTAssertEqual(viewModel.reviewedCount, 0)
        XCTAssertFalse(viewModel.allReviewed,
            "allReviewed should be false when there are zero suggestions")
        XCTAssertTrue(viewModel.toRenameOperations().isEmpty,
            "No rename operations when no suggestions loaded")
    }

    // MARK: - AC3: Accept and Reject Operations

    /// [P0] testAcceptSuggestionUpdatesState -- Accepting a suggestion updates review decision
    ///
    /// AC3: Given user is viewing a rename suggestion,
    /// When clicking the accept button,
    /// Then the suggestion is marked as accepted and ViewModel updates in real-time.
    func testAcceptSuggestionUpdatesState() throws {
        let viewModel = RenameViewModel()
        let suggestionID = UUID()
        let suggestions = [makeSuggestion(id: suggestionID)]

        viewModel.loadSuggestions(suggestions)
        viewModel.accept(suggestionID: suggestionID)

        let decision = viewModel.reviewDecisions[suggestionID]
        XCTAssertEqual(decision, .accepted,
            "Suggestion should be in .accepted state after accept")
    }

    /// [P0] testRejectSuggestionUpdatesState -- Rejecting a suggestion updates review decision
    ///
    /// AC3: Given user is viewing a rename suggestion,
    /// When clicking the reject button,
    /// Then the suggestion is marked as rejected and ViewModel updates in real-time.
    func testRejectSuggestionUpdatesState() throws {
        let viewModel = RenameViewModel()
        let suggestionID = UUID()
        let suggestions = [makeSuggestion(id: suggestionID)]

        viewModel.loadSuggestions(suggestions)
        viewModel.reject(suggestionID: suggestionID)

        let decision = viewModel.reviewDecisions[suggestionID]
        XCTAssertEqual(decision, .rejected,
            "Suggestion should be in .rejected state after reject")
    }

    // MARK: - AC2: Inline Editing (FR27)

    /// [P0] testEditSuggestionValid -- Editing to a valid name updates decision
    ///
    /// AC2: Given user is viewing a rename suggestion,
    /// When editing the suggested name to a valid file name,
    /// Then the decision is updated with the edited name.
    func testEditSuggestionValid() throws {
        let viewModel = RenameViewModel()
        let suggestionID = UUID()
        let suggestions = [makeSuggestion(id: suggestionID)]

        viewModel.loadSuggestions(suggestions)
        viewModel.edit(suggestionID: suggestionID, newName: "my-custom-name.jpg")

        let decision = viewModel.reviewDecisions[suggestionID]
        XCTAssertEqual(decision, .edited("my-custom-name.jpg"),
            "Suggestion should be in .edited state with the custom name")
    }

    /// [P0] testEditSuggestionInvalidNameRejected -- Editing to an invalid name is rejected
    ///
    /// AC2: Given user is editing a rename suggestion,
    /// When entering an invalid file name (empty, illegal chars, too long),
    /// Then the edit is rejected and the suggestion retains its previous state.
    func testEditSuggestionInvalidNameRejected() throws {
        let viewModel = RenameViewModel()
        let suggestionID = UUID()
        let suggestions = [makeSuggestion(id: suggestionID)]

        viewModel.loadSuggestions(suggestions)

        // Try to edit with an invalid name containing illegal characters
        viewModel.edit(suggestionID: suggestionID, newName: "bad/file:name.jpg")

        let decision = viewModel.reviewDecisions[suggestionID]
        XCTAssertEqual(decision, .pending,
            "Edit with invalid name should be rejected; decision should remain .pending")
    }

    /// [P0] testFileNameValidationVariousCases -- Various invalid file names are rejected
    ///
    /// AC2: Validates that the ViewModel delegates to RenameSuggestion.isValidFileName
    /// for various edge cases.
    func testFileNameValidationVariousCases() throws {
        let viewModel = RenameViewModel()
        let suggestionID = UUID()
        let suggestions = [makeSuggestion(id: suggestionID)]
        viewModel.loadSuggestions(suggestions)

        // Empty name
        viewModel.edit(suggestionID: suggestionID, newName: "")
        XCTAssertEqual(viewModel.reviewDecisions[suggestionID], .pending,
            "Empty name should be rejected")

        // Name with leading period
        viewModel.edit(suggestionID: suggestionID, newName: ".hidden-file.jpg")
        XCTAssertEqual(viewModel.reviewDecisions[suggestionID], .pending,
            "Name starting with period should be rejected")

        // Name with trailing period
        viewModel.edit(suggestionID: suggestionID, newName: "photo.")
        XCTAssertEqual(viewModel.reviewDecisions[suggestionID], .pending,
            "Name ending with period should be rejected")

        // Name exceeding 200 characters
        let longName = String(repeating: "a", count: 201) + ".jpg"
        viewModel.edit(suggestionID: suggestionID, newName: longName)
        XCTAssertEqual(viewModel.reviewDecisions[suggestionID], .pending,
            "Name exceeding 200 characters should be rejected")

        // Name with pipe character
        viewModel.edit(suggestionID: suggestionID, newName: "photo|landscape.jpg")
        XCTAssertEqual(viewModel.reviewDecisions[suggestionID], .pending,
            "Name with pipe character should be rejected")

        // Valid name should succeed
        viewModel.edit(suggestionID: suggestionID, newName: "valid-photo-name.jpg")
        XCTAssertEqual(viewModel.reviewDecisions[suggestionID], .edited("valid-photo-name.jpg"),
            "Valid name should be accepted")
    }

    // MARK: - AC3: Progress Tracking

    /// [P0] testProgressTracking -- Review progress statistics are accurate
    ///
    /// AC3: ViewModel provides statistics for UI display (Reviewed X / Y suggestions).
    func testProgressTracking() throws {
        let viewModel = RenameViewModel()

        let suggestion1ID = UUID()
        let suggestion2ID = UUID()
        let suggestion3ID = UUID()
        let suggestions = [
            makeSuggestion(id: suggestion1ID),
            makeSuggestion(id: suggestion2ID),
            makeSuggestion(id: suggestion3ID),
        ]

        viewModel.loadSuggestions(suggestions)

        // Initially: all pending
        XCTAssertEqual(viewModel.totalSuggestions, 3)
        XCTAssertEqual(viewModel.reviewedCount, 0,
            "No suggestions reviewed initially")
        XCTAssertEqual(viewModel.acceptedCount, 0,
            "No accepted suggestions initially")

        // Review some
        viewModel.accept(suggestionID: suggestion1ID)
        XCTAssertEqual(viewModel.reviewedCount, 1)
        XCTAssertEqual(viewModel.acceptedCount, 1)

        viewModel.reject(suggestionID: suggestion2ID)
        XCTAssertEqual(viewModel.reviewedCount, 2)
        XCTAssertEqual(viewModel.acceptedCount, 1)

        viewModel.edit(suggestionID: suggestion3ID, newName: "custom-name.jpg")
        XCTAssertEqual(viewModel.reviewedCount, 3)
        XCTAssertEqual(viewModel.acceptedCount, 2,
            "acceptedCount includes accepted and edited suggestions")
    }

    /// [P0] testAllReviewedReturnsFalseWhenPending -- allReviewed is false when suggestions are pending
    ///
    /// AC3: When there are unreviewed suggestions,
    /// Then allReviewed computed property returns false.
    func testAllReviewedReturnsFalseWhenPending() throws {
        let viewModel = RenameViewModel()
        let suggestions = [
            makeSuggestion(),
            makeSuggestion(),
        ]

        viewModel.loadSuggestions(suggestions)

        XCTAssertFalse(viewModel.allReviewed,
            "allReviewed should be false when suggestions are still pending")
    }

    /// [P0] testAllReviewedReturnsTrueWhenAllDone -- allReviewed is true when all suggestions reviewed
    ///
    /// AC3: When all suggestions have been reviewed (accepted, rejected, or edited),
    /// Then allReviewed computed property returns true.
    func testAllReviewedReturnsTrueWhenAllDone() throws {
        let viewModel = RenameViewModel()

        let suggestion1ID = UUID()
        let suggestion2ID = UUID()
        let suggestions = [
            makeSuggestion(id: suggestion1ID),
            makeSuggestion(id: suggestion2ID),
        ]

        viewModel.loadSuggestions(suggestions)
        viewModel.accept(suggestionID: suggestion1ID)
        viewModel.reject(suggestionID: suggestion2ID)

        XCTAssertTrue(viewModel.allReviewed,
            "allReviewed should be true when all suggestions have been reviewed")
    }

    // MARK: - Computed Properties

    /// [P1] testPendingSuggestionsReturnsOnlyUnreviewed -- pendingSuggestions filters correctly
    ///
    /// AC3: Users can filter by review status; pendingSuggestions returns unreviewed suggestions.
    func testPendingSuggestionsReturnsOnlyUnreviewed() throws {
        let viewModel = RenameViewModel()

        let suggestion1ID = UUID()
        let suggestion2ID = UUID()
        let suggestion3ID = UUID()
        let suggestions = [
            makeSuggestion(id: suggestion1ID),
            makeSuggestion(id: suggestion2ID),
            makeSuggestion(id: suggestion3ID),
        ]

        viewModel.loadSuggestions(suggestions)
        viewModel.accept(suggestionID: suggestion1ID)
        viewModel.reject(suggestionID: suggestion2ID)

        let pending = viewModel.pendingSuggestions
        XCTAssertEqual(pending.count, 1,
            "Only 1 suggestion should be pending")
        XCTAssertEqual(pending.first?.id, suggestion3ID,
            "The pending suggestion should be suggestion3")
    }

    /// [P1] testAcceptedCountTracksAcceptedAndEdited -- acceptedCount includes accepted and edited
    ///
    /// AC3: acceptedCount tracks how many suggestions the user has agreed to rename
    /// (either accepted as-is or edited with a custom name).
    func testAcceptedCountTracksAcceptedAndEdited() throws {
        let viewModel = RenameViewModel()

        let suggestion1ID = UUID()
        let suggestion2ID = UUID()
        let suggestion3ID = UUID()
        let suggestions = [
            makeSuggestion(id: suggestion1ID),
            makeSuggestion(id: suggestion2ID),
            makeSuggestion(id: suggestion3ID),
        ]

        viewModel.loadSuggestions(suggestions)
        viewModel.accept(suggestionID: suggestion1ID)
        viewModel.reject(suggestionID: suggestion2ID)
        viewModel.edit(suggestionID: suggestion3ID, newName: "custom.jpg")

        // acceptedCount should include accepted + edited (but not rejected)
        XCTAssertEqual(viewModel.acceptedCount, 2,
            "acceptedCount should include accepted and edited suggestions")
    }

    /// [P1] testProgressTextMatchesExpected -- progressText returns correct display string
    ///
    /// AC3: progressText returns "Reviewed X / Y suggestions" format for UI display.
    func testProgressTextMatchesExpected() throws {
        let viewModel = RenameViewModel()

        let suggestion1ID = UUID()
        let suggestion2ID = UUID()
        let suggestions = [
            makeSuggestion(id: suggestion1ID),
            makeSuggestion(id: suggestion2ID),
        ]

        viewModel.loadSuggestions(suggestions)

        XCTAssertEqual(viewModel.progressText, "Reviewed 0 / 2 suggestions")

        viewModel.accept(suggestionID: suggestion1ID)
        XCTAssertEqual(viewModel.progressText, "Reviewed 1 / 2 suggestions")

        viewModel.reject(suggestionID: suggestion2ID)
        XCTAssertEqual(viewModel.progressText, "Reviewed 2 / 2 suggestions")
    }

    // MARK: - AC3: Overriding Previous Decisions

    /// [P1] testAcceptSameSuggestionTwiceOverridesState -- Latest action wins when accepting again
    ///
    /// AC3: If user rejects a suggestion then accepts it, the latest action takes effect.
    func testAcceptSameSuggestionTwiceOverridesState() throws {
        let viewModel = RenameViewModel()
        let suggestionID = UUID()
        let suggestions = [makeSuggestion(id: suggestionID)]

        viewModel.loadSuggestions(suggestions)

        // Reject then accept
        viewModel.reject(suggestionID: suggestionID)
        XCTAssertEqual(viewModel.reviewDecisions[suggestionID], .rejected)

        viewModel.accept(suggestionID: suggestionID)
        XCTAssertEqual(viewModel.reviewDecisions[suggestionID], .accepted,
            "Latest action should override previous state")
    }

    /// [P1] testEditOverridesPreviousAccept -- Editing overrides a previous accept
    ///
    /// AC2/AC3: If user accepted a suggestion then edits it, the edit takes precedence.
    func testEditOverridesPreviousAccept() throws {
        let viewModel = RenameViewModel()
        let suggestionID = UUID()
        let suggestions = [makeSuggestion(id: suggestionID)]

        viewModel.loadSuggestions(suggestions)
        viewModel.accept(suggestionID: suggestionID)
        XCTAssertEqual(viewModel.reviewDecisions[suggestionID], .accepted)

        viewModel.edit(suggestionID: suggestionID, newName: "better-name.jpg")
        XCTAssertEqual(viewModel.reviewDecisions[suggestionID], .edited("better-name.jpg"),
            "Edit should override previous accept state")
    }

    // MARK: - ReviewDecision Enum

    /// [P0] testReviewDecisionEnumCases -- RenameReviewDecision has all required cases
    ///
    /// AC3: The review decision enum must have pending, accepted, rejected, and edited cases.
    func testReviewDecisionEnumCases() throws {
        let pending: RenameReviewDecision = .pending
        let accepted: RenameReviewDecision = .accepted
        let rejected: RenameReviewDecision = .rejected
        let edited: RenameReviewDecision = .edited("custom-name.jpg")

        // Verify all cases exist and are distinct
        XCTAssertNotEqual(pending, accepted)
        XCTAssertNotEqual(accepted, rejected)
        XCTAssertNotEqual(rejected, edited)
    }

    /// [P0] testReviewDecisionIsSendableAndEquatable -- Review decision conforms to Sendable and Equatable
    ///
    /// AC3: Review decision must be Sendable (for concurrency safety) and Equatable (for comparison).
    func testReviewDecisionIsSendableAndEquatable() async throws {
        // Equatable
        XCTAssertEqual(RenameReviewDecision.pending, RenameReviewDecision.pending)
        XCTAssertNotEqual(RenameReviewDecision.accepted, RenameReviewDecision.rejected)

        // Sendable -- use in async context
        async let decision: RenameReviewDecision = .accepted
        let received = await decision
        XCTAssertEqual(received, .accepted)

        // Equatable for edited with associated value
        XCTAssertEqual(RenameReviewDecision.edited("a.jpg"), RenameReviewDecision.edited("a.jpg"))
        XCTAssertNotEqual(RenameReviewDecision.edited("a.jpg"), RenameReviewDecision.edited("b.jpg"))
    }

    // MARK: - toRenameOperations (Story 6.4 Preparation)

    /// [P1] testToRenameOperationsReturnsCorrectOperations -- toRenameOperations produces PlannedOperations
    ///
    /// AC3: When user has accepted/edited suggestions, toRenameOperations() returns
    /// the corresponding PlannedOperation list with .rename type.
    func testToRenameOperationsReturnsCorrectOperations() throws {
        let viewModel = RenameViewModel()

        let suggestion1ID = UUID()
        let suggestion2ID = UUID()
        let suggestion3ID = UUID()

        let asset1ID = AssetID(rawValue: "test-asset-\(suggestion1ID.uuidString)")
        let asset2ID = AssetID(rawValue: "test-asset-\(suggestion2ID.uuidString)")
        let asset3ID = AssetID(rawValue: "test-asset-\(suggestion3ID.uuidString)")

        let suggestions = [
            RenameSuggestion(
                id: suggestion1ID,
                assetID: asset1ID,
                originalFileName: "IMG_001.jpg",
                suggestedName: "sunset.jpg",
                confidence: 0.9
            ),
            RenameSuggestion(
                id: suggestion2ID,
                assetID: asset2ID,
                originalFileName: "IMG_002.jpg",
                suggestedName: "beach.jpg",
                confidence: 0.8
            ),
            RenameSuggestion(
                id: suggestion3ID,
                assetID: asset3ID,
                originalFileName: "IMG_003.jpg",
                suggestedName: "mountain.jpg",
                confidence: 0.7
            ),
        ]

        viewModel.loadSuggestions(suggestions)
        viewModel.accept(suggestionID: suggestion1ID)
        viewModel.reject(suggestionID: suggestion2ID)
        viewModel.edit(suggestionID: suggestion3ID, newName: "alpine-peak.jpg")

        let operations = viewModel.toRenameOperations()

        // Only accepted and edited suggestions should produce operations (not rejected)
        XCTAssertEqual(operations.count, 2,
            "Only accepted and edited suggestions should produce rename operations")

        // Verify first operation (accepted -- uses suggested name)
        let acceptedOp = operations.first { $0.assetID == asset1ID }
        XCTAssertNotNil(acceptedOp)
        XCTAssertEqual(acceptedOp?.operationType, .rename)
        XCTAssertEqual(acceptedOp?.parameters, .rename(newTitle: "sunset.jpg"))

        // Verify second operation (edited -- uses custom name)
        let editedOp = operations.first { $0.assetID == asset3ID }
        XCTAssertNotNil(editedOp)
        XCTAssertEqual(editedOp?.operationType, .rename)
        XCTAssertEqual(editedOp?.parameters, .rename(newTitle: "alpine-peak.jpg"))

        // Verify rejected suggestion has no operation
        let rejectedOp = operations.first { $0.assetID == asset2ID }
        XCTAssertNil(rejectedOp,
            "Rejected suggestion should not produce a rename operation")
    }

    // MARK: - Batch Operations (Story 6.4 Preparation)

    /// [P1] testMarkAllAsAccept -- Marking all as accept updates all pending suggestions
    ///
    /// AC3: Batch accept updates all pending (unreviewed) suggestions to accepted.
    /// Already-reviewed suggestions are not affected.
    func testMarkAllAsAccept() throws {
        let viewModel = RenameViewModel()

        let suggestion1ID = UUID()
        let suggestion2ID = UUID()
        let suggestion3ID = UUID()
        let suggestions = [
            makeSuggestion(id: suggestion1ID),
            makeSuggestion(id: suggestion2ID),
            makeSuggestion(id: suggestion3ID),
        ]

        viewModel.loadSuggestions(suggestions)

        // Manually reject one first
        viewModel.reject(suggestionID: suggestion1ID)

        // Mark all remaining as accept
        viewModel.markAllAsAccept()

        XCTAssertEqual(viewModel.reviewDecisions[suggestion1ID], .rejected,
            "Already rejected suggestion should remain rejected")
        XCTAssertEqual(viewModel.reviewDecisions[suggestion2ID], .accepted,
            "Pending suggestion should be marked as accepted")
        XCTAssertEqual(viewModel.reviewDecisions[suggestion3ID], .accepted,
            "Pending suggestion should be marked as accepted")
        XCTAssertTrue(viewModel.allReviewed)
    }

    /// [P1] testMarkAllAsReject -- Marking all as reject updates all pending suggestions
    ///
    /// AC3: Batch reject updates all pending (unreviewed) suggestions to rejected.
    /// Already-reviewed suggestions are not affected.
    func testMarkAllAsReject() throws {
        let viewModel = RenameViewModel()

        let suggestion1ID = UUID()
        let suggestion2ID = UUID()
        let suggestion3ID = UUID()
        let suggestions = [
            makeSuggestion(id: suggestion1ID),
            makeSuggestion(id: suggestion2ID),
            makeSuggestion(id: suggestion3ID),
        ]

        viewModel.loadSuggestions(suggestions)

        // Manually accept one first
        viewModel.accept(suggestionID: suggestion1ID)

        // Mark all remaining as reject
        viewModel.markAllAsReject()

        XCTAssertEqual(viewModel.reviewDecisions[suggestion1ID], .accepted,
            "Already accepted suggestion should remain accepted")
        XCTAssertEqual(viewModel.reviewDecisions[suggestion2ID], .rejected,
            "Pending suggestion should be marked as rejected")
        XCTAssertEqual(viewModel.reviewDecisions[suggestion3ID], .rejected,
            "Pending suggestion should be marked as rejected")
        XCTAssertTrue(viewModel.allReviewed)
    }

    // MARK: - Independent Instantiation

    /// [P1] testViewModelCanBeCreatedIndependently -- RenameViewModel can be instantiated standalone
    ///
    /// Integration: The ViewModel must be creatable independently for injection into
    /// AgentExecutionPanel and MainWorkspaceView.
    func testViewModelCanBeCreatedIndependently() throws {
        let viewModel = RenameViewModel()

        XCTAssertTrue(viewModel.suggestions.isEmpty,
            "Newly created ViewModel should have empty suggestions")
        XCTAssertEqual(viewModel.totalSuggestions, 0)
        XCTAssertEqual(viewModel.reviewedCount, 0)
        XCTAssertFalse(viewModel.allReviewed)
        XCTAssertTrue(viewModel.pendingSuggestions.isEmpty)
    }

    // MARK: - Operations on Unknown IDs

    /// [P1] testAcceptUnknownSuggestionIgnored -- Accepting a non-existent ID is a no-op
    ///
    /// AC3: ViewModel should silently ignore operations on unknown suggestion IDs
    /// rather than crashing.
    func testAcceptUnknownSuggestionIgnored() throws {
        let viewModel = RenameViewModel()
        let realID = UUID()
        let fakeID = UUID()
        viewModel.loadSuggestions([makeSuggestion(id: realID)])

        viewModel.accept(suggestionID: fakeID)

        XCTAssertNil(viewModel.reviewDecisions[fakeID],
            "Unknown suggestion ID should not create a decision entry")
        XCTAssertEqual(viewModel.reviewedCount, 0,
            "reviewedCount should remain 0")
    }

    /// [P1] testRejectUnknownSuggestionIgnored -- Rejecting a non-existent ID is a no-op
    func testRejectUnknownSuggestionIgnored() throws {
        let viewModel = RenameViewModel()
        let realID = UUID()
        let fakeID = UUID()
        viewModel.loadSuggestions([makeSuggestion(id: realID)])

        viewModel.reject(suggestionID: fakeID)

        XCTAssertNil(viewModel.reviewDecisions[fakeID])
        XCTAssertEqual(viewModel.reviewedCount, 0)
    }

    /// [P1] testEditUnknownSuggestionIgnored -- Editing a non-existent ID is a no-op
    func testEditUnknownSuggestionIgnored() throws {
        let viewModel = RenameViewModel()
        let realID = UUID()
        let fakeID = UUID()
        viewModel.loadSuggestions([makeSuggestion(id: realID)])

        viewModel.edit(suggestionID: fakeID, newName: "new-name.jpg")

        XCTAssertNil(viewModel.reviewDecisions[fakeID])
        XCTAssertEqual(viewModel.reviewedCount, 0)
    }
}
