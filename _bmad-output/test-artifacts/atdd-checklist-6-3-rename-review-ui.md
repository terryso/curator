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
storyId: '6.3'
storyKey: 6-3-rename-review-ui
storyFile: _bmad-output/implementation-artifacts/6-3-rename-review-ui.md
atddChecklistPath: _bmad-output/test-artifacts/atdd-checklist-6-3-rename-review-ui.md
generatedTestFiles:
  - CuratorTests/Features/Rename/RenameViewModelTests.swift
inputDocuments:
  - _bmad-output/implementation-artifacts/6-3-rename-review-ui.md
  - Curator/Core/Models/RenameSuggestion.swift
  - Curator/Core/Operations/PlannedOperation.swift
  - Curator/Core/Models/AssetID.swift
  - Curator/Features/Deduplication/DeduplicationViewModel.swift
  - CuratorTests/Features/Deduplication/DeduplicationViewModelTests.swift
---

# ATDD Checklist: Story 6.3 -- Rename Review UI

**Date:** 2026-04-25
**Author:** TEA Agent (ATDD Workflow)
**Primary Test Level:** Unit (ViewModel logic)

---

## Story Summary

**As a** user
**I want** to view rename suggestions with inline editing support
**So that** I can confirm or modify suggested names before accepting them.

---

## Acceptance Criteria

1. **AC1:** RenameReviewView displays rename suggestions as RenameSuggestionCard (FR26, UX-DR5)
2. **AC2:** Inline editing of suggested names with real-time validation (FR27)
3. **AC3:** One-at-a-time review with status tracking and auto-focus to next

---

## Story Integration Metadata

- **Story ID:** `6.3`
- **Story Key:** `6-3-rename-review-ui`
- **Story File:** `_bmad-output/implementation-artifacts/6-3-rename-review-ui.md`
- **Checklist Path:** `_bmad-output/test-artifacts/atdd-checklist-6-3-rename-review-ui.md`
- **Generated Test Files:** `CuratorTests/Features/Rename/RenameViewModelTests.swift`

---

## Test Strategy

| Test Level | Tests | Purpose |
|---|---|---|
| Unit | 24 (all skipped via XCTSkip) | RenameViewModel state management, inline edit validation, progress tracking, batch operations |

### Why Unit Tests Only

This story is primarily about a ViewModel (RenameViewModel) managing in-memory state for rename review decisions. The SwiftUI views (RenameReviewView, RenameSuggestionCard) are rendering layers that will be validated through:

1. **ViewModel unit tests** (this ATDD) -- verify all business logic including inline editing validation
2. **Xcode Previews** -- validate visual rendering during development
3. **Manual verification** -- confirm UX-DR5 layout and accessibility

No E2E/browser tests needed (macOS native app, not web).

---

## Acceptance Criteria Coverage

### AC1: RenameReviewView Displays Suggestions (FR26, UX-DR5)

| Test | Priority | Status |
|---|---|---|
| `testLoadSuggestionsSetsCorrectCount` | P0 | RED (skipped) |
| `testLoadSuggestionsResetsPreviousState` | P0 | RED (skipped) |
| `testLoadEmptySuggestionsHandledGracefully` | P1 | RED (skipped) |

### AC2: Inline Editing with Validation (FR27)

| Test | Priority | Status |
|---|---|---|
| `testEditSuggestionValid` | P0 | RED (skipped) |
| `testEditSuggestionInvalidNameRejected` | P0 | RED (skipped) |
| `testFileNameValidationVariousCases` | P0 | RED (skipped) |
| `testEditOverridesPreviousAccept` | P1 | RED (skipped) |

### AC3: Review One at a Time with Status Tracking

| Test | Priority | Status |
|---|---|---|
| `testAcceptSuggestionUpdatesState` | P0 | RED (skipped) |
| `testRejectSuggestionUpdatesState` | P0 | RED (skipped) |
| `testProgressTracking` | P0 | RED (skipped) |
| `testAllReviewedReturnsFalseWhenPending` | P0 | RED (skipped) |
| `testAllReviewedReturnsTrueWhenAllDone` | P0 | RED (skipped) |
| `testPendingSuggestionsReturnsOnlyUnreviewed` | P1 | RED (skipped) |
| `testAcceptedCountTracksAcceptedAndEdited` | P1 | RED (skipped) |
| `testProgressTextMatchesExpected` | P1 | RED (skipped) |
| `testAcceptSameSuggestionTwiceOverridesState` | P1 | RED (skipped) |
| `testReviewDecisionEnumCases` | P0 | RED (skipped) |
| `testReviewDecisionIsSendableAndEquatable` | P0 | RED (skipped) |
| `testToRenameOperationsReturnsCorrectOperations` | P1 | RED (skipped) |
| `testMarkAllAsAccept` | P1 | RED (skipped) |
| `testMarkAllAsReject` | P1 | RED (skipped) |
| `testViewModelCanBeCreatedIndependently` | P1 | RED (skipped) |
| `testAcceptUnknownSuggestionIgnored` | P1 | RED (skipped) |
| `testRejectUnknownSuggestionIgnored` | P1 | RED (skipped) |
| `testEditUnknownSuggestionIgnored` | P1 | RED (skipped) |

---

## Red-Phase Test Scaffolds Created

### Unit Tests (25 tests)

**File:** `CuratorTests/Features/Rename/RenameViewModelTests.swift`

All tests use `throw XCTSkip("ATDD Red Phase -- remove when implementing RenameViewModel")` and will be skipped until implementation removes the skip guards.

**Test Stubs Included:**

The test file includes minimal stub implementations of `RenameViewModel` and `RenameReviewDecision` so the file compiles. These stubs must be **removed** when the real implementations are created in `Curator/Features/Rename/`.

**P0 Tests (Critical -- must pass for story completion):**

1. `testLoadSuggestionsSetsCorrectCount` -- loading suggestions sets correct count
2. `testLoadSuggestionsResetsPreviousState` -- reloading clears previous decisions
3. `testAcceptSuggestionUpdatesState` -- accept updates decision to .accepted
4. `testRejectSuggestionUpdatesState` -- reject updates decision to .rejected
5. `testEditSuggestionValid` -- valid edit updates decision to .edited(name)
6. `testEditSuggestionInvalidNameRejected` -- invalid name rejected, state unchanged
7. `testFileNameValidationVariousCases` -- comprehensive invalid name cases
8. `testProgressTracking` -- reviewedCount/acceptedCount/totalSuggestions accurate
9. `testAllReviewedReturnsFalseWhenPending` -- false when unreviewed exist
10. `testAllReviewedReturnsTrueWhenAllDone` -- true when all reviewed
11. `testReviewDecisionEnumCases` -- enum has pending/accepted/rejected/edited
12. `testReviewDecisionIsSendableAndEquatable` -- protocol conformance

**P1 Tests (Edge cases and robustness):**

13. `testLoadEmptySuggestionsHandledGracefully` -- empty list edge case
14. `testPendingSuggestionsReturnsOnlyUnreviewed` -- filtering works
15. `testAcceptedCountTracksAcceptedAndEdited` -- accepted+edited counted
16. `testProgressTextMatchesExpected` -- "Reviewed X / Y suggestions" format
17. `testAcceptSameSuggestionTwiceOverridesState` -- latest action wins
18. `testEditOverridesPreviousAccept` -- edit overrides accept
19. `testToRenameOperationsReturnsCorrectOperations` -- PlannedOperation conversion
20. `testMarkAllAsAccept` -- batch accept for pending
21. `testMarkAllAsReject` -- batch reject for pending
22. `testViewModelCanBeCreatedIndependently` -- standalone instantiation
23. `testAcceptUnknownSuggestionIgnored` -- unknown ID no-op
24. `testRejectUnknownSuggestionIgnored` -- unknown ID no-op
25. `testEditUnknownSuggestionIgnored` -- unknown ID no-op

---

## Priority Summary

| Priority | Count | Description |
|---|---|---|
| P0 | 12 | Critical happy paths -- must pass for story completion |
| P1 | 13 | Edge cases and robustness -- should pass |
| P2 | 0 | Nice-to-have |
| P3 | 0 | Performance/stress |

**Total: 25 tests**

---

## Mock Strategy

Tests use a `makeSuggestion()` helper factory that creates `RenameSuggestion` instances using existing production types (`AssetID`). No external service mocking needed -- all tests are pure in-memory ViewModel logic.

The tests reuse `RenameSuggestion.isValidFileName(_:)` for validation edge cases by verifying the ViewModel delegates correctly.

---

## Implementation Checklist

### Task 1: Create RenameViewModel (AC: #1, #2, #3)

**Tests to activate:**

- All 24 tests in `RenameViewModelTests.swift`

**Types to create:**

- [ ] Create `Curator/Features/Rename/RenameViewModel.swift`
- [ ] Define `RenameReviewDecision` enum: `.pending`, `.accepted`, `.rejected`, `.edited(String)` with Sendable, Equatable
- [ ] Define `@MainActor @Observable final class RenameViewModel`
- [ ] Properties: `suggestions: [RenameSuggestion]`, `reviewDecisions: [UUID: RenameReviewDecision]`
- [ ] Computed: `pendingSuggestions`, `totalSuggestions`, `reviewedCount`, `acceptedCount`, `allReviewed`, `progressText`
- [ ] Methods: `loadSuggestions(_:)`, `accept(suggestionID:)`, `reject(suggestionID:)`, `edit(suggestionID:newName:)`
- [ ] Methods: `markAllAsAccept()`, `markAllAsReject()` (batch for Story 6.4)
- [ ] Methods: `toRenameOperations() -> [PlannedOperation]` (for Story 6.4)
- [ ] Edit must validate via `RenameSuggestion.isValidFileName(_:)`
- [ ] Remove `throw XCTSkip(...)` from all tests
- [ ] Run tests: all 24 pass (green phase)

### Task 2: Create RenameSuggestionCard (AC: #1, #2, UX-DR5)

**No ATDD tests** -- UI component, validated via Xcode Previews.

- [ ] Create `Curator/Features/Rename/RenameSuggestionCard.swift`
- [ ] Implement per UX-DR5 spec

### Task 3: Create RenameReviewView (AC: #1, #3)

**No ATDD tests** -- SwiftUI view, validated via Xcode Previews.

- [ ] Create `Curator/Features/Rename/RenameReviewView.swift`
- [ ] Implement with ScrollView + LazyVStack

### Task 4: Integrate with AgentExecutionPanel (AC: #1)

**No ATDD tests** -- integration wiring, tested during manual verification.

- [ ] Modify `AgentExecutionPanel.swift` -- add renameViewModel parameter
- [ ] Modify `MainWorkspaceView.swift` -- extract RenameSuggestion data

---

## Running Tests

```bash
# Run all ATDD tests for this story (all skipped in red phase)
xcodebuild test -project Curator.xcodeproj -scheme Curator -destination 'platform=macOS' -only-testing:CuratorTests/RenameViewModelTests

# Run full test suite (verify no regressions)
xcodebuild test -project Curator.xcodeproj -scheme Curator -destination 'platform=macOS'
```

---

## Red-Green-Refactor Workflow

### RED Phase (Complete)

- All 25 tests written as red-phase scaffolds with `throw XCTSkip(...)`
- Test stubs provided for `RenameViewModel` and `RenameReviewDecision`
- Full test suite passes with 25 skips, 0 failures
- Build compiles successfully

### GREEN Phase (DEV Team -- Next Steps)

1. **Create real implementations** in `Curator/Features/Rename/RenameViewModel.swift`
2. **Remove test stubs** (lines 6-47 of the test file)
3. **Remove `throw XCTSkip`** from each test
4. **Run tests** -- verify they fail first (now testing real code), then pass
5. **Work one test at a time** for clean TDD cycle

### REFACTOR Phase (After All Tests Pass)

- Review ViewModel for code quality
- Ensure @Observable drives SwiftUI correctly
- Verify no race conditions with @MainActor

---

## Key Differences from Story 5.4 (DeduplicationViewModel)

| Aspect | DeduplicationViewModel | RenameViewModel |
|---|---|---|
| Data unit | `DuplicateGroup` (multiple assets) | `RenameSuggestion` (single asset) |
| Review actions | keep / remove | accept / reject / edit(name) |
| Inline editing | Not supported | Supported (FR27 core requirement) |
| Validation | N/A | `RenameSuggestion.isValidFileName` |
| Batch operations | markAllAsKeep / markAllAsRemove | markAllAsAccept / markAllAsReject |
| Conversion output | `.delete` PlannedOperation | `.rename(newTitle:)` PlannedOperation |

---

## Key Risks and Assumptions

1. **Test stubs must be removed** when real implementations are created -- duplicate symbols will cause compile errors if both exist
2. **XCTSkip pattern** -- tests are skipped, not failing. During green phase, remove skips and verify tests fail first (due to stub removal), then pass with real implementations
2. **Inline editing validation** relies on `RenameSuggestion.isValidFileName(_:)` which already exists
3. **No UI tests** -- SwiftUI views (RenameSuggestionCard, RenameReviewView) are validated via Xcode Previews and manual testing
4. **ViewModel-View contract** -- tests verify ViewModel logic; the @Observable macro drives SwiftUI updates
5. **toRenameOperations()** uses `.rename(newTitle:)` from existing `OperationParameters` enum

---

## Knowledge Base References Applied

- **component-tdd.md** -- Component test strategies applied to ViewModel unit tests
- **data-factories.md** -- `makeSuggestion()` factory pattern for test data generation
- **test-quality.md** -- Given-When-Then format, one assertion per test, determinism, isolation

---

## Next Steps

1. **Begin implementation** using Task 1 (RenameViewModel)
2. **Activate tests** by removing `throw XCTSkip` guards
3. **Work one test at a time** through the TDD red-green cycle
4. **After all ViewModel tests pass**, proceed to SwiftUI views (Tasks 2-4)
5. **Run full test suite** after all changes to verify no regressions

---

## Test Execution Evidence

### Initial Scaffold Review / RED Verification

**Command:**

```bash
xcodebuild test -project Curator.xcodeproj -scheme Curator -destination 'platform=macOS' -only-testing:CuratorTests/RenameViewModelTests
```

**Results:**

```
Executed 25 tests, with 25 tests skipped and 0 failures (0 unexpected) in 0.045 seconds
```

**Full suite:**

```
Executed 807 tests, with 25 tests skipped and 0 failures (0 unexpected) in 48.635 seconds
** TEST SUCCEEDED **
```

**Summary:**

- Total tests: 25 (new) + 782 (existing)
- Skipped: 25 (expected before activation)
- Activated RED tests: 0 (all still in skipped state)
- Passing: 782 (all existing tests still pass)
- Status: RED phase scaffolds verified
