---
stepsCompleted:
  - step-01-load-context
  - step-02-discover-tests
  - step-03-map-criteria
  - step-04-analyze-gaps
  - step-05-gate-decision
lastStep: step-05-gate-decision
lastSaved: '2026-04-20'
coverageBasis: acceptance_criteria
oracleConfidence: high
oracleResolutionMode: formal_requirements
oracleSources:
  - _bmad-output/implementation-artifacts/1-5-first-launch-onboarding.md
  - _bmad-output/test-artifacts/atdd-checklist-1-5-first-launch-onboarding.md
externalPointerStatus: not_used
tempCoverageMatrixPath: _bmad-output/test-artifacts/traceability/coverage-matrix-1-5.json
---

# Traceability Report: Story 1-5 — First Launch Onboarding Flow (Local Folder)

## Gate Decision: PENDING RE-IMPLEMENTATION

**Rationale:** Story 1-5 has been rewritten to align with the local folder architecture. Tests and implementation need to be updated to match the new OnboardingStep enum (6 cases instead of 7) and folder selection flow (NSOpenPanel instead of PhotoKit permission). Previous traceability results are invalidated.

## Coverage Summary

| Metric | Value |
|--------|-------|
| Total Requirements | 22 |
| Fully Covered | 0 (pending re-implementation) |
| Partially Covered | 0 |
| Uncovered | 22 |

### Priority Coverage

| Priority | Total | Covered | Percentage | Status |
|----------|-------|---------|------------|--------|
| P0 | 12 | 0 | 0% | PENDING |
| P1 | 10 | 0 | 0% | PENDING |
| P2 | 0 | 0 | N/A | N/A |
| P3 | 0 | 0 | N/A | N/A |

## Traceability Matrix

### AC1: Welcome Onboarding Flow (max 3 screens)

| Req ID | Requirement | Priority | Coverage | Test(s) |
|--------|-------------|----------|----------|---------|
| AC1-R01 | OnboardingStep enum defines 6 cases (welcome/privacy/folderSelection/scanning/complete/noFolder) | P0 | PENDING | testOnboardingStepEnumHasAllCases |
| AC1-R02 | OnboardingStep is Int-backed and CaseIterable | P1 | PENDING | testOnboardingStepIsIntBackedCaseIterable |
| AC1-R03 | OnboardingViewModel exists as MainActor ObservableObject | P0 | PENDING | testOnboardingViewModelExists |
| AC1-R04 | ViewModel initializes with currentStep = welcome | P0 | PENDING | testViewModelInitializesWithWelcomeStep |
| AC1-R05 | ViewModel initializes with isOnboardingComplete = false | P0 | PENDING | testViewModelInitializesWithOnboardingIncomplete |
| AC1-R06 | Forward navigation: welcome -> privacy | P0 | PENDING | testGoToNextStepFromWelcomeGoesToPrivacy |
| AC1-R07 | Forward navigation: privacy -> folderSelection | P0 | PENDING | testGoToNextStepFromPrivacyGoesToFolderSelection |
| AC1-R08 | folderSelection step triggers selectPhotoFolder() | P0 | PENDING | testGoToNextStepFromFolderSelectionTriggersSelectFolder |
| AC1-R09 | Backward navigation: privacy -> welcome | P0 | PENDING | testGoToPreviousStepFromPrivacyGoesToWelcome |
| AC1-R10 | Backward navigation: folderSelection -> privacy | P0 | PENDING | testGoToPreviousStepFromFolderSelectionGoesToPrivacy |
| AC1-R11 | Backward navigation: welcome is no-op | P1 | PENDING | testGoToPreviousStepAtWelcomeIsNoOp |
| AC1-R12 | canGoBack is true only on privacy and folderSelection | P1 | PENDING | testCanGoBackIsTrueOnPrivacyAndFolderSelection |

### AC2: Folder Selection and Photo Scan

| Req ID | Requirement | Priority | Coverage | Test(s) |
|--------|-------------|----------|----------|---------|
| AC2-R01 | Folder selected transitions to scanning | P0 | PENDING | testFolderSelectionGrantedTransitionsToScanning |
| AC2-R02 | Successful scan shows photo count summary | P0 | PENDING | testSuccessfulFolderSelectionShowsPhotoCountSummary |
| AC2-R03 | Scan with empty folder shows zero count | P1 | PENDING | testScanWithEmptyFolderShowsZeroCount |
| AC2-R04 | Scan with hasMore shows plus indicator | P1 | PENDING | testScanWithMorePhotosShowsPlusIndicator |

### AC3: No Folder Selected Degradation

| Req ID | Requirement | Priority | Coverage | Test(s) |
|--------|-------------|----------|----------|---------|
| AC3-R01 | Folder selection cancelled transitions to noFolder state | P0 | PENDING | testFolderSelectionCancelledTransitionsToNoFolder |
| AC3-R02 | noFolder state allows continue with restricted access | P0 | PENDING | testNoFolderStateAllowsContinueRestricted |
| AC3-R03 | noFolder state allows retry folder selection | P1 | PENDING | testNoFolderStateAllowsRetryFolderSelection |

### Onboarding Completion

| Req ID | Requirement | Priority | Coverage | Test(s) |
|--------|-------------|----------|----------|---------|
| COMP-R01 | Completing onboarding sets flag to true | P0 | PENDING | testCompletingOnboardingSetsFlagToTrue |
| COMP-R02 | isOnboardingComplete is observable by SwiftUI | P1 | PENDING | testIsOnboardingCompleteIsPublished |

### Repository Injection

| Req ID | Requirement | Priority | Coverage | Test(s) |
|--------|-------------|----------|----------|---------|
| INJ-R01 | ViewModel accepts repository via init injection | P0 | PENDING | testViewModelAcceptsRepositoryInjection |
| INJ-R02 | ViewModel handles nil repository gracefully | P0 | PENDING | testViewModelHandlesNilRepository |
| INJ-R03 | ViewModel uses injected repository for folder selection | P1 | PENDING | testViewModelUsesInjectedRepositoryForFolderSelection |

### Step Indicator Support

| Req ID | Requirement | Priority | Coverage | Test(s) |
|--------|-------------|----------|----------|---------|
| STEP-R01 | currentStepIndex provides correct 0-based index (3 steps) | P1 | PENDING | testCurrentStepIndexProvidesCorrectIndex |
| STEP-R02 | totalOnboardingSteps returns 3 | P1 | PENDING | testTotalOnboardingStepsIsThree |

## Removed Requirements (from PhotoKit version)

| Req ID | Requirement | Reason |
|--------|-------------|--------|
| AC1-R13 (old) | LLM config step navigation | Removed: LLM config moved to Epic 2 |
| AC3-R03 (old) | openSystemSettings action | Removed: no longer opens system settings |
| STEP-R02 (old) | totalOnboardingSteps returns 3 (was 4) | Updated: now truly 3 |

## Gaps and Recommendations

**All requirements pending re-implementation.**

### Advisory Notes

1. **[HIGH]** OnboardingStep enum must be updated first — all other changes depend on the new case names.
2. **[HIGH]** LLMConfigView.swift must be handled (deleted or relocated) before ViewModel rewrite, as it references properties being removed.
3. **[MEDIUM]** NSOpenPanel folder selection cannot be unit-tested directly. Mock repository simulates success/cancel paths.
4. **[LOW]** SwiftUI View tests remain limited. ViewModel behavioral tests provide coverage.
