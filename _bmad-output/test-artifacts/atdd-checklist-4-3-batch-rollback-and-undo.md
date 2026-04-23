---
stepsCompleted: ['step-01-preflight-and-context', 'step-02-generation-mode', 'step-03-test-strategy', 'step-04-generate-tests', 'step-04c-aggregate', 'step-05-validate-and-complete']
lastStep: 'step-05-validate-and-complete'
lastSaved: '2026-04-23'
storyId: '4.3'
storyKey: '4-3-batch-rollback-and-undo'
storyFile: '_bmad-output/implementation-artifacts/4-3-batch-rollback-and-undo.md'
atddChecklistPath: '_bmad-output/test-artifacts/atdd-checklist-4-3-batch-rollback-and-undo.md'
generatedTestFiles:
  - 'CuratorTests/Core/Operations/BatchRollbackUndoTests.swift'
---

# ATDD Checklist: Story 4.3 — Batch Rollback & Undo System

## TDD Red Phase Status

**Phase:** GREEN
**Total Tests:** 8 (all passing)
**Test File:** `CuratorTests/Core/Operations/BatchRollbackUndoTests.swift`
**Full Suite Result:** 607 tests, 0 failures (no regressions)

## Acceptance Criteria Coverage

| AC | Description | Tests | Priority | Status |
|----|------------|-------|----------|--------|
| AC1 | User-triggered batch undo via rollbackLastBatch (FR34, NFR16) | testRollbackLastBatchViaCommandZ, testRollbackCompletesWithin5Seconds | P0 | GREEN |
| AC2 | Mid-failure auto-rollback (FR36) | testPartialFailureAutoRollback | P0 | GREEN |
| AC3 | Bidirectional undo — rollback is undoable | testRedoAfterUndo | P0 | GREEN |
| AC4 | Crash recovery prompt (NFR17) | testDetectIncompleteBatchesOnStartup, testCrashRecoveryPromptShown | P0, P1 | GREEN |
| Edge | No completed batch silent ignore | testNoCompletedBatchSilentlyIgnored | P1 | GREEN |
| Edge | Operation log records rollback | testOperationLogRecordsRollback | P1 | GREEN |

## Test Inventory

### P0 Tests (5)

| Test Method | AC | Description | Activation |
|-------------|-----|-------------|------------|
| testRollbackLastBatchViaCommandZ | AC1 | rollbackLastBatch restores all assets to pre-operation state | Remove `XCTSkipIf(true, ...)` |
| testRollbackCompletesWithin5Seconds | AC1 | NFR16: 100-operation rollback completes in < 5 seconds | Remove `XCTSkipIf(true, ...)` |
| testPartialFailureAutoRollback | AC2 | Batch mid-failure auto-rolls back completed operations | Remove `XCTSkipIf(true, ...)` |
| testRedoAfterUndo | AC3 | reexecuteLastRolledBackBatch restores rolled-back batch | Change `#if false` to `#if true` |
| testDetectIncompleteBatchesOnStartup | AC4 | detectIncompleteBatches finds executing batches after crash | Remove `XCTSkipIf(true, ...)` |

### P1 Tests (3)

| Test Method | AC | Description | Activation |
|-------------|-----|-------------|------------|
| testNoCompletedBatchSilentlyIgnored | AC1 | rollbackLastBatch throws when no completed batch exists | Remove `XCTSkipIf(true, ...)` |
| testOperationLogRecordsRollback | AC3 | SwiftData persists rolledBack status with completedAt | Remove `XCTSkipIf(true, ...)` |
| testCrashRecoveryPromptShown | AC4 | Incomplete batch detection triggers recovery + rollback | Remove `XCTSkipIf(true, ...)` |

## Activation Strategy (Task-by-Task)

Tests reference types and methods that do not yet exist. Activate them in this order as implementation progresses:

### Task 1: Cmd+Z keyboard shortcut + UndoManagerViewModel
**New types needed:** `UndoManagerViewModel` (@MainActor @Observable), keyboard shortcut binding in MainWorkspaceView
**Activate:**
1. `testRollbackLastBatchViaCommandZ` — remove `XCTSkipIf(true, ...)`
2. `testNoCompletedBatchSilentlyIgnored` — remove `XCTSkipIf(true, ...)`

### Task 2: Undo button UI + RollbackProgressView
**New types needed:** `RollbackProgressView`, undo button in toolbar
**No new test activations** (UI components tested via existing MainWorkspaceTests pattern)

### Task 3: Rollback progress UI + result feedback
**No new test activations** (UI-level tests)

### Task 4: Bidirectional undo — reexecuteLastRolledBackBatch
**New types needed:** `reexecuteLastRolledBackBatch` method on `OperationManaging` protocol + `OperationManager` actor
**Activate:**
1. `testRedoAfterUndo` — change `#if false` to `#if true`

### Task 5: Crash recovery detection + prompt
**New types needed:** `CrashRecoverySheet`, startup detection in ViewModel
**Activate:**
1. `testDetectIncompleteBatchesOnStartup` — remove `XCTSkipIf(true, ...)`
2. `testCrashRecoveryPromptShown` — remove `XCTSkipIf(true, ...)`

### Task 6: Performance + logging verification
**Activate:**
1. `testRollbackCompletesWithin5Seconds` — remove `XCTSkipIf(true, ...)`
2. `testOperationLogRecordsRollback` — remove `XCTSkipIf(true, ...)`
3. `testPartialFailureAutoRollback` — remove `XCTSkipIf(true, ...)` (verifies existing 4.2 behavior in 4.3 context)

## Key Risks & Assumptions

1. **reexecuteLastRolledBackBatch**: This method does not exist yet. The `testRedoAfterUndo` test uses `#if false` compile guard and must be changed to `#if true` after the method is added to the `OperationManaging` protocol.
2. **NFR16 (5-second rollback)**: Test uses 100 mock operations with a no-op repository. Real filesystem operations may be slower; performance validation should also be done with real file I/O during integration testing.
3. **Crash recovery**: Tests simulate crash by manually setting batch status to `.executing` via SwiftData. Real crash scenarios may leave inconsistent state.
4. **Delete rollback**: Not directly tested here (covered in Story 4.2 OperationManagerTests). Story 4.3 focuses on the undo/redo flow and crash recovery.
5. **MockRollbackRepo**: Uses `@unchecked Sendable` with DispatchQueue for thread-safe tracking, following the same pattern as `MockPhotoLibraryRepositoryForOperations` in OperationManagerTests.

## Generated Files

- `CuratorTests/Core/Operations/BatchRollbackUndoTests.swift` — 8 test methods covering AC1-AC4

## Input Documents

- `_bmad-output/implementation-artifacts/4-3-batch-rollback-and-undo.md` (story file)
- `Curator/Core/Operations/OperationManaging.swift` (protocol — needs `reexecuteLastRolledBackBatch`)
- `Curator/Core/Operations/OperationManager.swift` (actor — needs reexecute implementation)
- `Curator/Core/Operations/BatchStatus.swift` (enum with `.rolledBack`)
- `Curator/Core/Operations/OperationSnapshot.swift` (value type)
- `Curator/Core/Operations/PlannedOperation.swift` (operation parameters)
- `Curator/Core/Operations/BatchOperation.swift` (batch model)
- `Curator/Infrastructure/Storage/SwiftDataModels.swift` (SwiftData entities)
- `CuratorTests/Core/Operations/OperationManagerTests.swift` (existing 4.2 tests + mock pattern)

## Next Recommended Workflow

Run `bmad-dev-story 4-3` to implement the feature. During implementation, activate tests task-by-task following the activation strategy above.
