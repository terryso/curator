import Foundation
import XCTest

@testable import Curator

/// ATDD Tests for Story 5.6 -- Dedup Result Summary
///
/// Tests verify:
/// - AC1: AgentResultSummary display with stats (UX-DR6)
/// - AC2: Disk space saved calculation (UX-DR6)
/// - AC3: Celebration animation feedback
/// - AC4: Undo button triggers rollback (FR34, NFR16)
/// - AC5: Deduplication history record persistence
/// - AC6: Integration with BatchApprovalView
///
/// **TDD RED PHASE:** Tests reference `ResultSummaryViewModel` and related types
/// that are not yet implemented. Each test is guarded with `#if true` and should
/// remain as red-phase scaffolds. Change guards as needed during implementation.
@MainActor
final class ResultSummaryViewModelTests: XCTestCase {

    // MARK: - Test Helpers

    /// Creates a DuplicateGroup for testing with configurable parameters.
    private func makeDuplicateGroup(
        id: UUID = UUID(),
        assetCount: Int = 2,
        fileSize: Int64? = 1_000_000,
        similarityScore: Double = 0.95,
        reason: String? = "Same scene, different exposure",
        status: DuplicateGroupStatus = .pending
    ) -> DuplicateGroup {
        let assets = (0..<assetCount).map { i in
            PhotoAsset(
                id: AssetID(rawValue: "asset-\(i)-\(id.uuidString.prefix(4))"),
                metadata: AssetMetadata(
                    fileName: "photo\(i).jpg",
                    fileSize: fileSize,
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

    /// Creates an ExecutionResult simulating a full success.
    private func makeFullSuccessResult(count: Int = 5) -> ExecutionResult {
        ExecutionResult(successCount: count, failureCount: 0, total: count)
    }

    /// Creates an ExecutionResult simulating a partial failure.
    private func makePartialFailureResult(successes: Int = 3, failures: Int = 2) -> ExecutionResult {
        ExecutionResult(successCount: successes, failureCount: failures, total: successes + failures)
    }

    // MARK: - AC1: AgentResultSummary Display (UX-DR6)

    /// [P0] testPopulateFromSetsCorrectCounts -- populateFrom correctly sets removed count and group count.
    ///
    /// AC1: Given dedup batch operations are complete,
    /// When the result summary view is shown,
    /// Then AgentResultSummary displays: removed photo count, processed duplicate group count, operation duration.
    /// And result data is computed by ResultSummaryViewModel from ExecutionResult and dedup metadata.
    func testPopulateFromSetsCorrectCounts() throws {
        #if true
        let viewModel = ResultSummaryViewModel()

        let group1ID = UUID()
        let group2ID = UUID()
        let group3ID = UUID()
        let groups = [
            makeDuplicateGroup(id: group1ID, assetCount: 3),
            makeDuplicateGroup(id: group2ID, assetCount: 2),
            makeDuplicateGroup(id: group3ID, assetCount: 4),
        ]

        // Mark group1 and group2 for removal (group3 kept)
        let reviewStates: [UUID: DuplicateGroupReviewState] = [
            group1ID: .remove,
            group2ID: .remove,
            group3ID: .keep,
        ]

        let result = makeFullSuccessResult(count: 5) // 3 + 2 = 5 removed

        // Asset sizes for removed photos
        let removedAssetSizes: [AssetID: Int64] = [
            AssetID(rawValue: "asset-0-\(group1ID.uuidString.prefix(4))"): 2_000_000,
            AssetID(rawValue: "asset-1-\(group1ID.uuidString.prefix(4))"): 1_500_000,
            AssetID(rawValue: "asset-2-\(group1ID.uuidString.prefix(4))"): 3_000_000,
            AssetID(rawValue: "asset-0-\(group2ID.uuidString.prefix(4))"): 1_000_000,
            AssetID(rawValue: "asset-1-\(group2ID.uuidString.prefix(4))"): 2_500_000,
        ]

        viewModel.populateFrom(
            result: result,
            groups: groups,
            reviewStates: reviewStates,
            removedAssetSizes: removedAssetSizes,
            duration: 150.0
        )

        // AC1: Removed count should match success count
        XCTAssertEqual(viewModel.removedCount, 5,
            "Removed count should be 5 (from ExecutionResult.successCount)")

        // AC1: Total groups should reflect processed duplicate groups
        XCTAssertEqual(viewModel.totalGroups, 3,
            "Total groups should be 3 (all groups)")

        // AC1: Duration should be preserved
        XCTAssertEqual(viewModel.duration, 150.0,
            "Duration should match the passed-in value")

        // Date should be set
        XCTAssertNotNil(viewModel.date,
            "Date should be set after populateFrom")
        #else
        throw XCTSkip("RED PHASE: Activate after ResultSummaryViewModel is implemented -- change #if false to #if true")
        #endif
    }

    // MARK: - AC2: Disk Space Saved Calculation (UX-DR6)

    /// [P0] testSavedSpaceFormatting -- ByteCountFormatter correctly formats (B/KB/MB/GB).
    ///
    /// AC2: Given dedup operations have removed photos,
    /// When the result summary is displayed,
    /// Then estimated saved disk space is shown (based on deleted photo file sizes sum),
    /// And space size is displayed in user-friendly format (e.g., "1.2 GB", "345 MB").
    func testSavedSpaceFormatting() throws {
        #if true
        let viewModel = ResultSummaryViewModel()

        // Test KB range
        let groupKB = makeDuplicateGroup(id: UUID(), assetCount: 1, fileSize: 512_000)
        let reviewStatesKB: [UUID: DuplicateGroupReviewState] = [groupKB.id: .remove]
        let sizesKB: [AssetID: Int64] = [groupKB.assets[0].id: 512_000]

        viewModel.populateFrom(
            result: makeFullSuccessResult(count: 1),
            groups: [groupKB],
            reviewStates: reviewStatesKB,
            removedAssetSizes: sizesKB,
            duration: 10.0
        )

        let kbString = viewModel.savedSpace
        XCTAssertTrue(kbString.contains("KB") || kbString.contains("kB"),
            "512 KB should be formatted with KB suffix, got: \(kbString)")

        // Test MB range
        let viewModelMB = ResultSummaryViewModel()
        let groupMB = makeDuplicateGroup(id: UUID(), assetCount: 1, fileSize: 50_000_000)
        let reviewStatesMB: [UUID: DuplicateGroupReviewState] = [groupMB.id: .remove]
        let sizesMB: [AssetID: Int64] = [groupMB.assets[0].id: 50_000_000]

        viewModelMB.populateFrom(
            result: makeFullSuccessResult(count: 1),
            groups: [groupMB],
            reviewStates: reviewStatesMB,
            removedAssetSizes: sizesMB,
            duration: 10.0
        )

        let mbString = viewModelMB.savedSpace
        XCTAssertTrue(mbString.contains("MB"),
            "50 MB should be formatted with MB suffix, got: \(mbString)")

        // Test GB range
        let viewModelGB = ResultSummaryViewModel()
        let groupGB = makeDuplicateGroup(id: UUID(), assetCount: 1, fileSize: 1_500_000_000)
        let reviewStatesGB: [UUID: DuplicateGroupReviewState] = [groupGB.id: .remove]
        let sizesGB: [AssetID: Int64] = [groupGB.assets[0].id: 1_500_000_000]

        viewModelGB.populateFrom(
            result: makeFullSuccessResult(count: 1),
            groups: [groupGB],
            reviewStates: reviewStatesGB,
            removedAssetSizes: sizesGB,
            duration: 10.0
        )

        let gbString = viewModelGB.savedSpace
        XCTAssertTrue(gbString.contains("GB"),
            "1.5 GB should be formatted with GB suffix, got: \(gbString)")
        #else
        throw XCTSkip("RED PHASE: Activate after ResultSummaryViewModel is implemented -- change #if false to #if true")
        #endif
    }

    /// [P1] testSavedSpaceWithNilFileSizes -- Photos with nil fileSize are handled gracefully.
    ///
    /// AC2 edge case: Some photos may have nil fileSize. The calculation should
    /// skip those and only sum available sizes.
    func testSavedSpaceWithNilFileSizes() throws {
        #if true
        let viewModel = ResultSummaryViewModel()

        let groupID = UUID()
        // Create a group where one asset has nil fileSize
        let assets = [
            PhotoAsset(
                id: AssetID(rawValue: "asset-with-size"),
                metadata: AssetMetadata(
                    fileName: "photo1.jpg", fileSize: 2_000_000, creationDate: nil,
                    cameraModel: nil, imageWidth: nil, imageHeight: nil,
                    gpsLocation: nil, fileFormat: nil
                ),
                thumbnailData: nil
            ),
            PhotoAsset(
                id: AssetID(rawValue: "asset-no-size"),
                metadata: AssetMetadata(
                    fileName: "photo2.jpg", fileSize: nil, creationDate: nil,
                    cameraModel: nil, imageWidth: nil, imageHeight: nil,
                    gpsLocation: nil, fileFormat: nil
                ),
                thumbnailData: nil
            ),
        ]
        let group = DuplicateGroup(
            id: groupID, assets: assets, similarityScore: 0.99,
            reason: nil, thumbnails: [:], status: .pending
        )

        let reviewStates: [UUID: DuplicateGroupReviewState] = [groupID: .remove]
        let sizes: [AssetID: Int64] = [
            AssetID(rawValue: "asset-with-size"): 2_000_000,
            // asset-no-size has no entry in removedAssetSizes
        ]

        viewModel.populateFrom(
            result: makeFullSuccessResult(count: 2),
            groups: [group],
            reviewStates: reviewStates,
            removedAssetSizes: sizes,
            duration: 5.0
        )

        // Should still compute saved space from available sizes
        XCTAssertTrue(viewModel.savedSpaceBytes == 2_000_000,
            "Saved space should only count assets with known file sizes, got: \(viewModel.savedSpaceBytes)")
        #else
        throw XCTSkip("RED PHASE: Activate after ResultSummaryViewModel is implemented -- change #if false to #if true")
        #endif
    }

    /// [P1] testSavedSpaceWithZeroRemovals -- Zero removed photos shows zero saved space.
    ///
    /// AC2 edge case: When no photos are removed, saved space should be zero.
    func testSavedSpaceWithZeroRemovals() throws {
        #if true
        let viewModel = ResultSummaryViewModel()

        let groupID = UUID()
        let group = makeDuplicateGroup(id: groupID, assetCount: 2)
        let reviewStates: [UUID: DuplicateGroupReviewState] = [groupID: .keep]

        viewModel.populateFrom(
            result: ExecutionResult(successCount: 0, failureCount: 0, total: 0),
            groups: [group],
            reviewStates: reviewStates,
            removedAssetSizes: [:],
            duration: 0.0
        )

        XCTAssertEqual(viewModel.savedSpaceBytes, 0,
            "Saved space should be 0 when no photos are removed")
        XCTAssertEqual(viewModel.removedCount, 0,
            "Removed count should be 0 when no photos are removed")
        #else
        throw XCTSkip("RED PHASE: Activate after ResultSummaryViewModel is implemented -- change #if false to #if true")
        #endif
    }

    // MARK: - AC3: Celebration Animation Feedback

    /// [P0] testCelebrationTriggeredOnFullSuccess -- isFullSuccess triggers showCelebration = true.
    ///
    /// AC3: Given dedup operations are all successful (ExecutionResult.isFullSuccess == true),
    /// When the result summary is first displayed,
    /// Then ResultSummaryViewModel triggers a brief celebration animation.
    func testCelebrationTriggeredOnFullSuccess() throws {
        #if true
        let viewModel = ResultSummaryViewModel()
        viewModel.reduceMotionOverride = false

        let groupID = UUID()
        let group = makeDuplicateGroup(id: groupID)
        let reviewStates: [UUID: DuplicateGroupReviewState] = [groupID: .remove]

        viewModel.populateFrom(
            result: makeFullSuccessResult(count: 2),
            groups: [group],
            reviewStates: reviewStates,
            removedAssetSizes: [group.assets[0].id: 1_000_000],
            duration: 10.0
        )

        // Full success should trigger celebration
        XCTAssertTrue(viewModel.showCelebration,
            "showCelebration should be true after full success")
        #else
        throw XCTSkip("RED PHASE: Activate after ResultSummaryViewModel is implemented -- change #if false to #if true")
        #endif
    }

    /// [P0] testCelebrationSkippedOnPartialFailure -- Partial failure does not trigger celebration.
    ///
    /// AC3: When there are failures, no celebration animation should play.
    func testCelebrationSkippedOnPartialFailure() throws {
        #if true
        let viewModel = ResultSummaryViewModel()

        let groupID = UUID()
        let group = makeDuplicateGroup(id: groupID)
        let reviewStates: [UUID: DuplicateGroupReviewState] = [groupID: .remove]

        viewModel.populateFrom(
            result: makePartialFailureResult(successes: 3, failures: 2),
            groups: [group],
            reviewStates: reviewStates,
            removedAssetSizes: [group.assets[0].id: 1_000_000],
            duration: 10.0
        )

        // Partial failure should NOT trigger celebration
        XCTAssertFalse(viewModel.showCelebration,
            "showCelebration should be false after partial failure")
        #else
        throw XCTSkip("RED PHASE: Activate after ResultSummaryViewModel is implemented -- change #if false to #if true")
        #endif
    }

    /// [P1] testCelebrationAutoResets -- showCelebration auto-resets to false after 1.5 seconds.
    ///
    /// AC3: The celebration animation should be brief and auto-reset.
    func testCelebrationAutoResets() async throws {
        #if true
        let viewModel = ResultSummaryViewModel()
        viewModel.reduceMotionOverride = false

        let groupID = UUID()
        let group = makeDuplicateGroup(id: groupID)
        let reviewStates: [UUID: DuplicateGroupReviewState] = [groupID: .remove]

        viewModel.populateFrom(
            result: makeFullSuccessResult(count: 2),
            groups: [group],
            reviewStates: reviewStates,
            removedAssetSizes: [group.assets[0].id: 1_000_000],
            duration: 10.0
        )

        // Celebration should be triggered initially
        XCTAssertTrue(viewModel.showCelebration,
            "showCelebration should be true initially")

        // Wait for auto-reset (1.5 seconds + small buffer)
        try await Task.sleep(for: .milliseconds(2000))

        // Celebration should have auto-reset
        XCTAssertFalse(viewModel.showCelebration,
            "showCelebration should auto-reset to false after 1.5 seconds")
        #else
        throw XCTSkip("RED PHASE: Activate after ResultSummaryViewModel is implemented -- change #if false to #if true")
        #endif
    }

    // MARK: - AC4: Undo Button (FR34, NFR16)

    /// [P0] testUndoTriggersRollback -- Undo button calls UndoManagerViewModel.performUndoAction().
    ///
    /// AC4: Given the result summary is displayed,
    /// When the user clicks the undo button,
    /// Then the system rolls back the dedup operation via UndoManagerViewModel.performUndoAction(),
    /// And all removed photos are restored from macOS Trash to their original locations,
    /// And rollback completes within 5 seconds (NFR16).
    func testUndoTriggersRollback() async throws {
        #if true
        let mockUndoManager = MockResultSummaryUndoManager()
        let viewModel = ResultSummaryViewModel(undoManager: mockUndoManager)

        let groupID = UUID()
        let group = makeDuplicateGroup(id: groupID)
        let reviewStates: [UUID: DuplicateGroupReviewState] = [groupID: .remove]

        viewModel.populateFrom(
            result: makeFullSuccessResult(count: 2),
            groups: [group],
            reviewStates: reviewStates,
            removedAssetSizes: [group.assets[0].id: 1_000_000],
            duration: 10.0
        )

        // Trigger undo
        let success = await viewModel.performUndo()

        XCTAssertTrue(success, "Undo should return true on success")
        XCTAssertTrue(mockUndoManager.performUndoActionCalled,
            "UndoManagerViewModel.performUndoAction() should be called")
        #else
        throw XCTSkip("RED PHASE: Activate after ResultSummaryViewModel is implemented -- change #if false to #if true")
        #endif
    }

    /// [P1] testUndoDisabledWhenNoActionAvailable -- Undo is disabled when no action available.
    ///
    /// AC4 edge case: When UndoManagerViewModel.canPerformAction is false,
    /// the undo button should be disabled.
    func testUndoDisabledWhenNoActionAvailable() throws {
        #if true
        let mockUndoManager = MockResultSummaryUndoManager()
        mockUndoManager.mockCanPerformAction = false

        let viewModel = ResultSummaryViewModel(undoManager: mockUndoManager)

        XCTAssertFalse(viewModel.canUndo,
            "canUndo should be false when UndoManager cannot perform action")
        #else
        throw XCTSkip("RED PHASE: Activate after ResultSummaryViewModel is implemented -- change #if false to #if true")
        #endif
    }

    // MARK: - AC5: Deduplication History Record

    /// [P1] testHistoryRecordSaved -- History record is correctly persisted on completion.
    ///
    /// AC5: Given user completes a dedup flow,
    /// When viewing history (session history or after summary is collapsed),
    /// Then this dedup result is recorded, containing date, processed group count,
    /// removed photo count, and saved space,
    /// And the record is persisted to SwiftData.
    func testHistoryRecordSaved() async throws {
        #if true
        let viewModel = ResultSummaryViewModel()

        let group1ID = UUID()
        let group2ID = UUID()
        let groups = [
            makeDuplicateGroup(id: group1ID, assetCount: 3, fileSize: 1_000_000),
            makeDuplicateGroup(id: group2ID, assetCount: 2, fileSize: 2_000_000),
        ]
        let reviewStates: [UUID: DuplicateGroupReviewState] = [
            group1ID: .remove,
            group2ID: .remove,
        ]
        let sizes: [AssetID: Int64] = [
            groups[0].assets[0].id: 1_000_000,
            groups[0].assets[1].id: 1_000_000,
            groups[0].assets[2].id: 1_000_000,
            groups[1].assets[0].id: 2_000_000,
            groups[1].assets[1].id: 2_000_000,
        ]

        viewModel.populateFrom(
            result: makeFullSuccessResult(count: 5),
            groups: groups,
            reviewStates: reviewStates,
            removedAssetSizes: sizes,
            duration: 120.0
        )

        // Save history record
        let record = viewModel.saveToHistory()

        // Verify record fields
        XCTAssertEqual(record.removedCount, 5,
            "History record should have correct removed count")
        XCTAssertEqual(record.totalGroups, 2,
            "History record should have correct group count (only removed groups)")
        XCTAssertEqual(record.savedSpaceBytes, 7_000_000,
            "History record should have correct saved space bytes")
        XCTAssertEqual(record.durationSeconds, 120.0,
            "History record should have correct duration")
        XCTAssertNotNil(record.date,
            "History record should have a date")
        #else
        throw XCTSkip("RED PHASE: Activate after ResultSummaryViewModel is implemented -- change #if false to #if true")
        #endif
    }

    // MARK: - AC6: Integration with BatchApprovalView

    /// [P1] testPopulateFromIntegratesWithExecutionResult -- populateFrom correctly consumes ExecutionResult.
    ///
    /// AC6: Given BatchApprovalView shows execution result (resultSummary area),
    /// When user clicks "Dismiss",
    /// Then BatchApprovalView's result summary is replaced by the full AgentResultSummary,
    /// And AgentResultSummary is shown as the final step in the Agent execution panel.
    func testPopulateFromIntegratesWithExecutionResult() throws {
        #if true
        // Simulate the integration flow:
        // 1. ConfirmationViewModel has an ExecutionResult
        // 2. ResultSummaryViewModel.populateFrom consumes it
        // 3. ResultSummaryViewModel has all the data needed for display

        let confirmationVM = ConfirmationViewModel()
        // Manually set the execution result (simulating batch completion)
        // Note: executionResult is @Observable, so we set it directly in test
        // In production this is set after batch execution completes

        let viewModel = ResultSummaryViewModel()
        viewModel.reduceMotionOverride = false

        let groupID = UUID()
        let group = makeDuplicateGroup(id: groupID, assetCount: 2, fileSize: 5_000_000)
        let reviewStates: [UUID: DuplicateGroupReviewState] = [groupID: .remove]
        let sizes: [AssetID: Int64] = [
            group.assets[0].id: 5_000_000,
            group.assets[1].id: 5_000_000,
        ]

        let result = ExecutionResult(successCount: 2, failureCount: 0, total: 2)

        viewModel.populateFrom(
            result: result,
            groups: [group],
            reviewStates: reviewStates,
            removedAssetSizes: sizes,
            duration: 30.0
        )

        // Verify all data is populated for the view to render
        XCTAssertEqual(viewModel.removedCount, 2)
        XCTAssertEqual(viewModel.totalGroups, 1)
        XCTAssertEqual(viewModel.savedSpaceBytes, 10_000_000)
        XCTAssertEqual(viewModel.duration, 30.0)
        XCTAssertTrue(viewModel.showCelebration) // isFullSuccess
        #else
        throw XCTSkip("RED PHASE: Activate after ResultSummaryViewModel is implemented -- change #if false to #if true")
        #endif
    }

    // MARK: - P1: Edge Cases

    /// [P1] testPopulateFromWithEmptyGroups -- populateFrom handles empty groups gracefully.
    ///
    /// Edge case: No groups loaded or analyzed.
    func testPopulateFromWithEmptyGroups() throws {
        #if true
        let viewModel = ResultSummaryViewModel()

        viewModel.populateFrom(
            result: ExecutionResult(successCount: 0, failureCount: 0, total: 0),
            groups: [],
            reviewStates: [:],
            removedAssetSizes: [:],
            duration: 0.0
        )

        XCTAssertEqual(viewModel.removedCount, 0,
            "Removed count should be 0 with empty groups")
        XCTAssertEqual(viewModel.totalGroups, 0,
            "Total groups should be 0 with empty groups")
        XCTAssertEqual(viewModel.savedSpaceBytes, 0,
            "Saved space should be 0 with empty groups")
        XCTAssertFalse(viewModel.showCelebration,
            "No celebration with empty result")
        #else
        throw XCTSkip("RED PHASE: Activate after ResultSummaryViewModel is implemented -- change #if false to #if true")
        #endif
    }

    /// [P1] testSavedSpaceSumAcrossMultipleGroups -- Saved space is correctly summed across multiple removed groups.
    ///
    /// AC2: Verifies correct accumulation of file sizes across multiple groups.
    func testSavedSpaceSumAcrossMultipleGroups() throws {
        #if true
        let viewModel = ResultSummaryViewModel()

        let g1 = UUID()
        let g2 = UUID()
        let g3 = UUID()
        let groups = [
            makeDuplicateGroup(id: g1, assetCount: 2, fileSize: 1_000_000),
            makeDuplicateGroup(id: g2, assetCount: 1, fileSize: 5_000_000),
            makeDuplicateGroup(id: g3, assetCount: 3, fileSize: 500_000),
        ]

        let reviewStates: [UUID: DuplicateGroupReviewState] = [
            g1: .remove,
            g2: .keep,
            g3: .remove,
        ]

        let sizes: [AssetID: Int64] = [
            groups[0].assets[0].id: 1_000_000,
            groups[0].assets[1].id: 1_000_000,
            // g2 is kept -- not included
            groups[2].assets[0].id: 500_000,
            groups[2].assets[1].id: 500_000,
            groups[2].assets[2].id: 500_000,
        ]

        viewModel.populateFrom(
            result: ExecutionResult(successCount: 5, failureCount: 0, total: 5),
            groups: groups,
            reviewStates: reviewStates,
            removedAssetSizes: sizes,
            duration: 45.0
        )

        // g1: 2 * 1MB = 2MB, g3: 3 * 500KB = 1.5MB = total 3.5MB
        XCTAssertEqual(viewModel.savedSpaceBytes, 3_500_000,
            "Saved space should be sum of all removed groups' assets: 3,500,000 bytes")
        XCTAssertEqual(viewModel.removedCount, 5,
            "Removed count should be 5 (2 from g1 + 3 from g3)")
        #else
        throw XCTSkip("RED PHASE: Activate after ResultSummaryViewModel is implemented -- change #if false to #if true")
        #endif
    }
}

// MARK: - Mock UndoCapability for Result Summary Tests

/// Mock implementation of UndoCapability for Story 5.6 result summary tests.
/// Tracks method calls and simulates undo behavior without real file operations.
@MainActor
private final class MockResultSummaryUndoManager: UndoCapability {

    private let queue = DispatchQueue(label: "MockResultSummaryUndoManager")

    private var _performUndoActionCalled = false
    var mockCanPerformAction = true

    var performUndoActionCalled: Bool { queue.sync { _performUndoActionCalled } }

    var canPerformAction: Bool {
        mockCanPerformAction
    }

    func performUndoAction() async -> Bool {
        queue.sync { _performUndoActionCalled = true }
        return true
    }
}
