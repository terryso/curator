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
storyId: '1.4'
storyKey: 1-4-photo-library-browse-grid
storyFile: _bmad-output/implementation-artifacts/1-4-photo-library-browse-grid.md
atddChecklistPath: _bmad-output/test-artifacts/atdd-checklist-1-4-photo-library-browse-grid.md
generatedTestFiles:
  - CuratorTests/Features/PhotoLibrary/PhotoLibraryViewModelTests.swift
  - CuratorTests/Features/PhotoLibrary/GridColumnCalculatorTests.swift
---

# ATDD Checklist: Story 1.4 - Photo Library Browse Grid

## TDD Red Phase (Current)

RED-phase test scaffolds generated. All tests use XCTSkip() to skip execution
until implementation types (PhotoLibraryViewModel, GridColumnCalculator) are
created. Build succeeds; tests pass by skipping. This is intentional (TDD red phase).

- **Unit Tests**: 32 test methods across 2 test files (all XCTSkip red-phase)
- **E2E Tests**: N/A (backend Swift project, no browser testing)
- **Build Status**: SUCCEEDS (test files compile, tests skip gracefully)
- **Total Test Suite**: 122 tests (32 skipped, 90 passing)

## Acceptance Criteria Coverage

### AC1: Adaptive Grid Layout (UX-DR13)

| Test File | Test Method | Priority | Status |
|-----------|-------------|----------|--------|
| GridColumnCalculatorTests | testGridColumnCountNarrowWidth | P0 | RED (XCTSkip) |
| GridColumnCalculatorTests | testGridColumnCount800Width | P0 | RED (XCTSkip) |
| GridColumnCalculatorTests | testGridColumnCountMinimumOne | P0 | RED (XCTSkip) |
| GridColumnCalculatorTests | testGridColumnCountVerySmallWidth | P1 | RED (XCTSkip) |
| GridColumnCalculatorTests | testGridColumnCountWideDisplay | P1 | RED (XCTSkip) |
| GridColumnCalculatorTests | testGridColumnsProducesCorrectGridItemArray | P1 | RED (XCTSkip) |
| GridColumnCalculatorTests | testGridColumnsSpacingIs4pt | P1 | RED (XCTSkip) |
| GridColumnCalculatorTests | testGridColumnCountExactlyTwoColumns | P2 | RED (XCTSkip) |
| GridColumnCalculatorTests | testGridColumnCountFractionalBoundary | P2 | RED (XCTSkip) |
| PhotoLibraryViewModelTests | testGridColumnsSingleColumnForNarrowWidth | P0 | RED (XCTSkip) |
| PhotoLibraryViewModelTests | testGridColumnsCorrectForTypicalWidth | P0 | RED (XCTSkip) |
| PhotoLibraryViewModelTests | testGridColumnsMinimumOneColumn | P1 | RED (XCTSkip) |
| PhotoLibraryViewModelTests | testGridColumnsForWideDisplay | P1 | RED (XCTSkip) |

### AC2: Paginated Infinite Scroll

| Test File | Test Method | Priority | Status |
|-----------|-------------|----------|--------|
| PhotoLibraryViewModelTests | testLoadInitialPageTransitionsToLoaded | P0 | RED (XCTSkip) |
| PhotoLibraryViewModelTests | testLoadInitialPageSetsLoadingStateDuringFetch | P0 | RED (XCTSkip) |
| PhotoLibraryViewModelTests | testLoadNextPageAppendsToExistingPhotos | P0 | RED (XCTSkip) |
| PhotoLibraryViewModelTests | testLoadNextPageDoesNotFetchWhenNoMorePages | P0 | RED (XCTSkip) |
| PhotoLibraryViewModelTests | testHasMorePagesReflectsState | P1 | RED (XCTSkip) |
| PhotoLibraryViewModelTests | testLoadNextPagePreventsConcurrentLoading | P1 | RED (XCTSkip) |
| PhotoLibraryViewModelTests | testLoadNextPageDoesNothingWhenLoading | P1 | RED (XCTSkip) |

### AC3: Photo Detail Sheet

| Test File | Test Method | Priority | Status |
|-----------|-------------|----------|--------|
| PhotoLibraryViewModelTests | testSelectedPhotoAssetTracksSheetState | P0 | RED (XCTSkip) |
| PhotoLibraryViewModelTests | testDeselectingPhotoClearsSheetState | P0 | RED (XCTSkip) |
| PhotoLibraryViewModelTests | testPhotoDetailSheetShowsMetadata | P1 | RED (XCTSkip) |

### Error Handling & Empty State

| Test File | Test Method | Priority | Status |
|-----------|-------------|----------|--------|
| PhotoLibraryViewModelTests | testLoadInitialPageTransitionsToFailedOnError | P0 | RED (XCTSkip) |
| PhotoLibraryViewModelTests | testLoadNextPageTransitionsToFailedOnError | P0 | RED (XCTSkip) |
| PhotoLibraryViewModelTests | testEmptyStateWhenNoPhotos | P0 | RED (XCTSkip) |
| PhotoLibraryViewModelTests | testViewModelProvidesIsEmptyProperty | P1 | RED (XCTSkip) |

### ViewModel Lifecycle & DI

| Test File | Test Method | Priority | Status |
|-----------|-------------|----------|--------|
| PhotoLibraryViewModelTests | testPhotoLibraryViewModelExists | P0 | RED (XCTSkip) |
| PhotoLibraryViewModelTests | testViewModelInitializesWithIdleState | P0 | RED (XCTSkip) |
| PhotoLibraryViewModelTests | testViewModelInitializesWithEmptyPhotos | P0 | RED (XCTSkip) |
| PhotoLibraryViewModelTests | testViewModelAcceptsRepositoryInjection | P0 | RED (XCTSkip) |
| PhotoLibraryViewModelTests | testViewModelHandlesNilRepository | P0 | RED (XCTSkip) |

## Test Priority Distribution

| Priority | Count | Description |
|----------|-------|-------------|
| P0 | 19 | Must pass before merge |
| P1 | 10 | Should pass, non-blocking |
| P2 | 3 | Nice to have |
| P3 | 0 | Future consideration |
| **Total** | **32** | |

## Next Steps (Task-by-Task Activation)

During implementation of each task in Story 1.4:

1. **Task 1: Implement PhotoLibraryViewModel** (AC1, AC2, AC3)
   - Create `Curator/Features/PhotoLibrary/PhotoLibraryViewModel.swift`
   - Remove `XCTSkip()` from PhotoLibraryViewModelTests as methods are implemented
   - Run tests: `xcodebuild test -scheme Curator -destination 'platform=macOS,arch=arm64' -only-testing:CuratorTests/PhotoLibraryViewModelTests`
   - Verify tests pass (GREEN phase)

2. **Task 2: Implement PhotoGridView** (AC1, AC2)
   - Create `Curator/Features/PhotoLibrary/PhotoGridView.swift`
   - Implement GridColumnCalculator (or include in ViewModel)
   - Remove `XCTSkip()` from GridColumnCalculatorTests
   - Run tests: `xcodebuild test -scheme Curator -destination 'platform=macOS,arch=arm64' -only-testing:CuratorTests/GridColumnCalculatorTests`
   - Verify tests pass (GREEN phase)

3. **Task 3: Implement PhotoThumbnailView** (AC1)
   - Create `Curator/Features/PhotoLibrary/PhotoThumbnailView.swift`
   - Update ContentView to display PhotoGridView

4. **Task 4: Implement PhotoDetailSheet** (AC3)
   - Create `Curator/Features/PhotoLibrary/PhotoDetailSheet.swift`

5. **Task 5: Full test suite**
   - Run all tests: `xcodebuild test -scheme Curator -destination 'platform=macOS,arch=arm64'`
   - Verify all 122+ tests pass with no regressions

## Implementation Guidance

### Types to Implement

1. **PhotoLibraryViewModel** (@MainActor, ObservableObject)
   - `@Published var photos: [PhotoAsset] = []`
   - `@Published var loadingState: LoadingState<[PhotoAsset]> = .idle`
   - `@Published var selectedPhoto: PhotoAsset?`
   - `var hasMorePages: Bool`
   - `var isEmpty: Bool`
   - `init(repository: (any PhotoLibraryRepository)?)`
   - `func loadInitialPage() async`
   - `func loadNextPage() async`
   - `func selectPhoto(_ photo: PhotoAsset)`
   - `func deselectPhoto()`

2. **GridColumnCalculator** (enum with static methods, or free functions)
   - `static func columnCount(for width: CGFloat) -> Int`
   - `static func gridItems(for width: CGFloat) -> [GridItem]`
   - Constants: `minColumnWidth = 120`, `spacing: CGFloat = 4`

3. **PhotoGridView** (SwiftUI View)
   - LazyVGrid + ScrollView
   - GeometryReader for width detection
   - Infinite scroll via onAppear

4. **PhotoThumbnailView** (SwiftUI View)
   - 120x120 thumbnail display
   - Placeholder for nil data
   - Accessibility label

5. **PhotoDetailSheet** (SwiftUI View)
   - Sheet with metadata display
   - Date, title, description, keywords, location
   - Graceful nil handling

### Mock Infrastructure

`MockPhotoLibraryRepository` (actor) is included in the test file:
- Configurable pages, errors, and delays
- Thread-safe page index tracking via actor isolation
- Serves pages sequentially for multi-page testing

### Execution Commands

```bash
# Run all tests
xcodebuild test -scheme Curator -destination 'platform=macOS,arch=arm64'

# Run ViewModel tests only
xcodebuild test -scheme Curator -destination 'platform=macOS,arch=arm64' -only-testing:CuratorTests/PhotoLibraryViewModelTests

# Run Grid column tests only
xcodebuild test -scheme Curator -destination 'platform=macOS,arch=arm64' -only-testing:CuratorTests/GridColumnCalculatorTests

# Build only (check compilation)
xcodebuild build -scheme Curator -destination 'platform=macOS,arch=arm64'
```

## Key Risks and Assumptions

1. **XCTSkip pattern**: Swift doesn't have `test.skip()` like JavaScript. Tests use `XCTSkip()` which still requires the type to exist for compilation. Unlike JS red-phase tests, Swift red-phase tests compile but skip execution.
2. **SwiftUI View testing**: Direct view testing in XCTest is limited. Grid column calculation is extracted to testable pure functions. View behavior (LazyVGrid, onAppear) is tested through the ViewModel.
3. **Thumbnail loading strategy**: Story 1.3 returns nil thumbnailData. Story 1.4 needs to decide on thumbnail loading approach (see Story Dev Notes). Tests are agnostic to the strategy chosen.
4. **Concurrency**: PhotoLibraryViewModel is @MainActor. All test methods that interact with it are marked @MainActor. MockPhotoLibraryRepository is an actor for thread safety.
5. **ContentView modification**: The story requires modifying ContentView. This is not directly tested here but verified via build success.

## ATDD Artifacts

- **Checklist**: `_bmad-output/test-artifacts/atdd-checklist-1-4-photo-library-browse-grid.md`
- **ViewModel Tests**: `CuratorTests/Features/PhotoLibrary/PhotoLibraryViewModelTests.swift`
- **Grid Calculator Tests**: `CuratorTests/Features/PhotoLibrary/GridColumnCalculatorTests.swift`
