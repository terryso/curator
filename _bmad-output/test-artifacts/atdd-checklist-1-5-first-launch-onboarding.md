---
stepsCompleted:
  - step-01-preflight-and-context
  - step-02-generation-mode
  - step-03-test-strategy
  - step-04-generate-tests
  - step-04c-aggregate
  - step-05-validate-and-complete
lastStep: step-05-validate-and-complete
lastSaved: '2026-04-18'
storyId: '1.5'
storyKey: 1-5-first-launch-onboarding
storyFile: _bmad-output/implementation-artifacts/1-5-first-launch-onboarding.md
atddChecklistPath: _bmad-output/test-artifacts/atdd-checklist-1-5-first-launch-onboarding.md
generatedTestFiles:
  - CuratorTests/Features/Onboarding/OnboardingViewModelTests.swift
  - Curator/Features/Onboarding/OnboardingStep.swift
  - Curator/Features/Onboarding/OnboardingViewModel.swift
---

# ATDD Checklist: Story 1.5 - First Launch Onboarding Flow

## TDD Red Phase (Current)

RED-phase test scaffolds generated. Stub types (OnboardingStep, OnboardingViewModel)
exist with minimal implementations so tests compile. Tests verify expected behavior
and fail against the stubs. This is intentional (TDD red phase).

- **Unit Tests**: 26 test methods across 1 test file
  - 11 passing (verify stub/enum/default state)
  - 15 failing (require actual ViewModel implementation)
- **E2E Tests**: N/A (Swift/macOS native project, no browser testing)
- **Build Status**: SUCCEEDS (test files compile, stubs compile)
- **Total Test Suite**: 144 tests (118 existing passing, 26 new — 15 failing RED)

## Acceptance Criteria Coverage

### AC1: Welcome Onboarding Flow (max 3 screens)

| Test File | Test Method | Priority | Status |
|-----------|-------------|----------|--------|
| OnboardingViewModelTests | testOnboardingStepEnumHasAllCases | P0 | GREEN (enum stub complete) |
| OnboardingViewModelTests | testOnboardingStepIsIntBackedCaseIterable | P1 | GREEN (enum stub complete) |
| OnboardingViewModelTests | testOnboardingViewModelExists | P0 | GREEN (stub exists) |
| OnboardingViewModelTests | testViewModelInitializesWithWelcomeStep | P0 | GREEN (default matches) |
| OnboardingViewModelTests | testViewModelInitializesWithOnboardingIncomplete | P0 | GREEN (default matches) |
| OnboardingViewModelTests | testGoToNextStepFromWelcomeGoesToPrivacy | P0 | RED |
| OnboardingViewModelTests | testGoToNextStepFromPrivacyGoesToPermission | P0 | RED |
| OnboardingViewModelTests | testGoToNextStepFromPermissionTriggersPermissionRequest | P0 | RED |
| OnboardingViewModelTests | testGoToPreviousStepFromPrivacyGoesToWelcome | P0 | RED |
| OnboardingViewModelTests | testGoToPreviousStepFromPermissionGoesToPrivacy | P0 | RED |
| OnboardingViewModelTests | testGoToPreviousStepAtWelcomeIsNoOp | P1 | GREEN (stub no-op matches) |
| OnboardingViewModelTests | testCanGoBackIsTrueOnPrivacyAndPermissionSteps | P1 | RED |

### AC2: Permission Grant and Photo Scan

| Test File | Test Method | Priority | Status |
|-----------|-------------|----------|--------|
| OnboardingViewModelTests | testRequestPermissionGrantedTransitionsToScanning | P0 | RED |
| OnboardingViewModelTests | testSuccessfulPermissionGrantShowsPhotoCountSummary | P0 | RED |
| OnboardingViewModelTests | testScanWithEmptyLibraryShowsZeroCount | P1 | RED |
| OnboardingViewModelTests | testScanWithMorePhotosShowsPlusIndicator | P1 | RED |

### AC3: Permission Denied Degradation

| Test File | Test Method | Priority | Status |
|-----------|-------------|----------|--------|
| OnboardingViewModelTests | testPermissionDeniedTransitionsToDeniedState | P0 | RED |
| OnboardingViewModelTests | testDeniedStateAllowsContinueRestricted | P0 | RED |
| OnboardingViewModelTests | testDeniedStateProvidesOpenSystemSettingsAction | P1 | RED |

### Onboarding Completion

| Test File | Test Method | Priority | Status |
|-----------|-------------|----------|--------|
| OnboardingViewModelTests | testCompletingOnboardingSetsFlagToTrue | P0 | RED |
| OnboardingViewModelTests | testIsOnboardingCompleteIsPublished | P1 | GREEN (ObservableObject) |

### Repository Injection

| Test File | Test Method | Priority | Status |
|-----------|-------------|----------|--------|
| OnboardingViewModelTests | testViewModelAcceptsRepositoryInjection | P0 | GREEN (stub accepts) |
| OnboardingViewModelTests | testViewModelHandlesNilRepository | P0 | RED |
| OnboardingViewModelTests | testViewModelUsesInjectedRepositoryForPermission | P1 | GREEN (no-op stub) |

### Step Indicator Support

| Test File | Test Method | Priority | Status |
|-----------|-------------|----------|--------|
| OnboardingViewModelTests | testCurrentStepIndexProvidesCorrectIndex | P1 | RED |
| OnboardingViewModelTests | testTotalOnboardingStepsIsThree | P1 | GREEN (constant matches) |

## Test Priority Distribution

| Priority | Count | Description |
|----------|-------|-------------|
| P0 | 14 | Must pass before merge |
| P1 | 12 | Should pass, non-blocking |
| P2 | 0 | Nice to have |
| P3 | 0 | Future consideration |
| **Total** | **26** | |

## Next Steps (Task-by-Task Activation)

During implementation of each task in Story 1.5:

1. **Task 1: Implement OnboardingViewModel** (AC: #1, #2, #3)
   - Fill in `Curator/Features/Onboarding/OnboardingViewModel.swift` implementation
   - Remove stub bodies and replace with real logic
   - Run tests: `xcodebuild test -project Curator.xcodeproj -scheme Curator -destination 'platform=macOS,arch=arm64' -only-testing:CuratorTests/OnboardingViewModelTests`
   - Verify RED tests transition to GREEN

2. **Task 2-5: Create Views** (AC: #1, #2, #3)
   - Create WelcomeView, PrivacyExplanationView, PermissionRequestView
   - Create LibraryScanView, PermissionDeniedView
   - Views are not directly unit-tested (SwiftUI limitation)
   - ViewModel tests provide behavioral coverage

3. **Task 6: Create OnboardingContainerView** (AC: #1)
   - Container view that switches based on viewModel.currentStep
   - Step indicator integration

4. **Task 7: Integrate into ContentView** (AC: #1, #2)
   - Modify ContentView to check @AppStorage("hasCompletedOnboarding")
   - Test via build + manual verification

5. **Task 8: Full test suite**
   - Run all tests: `xcodebuild test -project Curator.xcodeproj -scheme Curator -destination 'platform=macOS,arch=arm64'`
   - Verify all 144+ tests pass with no regressions

## Implementation Guidance

### Types to Implement (fill in stubs)

1. **OnboardingViewModel** (@MainActor, ObservableObject) -- stub exists
   - `@Published var currentStep: OnboardingStep = .welcome`
   - `@Published var isOnboardingComplete: Bool = false`
   - `@Published var discoveredPhotoCount: Int? = nil`
   - `@Published var hasMorePhotos: Bool = false`
   - `var canGoBack: Bool` — computed, true for privacy/permission steps
   - `var currentStepIndex: Int` — computed, maps step to 0-based index
   - `let totalOnboardingSteps: Int = 3`
   - `init(repository: (any PhotoLibraryRepository)?)`
   - `func goToNextStep()` — advance step in welcome->privacy->permission sequence
   - `func goToPreviousStep()` — go back one step, no-op at welcome
   - `func requestPhotoPermission() async` — call repository, transition to scanning/complete/denied
   - `func completeOnboarding()` — set isOnboardingComplete = true
   - `func continueWithRestrictedAccess()` — set isOnboardingComplete = true from denied
   - `func openSystemSettings()` — open macOS system preferences

2. **OnboardingStep** (Int enum, CaseIterable) -- complete stub exists
   - Cases: welcome=0, privacy=1, permission=2, scanning=3, complete=4, denied=5

### Views to Create (not unit-tested, SwiftUI)

3. **WelcomeView** — product intro screen
4. **PrivacyExplanationView** — privacy explanation screen
5. **PermissionRequestView** — photo permission request screen
6. **LibraryScanView** — scanning progress / photo count summary
7. **PermissionDeniedView** — permission denied with system settings link
8. **OnboardingContainerView** — container that switches views by currentStep

### Mock Infrastructure

`MockOnboardingRepository` (actor) is included in the test file:
- Configurable permission grant/deny
- Configurable asset count and hasMore flag
- Paginated asset fetch support
- Thread-safe via actor isolation

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

1. **Swift red-phase pattern**: Unlike JavaScript `test.skip()`, Swift requires types to exist for compilation. Minimal stubs are provided so tests compile. The stubs have empty method bodies that cause test failures -- this IS the red phase.
2. **Enum completeness**: OnboardingStep enum is fully defined in the stub (all 6 cases). Tests verify this enum won't change during implementation.
3. **SwiftUI View testing**: Direct view testing in XCTest is limited. OnboardingContainerView and sub-views are not unit-tested. ViewModel tests provide complete behavioral coverage.
4. **@AppStorage testing**: The `hasCompletedOnboarding` flag is tested through the ViewModel's `isOnboardingComplete` property. Actual @AppStorage integration is verified via ContentView build.
5. **Photo count strategy**: Tests follow "Plan B" from story notes -- fetch first page (pageSize: 100), display count + "+" if hasMore.
6. **Concurrency**: OnboardingViewModel is @MainActor. All test methods are @MainActor. MockOnboardingRepository is an actor for thread safety.

## ATDD Artifacts

- **Checklist**: `_bmad-output/test-artifacts/atdd-checklist-1-5-first-launch-onboarding.md`
- **ViewModel Tests**: `CuratorTests/Features/Onboarding/OnboardingViewModelTests.swift`
- **Enum Stub**: `Curator/Features/Onboarding/OnboardingStep.swift`
- **ViewModel Stub**: `Curator/Features/Onboarding/OnboardingViewModel.swift`
