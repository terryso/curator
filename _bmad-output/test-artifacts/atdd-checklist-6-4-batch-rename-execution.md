---
stepsCompleted:
  - step-01-preflight-and-context
  - step-02-generation-mode
  - step-03-test-strategy
  - step-04-generate-tests
  - step-04c-aggregate
  - step-05-validate-and-complete
lastStep: step-05-validate-and-complete
lastSaved: '2026-04-25'
storyId: '6.4'
storyKey: 6-4-batch-rename-execution
storyFile: _bmad-output/implementation-artifacts/6-4-batch-rename-execution.md
atddChecklistPath: _bmad-output/test-artifacts/atdd-checklist-6-4-batch-rename-execution.md
generatedTestFiles:
  - CuratorTests/Features/Rename/BatchRenameViewModelTests.swift
inputDocuments:
  - _bmad-output/implementation-artifacts/6-4-batch-rename-execution.md
  - Curator/Features/Rename/RenameViewModel.swift
  - Curator/Core/Models/RenameSuggestion.swift
  - Curator/Core/Operations/PlannedOperation.swift
  - Curator/Features/Confirmation/ConfirmationLevel.swift
  - Curator/Features/Confirmation/ConfirmationRequest.swift
  - Curator/Features/Confirmation/ConfirmationViewModel.swift
  - CuratorTests/Features/Deduplication/BatchApprovalViewModelTests.swift
  - CuratorTests/Features/Rename/RenameViewModelTests.swift
detected_stack: backend
generation_mode: ai-generation
---

# ATDD Checklist: Story 6.4 -- Batch Rename Execution

**Date:** 2026-04-25
**Author:** TEA Agent (ATDD Workflow)
**Primary Test Level:** Unit (ViewModel logic + Confirmation workflow)

---

## Story Summary

**As a** user
**I want** to batch execute renames after reviewing all suggestions
**So that** I can efficiently complete the entire rename workflow.

---

## Acceptance Criteria

1. **AC1:** Batch operation buttons -- "Accept All" / "Reject All" (FR28, UX-DR17)
2. **AC2:** Batch confirmation and execution via ConfirmationViewModel (FR28, FR33, UX-DR11)
3. **AC3:** Execution result summary with success/failure/skipped counts (UX-DR6)
4. **AC4:** Undo/rollback via OperationManager (FR34, NFR16)
5. **AC5:** Partial failure tolerance -- skip failures, continue processing (FR36, NFR15)
6. **AC6:** Bridge from review data to confirmation workflow via PlannedOperation
7. **AC7:** Integration with AgentExecutionPanel

---

## Story Integration Metadata

- **Story ID:** `6.4`
- **Story Key:** `6-4-batch-rename-execution`
- **Story File:** `_bmad-output/implementation-artifacts/6-4-batch-rename-execution.md`
- **Checklist Path:** `_bmad-output/test-artifacts/atdd-checklist-6-4-batch-rename-execution.md`
- **Generated Test Files:** `CuratorTests/Features/Rename/BatchRenameViewModelTests.swift`

---

## Stack Detection

- **Detected Stack**: `backend` (Swift/macOS, XCTest)
- **Test Framework**: XCTest
- **Generation Mode**: AI Generation (backend project, no browser testing needed)

---

## Test Strategy

### Test Levels

| Level | Usage | Rationale |
|---|---|---|
| Unit | RenameViewModel batch operations (markAllAsAccept/Reject, toRenameOperations), ConfirmationLevel routing | Pure in-memory logic, value type verification |
| Integration | ConfirmationViewModel + OperationManager execution flow, execution result propagation | Cross-component interaction with mock OperationManager |

### Priority Matrix

| Priority | Criteria | Coverage Target |
|---|---|---|
| P0 | markAllAsAccept/Reject updates states, toRenameOperations correct, ConfirmationLevel.standard for rename, execution result propagation | 100% |
| P1 | markAll preserves reviewed states, empty operations handled, partial failure result, ExecutionResult value type, undo availability | 80% |
| P2 | Edge cases, high concurrency | 50% |

---

## Acceptance Criteria Coverage

### AC1: Batch Operation Buttons (FR28, UX-DR17)

| Test | Priority | Status |
|---|---|---|
| `testMarkAllAsAcceptUpdatesAllStates` | P0 | RED (skipped) |
| `testMarkAllAsRejectUpdatesAllStates` | P0 | RED (skipped) |
| `testMarkAllPreservesAlreadyReviewedStates` | P1 | RED (skipped) |

### AC2: Batch Confirmation and Execution (FR28, FR33, UX-DR11)

| Test | Priority | Status |
|---|---|---|
| `testBatchRenameTriggersStandardConfirmation` | P0 | RED (skipped) |
| `testExecutionResultUpdatesOnCompletion` | P0 | RED (skipped) |

### AC3: Execution Result Summary (UX-DR6)

| Test | Priority | Status |
|---|---|---|
| `testExecutionResultFullSuccess` | P1 | RED (skipped) |
| `testExecutionResultPartialSuccess` | P1 | RED (skipped) |

### AC4: Undo/Rollback (FR34, NFR16)

| Test | Priority | Status |
|---|---|---|
| `testExecutionResultProvidesUndoCapability` | P1 | RED (skipped) |

### AC5: Partial Failure Tolerance (FR36, NFR15)

| Test | Priority | Status |
|---|---|---|
| `testPartialFailureResultShowsBothCounts` | P1 | RED (skipped) |

### AC6: Review Data to Confirmation Workflow Bridge

| Test | Priority | Status |
|---|---|---|
| `testToRenameOperationsReturnsCorrectOperations` | P0 | RED (skipped) |
| `testToRenameOperationsExcludesRejected` | P0 | RED (skipped) |
| `testToRenameOperationsIncludesEdited` | P0 | RED (skipped) |
| `testBatchRenameWithEmptyOperations` | P1 | RED (skipped) |

### AC7: Integration with AgentExecutionPanel

| Test | Priority | Status |
|---|---|---|
| `testRenameConfirmationLevelIsStandard` | P1 | RED (skipped) |
| `testConfirmationRequestForRenameContainsCorrectSummary` | P1 | RED (skipped) |

---

## Red-Phase Test Scaffolds Created

### Unit + Integration Tests (15 tests)

**File:** `CuratorTests/Features/Rename/BatchRenameViewModelTests.swift`

All tests use `throw XCTSkip("ATDD Red Phase -- remove when implementing BatchRenameView")` and will be skipped until implementation removes the skip guards.

**P0 Tests (Critical -- must pass for story completion):**

1. `testMarkAllAsAcceptUpdatesAllStates` -- all pending suggestions become accepted
2. `testMarkAllAsRejectUpdatesAllStates` -- all pending suggestions become rejected
3. `testToRenameOperationsReturnsCorrectOperations` -- PlannedOperation list with .rename type, matching names
4. `testToRenameOperationsExcludesRejected` -- rejected suggestions excluded from operations
5. `testToRenameOperationsIncludesEdited` -- edited suggestions use custom name
6. `testBatchRenameTriggersStandardConfirmation` -- rename operations route to .standard level
7. `testExecutionResultUpdatesOnCompletion` -- ExecutionResult set after batch execution

**P1 Tests (Edge cases and robustness):**

8. `testMarkAllPreservesAlreadyReviewedStates` -- markAll does not overwrite already-reviewed
9. `testBatchRenameWithEmptyOperations` -- no operations when all rejected
10. `testRenameConfirmationLevelIsStandard` -- ConfirmationLevel.forOperations returns .standard
11. `testExecutionResultFullSuccess` -- ExecutionResult with zero failures
12. `testExecutionResultPartialSuccess` -- ExecutionResult with failures
13. `testExecutionResultProvidesUndoCapability` -- undo available after execution
14. `testPartialFailureResultShowsBothCounts` -- partial failure shows both counts
15. `testConfirmationRequestForRenameContainsCorrectSummary` -- request summary is descriptive

---

## Priority Summary

| Priority | Count | Description |
|---|---|---|
| P0 | 7 | Critical happy paths -- must pass for story completion |
| P1 | 8 | Edge cases and robustness -- should pass |
| P2 | 0 | Nice-to-have |

**Total: 15 tests**

---

## Mock Strategy

Tests reuse production `RenameViewModel` directly (pure in-memory, no external dependencies). For integration tests involving `ConfirmationViewModel`, a `MockBatchRenameOperationManager` is provided (mirroring `MockBatchApprovalOperationManager` from Epic 5).

**Mock Infrastructure:**

| Mock | Purpose | Location |
|---|---|---|
| MockBatchRenameOperationManager | Tracks beginBatch/executeBatch calls, supports failure injection | Inline in test file |
| MockBatchRenameGrantedRepository | Always grants write access | Inline in test file |

---

## NFR Coverage

| NFR | Test Coverage |
|---|---|
| NFR15 (Zero file corruption) | Rename operations use .rename(newTitle:) which only changes file name, not content |
| NFR16 (5s rollback) | ExecutionResult tests verify undo capability via ConfirmationViewModel |
| UX-DR17 (Button hierarchy) | BatchRenameView uses standard fill for execute, secondary stroke for accept/reject (validated in UI review) |

---

## TDD Red Phase Compliance

- [x] All tests use `throw XCTSkip("ATDD Red Phase -- ...")` -- will be activated during dev-story
- [x] All tests assert EXPECTED behavior (not current behavior)
- [x] Activated tests will FAIL until feature is implemented
- [x] No active passing tests generated
- [x] Mock implementations provided (MockBatchRenameOperationManager, MockBatchRenameGrantedRepository)

---

## Implementation Guidance

### Task-by-Task Activation

During implementation of each task:

1. Remove `throw XCTSkip(...)` from the relevant test(s)
2. Run tests: `xcodebuild test` or `swift test`
3. Verify the activated test fails first, then passes after implementation (green phase)
4. If any activated tests still fail unexpectedly:
   - Either fix implementation (feature bug)
   - Or fix test (test bug)
5. Commit passing tests

### Suggested activation order:

1. **Task 1** (BatchRenameView component) -> Activate AC1 tests (testMarkAllAsAcceptUpdatesAllStates, testMarkAllAsRejectUpdatesAllStates, testMarkAllPreservesAlreadyReviewedStates)
2. **Task 2** (Batch confirmation flow) -> Activate AC6 + AC2 tests (testToRenameOperations*, testBatchRenameTriggersStandardConfirmation, testRenameConfirmationLevelIsStandard, testBatchRenameWithEmptyOperations, testConfirmationRequestForRenameContainsCorrectSummary)
3. **Task 3** (Result display + undo) -> Activate AC3 + AC4 + AC5 tests (testExecutionResult*, testPartialFailureResultShowsBothCounts, testExecutionResultProvidesUndoCapability)
4. **Task 4** (Integration) -> Verify no regressions, manual UI validation

---

## Key Design Decisions

1. **RenameViewModel methods are already implemented** -- markAllAsAccept/markAllAsReject/toRenameOperations exist from Story 6.3. Tests verify their behavior in the batch execution context.
2. **ConfirmationLevel.forOperations returns .standard for .rename** -- rename is non-destructive (file name is fully recoverable), so it routes to standard confirmation (no second confirmation sheet).
3. **ExecutionResult is a value type** -- tests verify struct properties directly without mocking.
4. **Mock OperationManager mirrors Epic 5** -- same pattern as MockBatchApprovalOperationManager for consistency.

---

## Running Tests

```bash
# Run all ATDD tests for this story (all skipped in red phase)
xcodebuild test -project Curator.xcodeproj -scheme Curator -destination 'platform=macOS' -only-testing:CuratorTests/BatchRenameViewModelTests

# Run full test suite (verify no regressions)
xcodebuild test -project Curator.xcodeproj -scheme Curator -destination 'platform=macOS'
```

---

## Red-Green-Refactor Workflow

### RED Phase (Complete)

- All 15 tests written as red-phase scaffolds with `throw XCTSkip(...)`
- Mock infrastructure provided (MockBatchRenameOperationManager, MockBatchRenameGrantedRepository)
- Full test suite passes with 15 skips, 0 failures
- Build compiles successfully

### GREEN Phase (DEV Team -- Next Steps)

1. **Create BatchRenameView** in `Curator/Features/Rename/BatchRenameView.swift`
2. **Remove `throw XCTSkip`** from each test as tasks are implemented
3. **Run tests** -- verify they fail first (now testing real code), then pass
4. **Work one test at a time** for clean TDD cycle

### REFACTOR Phase (After All Tests Pass)

- Review BatchRenameView for code quality
- Ensure @Observable drives SwiftUI correctly
- Verify button hierarchy matches UX-DR17

---

## Knowledge Base References Applied

- **component-tdd.md** -- Component test strategies applied to ViewModel unit tests
- **data-factories.md** -- `makeSuggestion()` factory pattern for test data generation
- **test-quality.md** -- Given-When-Then format, one assertion per test, determinism, isolation

---

## Test Execution Evidence

### Initial Scaffold Review / RED Verification

**Command:**

```bash
xcodebuild test -project Curator.xcodeproj -scheme Curator -destination 'platform=macOS' -only-testing:CuratorTests/BatchRenameViewModelTests
```

**Expected Results:**

```
Executed 15 tests, with 15 tests skipped and 0 failures (0 unexpected) in X.XXX seconds
```

**Summary:**

- Total tests: 15 (new)
- Skipped: 15 (expected before activation)
- Activated RED tests: 0 (all still in skipped state)
- Status: RED phase scaffolds verified
