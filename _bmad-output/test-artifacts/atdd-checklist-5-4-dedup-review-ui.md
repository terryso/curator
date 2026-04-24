---
stepsCompleted:
  - step-01-preflight-and-context
  - step-02-generation-mode
  - step-03-test-strategy
  - step-04-generate-tests
  - step-05-validate-and-complete
lastStep: step-05-validate-and-complete
lastSaved: '2026-04-24'
storyId: '5.4'
storyKey: 5-4-dedup-review-ui
storyFile: _bmad-output/implementation-artifacts/5-4-dedup-review-ui.md
atddChecklistPath: _bmad-output/test-artifacts/atdd-checklist-5-4-dedup-review-ui.md
generatedTestFiles:
  - CuratorTests/Features/Deduplication/DeduplicationViewModelTests.swift
inputDocuments:
  - _bmad-output/implementation-artifacts/5-4-dedup-review-ui.md
  - Curator/Core/Models/DuplicateGroup.swift
  - Curator/Core/Models/PhotoAsset.swift
  - Curator/Core/Models/AssetID.swift
  - Curator/Core/Models/AssetMetadata.swift
  - Curator/Features/AgentExecution/AgentExecutionPanel.swift
  - Curator/Features/MainWorkspace/MainWorkspaceView.swift
  - Curator/App/AppDependencies.swift
  - CuratorTests/Features/Confirmation/ConfirmationWorkflowTests.swift
  - CuratorTests/Core/Agent/AgentJobTests.swift
---

# ATDD Checklist: Story 5.4 -- Deduplication Review UI

**Date:** 2026-04-24
**Author:** TEA Agent (ATDD Workflow)
**Primary Test Level:** Unit (ViewModel logic)

---

## Story Summary

**As a** user
**I want** to view duplicate photo groups in a side-by-side comparison with match reasons
**So that** I can make informed keep/remove decisions.

---

## Acceptance Criteria

1. **AC1:** DuplicateReviewView displays duplicate groups with PhotoComparisonCard (FR21, UX-DR4)
2. **AC2:** User reviews groups one at a time with keep/remove actions (FR22)
3. **AC3:** Thumbnail loading and scrolling experience (NFR2, NFR8)
4. **AC4:** DeduplicationViewModel state management tracks review decisions
5. **AC5:** Integration with AgentExecutionPanel review state
6. **AC6:** Accessibility and keyboard navigation (UX-DR14)

---

## Story Integration Metadata

- **Story ID:** `5.4`
- **Story Key:** `5-4-dedup-review-ui`
- **Story File:** `_bmad-output/implementation-artifacts/5-4-dedup-review-ui.md`
- **Checklist Path:** `_bmad-output/test-artifacts/atdd-checklist-5-4-dedup-review-ui.md`
- **Generated Test Files:** `CuratorTests/Features/Deduplication/DeduplicationViewModelTests.swift`

---

## Test Strategy

| Test Level | Tests | Purpose |
|---|---|---|
| Unit | 17 (all skipped via XCTSkipIf) | DeduplicationViewModel state management, computed properties, review state transitions |

### Why Unit Tests Only

This story is primarily about a ViewModel (DeduplicationViewModel) managing in-memory state. The SwiftUI views (DuplicateReviewView, PhotoComparisonCard) are rendering layers that will be validated through:

1. **ViewModel unit tests** (this ATDD) -- verify all business logic
2. **Xcode Previews** -- validate visual rendering during development
3. **Manual verification** -- confirm UX-DR4 layout and accessibility

No E2E/browser tests needed (macOS native app, not web).

---

## Acceptance Criteria Coverage

### AC1: DuplicateReviewView Displays Groups (FR21, UX-DR4)

Covered indirectly via ViewModel tests -- the ViewModel provides `groups` array that drives the view.

### AC2: User Reviews Groups One at a Time (FR22)

| Test | Priority | Status |
|---|---|---|
| `testMarkAsKeepUpdatesState` | P0 | RED (skipped) |
| `testMarkAsRemoveUpdatesState` | P0 | RED (skipped) |
| `testToggleReviewStateCycles` | P1 | RED (skipped) |
| `testMarkSameGroupTwiceOverridesState` | P1 | RED (skipped) |

### AC3: Thumbnail Loading and Scrolling (NFR2, NFR8)

Covered by `testEmptyGroupListHandledCorrectly` and `testPendingGroupsReturnsOnlyUnreviewed` -- validates ViewModel filtering for LazyVStack rendering.

### AC4: DeduplicationViewModel State Management

| Test | Priority | Status |
|---|---|---|
| `testLoadGroupsSetsCorrectCount` | P0 | RED (skipped) |
| `testAssetsToRemoveReturnsCorrectIDs` | P0 | RED (skipped) |
| `testAllReviewedReturnsFalseWhenPending` | P0 | RED (skipped) |
| `testAllReviewedReturnsTrueWhenAllDone` | P0 | RED (skipped) |
| `testComputedPropertiesUpdate` | P1 | RED (skipped) |
| `testLoadGroupsResetsPreviousState` | P1 | RED (skipped) |
| `testPendingGroupsReturnsOnlyUnreviewed` | P1 | RED (skipped) |
| `testReviewStateEnumCases` | P0 | RED (skipped) |
| `testReviewStateIsSendableAndEquatable` | P0 | RED (skipped) |
| `testReviewStateForUnknownGroupReturnsPending` | P1 | RED (skipped) |
| `testViewModelCanBeCreatedIndependently` | P1 | RED (skipped) |
| `testEmptyGroupListHandledCorrectly` | P1 | RED (skipped) |
| `testAssetsToRemoveExcludesKeptGroups` | P1 | RED (skipped) |

### AC5: Integration with AgentExecutionPanel

Covered by `testViewModelCanBeCreatedIndependently` -- verifies ViewModel can be instantiated for DI.

### AC6: Accessibility (UX-DR14)

Accessibility is a SwiftUI view concern. ViewModel tests don't cover this directly. Accessibility labels will be verified during SwiftUI implementation via Xcode Accessibility Inspector.

---

## Red-Phase Test Scaffolds Created

### Unit Tests (17 tests)

**File:** `CuratorTests/Features/Deduplication/DeduplicationViewModelTests.swift` (543 lines)

All tests use `XCTSkipIf(true, "ATDD Red Phase -- remove when implementing DeduplicationViewModel")` and will be skipped until implementation removes the skip guards.

**Test Stubs Included:**

The test file includes minimal stub implementations of `DeduplicationViewModel` and `DuplicateGroupReviewState` so the file compiles. These stubs must be **removed** when the real implementations are created in `Curator/Features/Deduplication/`.

- `testLoadGroupsSetsCorrectCount` -- P0 -- verifies loading groups sets correct count
- `testMarkAsKeepUpdatesState` -- P0 -- verifies keep action updates state
- `testMarkAsRemoveUpdatesState` -- P0 -- verifies remove action updates state
- `testAssetsToRemoveReturnsCorrectIDs` -- P0 -- verifies asset ID extraction for batch operations
- `testAllReviewedReturnsFalseWhenPending` -- P0 -- verifies false when unreviewed groups exist
- `testAllReviewedReturnsTrueWhenAllDone` -- P0 -- verifies true when all groups reviewed
- `testToggleReviewStateCycles` -- P1 -- verifies pending->keep->remove->pending cycle
- `testComputedPropertiesUpdate` -- P1 -- verifies reviewedCount/totalGroups/markedForRemovalCount
- `testLoadGroupsResetsPreviousState` -- P1 -- verifies reload clears old state
- `testPendingGroupsReturnsOnlyUnreviewed` -- P1 -- verifies pending filtering
- `testReviewStateEnumCases` -- P0 -- verifies enum has pending/keep/remove cases
- `testReviewStateIsSendableAndEquatable` -- P0 -- verifies protocol conformance
- `testReviewStateForUnknownGroupReturnsPending` -- P1 -- verifies default state
- `testViewModelCanBeCreatedIndependently` -- P1 -- verifies standalone instantiation
- `testEmptyGroupListHandledCorrectly` -- P1 -- verifies empty list edge case
- `testMarkSameGroupTwiceOverridesState` -- P1 -- verifies latest action wins
- `testAssetsToRemoveExcludesKeptGroups` -- P1 -- verifies only remove-marked groups

---

## Priority Summary

| Priority | Count | Description |
|---|---|---|
| P0 | 8 | Critical happy paths -- must pass for story completion |
| P1 | 9 | Edge cases and robustness -- should pass |
| P2 | 0 | Nice-to-have |
| P3 | 0 | Performance/stress |

---

## Mock Strategy

Tests use a `makeDuplicateGroup()` helper factory (defined in the test file) that creates `DuplicateGroup` instances using existing production types (`PhotoAsset`, `AssetID`, `AssetMetadata`, `DuplicateGroup`). No external service mocking needed -- all tests are pure in-memory ViewModel logic.

---

## Implementation Checklist

### Task 1: Create DeduplicationViewModel (AC: #4)

**Tests to activate:**

- `testLoadGroupsSetsCorrectCount`
- `testMarkAsKeepUpdatesState`
- `testMarkAsRemoveUpdatesState`
- `testAssetsToRemoveReturnsCorrectIDs`
- `testAllReviewedReturnsFalseWhenPending`
- `testAllReviewedReturnsTrueWhenAllDone`
- `testToggleReviewStateCycles`
- `testComputedPropertiesUpdate`
- `testLoadGroupsResetsPreviousState`
- `testPendingGroupsReturnsOnlyUnreviewed`
- `testReviewStateForUnknownGroupReturnsPending`
- `testViewModelCanBeCreatedIndependently`
- `testEmptyGroupListHandledCorrectly`
- `testMarkSameGroupTwiceOverridesState`
- `testAssetsToRemoveExcludesKeptGroups`

**Tasks to make these tests pass:**

- [ ] Create `Curator/Features/Deduplication/DeduplicationViewModel.swift`
- [ ] Define `DuplicateGroupReviewState` enum (`.pending`, `.keep`, `.remove`) with Sendable, Equatable
- [ ] Implement `@MainActor @Observable final class DeduplicationViewModel`
- [ ] Properties: `groups: [DuplicateGroup]`, `reviewStates: [UUID: DuplicateGroupReviewState]`
- [ ] Computed: `pendingGroups`, `reviewedCount`, `totalGroups`, `markedForRemovalCount`, `allReviewed`
- [ ] Methods: `loadGroups(_:)`, `markAsKeep(groupID:)`, `markAsRemove(groupID:)`, `toggleReviewState(groupID:)`, `reviewState(for:)`, `assetsToRemove()`
- [ ] Remove stub declarations from test file (lines 17-85)
- [ ] Remove `XCTSkipIf(true, ...)` from all tests
- [ ] Run tests: `xcodebuild test -project Curator.xcodeproj -scheme Curator -destination 'platform=macOS' -only-testing:CuratorTests/DeduplicationViewModelTests`
- [ ] All 17 tests pass (green phase)

### Task 2: Create PhotoComparisonCard (AC: #1, UX-DR4)

**No ATDD tests** -- UI component, validated via Xcode Previews.

- [ ] Create `Curator/Features/Deduplication/PhotoComparisonCard.swift`
- [ ] Implement per UX-DR4 spec

### Task 3: Create DuplicateReviewView (AC: #1, #3)

**No ATDD tests** -- SwiftUI view, validated via Xcode Previews.

- [ ] Create `Curator/Features/Deduplication/DuplicateReviewView.swift`
- [ ] Implement with ScrollView + LazyVStack

### Task 4: Integrate with AgentExecutionPanel (AC: #5)

**No ATDD tests** -- integration wiring, tested during manual verification.

- [ ] Modify `AgentExecutionPanel.swift` -- embed DuplicateReviewView in review state
- [ ] Modify `MainWorkspaceView.swift` -- integrate DeduplicationViewModel
- [ ] Modify `AppDependencies.swift` -- add deduplicationViewModel property

---

## Running Tests

```bash
# Run all ATDD tests for this story (all skipped in red phase)
xcodebuild test -project Curator.xcodeproj -scheme Curator -destination 'platform=macOS' -only-testing:CuratorTests/DeduplicationViewModelTests

# Run full test suite (verify no regressions)
xcodebuild test -project Curator.xcodeproj -scheme Curator -destination 'platform=macOS'
```

---

## Red-Green-Refactor Workflow

### RED Phase (Complete)

- All 17 tests written as red-phase scaffolds with `XCTSkipIf(true, ...)`
- Test stubs provided for `DeduplicationViewModel` and `DuplicateGroupReviewState`
- Full test suite passes with 17 skips, 0 failures
- Build compiles successfully

### GREEN Phase (DEV Team -- Next Steps)

1. **Create real implementations** in `Curator/Features/Deduplication/`
2. **Remove test stubs** (lines 17-85 of the test file)
3. **Remove `XCTSkipIf`** from each test
4. **Run tests** -- verify they fail first (now testing real code), then pass
5. **Work one test at a time** for clean TDD cycle

### REFACTOR Phase (After All Tests Pass)

- Review ViewModel for code quality
- Ensure @Observable drives SwiftUI correctly
- Verify no race conditions with @MainActor

---

## Test Execution Evidence

### Initial Scaffold Review / RED Verification

**Command:**

```bash
xcodebuild test -project Curator.xcodeproj -scheme Curator -destination 'platform=macOS' -only-testing:CuratorTests/DeduplicationViewModelTests
```

**Results:**

```
Executed 17 tests, with 17 tests skipped and 0 failures (0 unexpected) in 0.071 seconds
```

**Full suite:**

```
Executed 717 tests, with 17 tests skipped and 0 failures (0 unexpected) in 45.186 seconds
** TEST SUCCEEDED **
```

**Summary:**

- Total tests: 17 (new) + 700 (existing)
- Skipped: 17 (expected before activation)
- Activated RED tests: 0 (all still in skipped state)
- Passing: 700 (all existing tests still pass)
- Status: RED phase scaffolds verified

---

## Key Risks and Assumptions

1. **Test stubs must be removed** when real implementations are created -- duplicate symbols will cause compile errors if both exist
2. **XCTSkipIf pattern** -- tests are skipped, not failing. During green phase, remove skips and verify tests fail first (due to stub removal), then pass with real implementations
3. **No UI tests** -- SwiftUI views (PhotoComparisonCard, DuplicateReviewView) are validated via Xcode Previews and manual testing, not automated tests
4. **ViewModel-View contract** -- tests verify ViewModel logic; the SwiftUI rendering contract (Observable updates driving view) is assumed to work via the @Observable macro
5. **FileFormat enum** -- test helper uses `FileFormat(rawValue: "JPEG")` which should produce `.jpeg` case

---

## Knowledge Base References Applied

- **component-tdd.md** -- Component test strategies applied to ViewModel unit tests
- **data-factories.md** -- `makeDuplicateGroup()` factory pattern for test data generation
- **test-quality.md** -- Given-When-Then format, one assertion per test, determinism, isolation

---

## Next Steps

1. **Begin implementation** using Task 1 (DeduplicationViewModel)
2. **Remove test stubs** when creating real implementations
3. **Activate tests** by removing `XCTSkipIf` guards
4. **Work one test at a time** through the TDD red-green cycle
5. **After all ViewModel tests pass**, proceed to SwiftUI views (Tasks 2-4)
6. **Run full test suite** after all changes to verify no regressions
