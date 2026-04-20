---
stepsCompleted:
  - step-01-preflight-and-context
  - step-02-generation-mode
  - step-03-test-strategy
  - step-04-generate-tests
  - step-04c-aggregate
  - step-05-validate-and-complete
lastStep: step-05-validate-and-complete
lastSaved: '2026-04-20'
storyId: '1.5'
storyKey: 1-5-first-launch-onboarding
storyFile: _bmad-output/implementation-artifacts/1-5-first-launch-onboarding.md
atddChecklistPath: _bmad-output/test-artifacts/atdd-checklist-1-5-first-launch-onboarding.md
generatedTestFiles:
  - CuratorTests/Features/Onboarding/OnboardingViewModelTests.swift
  - Curator/Features/Onboarding/OnboardingStep.swift
  - Curator/Features/Onboarding/OnboardingViewModel.swift
---

# ATDD Checklist: Story 1.5 - First Launch Onboarding Flow (Local Folder)

## TDD Red Phase (Current)

Updated for local folder architecture. PhotoKit permission model replaced with
NSOpenPanel folder selection. LLM config step removed (moved to Epic 2).

- **Unit Tests**: ~22 test methods across 1 test file (updated count)
- **E2E Tests**: N/A (Swift/macOS native project, no browser testing)
- **Build Status**: Pending (tests need update to match new OnboardingStep enum)

## Acceptance Criteria Coverage

### AC1: Welcome Onboarding Flow (max 3 screens)

| Test File | Test Method | Priority | Status |
|-----------|-------------|----------|--------|
| OnboardingViewModelTests | testOnboardingStepEnumHasAllCases | P0 | NEEDS UPDATE (6 cases: welcome/privacy/folderSelection/scanning/complete/noFolder) |
| OnboardingViewModelTests | testOnboardingStepIsIntBackedCaseIterable | P1 | NEEDS UPDATE |
| OnboardingViewModelTests | testOnboardingViewModelExists | P0 | PASS (stub exists) |
| OnboardingViewModelTests | testViewModelInitializesWithWelcomeStep | P0 | PASS |
| OnboardingViewModelTests | testViewModelInitializesWithOnboardingIncomplete | P0 | PASS |
| OnboardingViewModelTests | testGoToNextStepFromWelcomeGoesToPrivacy | P0 | NEEDS UPDATE |
| OnboardingViewModelTests | testGoToNextStepFromPrivacyGoesToFolderSelection | P0 | NEEDS UPDATE (renamed from permission) |
| OnboardingViewModelTests | testGoToNextStepFromFolderSelectionTriggersSelectFolder | P0 | NEW (replaces permission request test) |
| OnboardingViewModelTests | testGoToPreviousStepFromPrivacyGoesToWelcome | P0 | PASS |
| OnboardingViewModelTests | testGoToPreviousStepFromFolderSelectionGoesToPrivacy | P0 | NEEDS UPDATE (renamed from permission) |
| OnboardingViewModelTests | testGoToPreviousStepAtWelcomeIsNoOp | P1 | PASS |
| OnboardingViewModelTests | testCanGoBackIsTrueOnPrivacyAndFolderSelection | P1 | NEEDS UPDATE |

### AC2: Folder Selection and Photo Scan

| Test File | Test Method | Priority | Status |
|-----------|-------------|----------|--------|
| OnboardingViewModelTests | testFolderSelectionGrantedTransitionsToScanning | P0 | NEEDS UPDATE (renamed from permission) |
| OnboardingViewModelTests | testSuccessfulFolderSelectionShowsPhotoCountSummary | P0 | NEEDS UPDATE |
| OnboardingViewModelTests | testScanWithEmptyFolderShowsZeroCount | P1 | NEEDS UPDATE |
| OnboardingViewModelTests | testScanWithMorePhotosShowsPlusIndicator | P1 | PASS |

### AC3: No Folder Selected Degradation

| Test File | Test Method | Priority | Status |
|-----------|-------------|----------|--------|
| OnboardingViewModelTests | testFolderSelectionCancelledTransitionsToNoFolder | P0 | NEEDS UPDATE (renamed from denied) |
| OnboardingViewModelTests | testNoFolderStateAllowsContinueRestricted | P0 | NEEDS UPDATE |
| OnboardingViewModelTests | testNoFolderStateAllowsRetryFolderSelection | P1 | NEW (replaces openSystemSettings) |

### Onboarding Completion

| Test File | Test Method | Priority | Status |
|-----------|-------------|----------|--------|
| OnboardingViewModelTests | testCompletingOnboardingSetsFlagToTrue | P0 | PASS |
| OnboardingViewModelTests | testIsOnboardingCompleteIsPublished | P1 | PASS |

### Repository Injection

| Test File | Test Method | Priority | Status |
|-----------|-------------|----------|--------|
| OnboardingViewModelTests | testViewModelAcceptsRepositoryInjection | P0 | PASS |
| OnboardingViewModelTests | testViewModelHandlesNilRepository | P0 | PASS |
| OnboardingViewModelTests | testViewModelUsesInjectedRepositoryForFolderSelection | P1 | NEEDS UPDATE |

### Step Indicator Support

| Test File | Test Method | Priority | Status |
|-----------|-------------|----------|--------|
| OnboardingViewModelTests | testCurrentStepIndexProvidesCorrectIndex | P1 | NEEDS UPDATE (3 steps: 0/1/2) |
| OnboardingViewModelTests | testTotalOnboardingStepsIsThree | P1 | PASS |

## Test Priority Distribution

| Priority | Count | Description |
|----------|-------|-------------|
| P0 | 12 | Must pass before merge |
| P1 | 10 | Should pass, non-blocking |
| P2 | 0 | Nice to have |
| P3 | 0 | Future consideration |
| **Total** | **~22** | (reduced from 26 due to LLM config removal) |

## Removed Tests

The following tests from the original PhotoKit implementation are no longer needed:

| Test Method | Reason |
|-------------|--------|
| testGoToNextStepFromPermissionTriggersPermissionRequest | Replaced by testGoToNextStepFromFolderSelectionTriggersSelectFolder |
| testPermissionDeniedTransitionsToDeniedState | Replaced by testFolderSelectionCancelledTransitionsToNoFolder |
| testDeniedStateAllowsContinueRestricted | Replaced by testNoFolderStateAllowsContinueRestricted |
| testDeniedStateProvidesOpenSystemSettingsAction | Removed (no longer opens system settings; replaced by retry folder selection) |

## Implementation Guidance

### Types to Update

1. **OnboardingStep** (Int enum, CaseIterable) -- update existing
   - Cases: welcome=0, privacy=1, folderSelection=2, scanning=3, complete=4, noFolder=5
   - Remove: llmConfig
   - Rename: permission → folderSelection, denied → noFolder

2. **OnboardingViewModel** (@MainActor, ObservableObject) -- rewrite
   - Remove: baseURL, apiKey, modelID, isLLMConfigValid, saveLLMConfig()
   - Change: totalOnboardingSteps = 3 (was 4)
   - Change: requestPhotoPermission() → selectPhotoFolder()
   - Add: retryFolderSelection()
   - Remove: openSystemSettings()

### Mock Infrastructure

`MockPhotoLibraryRepository` (已存在于 `Curator/Infrastructure/Mock/MockPhotoLibraryRepository.swift`):
- Configurable permission grant/deny (via requestReadAccess)
- Configurable asset count and hasMore flag
- Paginated asset fetch support

### Execution Commands

```bash
# Run all tests
xcodebuild test -project Curator.xcodeproj -scheme Curator -destination 'platform=macOS,arch=arm64'

# Run Onboarding tests only
xcodebuild test -project Curator.xcodeproj -scheme Curator -destination 'platform=macOS,arch=arm64' -only-testing:CuratorTests/OnboardingViewModelTests

# Build only (check compilation)
xcodebuild build -project Curator.xcodeproj -scheme Curator -destination 'platform=macOS,arch=arm64'
```

## Key Risks and Assumptions

1. **Enum rename impact**: Changing OnboardingStep cases will affect OnboardingContainerView, all sub-views, and test files. Ensure all switch statements are updated.
2. **LLMConfigView disposition**: LLMConfigView.swift must be removed or relocated before tests, as it references ViewModel properties (baseURL, apiKey, modelID) that are being removed.
3. **Folder selection via repository**: The selectPhotoFolder() method delegates to repository.requestReadAccess() which internally uses FolderBookmarkManager. The ViewModel does not call FolderBookmarkManager directly.
4. **NSOpenPanel in tests**: NSOpenPanel cannot be tested in unit tests. The mock repository simulates the success/cancel paths.
5. **Step count change**: totalOnboardingSteps changes from 4 to 3, affecting step indicator dot count.

## ATDD Artifacts

- **Checklist**: `_bmad-output/test-artifacts/atdd-checklist-1-5-first-launch-onboarding.md`
- **ViewModel Tests**: `CuratorTests/Features/Onboarding/OnboardingViewModelTests.swift`（需更新）
- **Enum**: `Curator/Features/Onboarding/OnboardingStep.swift`（需更新）
- **ViewModel**: `Curator/Features/Onboarding/OnboardingViewModel.swift`（需重写）
