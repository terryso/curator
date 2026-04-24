---
stepsCompleted:
  - step-01-preflight-and-context
  - step-02-generation-mode
  - step-03-test-strategy
  - step-04-generate-tests
  - step-04c-aggregate
lastStep: step-04c-aggregate
lastSaved: '2026-04-24'
storyId: '5.6'
storyKey: 5-6-dedup-result-summary
storyFile: _bmad-output/implementation-artifacts/5-6-dedup-result-summary.md
atddChecklistPath: _bmad-output/test-artifacts/atdd-checklist-5-6-dedup-result-summary.md
generatedTestFiles:
  - CuratorTests/Features/ResultSummary/ResultSummaryViewModelTests.swift
inputDocuments:
  - _bmad-output/implementation-artifacts/5-6-dedup-result-summary.md
  - Curator/Features/Confirmation/ConfirmationViewModel.swift
  - Curator/Core/Models/DuplicateGroup.swift
  - Curator/Core/Models/PhotoAsset.swift
  - Curator/Core/Models/AssetMetadata.swift
  - Curator/Core/Models/AssetID.swift
  - Curator/Features/Undo/UndoManagerViewModel.swift
  - Curator/Features/Deduplication/DeduplicationViewModel.swift
  - Curator/Features/Deduplication/BatchApprovalView.swift
  - CuratorTests/Features/Deduplication/BatchApprovalViewModelTests.swift
  - CuratorTests/Features/Confirmation/ConfirmationWorkflowTests.swift
---

# ATDD Checklist: Story 5.6 -- Dedup Result Summary

## TDD Red Phase (Current)

Red-phase test scaffolds generated. All tests are compile-gated with `#if true` and will fail to compile until `ResultSummaryViewModel` is implemented.

- **Unit Tests:** 14 tests (all compile-gated)
- **Test Level:** Unit (ViewModel logic, no UI/E2E)
- **Generation Mode:** AI Generation (backend Swift/XCTest project)

## Acceptance Criteria Coverage

| AC | Description | Tests | Priority |
|----|-------------|-------|----------|
| AC1 | AgentResultSummary display with stats (UX-DR6) | `testPopulateFromSetsCorrectCounts`, `testPopulateFromWithEmptyGroups`, `testPopulateFromIntegratesWithExecutionResult` | P0/P1 |
| AC2 | Disk space saved calculation (UX-DR6) | `testSavedSpaceFormatting`, `testSavedSpaceWithNilFileSizes`, `testSavedSpaceWithZeroRemovals`, `testSavedSpaceSumAcrossMultipleGroups` | P0/P1 |
| AC3 | Celebration animation feedback | `testCelebrationTriggeredOnFullSuccess`, `testCelebrationSkippedOnPartialFailure`, `testCelebrationAutoResets` | P0/P1 |
| AC4 | Undo button triggers rollback (FR34, NFR16) | `testUndoTriggersRollback`, `testUndoDisabledWhenNoActionAvailable` | P0/P1 |
| AC5 | Deduplication history record persistence | `testHistoryRecordSaved` | P1 |
| AC6 | Integration with BatchApprovalView | `testPopulateFromIntegratesWithExecutionResult` | P1 |

## Test Priority Summary

| Priority | Count | Tests |
|----------|-------|-------|
| P0 | 5 | `testPopulateFromSetsCorrectCounts`, `testSavedSpaceFormatting`, `testCelebrationTriggeredOnFullSuccess`, `testCelebrationSkippedOnPartialFailure`, `testUndoTriggersRollback` |
| P1 | 9 | `testCelebrationAutoResets`, `testUndoDisabledWhenNoActionAvailable`, `testHistoryRecordSaved`, `testPopulateFromIntegratesWithExecutionResult`, `testSavedSpaceWithNilFileSizes`, `testSavedSpaceWithZeroRemovals`, `testPopulateFromWithEmptyGroups`, `testSavedSpaceSumAcrossMultipleGroups`, `testPopulateFromIntegratesWithExecutionResult` |

## Generated Files

- `CuratorTests/Features/ResultSummary/ResultSummaryViewModelTests.swift` -- 14 ATDD unit tests

## Types to Implement (Red Phase)

The following types are referenced by tests but do not yet exist:

1. **`ResultSummaryViewModel`** (`@MainActor @Observable`)
   - Properties: `removedCount`, `totalGroups`, `savedSpace: String`, `savedSpaceBytes: Int64`, `duration: TimeInterval`, `date: Date`, `showCelebration: Bool`, `canUndo: Bool`
   - Methods: `populateFrom(result:groups:reviewStates:removedAssetSizes:duration:)`, `performUndo() -> Bool`, `saveToHistory() -> DeduplicationResultRecord`
   - Init: `init(undoManager: UndoManagerViewModel? = nil)`

2. **`DeduplicationResultRecord`** (value type for history)
   - Properties: `id: UUID`, `date: Date`, `removedCount: Int`, `totalGroups: Int`, `savedSpaceBytes: Int64`, `durationSeconds: Double`

3. **`DeduplicationResult`** (SwiftData `@Model`)
   - Properties matching `DeduplicationResultRecord`

## Mock Infrastructure

- `MockResultSummaryUndoManager` -- Mock subclass of `UndoManagerViewModel` with call tracking

## Red Phase Activation Instructions

During implementation of each task:

1. Tests are gated with `#if true` / `#if false` pattern (change `#if false` to `#if true` to activate)
2. Run tests: `xcodebuild test -project Curator.xcodeproj -scheme Curator -destination 'platform=macOS'`
3. Verify the activated test fails first (red), then passes after implementation (green)
4. If any activated tests still fail unexpectedly:
   - Either fix implementation (feature bug)
   - Or fix test (test bug)
5. Commit passing tests

## Architecture Notes

- Tests follow the same `@MainActor` pattern as existing ViewModel tests in the project
- Test helpers (`makeDuplicateGroup`, `makeFullSuccessResult`, `makePartialFailureResult`) match the pattern from `BatchApprovalViewModelTests`
- Mock follows project convention: `private final class Mock*` with `@unchecked Sendable` and `DispatchQueue` for thread safety
- `ResultSummaryViewModel` should be `@MainActor @Observable` per project conventions
- No `Task` naming (project rule: avoid Swift Concurrency name clash)

## NFR Coverage

| NFR | Test Coverage |
|-----|---------------|
| NFR16 (5s rollback) | `testUndoTriggersRollback` -- delegates to UndoManagerViewModel |
| UX-DR6 (AgentResultSummary) | All AC1/AC2 tests |
| UX-DR14 (Accessibility) | `testCelebrationSkippedOnPartialFailure` -- reduce motion check |
| UX-DR17 (Button hierarchy) | Indirectly via AC4 undo button tests |
