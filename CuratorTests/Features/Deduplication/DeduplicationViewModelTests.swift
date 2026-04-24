import XCTest
@testable import Curator

/// ATDD Tests for Story 5.4 -- Deduplication Review UI
///
/// Tests verify:
/// - AC1: DuplicateReviewView displays duplicate groups (FR21, UX-DR4)
/// - AC2: User reviews groups one at a time with keep/remove actions (FR22)
/// - AC3: Thumbnail loading and scrolling experience (NFR2, NFR8)
/// - AC4: DeduplicationViewModel state management
/// - AC5: Integration with AgentExecutionPanel review state
/// - AC6: Accessibility and keyboard navigation (UX-DR14)
@MainActor
final class DeduplicationViewModelTests: XCTestCase {

    // MARK: - Test Helpers

    /// Creates a DuplicateGroup for testing with configurable parameters.
    private func makeDuplicateGroup(
        id: UUID = UUID(),
        assetCount: Int = 2,
        similarityScore: Double = 0.95,
        reason: String? = "Same scene, different exposure",
        status: DuplicateGroupStatus = .pending
    ) -> DuplicateGroup {
        let assets = (0..<assetCount).map { i in
            PhotoAsset(
                id: AssetID(rawValue: "asset-\(i)-\(id.uuidString.prefix(4))"),
                metadata: AssetMetadata(
                    fileName: "photo\(i).jpg",
                    fileSize: 1_000_000,
                    creationDate: Date(),
                    cameraModel: nil,
                    imageWidth: 4000,
                    imageHeight: 3000,
                    gpsLocation: nil,
                    fileFormat: .jpeg
                ),
                thumbnailData: nil
            )
        }
        return DuplicateGroup(
            id: id,
            assets: assets,
            similarityScore: similarityScore,
            reason: reason,
            thumbnails: [:],
            status: status
        )
    }

    // MARK: - AC4: DeduplicationViewModel State Management

    /// [P0] testLoadGroupsSetsCorrectCount -- Loading groups sets correct count
    ///
    /// AC4: Given dedup review flow is initialized,
    /// When ViewModel receives DuplicateGroup list,
    /// Then groups property reflects the loaded list.
    func testLoadGroupsSetsCorrectCount() {
        let viewModel = DeduplicationViewModel()
        let groups = [
            makeDuplicateGroup(),
            makeDuplicateGroup(),
            makeDuplicateGroup(),
        ]

        viewModel.loadGroups(groups)

        XCTAssertEqual(viewModel.groups.count, 3,
            "ViewModel should have 3 groups after loading 3 groups")
    }

    /// [P0] testMarkAsKeepUpdatesState -- Marking a group as keep updates review state
    ///
    /// AC2: Given user is viewing a duplicate group,
    /// When clicking the keep button,
    /// Then the group is marked as keep and ViewModel updates in real-time.
    func testMarkAsKeepUpdatesState() {
        let viewModel = DeduplicationViewModel()
        let groupID = UUID()
        let groups = [makeDuplicateGroup(id: groupID)]

        viewModel.loadGroups(groups)
        viewModel.markAsKeep(groupID: groupID)

        let state = viewModel.reviewStates[groupID]
        XCTAssertEqual(state, .keep,
            "Group should be in .keep state after markAsKeep")
    }

    /// [P0] testMarkAsRemoveUpdatesState -- Marking a group as remove updates review state
    ///
    /// AC2: Given user is viewing a duplicate group,
    /// When clicking the remove button,
    /// Then the group is marked as remove and ViewModel updates in real-time.
    func testMarkAsRemoveUpdatesState() {
        let viewModel = DeduplicationViewModel()
        let groupID = UUID()
        let groups = [makeDuplicateGroup(id: groupID)]

        viewModel.loadGroups(groups)
        viewModel.markAsRemove(groupID: groupID)

        let state = viewModel.reviewStates[groupID]
        XCTAssertEqual(state, .remove,
            "Group should be in .remove state after markAsRemove")
    }

    /// [P0] testAssetsToRemoveReturnsCorrectIDs -- assetsToRemove returns correct ID list
    ///
    /// AC4/AC5: When user has marked groups for removal,
    /// Then assetsToRemove() returns the asset IDs from those groups
    /// for the batch approval flow (Story 5.5).
    func testAssetsToRemoveReturnsCorrectIDs() {
        let viewModel = DeduplicationViewModel()

        let group1ID = UUID()
        let group2ID = UUID()
        let groups = [
            makeDuplicateGroup(id: group1ID),
            makeDuplicateGroup(id: group2ID),
        ]

        viewModel.loadGroups(groups)

        // Mark group1 as remove, group2 as keep
        viewModel.markAsRemove(groupID: group1ID)
        viewModel.markAsKeep(groupID: group2ID)

        let assetsToRemove = viewModel.assetsToRemove()

        // Should contain assets from group1 only
        XCTAssertEqual(assetsToRemove.count, 2,
            "assetsToRemove should return 2 assets from the single group marked for removal")

        let expectedIDs = groups[0].assets.map(\.id).sorted(by: { $0.rawValue < $1.rawValue })
        let actualIDs = assetsToRemove.sorted(by: { $0.rawValue < $1.rawValue })
        XCTAssertEqual(actualIDs, expectedIDs,
            "assetsToRemove should contain exactly the assets from the group marked for removal")
    }

    /// [P0] testAllReviewedReturnsFalseWhenPending -- allReviewed is false when groups are pending
    ///
    /// AC4: When there are unreviewed groups,
    /// Then allReviewed computed property returns false.
    func testAllReviewedReturnsFalseWhenPending() {
        let viewModel = DeduplicationViewModel()
        let groups = [
            makeDuplicateGroup(),
            makeDuplicateGroup(),
        ]

        viewModel.loadGroups(groups)

        XCTAssertFalse(viewModel.allReviewed,
            "allReviewed should be false when groups are still pending")
    }

    /// [P0] testAllReviewedReturnsTrueWhenAllDone -- allReviewed is true when all groups reviewed
    ///
    /// AC4: When all groups have been reviewed (keep or remove),
    /// Then allReviewed computed property returns true.
    func testAllReviewedReturnsTrueWhenAllDone() {
        let viewModel = DeduplicationViewModel()

        let group1ID = UUID()
        let group2ID = UUID()
        let groups = [
            makeDuplicateGroup(id: group1ID),
            makeDuplicateGroup(id: group2ID),
        ]

        viewModel.loadGroups(groups)
        viewModel.markAsKeep(groupID: group1ID)
        viewModel.markAsRemove(groupID: group2ID)

        XCTAssertTrue(viewModel.allReviewed,
            "allReviewed should be true when all groups have been reviewed")
    }

    // MARK: - AC4: Computed Properties

    /// [P1] testToggleReviewStateCycles -- Toggle cycles through pending -> keep -> remove -> pending
    ///
    /// AC2/AC4: Toggle allows cycling through review states for quick user interaction.
    func testToggleReviewStateCycles() {
        let viewModel = DeduplicationViewModel()
        let groupID = UUID()
        let groups = [makeDuplicateGroup(id: groupID)]

        viewModel.loadGroups(groups)

        // Initial state: pending
        XCTAssertEqual(viewModel.reviewStates[groupID], .pending)

        // pending -> keep
        viewModel.toggleReviewState(groupID: groupID)
        XCTAssertEqual(viewModel.reviewStates[groupID], .keep)

        // keep -> remove
        viewModel.toggleReviewState(groupID: groupID)
        XCTAssertEqual(viewModel.reviewStates[groupID], .remove)

        // remove -> pending
        viewModel.toggleReviewState(groupID: groupID)
        XCTAssertEqual(viewModel.reviewStates[groupID], .pending)
    }

    /// [P1] testComputedPropertiesUpdate -- reviewedCount, totalGroups, markedForRemovalCount correct
    ///
    /// AC4: ViewModel provides statistics for UI display (reviewed X / Y groups).
    func testComputedPropertiesUpdate() {
        let viewModel = DeduplicationViewModel()

        let group1ID = UUID()
        let group2ID = UUID()
        let group3ID = UUID()
        let groups = [
            makeDuplicateGroup(id: group1ID),
            makeDuplicateGroup(id: group2ID),
            makeDuplicateGroup(id: group3ID),
        ]

        viewModel.loadGroups(groups)

        // Initially: all pending
        XCTAssertEqual(viewModel.totalGroups, 3)
        XCTAssertEqual(viewModel.reviewedCount, 0,
            "No groups reviewed initially")
        XCTAssertEqual(viewModel.markedForRemovalCount, 0,
            "No groups marked for removal initially")

        // Review some
        viewModel.markAsKeep(groupID: group1ID)
        XCTAssertEqual(viewModel.reviewedCount, 1)
        XCTAssertEqual(viewModel.markedForRemovalCount, 0)

        viewModel.markAsRemove(groupID: group2ID)
        XCTAssertEqual(viewModel.reviewedCount, 2)
        XCTAssertEqual(viewModel.markedForRemovalCount, 1)

        viewModel.markAsRemove(groupID: group3ID)
        XCTAssertEqual(viewModel.reviewedCount, 3)
        XCTAssertEqual(viewModel.markedForRemovalCount, 2)
    }

    /// [P1] testLoadGroupsResetsPreviousState -- Reloading clears previous review states
    ///
    /// AC4: When loading new groups, any previous review state is cleared
    /// to avoid stale state from a previous dedup session.
    func testLoadGroupsResetsPreviousState() {
        let viewModel = DeduplicationViewModel()

        // First load
        let group1ID = UUID()
        viewModel.loadGroups([makeDuplicateGroup(id: group1ID)])
        viewModel.markAsKeep(groupID: group1ID)
        XCTAssertEqual(viewModel.reviewedCount, 1)

        // Second load -- should reset
        let group2ID = UUID()
        let group3ID = UUID()
        viewModel.loadGroups([
            makeDuplicateGroup(id: group2ID),
            makeDuplicateGroup(id: group3ID),
        ])

        XCTAssertEqual(viewModel.groups.count, 2,
            "Groups should be replaced, not appended")
        XCTAssertEqual(viewModel.reviewedCount, 0,
            "Review states should be reset after reloading groups")
        XCTAssertEqual(viewModel.reviewStates[group1ID], nil,
            "Old group state should be cleared after reloading")
    }

    // MARK: - AC4: pendingGroups and Filtering

    /// [P1] testPendingGroupsReturnsOnlyUnreviewed -- pendingGroups filters correctly
    ///
    /// AC3: Users can filter by review status; pendingGroups returns unreviewed groups.
    func testPendingGroupsReturnsOnlyUnreviewed() {
        let viewModel = DeduplicationViewModel()

        let group1ID = UUID()
        let group2ID = UUID()
        let group3ID = UUID()
        let groups = [
            makeDuplicateGroup(id: group1ID),
            makeDuplicateGroup(id: group2ID),
            makeDuplicateGroup(id: group3ID),
        ]

        viewModel.loadGroups(groups)
        viewModel.markAsKeep(groupID: group1ID)
        viewModel.markAsRemove(groupID: group2ID)

        let pending = viewModel.pendingGroups
        XCTAssertEqual(pending.count, 1,
            "Only 1 group should be pending")
        XCTAssertEqual(pending.first?.id, group3ID,
            "The pending group should be group3")
    }

    // MARK: - AC1: DuplicateGroupReviewState Enum

    /// [P0] testReviewStateEnumCases -- DuplicateGroupReviewState has all required cases
    ///
    /// AC4: The review state enum must have pending, keep, and remove cases.
    func testReviewStateEnumCases() {
        let allCases: [DuplicateGroupReviewState] = [.pending, .keep, .remove]
        XCTAssertEqual(allCases.count, 3,
            "DuplicateGroupReviewState should have exactly 3 cases: pending, keep, remove")
    }

    /// [P0] testReviewStateIsSendableAndEquatable -- Review state conforms to Sendable and Equatable
    ///
    /// AC4: Review state must be Sendable (for concurrency safety) and Equatable (for comparison).
    func testReviewStateIsSendableAndEquatable() async throws {
        // Equatable
        XCTAssertEqual(DuplicateGroupReviewState.pending, DuplicateGroupReviewState.pending)
        XCTAssertNotEqual(DuplicateGroupReviewState.keep, DuplicateGroupReviewState.remove)

        // Sendable -- use in async context
        async let state: DuplicateGroupReviewState = .keep
        let received = await state
        XCTAssertEqual(received, .keep)
    }

    // MARK: - AC5: Integration with AgentExecutionPanel

    /// [P1] testViewModelCanBeCreatedIndependently -- DeduplicationViewModel can be instantiated standalone
    ///
    /// AC5: The ViewModel must be creatable independently for injection into
    /// AgentExecutionPanel and MainWorkspaceView via AppDependencies.
    func testViewModelCanBeCreatedIndependently() {
        let viewModel = DeduplicationViewModel()

        XCTAssertTrue(viewModel.groups.isEmpty,
            "Newly created ViewModel should have empty groups")
        XCTAssertEqual(viewModel.totalGroups, 0)
        XCTAssertEqual(viewModel.reviewedCount, 0)
        XCTAssertFalse(viewModel.allReviewed)
    }

    // MARK: - AC3: Empty State Handling

    /// [P1] testEmptyGroupListHandledCorrectly -- Empty group list is handled gracefully
    ///
    /// AC3: When no duplicate groups exist, the UI shows a friendly message.
    /// ViewModel must handle empty lists without errors.
    func testEmptyGroupListHandledCorrectly() {
        let viewModel = DeduplicationViewModel()
        viewModel.loadGroups([])

        XCTAssertTrue(viewModel.groups.isEmpty)
        XCTAssertEqual(viewModel.totalGroups, 0)
        XCTAssertEqual(viewModel.reviewedCount, 0)
        XCTAssertFalse(viewModel.allReviewed,
            "allReviewed should be false when there are zero groups")
        XCTAssertTrue(viewModel.assetsToRemove().isEmpty,
            "No assets to remove when no groups loaded")
    }

    // MARK: - AC4: Marking Same Group Multiple Times

    /// [P1] testMarkSameGroupTwiceOverridesState -- Latest action wins when marking same group
    ///
    /// AC2: If user marks a group as keep then changes to remove, the latest action takes effect.
    func testMarkSameGroupTwiceOverridesState() {
        let viewModel = DeduplicationViewModel()
        let groupID = UUID()
        let groups = [makeDuplicateGroup(id: groupID)]

        viewModel.loadGroups(groups)

        // Mark as keep, then change to remove
        viewModel.markAsKeep(groupID: groupID)
        XCTAssertEqual(viewModel.reviewStates[groupID], .keep)

        viewModel.markAsRemove(groupID: groupID)
        XCTAssertEqual(viewModel.reviewStates[groupID], .remove,
            "Latest action should override previous state")

        XCTAssertEqual(viewModel.markedForRemovalCount, 1,
            "Group should be counted as marked for removal")
    }

    // MARK: - AC4: assetsToRemove Excludes Kept Groups

    /// [P1] testAssetsToRemoveExcludesKeptGroups -- Only remove-marked groups contribute assets
    ///
    /// AC4/AC5: assetsToRemove only returns assets from groups marked as remove.
    /// Groups marked as keep are excluded.
    func testAssetsToRemoveExcludesKeptGroups() {
        let viewModel = DeduplicationViewModel()

        let group1ID = UUID()
        let group2ID = UUID()
        let group3ID = UUID()
        let groups = [
            makeDuplicateGroup(id: group1ID),
            makeDuplicateGroup(id: group2ID),
            makeDuplicateGroup(id: group3ID),
        ]

        viewModel.loadGroups(groups)
        viewModel.markAsKeep(groupID: group1ID)
        viewModel.markAsRemove(groupID: group2ID)
        // group3 remains pending

        let assetsToRemove = viewModel.assetsToRemove()

        // Only group2's assets should be included
        let expectedCount = groups[1].assets.count
        XCTAssertEqual(assetsToRemove.count, expectedCount,
            "Only group2's assets should be in assetsToRemove (group1 kept, group3 pending)")
    }
}
