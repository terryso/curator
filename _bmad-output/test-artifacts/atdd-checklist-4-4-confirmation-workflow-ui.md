---
stepsCompleted: ['step-01-preflight-and-context', 'step-02-generation-mode', 'step-03-test-strategy', 'step-04-generate-tests', 'step-04c-aggregate']
lastStep: 'step-04c-aggregate'
lastSaved: '2026-04-23'
storyId: '4.4'
storyKey: '4-4-confirmation-workflow-ui'
storyFile: '_bmad-output/implementation-artifacts/4-4-confirmation-workflow-ui.md'
atddChecklistPath: '_bmad-output/test-artifacts/atdd-checklist-4-4-confirmation-workflow-ui.md'
generatedTestFiles:
  - 'CuratorTests/Features/Confirmation/ConfirmationWorkflowTests.swift'
inputDocuments:
  - '_bmad-output/implementation-artifacts/4-4-confirmation-workflow-ui.md'
  - 'Curator/Core/Operations/OperationManaging.swift'
  - 'Curator/Core/Operations/PlannedOperation.swift'
  - 'Curator/Core/Operations/OperationType.swift'
  - 'Curator/Core/Models/PermissionState.swift'
  - 'Curator/Core/Agent/AgentJob.swift'
  - 'CuratorTests/Core/Operations/BatchRollbackUndoTests.swift'
---

# ATDD Checklist: Story 4.4 — Confirmation Workflow UI

## TDD Red Phase (Current)

Red-phase test scaffolds generated. All tests use `XCTSkipIf(true, ...)` and will compile
but skip execution until the feature is implemented.

## Test File

`CuratorTests/Features/Confirmation/ConfirmationWorkflowTests.swift`

## Acceptance Criteria Coverage

| AC | Description | Tests | Priority |
|----|-------------|-------|----------|
| AC1 | Read-only operations skip confirmation | `testReadOnlyOperationsSkipConfirmation` | P0 |
| AC2 | Write operations show batch confirmation summary | `testWriteOperationsShowBatchConfirmation` | P0 |
| AC3 | Destructive operations require second confirmation | `testDestructiveOperationsShowSecondConfirmation` | P0 |
| AC4 | Confirmation integrates with OperationManager | `testConfirmationCallsBeginBatchThenExecuteBatch` | P0 |
| AC4 | Execution progress updates during batch | `testExecutionProgressUpdates` | P1 |
| AC4 | Execution result shows success/failure | `testExecutionResultShowsSuccessAndFailure` | P1 |
| AC5 | Permission check before confirmation | `testPermissionCheckBeforeConfirmation` | P0 |
| AC5 | Permission denied cancels operation | `testPermissionDeniedCancelsOperation` | P0 |
| -- | Cancel resets all state | `testCancelResetsState` | P1 |
| -- | Undo path displayed in confirmation | `testUndoPathDisplayed` | P1 |
| -- | ConfirmationLevel .none for read-only | `testConfirmationLevelNoneForReadOnly` | P0 |
| -- | ConfirmationLevel .standard for write | `testConfirmationLevelStandardForWrite` | P0 |
| -- | ConfirmationLevel .destructive for delete | `testConfirmationLevelDestructiveForDelete` | P0 |

## Summary Statistics

- **Total tests:** 13
- **P0 tests:** 8
- **P1 tests:** 5
- **All tests skipped:** Yes (TDD red phase)
- **Expected to fail if activated:** Yes
- **Test level:** Unit (ViewModel + model logic)
- **Generation mode:** AI (sequential)
- **Detected stack:** Backend (Swift/XCTest)

## Types Referenced (Not Yet Implemented)

These types must be created during implementation. Tests will not compile until
they exist, even if `XCTSkipIf` is removed.

1. **`ConfirmationLevel`** (enum: `.none`, `.standard`, `.destructive`, `Sendable`)
   - Static method `forOperations(_: )` for auto-detection
   - File: `Curator/Features/Confirmation/ConfirmationLevel.swift`

2. **`ConfirmationRequest`** (struct: `Sendable`)
   - Properties: `operations`, `confirmationLevel`, `summary`, `affectedAssetIDs`, `undoDescription`
   - File: `Curator/Features/Confirmation/ConfirmationRequest.swift`

3. **`ConfirmationViewModel`** (`@Observable @MainActor`)
   - Properties: `request`, `isExecuting`, `executionProgress`, `executionResult`, `showSecondConfirmation`, `needsPermissionUpgrade`
   - Methods: `presentConfirmation(request:)`, `confirm()`, `confirmDestructive()`, `executeOperations()`, `cancel()`, `permissionDenied()`
   - Dependencies: `OperationManaging`, `PermissionState`
   - File: `Curator/Features/Confirmation/ConfirmationViewModel.swift`

4. **`ExecutionResult`** (struct for success/failure counts)

## Next Steps (Task-by-Task Activation)

During implementation of each task:

1. Implement the required types (`ConfirmationLevel`, `ConfirmationRequest`, `ConfirmationViewModel`)
2. Remove `XCTSkipIf(true, ...)` from the relevant test(s)
3. Build and verify the test fails (TDD red confirmation)
4. Implement the feature logic
5. Re-run and verify the test passes (TDD green)
6. Commit passing tests

### Recommended Activation Order

1. **Task 1 first** — Create `ConfirmationLevel` and `ConfirmationRequest` models
   - Activate: `testConfirmationLevelNoneForReadOnly`, `testConfirmationLevelStandardForWrite`, `testConfirmationLevelDestructiveForDelete`
2. **Task 2** — Create `ConfirmationViewModel`
   - Activate: `testReadOnlyOperationsSkipConfirmation`, `testWriteOperationsShowBatchConfirmation`, `testCancelResetsState`
3. **Task 2 (permissions)** — Wire permission checks
   - Activate: `testPermissionCheckBeforeConfirmation`, `testPermissionDeniedCancelsOperation`
4. **Task 2 (destructive)** — Wire destructive confirmation
   - Activate: `testDestructiveOperationsShowSecondConfirmation`
5. **Task 2 (execution)** — Wire OperationManager integration
   - Activate: `testConfirmationCallsBeginBatchThenExecuteBatch`, `testExecutionProgressUpdates`, `testExecutionResultShowsSuccessAndFailure`
6. **Task 2 (undo)** — Wire undo description
   - Activate: `testUndoPathDisplayed`

## Implementation Guidance

### Types to Implement

- `Curator/Features/Confirmation/ConfirmationLevel.swift`
- `Curator/Features/Confirmation/ConfirmationRequest.swift`
- `Curator/Features/Confirmation/ConfirmationViewModel.swift`
- `Curator/Features/Confirmation/BatchConfirmationSummaryView.swift`
- `Curator/Features/Confirmation/DestructiveConfirmationSheet.swift`
- `Curator/Features/Confirmation/ExecutionProgressView.swift`
- `Curator/Features/Confirmation/ExecutionResultView.swift`
- `Curator/Features/Confirmation/PermissionUpgradeView.swift`

### Files to Modify

- `Curator/Features/AgentExecution/AgentExecutionPanel.swift` — integrate confirmation
- `Curator/App/AppDependencies.swift` — register ConfirmationViewModel
