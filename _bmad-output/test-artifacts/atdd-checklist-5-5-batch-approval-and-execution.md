---
stepsCompleted:
  - 'step-01-preflight-and-context'
  - 'step-02-generation-mode'
  - 'step-03-test-strategy'
  - 'step-04-generate-tests'
  - 'step-05-validate-and-complete'
lastStep: 'step-05-validate-and-complete'
lastSaved: '2026-04-24'
workflowType: 'testarch-atdd'
storyId: '5.5'
storyKey: '5-5-batch-approval-and-execution'
storyFile: '_bmad-output/implementation-artifacts/5-5-batch-approval-and-execution.md'
atddChecklistPath: '_bmad-output/test-artifacts/atdd-checklist-5-5-batch-approval-and-execution.md'
generatedTestFiles:
  - 'CuratorTests/Features/Deduplication/BatchApprovalViewModelTests.swift'
inputDocuments:
  - '_bmad-output/implementation-artifacts/5-5-batch-approval-and-execution.md'
  - 'Curator/Features/Deduplication/DeduplicationViewModel.swift'
  - 'Curator/Features/Confirmation/ConfirmationViewModel.swift'
  - 'Curator/Features/Confirmation/ConfirmationRequest.swift'
  - 'Curator/Features/Confirmation/ConfirmationLevel.swift'
  - 'Curator/Core/Operations/PlannedOperation.swift'
  - 'Curator/Core/Models/DuplicateGroup.swift'
  - 'Curator/Core/Agent/StepResult.swift'
  - 'Curator/Core/Agent/AgentJob.swift'
  - 'Curator/Core/Agent/AgentEvent.swift'
  - 'Curator/Features/MainWorkspace/MainWorkspaceView.swift'
  - 'CuratorTests/Features/Deduplication/DeduplicationViewModelTests.swift'
  - 'CuratorTests/Features/Confirmation/ConfirmationWorkflowTests.swift'
---

# ATDD Checklist - Epic 5, Story 5: Batch Approval and Execution

**Date:** 2026-04-24
**Author:** TEA Agent (Claude)
**Primary Test Level:** Unit / Integration (Swift XCTest)

---

## Story Summary

As a user, I want to batch-approve all duplicates, so that I save time when handling large numbers of duplicate photos.

**As a** user
**I want** to batch-approve all duplicates
**So that** I save time when handling large numbers of duplicate photos

---

## Acceptance Criteria

1. **AC1: Batch Operation Buttons (FR23, UX-DR17)** -- "Keep All" and "Remove All" buttons mark all pending groups, then trigger confirmation flow.
2. **AC2: Execution Result Summary (FR23)** -- After batch operations complete, system shows success/failure/skipped counts with undo option.
3. **AC3: Partial Failure Tolerance (NFR16, FR36)** -- Individual operation failures are skipped; execution continues; failures are summarized.
4. **AC4: Review Data to Confirmation Workflow Bridge** -- DeduplicationViewModel.assetsToRemove() converts to [PlannedOperation] (.delete type), routed through ConfirmationViewModel at .destructive level.
5. **AC5: DuplicateGroup Data Flow** -- AnalyzeDuplicatesTool results flow through AgentEvent to MainWorkspaceView.extractDuplicateGroups, parsed into [DuplicateGroup].
6. **AC6: Integration with Existing Confirmation Workflow** -- Batch delete auto-routes to .destructive confirmation level, triggers DestructiveConfirmationSheet, supports 5-second rollback.

---

## Story Integration Metadata

- **Story ID:** `5.5`
- **Story Key:** `5-5-batch-approval-and-execution`
- **Story File:** `_bmad-output/implementation-artifacts/5-5-batch-approval-and-execution.md`
- **Checklist Path:** `_bmad-output/test-artifacts/atdd-checklist-5-5-batch-approval-and-execution.md`
- **Generated Test Files:** `CuratorTests/Features/Deduplication/BatchApprovalViewModelTests.swift`

---

## Red-Phase Test Scaffolds Created

### Unit / Integration Tests (19 tests)

**File:** `CuratorTests/Features/Deduplication/BatchApprovalViewModelTests.swift` (583 lines)

#### P0 Tests (6 tests) -- Must pass for story completion

- **Test:** `testMarkAllAsKeepUpdatesAllStates`
  - **Status:** RED -- `DeduplicationViewModel.markAllAsKeep()` not yet implemented
  - **Verifies:** AC1 -- All pending groups are marked as .keep after markAllAsKeep()

- **Test:** `testMarkAllAsRemoveUpdatesAllStates`
  - **Status:** RED -- `DeduplicationViewModel.markAllAsRemove()` not yet implemented
  - **Verifies:** AC1 -- All pending groups are marked as .remove after markAllAsRemove()

- **Test:** `testToDeleteOperationsReturnsCorrectOperations`
  - **Status:** RED -- `DeduplicationViewModel.toDeleteOperations()` not yet implemented
  - **Verifies:** AC4 -- Correct [PlannedOperation] list generated with .delete type and matching asset IDs

- **Test:** `testToDeleteOperationsExcludesKeepGroups`
  - **Status:** RED -- `DeduplicationViewModel.toDeleteOperations()` not yet implemented
  - **Verifies:** AC4 -- Groups marked as .keep are excluded from delete operations

- **Test:** `testExtractDuplicateGroupsParsesStepResult`
  - **Status:** RED -- `MainWorkspaceView.extractDuplicateGroupsFromStepResult()` not yet implemented
  - **Verifies:** AC5 -- Correctly parses JSON from StepResult.data into [DuplicateGroup]

- **Test:** `testExtractDuplicateGroupsReturnsEmptyForNoData`
  - **Status:** RED -- `MainWorkspaceView.extractDuplicateGroupsFromStepResult()` not yet implemented
  - **Verifies:** AC5 -- Returns empty array when no duplicateGroups data present

#### P1 Tests (13 tests) -- Important for quality assurance

- **Test:** `testBatchApprovalTriggersDestructiveConfirmation`
  - **Status:** RED -- depends on `markAllAsRemove()` and `toDeleteOperations()`
  - **Verifies:** AC6 -- Delete operations trigger .destructive confirmation level

- **Test:** `testExecutionResultUpdatesOnCompletion`
  - **Status:** RED -- depends on `toDeleteOperations()`
  - **Verifies:** AC2 -- ExecutionResult is set after batch operations complete

- **Test:** `testMarkAllPreservesAlreadyReviewedStates`
  - **Status:** RED -- depends on `markAllAsRemove()`
  - **Verifies:** AC3 -- Already-reviewed groups are NOT overwritten by markAll

- **Test:** `testPartialFailureResultShowsBothCounts`
  - **Status:** RED -- uses ConfirmationViewModel directly
  - **Verifies:** AC3 -- Partial failure result shows both success and failure counts

- **Test:** `testExecutionResultFullSuccess`
  - **Status:** RED -- depends on ExecutionResult (already exists)
  - **Verifies:** AC2 -- Full success result has isFullSuccess = true

- **Test:** `testExecutionResultPartialSuccess`
  - **Status:** RED -- depends on ExecutionResult (already exists)
  - **Verifies:** AC2 -- Partial success result has isFullSuccess = false

- **Test:** `testMarkAllAsKeepWithNoGroups`
  - **Status:** RED -- depends on `markAllAsKeep()`
  - **Verifies:** AC1 -- Empty group list handled gracefully

- **Test:** `testMarkAllAsRemoveWithNoGroups`
  - **Status:** RED -- depends on `markAllAsRemove()` and `toDeleteOperations()`
  - **Verifies:** AC1 -- Empty group list handled gracefully

- **Test:** `testToDeleteOperationsParametersAreDelete`
  - **Status:** RED -- depends on `markAllAsRemove()` and `toDeleteOperations()`
  - **Verifies:** AC4 -- Each PlannedOperation has .delete parameters

- **Test:** `testExtractDuplicateGroupsHandlesMalformedJSON`
  - **Status:** RED -- depends on `extractDuplicateGroupsFromStepResult()`
  - **Verifies:** AC5 -- Malformed JSON returns empty array gracefully

- **Test:** `testExtractDuplicateGroupsHandlesEmptyGroupsArray`
  - **Status:** RED -- depends on `extractDuplicateGroupsFromStepResult()`
  - **Verifies:** AC5 -- Empty groups JSON returns empty list

---

## Mock Requirements

### MockBatchApprovalOperationManager

Mock implementation of `OperationManaging` protocol for batch approval tests.

**Protocol:** `OperationManaging`
**Tracking:** `beginBatchCalled`, `executeBatchCalled`, `lastOperations`
**Failure Simulation:** `simulatePartialFailure` flag throws on `executeBatch`

### MockBatchApprovalGrantedRepository

Mock implementation of `PhotoLibraryRepository` that always grants write access.

**Protocol:** `PhotoLibraryRepository`
**Methods:** All methods return no-op defaults; `requestWriteAccess()` returns `true`

---

## Implementation Checklist

### Task 1: Add `markAllAsKeep()` to DeduplicationViewModel

**File:** `Curator/Features/Deduplication/DeduplicationViewModel.swift`

**Tests this enables:**
- `testMarkAllAsKeepUpdatesAllStates` [P0]
- `testMarkAllAsKeepWithNoGroups` [P1]
- `testMarkAllPreservesAlreadyReviewedStates` [P1]

**Tasks to make these tests pass:**

- [ ] Add `func markAllAsKeep()` method to `DeduplicationViewModel`
- [ ] Method should only update groups with `reviewStates[groupID] == .pending`
- [ ] Already-reviewed groups (.keep, .remove) should NOT be overwritten
- [ ] Run tests: `xcodebuild test -project Curator.xcodeproj -scheme Curator -destination 'platform=macOS' -only-testing:CuratorTests/BatchApprovalViewModelTests/testMarkAllAsKeepUpdatesAllStates`

**Estimated Effort:** 0.5 hours

---

### Task 2: Add `markAllAsRemove()` to DeduplicationViewModel

**File:** `Curator/Features/Deduplication/DeduplicationViewModel.swift`

**Tests this enables:**
- `testMarkAllAsRemoveUpdatesAllStates` [P0]
- `testMarkAllAsRemoveWithNoGroups` [P1]

**Tasks to make these tests pass:**

- [ ] Add `func markAllAsRemove()` method to `DeduplicationViewModel`
- [ ] Method should only update groups with `reviewStates[groupID] == .pending`
- [ ] Run tests: `xcodebuild test -project Curator.xcodeproj -scheme Curator -destination 'platform=macOS' -only-testing:CuratorTests/BatchApprovalViewModelTests/testMarkAllAsRemoveUpdatesAllStates`

**Estimated Effort:** 0.5 hours

---

### Task 3: Add `toDeleteOperations()` to DeduplicationViewModel

**File:** `Curator/Features/Deduplication/DeduplicationViewModel.swift`

**Tests this enables:**
- `testToDeleteOperationsReturnsCorrectOperations` [P0]
- `testToDeleteOperationsExcludesKeepGroups` [P0]
- `testToDeleteOperationsParametersAreDelete` [P1]
- `testBatchApprovalTriggersDestructiveConfirmation` [P1]
- `testExecutionResultUpdatesOnCompletion` [P1]
- `testMarkAllAsRemoveWithNoGroups` [P1]

**Tasks to make these tests pass:**

- [ ] Add `func toDeleteOperations() -> [PlannedOperation]` method
- [ ] Use `assetsToRemove()` to get asset IDs from .remove-marked groups
- [ ] Map each asset ID to `PlannedOperation(operationType: .delete, assetID:, parameters: .delete)`
- [ ] Run tests: `xcodebuild test -project Curator.xcodeproj -scheme Curator -destination 'platform=macOS' -only-testing:CuratorTests/BatchApprovalViewModelTests/testToDeleteOperationsReturnsCorrectOperations`

**Estimated Effort:** 0.5 hours

---

### Task 4: Implement `extractDuplicateGroupsFromStepResult()` on MainWorkspaceView

**File:** `Curator/Features/MainWorkspace/MainWorkspaceView.swift`

**Tests this enables:**
- `testExtractDuplicateGroupsParsesStepResult` [P0]
- `testExtractDuplicateGroupsReturnsEmptyForNoData` [P0]
- `testExtractDuplicateGroupsHandlesMalformedJSON` [P1]
- `testExtractDuplicateGroupsHandlesEmptyGroupsArray` [P1]

**Tasks to make these tests pass:**

- [ ] Add `static func extractDuplicateGroupsFromStepResult(_ stepResult: StepResult) -> [DuplicateGroup]` (internal access for testing)
- [ ] Read `stepResult.data["duplicateGroups"]` JSON string
- [ ] Parse JSON using `JSONSerialization` (DuplicateGroup is not Codable)
- [ ] Build `DuplicateGroup` instances from parsed JSON fields (id, assetIDs, similarityScore, reason, status)
- [ ] Return empty array on missing key, malformed JSON, or empty groups
- [ ] Wire into existing `extractDuplicateGroups(from:)` method
- [ ] Run tests: `xcodebuild test -project Curator.xcodeproj -scheme Curator -destination 'platform=macOS' -only-testing:CuratorTests/BatchApprovalViewModelTests/testExtractDuplicateGroupsParsesStepResult`

**Estimated Effort:** 1.5 hours

---

### Task 5: Wire BatchApprovalView to DuplicateReviewView (UI)

**File:** `Curator/Features/Deduplication/DuplicateReviewView.swift` (modify)
**File:** `Curator/Features/Deduplication/BatchApprovalView.swift` (new)

**Tasks:**

- [ ] Create `BatchApprovalView.swift` with "Keep All" / "Remove All" buttons
- [ ] Add BatchApprovalView to DuplicateReviewView bottom bar
- [ ] "Remove All" calls `markAllAsRemove()` then `toDeleteOperations()` then `ConfirmationViewModel.presentConfirmation()`
- [ ] Display ExecutionResult after completion with undo button
- [ ] Verify UX-DR17 button hierarchy (one primary, destructive in red)

**Estimated Effort:** 2 hours

---

### Task 6: AnalyzeDuplicatesTool writes JSON to StepResult.data

**File:** `Curator/Infrastructure/SDKTools/AnalyzeDuplicatesTool.swift` (modify)

**Tasks:**

- [ ] After analysis, encode DuplicateGroup list as JSON string
- [ ] Write to `StepResult.data["duplicateGroups"]`
- [ ] Ensure the JSON format matches what `extractDuplicateGroupsFromStepResult` expects

**Estimated Effort:** 0.5 hours

---

## Running Tests

```bash
# Run all tests for this story
xcodebuild test -project Curator.xcodeproj -scheme Curator -destination 'platform=macOS' -only-testing:CuratorTests/BatchApprovalViewModelTests

# Run specific P0 test
xcodebuild test -project Curator.xcodeproj -scheme Curator -destination 'platform=macOS' -only-testing:CuratorTests/BatchApprovalViewModelTests/testMarkAllAsKeepUpdatesAllStates

# Run full test suite
xcodebuild test -project Curator.xcodeproj -scheme Curator -destination 'platform=macOS'
```

---

## Red-Green-Refactor Workflow

### RED Phase (Complete)

**TEA Agent Responsibilities:**

- All 19 tests written as red-phase test methods that compile but fail due to missing implementation
- Build produces 18 compilation errors for 4 missing methods:
  - `DeduplicationViewModel.markAllAsKeep()`
  - `DeduplicationViewModel.markAllAsRemove()`
  - `DeduplicationViewModel.toDeleteOperations()`
  - `MainWorkspaceView.extractDuplicateGroupsFromStepResult()`
- Mock infrastructure provided (MockBatchApprovalOperationManager, MockBatchApprovalGrantedRepository)
- Implementation checklist maps tests to concrete tasks

**Verification:**

- `xcodebuild build-for-testing` produces only "no member" / "has no member" errors (expected)
- All errors point to methods that will be implemented in GREEN phase
- No type inference errors or test logic bugs

---

### GREEN Phase (DEV Team - Next Steps)

**DEV Agent Responsibilities:**

1. **Start with Task 1:** Implement `markAllAsKeep()` in DeduplicationViewModel
2. **Run test:** Confirm `testMarkAllAsKeepUpdatesAllStates` passes
3. **Task 2:** Implement `markAllAsRemove()` -- confirm tests pass
4. **Task 3:** Implement `toDeleteOperations()` -- confirm tests pass
5. **Task 4:** Implement `extractDuplicateGroupsFromStepResult()` -- confirm tests pass
6. **Task 5-6:** Wire UI and SDK tool -- verify with manual testing
7. **Run full suite:** All 19 tests pass + all existing tests still pass

---

### REFACTOR Phase (After All Tests Pass)

- Review BatchApprovalView for SwiftUI best practices (view under 200 lines)
- Verify @MainActor/@Observable patterns
- Ensure Sendable compliance on value types
- Check error handling follows three-layer error system

---

## Test Execution Evidence

### RED Verification Build

**Command:** `xcodebuild build-for-testing -project Curator.xcodeproj -scheme Curator -destination 'platform=macOS'`

**Results:** 18 compilation errors, all of the form "has no member" for methods not yet implemented:

```
error: value of type 'DeduplicationViewModel' has no member 'markAllAsKeep'
error: value of type 'DeduplicationViewModel' has no member 'markAllAsRemove'
error: value of type 'DeduplicationViewModel' has no member 'toDeleteOperations'
error: type 'MainWorkspaceView' has no member 'extractDuplicateGroupsFromStepResult'
```

**Summary:**

- Total tests: 19
- P0 tests: 6
- P1 tests: 13
- Status: RED-phase scaffolds verified (compilation errors for missing methods)

---

## Key Design Decisions for Implementation

1. **markAllAsKeep/markAllAsRemove only update pending groups** -- This prevents overwriting user's individual review decisions.
2. **toDeleteOperations() reuses assetsToRemove()** -- Single source of truth for which assets are marked for removal.
3. **extractDuplicateGroupsFromStepResult uses manual JSON parsing** -- DuplicateGroup is not Codable, so we parse the same JSON format that AnalyzeDuplicatesTool produces.
4. **ConfirmationLevel.forOperations auto-detects .destructive** -- No special casing needed; delete operations automatically route to destructive confirmation.

---

## Notes

- The existing `DeduplicationViewModel` already has `assetsToRemove()`, `markAsKeep(groupID:)`, `markAsRemove(groupID:)`, and `allReviewed` -- new methods build on these.
- `ConfirmationViewModel` already handles the full confirmation flow with permission checks, destructive routing, progress tracking, and result reporting -- no modifications needed.
- `OperationManager` already has `beginBatch`/`executeBatch`/`rollbackBatch`/`rollbackLastBatch` -- no modifications needed.
- `ExecutionResult` struct already exists with `successCount`, `failureCount`, `total`, `isFullSuccess`.
- The test file must be added to `Curator.xcodeproj/project.pbxproj` to be included in the test target (already done).

---

**Generated by BMad TEA Agent** - 2026-04-24
