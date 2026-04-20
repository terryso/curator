---
stepsCompleted:
  - step-01-preflight-and-context
  - step-02-generation-mode
  - step-03-test-strategy
  - step-04c-aggregate
  - step-05-validate-and-complete
lastStep: step-05-validate-and-complete
lastSaved: '2026-04-20'
storyId: '2.5'
storyKey: 2-5-provider-settings-ui
storyFile: _bmad-output/implementation-artifacts/2-5-provider-settings-ui.md
atddChecklistPath: _bmad-output/test-artifacts/atdd-checklist-2-5-provider-settings-ui.md
generatedTestFiles:
  - CuratorTests/Features/Settings/SettingsViewModelTests.swift
inputDocuments:
  - _bmad-output/implementation-artifacts/2-5-provider-settings-ui.md
  - Curator/Core/Models/LLMConfig.swift
  - Curator/Core/Models/LLMProviderConfig.swift
  - Curator/Core/Models/LLMProvider.swift
  - Curator/Core/Models/LLMGatewayProtocol.swift
  - Curator/Core/Models/CostTrackerProtocol.swift
  - Curator/Core/Models/LLMResponse.swift
  - Curator/Core/Models/CostSummary.swift
  - Curator/Core/Models/CostRecord.swift
  - Curator/Infrastructure/LLM/LLMModels.swift
  - Curator/Infrastructure/LLM/AnthropicProvider.swift
  - Curator/App/AppDependencies.swift
  - Curator/Features/Settings/SettingsPlaceholderView.swift
  - CuratorTests/Core/Models/LLMConfigTests.swift
  - CuratorTests/Infrastructure/LLM/LLMGatewayTests.swift
  - CuratorTests/DependencyInjectionTests.swift
---

# ATDD Checklist: Story 2.5 - Provider Settings UI

## TDD Red Phase (Current)

Red-phase test scaffolds generated. All tests assert EXPECTED behavior against types/APIs that do not yet exist. Activated tests will FAIL until the feature is implemented.

## Test Strategy

- **Stack:** backend (Swift/XCTest)
- **Generation Mode:** AI Generation (no browser recording needed — native macOS SwiftUI views)
- **Test Levels:** Unit (ViewModel logic, config mapping, validation state), DI (AppDependencies integration)
- **Note:** SwiftUI views (SettingsView, APIKeyManagementView, ModelSelectionView, CostTrackingSettingsView) are tested indirectly through SettingsViewModel. View tests would require XCUITest or ViewInspector, which are out of scope for this ATDD cycle.

## Acceptance Criteria Coverage

| AC # | Description | Test Scenarios | Priority | Level |
|------|-------------|----------------|----------|-------|
| AC1 | Settings page renders with correct components | SettingsViewModel creation, @MainActor @Observable, property defaults, validation state | P0/P1 | Unit |
| AC2 | API Key validation and storage | loadCurrentConfig, saveConfig persistence, validate success, validate failure, validating state, fallback validation, gateway rebuild | P0 | Unit/DI |
| AC3 | Default model selection updates immediately | Model selection updates config, all LLMModelID cases available | P1 | Unit |
| AC2 | Fallback provider toggle | Enable fallback saves correctly, disable fallback removes from config | P1 | Unit |
| AC1 | Cost tracking entry point | ViewModel accesses cost tracker through dependencies | P1 | DI |
| AC2 | ValidationResult type | Enum has success/failure cases | P1 | Unit |

## Generated Test Files

### 1. `CuratorTests/Features/Settings/SettingsViewModelTests.swift`
- **Level:** Unit (ViewModel logic, config mapping, validation state), DI (AppDependencies integration)
- **Tests:** 18 tests
- **AC Coverage:** AC1 (rendering/creation), AC2 (load/save/validate/rebuild), AC3 (model selection)
- **Priority:** P0 (7), P1 (11)

## Summary Statistics

- **Total Tests:** 18
- **P0 Tests:** 7
- **P1 Tests:** 11
- **All tests skipped:** Yes (TDD RED PHASE via `try XCTSkip()`)
- **Expected to fail:** Yes (SettingsViewModel not yet implemented)
- **Knowledge fragments used:** data-factories, component-tdd, test-quality, test-healing-patterns

## Implementation Guidance

### Types to Create

1. `Curator/Features/Settings/SettingsViewModel.swift` -- @MainActor @Observable, manages LLMConfig load/save, API key validation, gateway rebuild
2. `Curator/Features/Settings/SettingsView.swift` -- NavigationSplitView layout with provider config, model selection, cost tracking
3. `Curator/Features/Settings/APIKeyManagementView.swift` -- Form with provider type picker, base URL, SecureField, validate button
4. `Curator/Features/Settings/ModelSelectionView.swift` -- Model list from LLMModelID.allCases with pricing
5. `Curator/Features/Settings/CostTrackingSettingsView.swift` -- Monthly summary display + link to future Story 2.6 panel

### Types to Modify

6. `Curator/App/AppDependencies.swift` -- Add settingsViewModel property
7. `Curator/CuratorApp.swift` -- Replace SettingsPlaceholderView with SettingsView, inject SettingsViewModel

### Types to Delete

8. `Curator/Features/Settings/SettingsPlaceholderView.swift` -- Replaced by new SettingsView

## Next Steps (Task-by-Task Activation)

During implementation of each task:

1. Remove `try XCTSkip("RED: ...")` from the current test method
2. Run tests: `xcodebuild test -project Curator.xcodeproj -scheme Curator -destination 'platform=macOS,arch=arm64'`
3. Verify the activated test fails first, then passes after implementation (green phase)
4. If any activated tests still fail unexpectedly:
   - Either fix implementation (feature bug)
   - Or fix test (test bug)
5. Commit passing tests

## Key Risks and Assumptions

1. **API Key Validation Strategy:** The design calls for sending a minimal test request via LLMProvider.analyze() to validate keys. The ATDD tests assume this approach but do not test the actual network call — validation tests use mock providers. Real network validation should be tested manually or in integration tests.
2. **SettingsViewModel Initialization:** Tests assume SettingsViewModel takes `AppDependencies` as a constructor parameter. If the design changes to use @Environment or a different DI pattern, some tests may need adjustment.
3. **Validation Mocking:** The test file includes `MockLLMProviderForSettings` for validation testing. The actual SettingsViewModel may need a way to inject providers for testing (e.g., via AppDependencies or protocol injection) rather than directly constructing providers.
4. **SwiftUI View Testing:** Views (SettingsView, APIKeyManagementView, etc.) are not directly tested in ATDD because they require XCUITest or ViewInspector. The ViewModel tests cover the behavioral logic that views delegate to.
5. **Cost Tracker Access:** The `monthlyCostSummary` property test assumes the ViewModel exposes a computed property or similar. The actual API shape may differ slightly.
6. **UserDefaults Isolation:** Tests use `LLMConfig.clear()` in setUp/tearDown to isolate config state. Tests running in parallel could interfere — this matches the existing pattern used in `LLMConfigTests`.

## Handoff for dev-story

- **Checklist:** `_bmad-output/test-artifacts/atdd-checklist-2-5-provider-settings-ui.md`
- **Test files:**
  - `CuratorTests/Features/Settings/SettingsViewModelTests.swift`
- **Story file:** `_bmad-output/implementation-artifacts/2-5-provider-settings-ui.md`
