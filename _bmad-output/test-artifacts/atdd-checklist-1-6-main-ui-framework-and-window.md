---
stepsCompleted:
  - step-01-preflight-and-context
  - step-02-generation-mode
  - step-03-test-strategy
  - step-04-generate-tests
  - step-04c-aggregate
  - step-05-validate-and-complete
lastStep: step-05-validate-and-complete
lastSaved: '2026-04-19'
storyId: '1.6'
storyKey: 1-6-main-ui-framework-and-window
storyFile: _bmad-output/implementation-artifacts/1-6-main-ui-framework-and-window.md
atddChecklistPath: _bmad-output/test-artifacts/atdd-checklist-1-6-main-ui-framework-and-window.md
generatedTestFiles:
  - CuratorTests/Features/MainWorkspace/MainWorkspaceTests.swift
  - Curator/App/NavigationModel.swift
---

# ATDD Checklist: Story 1.6 - Main UI Framework and Window Management

## TDD Red Phase (Current)

RED-phase test scaffolds generated. Stub types (NavigationModel, ActivePanel)
exist with minimal implementations so tests compile. Tests verify expected behavior
and fail against the stubs. This is intentional (TDD red phase).

- **Unit Tests**: 29 test methods across 1 test file
  - 21 passing (verify stub defaults, enum existence, constants, @AppStorage reads)
  - 8 failing (require actual sidebar toggle/panel/persistence implementation)
- **E2E Tests**: N/A (Swift/macOS native project, no browser testing)
- **Build Status**: SUCCEEDS (test files compile, stubs compile)
- **Total Test Suite**: 173 tests (144 existing passing + 29 new -- 8 failing RED, 2 skipped)

## Acceptance Criteria Coverage

### AC1: NavigationSplitView Three-Column Layout

| Test File | Test Method | Priority | Status |
|-----------|-------------|----------|--------|
| MainWorkspaceTests | testNavigationModelExists | P0 | GREEN (ObservableObject stub) |
| MainWorkspaceTests | testNavigationModelInitializesWithSidebarVisible | P0 | GREEN (default true) |
| MainWorkspaceTests | testActivePanelEnumHasRequiredCases | P0 | GREEN (enum stub complete) |
| MainWorkspaceTests | testNavigationModelInitializesWithAgentWorkspaceActive | P0 | GREEN (default matches) |
| MainWorkspaceTests | testToggleSidebarFromVisibleToHidden | P0 | RED |
| MainWorkspaceTests | testToggleSidebarFromHiddenToVisible | P0 | RED |
| MainWorkspaceTests | testShowSidebarSetsVisibleToTrue | P1 | RED |
| MainWorkspaceTests | testHideSidebarSetsVisibleToFalse | P1 | RED |
| MainWorkspaceTests | testShowSidebarIsIdempotent | P1 | GREEN (already visible) |
| MainWorkspaceTests | testSetActivePanelChangesState | P0 | RED |
| MainWorkspaceTests | testSetActivePanelToSameIsNoOp | P1 | GREEN (no change) |

### AC2: Window State Persistence via @AppStorage

| Test File | Test Method | Priority | Status |
|-----------|-------------|----------|--------|
| MainWorkspaceTests | testNavigationModelReadsWindowWidthFromAppStorage | P0 | GREEN (@AppStorage reads) |
| MainWorkspaceTests | testNavigationModelReadsWindowHeightFromAppStorage | P0 | GREEN (@AppStorage reads) |
| MainWorkspaceTests | testNavigationModelDefaultsWindowDimensions | P0 | GREEN (defaults match) |
| MainWorkspaceTests | testUpdatingWindowWidthPersistsToUserDefaults | P0 | GREEN (@AppStorage writes) |
| MainWorkspaceTests | testUpdatingWindowHeightPersistsToUserDefaults | P0 | GREEN (@AppStorage writes) |
| MainWorkspaceTests | testSidebarCollapsedStatePersistsToAppStorage | P0 | RED |
| MainWorkspaceTests | testSidebarStateRestoredFromAppStorageOnInit | P1 | RED |
| MainWorkspaceTests | testWindowDimensionsRestoredAcrossInstances | P1 | GREEN (@AppStorage) |
| MainWorkspaceTests | testSidebarVisibilityRawValueRoundTrip | P1 | RED |

### AC3: Window Toolbar and Keyboard Shortcuts

| Test File | Test Method | Priority | Status |
|-----------|-------------|----------|--------|
| MainWorkspaceTests | testToggleSidebarMethodExists | P0 | GREEN (stub callable) |
| MainWorkspaceTests | testNewSessionActionExists | P1 | GREEN (placeholder) |
| MainWorkspaceTests | testOpenSettingsActionExists | P1 | GREEN (placeholder) |
| MainWorkspaceTests | testMinimumWindowWidthIs900 | P0 | GREEN (constant) |
| MainWorkspaceTests | testMinimumWindowHeightIs600 | P1 | GREEN (constant) |

### Concurrency Safety

| Test File | Test Method | Priority | Status |
|-----------|-------------|----------|--------|
| MainWorkspaceTests | testNavigationModelIsMainActor | P0 | GREEN (compiles on @MainActor) |

### Edge Cases

| Test File | Test Method | Priority | Status |
|-----------|-------------|----------|--------|
| MainWorkspaceTests | testWindowWidthClampedToMinimum | P1 | GREEN (max() in stub) |
| MainWorkspaceTests | testWindowHeightClampedToMinimum | P1 | GREEN (max() in stub) |
| MainWorkspaceTests | testRapidSidebarToggleMaintainsConsistentState | P1 | GREEN (stub is no-op) |

## Test Priority Distribution

| Priority | Count | Description |
|----------|-------|-------------|
| P0 | 13 | Must pass before merge |
| P1 | 16 | Should pass, non-blocking |
| P2 | 0 | Nice to have |
| P3 | 0 | Future consideration |
| **Total** | **29** | |

## Next Steps (Task-by-Task Activation)

During implementation of each task in Story 1.6:

1. **Task 1: Implement NavigationModel** (AC: #1, #2, #3)
   - Fill in `Curator/App/NavigationModel.swift` implementation
   - Replace stub method bodies with real logic:
     - `toggleSidebar()` — flip `sidebarVisible` and update `sidebarCollapsed` @AppStorage
     - `showSidebar()` / `hideSidebar()` — set `sidebarVisible` and persist
     - `setActivePanel()` — update `activePanel`
     - `sidebarVisibility` — derive from `sidebarVisible` state
     - Init should read `sidebarCollapsed` from @AppStorage
   - Run tests: `xcodebuild test -project Curator.xcodeproj -scheme Curator -destination 'platform=macOS,arch=arm64' -only-testing:CuratorTests/MainWorkspaceTests`
   - Verify RED tests transition to GREEN

2. **Task 2: Create MainWorkspaceView** (AC: #1)
   - Create `Curator/Features/MainWorkspace/MainWorkspaceView.swift`
   - Implement NavigationSplitView with sidebar (PhotoGridView) + detail (AgentContentAreaPlaceholder)
   - Create `Curator/Features/MainWorkspace/AgentContentAreaPlaceholder.swift`
   - Views are not directly unit-tested (SwiftUI limitation)
   - NavigationModel tests provide behavioral coverage

3. **Task 3: Create SettingsPlaceholderView** (AC: #3)
   - Create `Curator/Features/Settings/SettingsPlaceholderView.swift`
   - Minimal placeholder for Settings scene

4. **Task 4: Integrate into ContentView** (AC: #1, #2)
   - Modify ContentView to show MainWorkspaceView after onboarding
   - Update frame(minWidth: 900, minHeight: 600)
   - Pass NavigationModel instance

5. **Task 5: Update CuratorApp** (AC: #2, #3)
   - Add Settings scene to CuratorApp
   - Configure default window size (1200x800)

6. **Task 6: Full test suite**
   - Run all tests: `xcodebuild test -project Curator.xcodeproj -scheme Curator -destination 'platform=macOS,arch=arm64'`
   - Verify all 173+ tests pass with no regressions

## Implementation Guidance

### Types to Implement (fill in stubs)

1. **NavigationModel** (@MainActor, ObservableObject) -- stub exists
   - `@Published var sidebarVisible: Bool = true`
   - `@Published var activePanel: ActivePanel = .agentWorkspace`
   - `@AppStorage("windowWidth") var windowWidth: Double = 1200.0`
   - `@AppStorage("windowHeight") var windowHeight: Double = 800.0`
   - `var sidebarVisibility: NavigationSplitViewVisibility` -- derive from sidebarVisible
   - `let minimumWindowWidth: Double = 900.0`
   - `let minimumWindowHeight: Double = 600.0`
   - `var effectiveWindowWidth: Double` -- max(windowWidth, minimumWindowWidth)
   - `var effectiveWindowHeight: Double` -- max(windowHeight, minimumWindowHeight)
   - `init()` — read sidebarCollapsed from @AppStorage to set initial sidebarVisible
   - `func toggleSidebar()` — flip sidebarVisible, update @AppStorage
   - `func showSidebar()` — set sidebarVisible = true, persist
   - `func hideSidebar()` — set sidebarVisible = false, persist
   - `func setActivePanel(_ panel: ActivePanel)` — update activePanel
   - `func newSession()` — placeholder for Cmd+N
   - `func requestOpenSettings()` — open Settings scene via NSApp

2. **ActivePanel** (String enum, CaseIterable, Sendable) -- complete stub exists
   - Cases: agentWorkspace, photoLibrary

### Views to Create (not unit-tested, SwiftUI)

3. **MainWorkspaceView** — NavigationSplitView three-column layout
4. **AgentContentAreaPlaceholder** — welcome/empty state placeholder
5. **SettingsPlaceholderView** — minimal settings page

### Mock Infrastructure

No mock needed — NavigationModel is a pure state object with no external dependencies.

### Execution Commands

```bash
# Run all tests
xcodebuild test -project Curator.xcodeproj -scheme Curator -destination 'platform=macOS,arch=arm64'

# Run MainWorkspace tests only
xcodebuild test -project Curator.xcodeproj -scheme Curator -destination 'platform=macOS,arch=arm64' -only-testing:CuratorTests/MainWorkspaceTests

# Build only (check compilation)
xcodebuild build -project Curator.xcodeproj -scheme Curator -destination 'platform=macOS,arch=arm64'
```

## Key Risks and Assumptions

1. **Swift red-phase pattern**: Unlike JavaScript `test.skip()`, Swift requires types to exist for compilation. Minimal stubs are provided so tests compile. The stubs have empty method bodies that cause test failures -- this IS the red phase.
2. **ActivePanel enum completeness**: ActivePanel enum is fully defined in the stub (2 cases). Tests verify this enum won't change during implementation.
3. **SwiftUI View testing**: Direct view testing in XCTest is limited. MainWorkspaceView, AgentContentAreaPlaceholder, and SettingsPlaceholderView are not unit-tested. NavigationModel tests provide complete behavioral coverage.
4. **@AppStorage testing**: Window dimensions use @AppStorage which is backed by UserDefaults. Tests clear UserDefaults keys in setUp/tearDown for isolation. The sidebar collapsed state also uses @AppStorage.
5. **NavigationSplitViewVisibility**: The `sidebarVisibility` property derives `NavigationSplitViewVisibility` from the `sidebarVisible` boolean. The stub always returns `.automatic`, so the round-trip test fails (expected RED).
6. **Concurrency**: NavigationModel is @MainActor. All test methods are @MainActor. No mock actors needed since NavigationModel has no async dependencies.
7. **Window clamping**: The `effectiveWindowWidth/Height` properties use `max()` which is already in the stub. These tests pass (GREEN) -- the clamping logic is trivially correct.
8. **No regressions**: All 144 existing tests continue to pass. The 8 failures are exclusively in new MainWorkspaceTests (intentional RED phase).

## ATDD Artifacts

- **Checklist**: `_bmad-output/test-artifacts/atdd-checklist-1-6-main-ui-framework-and-window.md`
- **NavigationModel Tests**: `CuratorTests/Features/MainWorkspace/MainWorkspaceTests.swift`
- **NavigationModel Stub**: `Curator/App/NavigationModel.swift`
