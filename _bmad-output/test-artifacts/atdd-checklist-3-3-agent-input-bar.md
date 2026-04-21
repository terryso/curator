---
stepsCompleted:
  - step-01-preflight-and-context
  - step-02-generation-mode
  - step-03-test-strategy
  - step-04-generate-tests
  - step-04c-aggregate
  - step-05-validate-and-complete
lastStep: step-05-validate-and-complete
lastSaved: '2026-04-21'
storyId: '3.3'
storyKey: 3-3-agent-input-bar
storyFile: _bmad-output/implementation-artifacts/3-3-agent-input-bar.md
atddChecklistPath: _bmad-output/test-artifacts/atdd-checklist-3-3-agent-input-bar.md
generatedTestFiles:
  - CuratorTests/Features/ChatInput/ChatInputViewModelTests.swift
---

# ATDD Checklist: Story 3.3 - Agent Input Bar

## TDD Red Phase (Current)

Tests are written as **compilation-failing** test scaffolds (TDD red phase). They reference types that do not yet exist and will not compile until the implementation is created.

- **Total Test Files:** 1
- **Total Test Methods:** 24
- **Stack:** backend (Swift/XCTest)

## Test Files Created

| File | Tests | AC Coverage | Priority |
|------|-------|-------------|----------|
| `CuratorTests/Features/ChatInput/ChatInputViewModelTests.swift` | 24 | AC1-AC5 | P0+P1 |

## Acceptance Criteria Coverage

### AC1: AgentInputBar Component Rendering (UX-DR2)

| Test | Level | Priority | Status |
|------|-------|----------|--------|
| `testChatInputViewModelExists` | Unit | P0 | RED |
| `testInitialInputTextIsEmpty` | Unit | P0 | RED |
| `testInitialAgentJobIsNil` | Unit | P0 | RED |
| `testInitialIsSubmittingIsFalse` | Unit | P0 | RED |

### AC2: Instruction Submission & Agent Connection (FR8)

| Test | Level | Priority | Status |
|------|-------|----------|--------|
| `testSubmitInputClearsInputText` | Unit | P0 | RED |
| `testSubmitInputSetsIsSubmitting` | Unit | P0 | RED |
| `testSubmitInputCreatesAgentJob` | Unit | P0 | RED |
| `testSubmitInputEmptyTextDoesNotSubmit` | Unit | P0 | RED |
| `testSubmitInputWhitespaceOnlyDoesNotSubmit` | Unit | P0 | RED |

### AC3: Quick Command Suggestions (UX-DR2, UX-DR15)

| Test | Level | Priority | Status |
|------|-------|----------|--------|
| `testSubmitQuickCommandSubmitsText` | Unit | P0 | RED |
| `testQuickCommandsVisibleWhenNoAgentJob` | Unit | P0 | RED |
| `testQuickCommandsVisibleWhenAgentJobPlanning` | Unit | P1 | RED |

### AC4: Input Bar State Management (FR17)

| Test | Level | Priority | Status |
|------|-------|----------|--------|
| `testIsAgentRunningFalseWhenNoAgentJob` | Unit | P0 | RED |
| `testIsAgentRunningFalseWhenPlanning` | Unit | P0 | RED |
| `testIsAgentRunningTrueWhenRunning` | Unit | P0 | RED |
| `testCancelExecutionCancelsAgentJob` | Unit | P0 | RED |
| `testCancelExecutionWithNoAgentJobDoesNotCrash` | Unit | P0 | RED |
| `testIsInputEnabledTrueWhenNotRunningAndHasText` | Unit | P1 | RED |
| `testIsInputDisabledDuringExecution` | Unit | P1 | RED |
| `testIsInputEnabledFalseWhenTextIsEmpty` | Unit | P1 | RED |
| `testQuickCommandsHiddenDuringExecution` | Unit | P1 | RED |

### AC5: MainWorkspaceView Integration

| Test | Level | Priority | Status |
|------|-------|----------|--------|
| `testViewModelAcceptsDependenciesInjection` | Unit | P0 | RED |
| `testViewModelHandlesNilFactory` | Unit | P0 | RED |
| `testViewModelHandlesNilToolRegistry` | Unit | P1 | RED |

### Edge Cases

| Test | Level | Priority | Status |
|------|-------|----------|--------|
| `testRapidSubmitOnlyCreatesOneAgentJob` | Unit | P1 | RED |
| `testSubmitAfterCompletionCreatesNewAgentJob` | Unit | P1 | RED |
| `testCancelAlreadyCancelledJobIsNoOp` | Unit | P1 | RED |

## Generation Mode

- **Mode:** AI Generation (sequential)
- **Reason:** Swift/XCTest backend project; acceptance criteria are clear; standard ViewModel testing patterns

## Test Strategy

- **Level:** Unit tests (ChatInputViewModel is a @MainActor ViewModel)
- **Mock Strategy:** AppDependencies used as-is with registerAgentInfrastructure(); AgentJob (already implemented in Story 3.1) used directly for state transitions
- **No UI Tests:** UI testing for the input bar is deferred to Story 3.4 (AgentExecutionPanel integration)

## Priority Distribution

| Priority | Count | Percentage |
|----------|-------|------------|
| P0       | 15    | 63%        |
| P1       | 9     | 37%        |
| P2       | 0     | 0%         |
| P3       | 0     | 0%         |
| **Total**| **24**| **100%**   |

## FR/NFR Coverage

| Requirement | Tests |
|-------------|-------|
| FR8 (natural language input) | testSubmitInputCreatesAgentJob, testSubmitQuickCommandSubmitsText |
| FR17 (cancel agent task) | testCancelExecutionCancelsAgentJob, testCancelExecutionWithNoAgentJobDoesNotCrash |
| UX-DR2 (AgentInputBar component) | testChatInputViewModelExists, testInitialInputTextIsEmpty |
| UX-DR15 (quick command suggestions) | testQuickCommandsVisibleWhenNoAgentJob, testSubmitQuickCommandSubmitsText |

## Input Documents

- _bmad-output/implementation-artifacts/3-3-agent-input-bar.md (story file)
- _bmad-output/planning-artifacts/epics.md (Epic 3, Story 3.3)
- Curator/Core/Agent/AgentJob.swift (Story 3.1 prerequisite)
- Curator/Core/Agent/AgentJobState.swift (Story 3.1 prerequisite)
- Curator/Core/Agent/AgentEvent.swift (Story 3.1 prerequisite)
- Curator/Core/Agent/CuratorAgentFactory.swift (Story 3.2 prerequisite)
- Curator/Core/Agent/CuratorAgent.swift (Story 3.2 prerequisite)
- Curator/Core/Agent/AgentToolRegistry.swift (Story 3.2 prerequisite)
- Curator/App/AppDependencies.swift (DI container)

## Next Steps (Task-by-Task Activation)

During implementation of each task in Story 3.3:

1. Implement `ChatInputViewModel` (Task 1 in story)
2. Run tests: `xcodebuild test -scheme Curator -destination 'platform=macOS'`
3. Verify tests transition from RED to GREEN as implementation progresses
4. Implement `AgentInputBar` view (Task 2)
5. Implement `QuickCommandSuggestions` view (Task 3)
6. Update `MainWorkspaceView` integration (Task 4)
7. Full test suite must pass (442+ existing tests + 24 new tests)

## Implementation Guidance

Types to implement for tests to compile:

1. **ChatInputViewModel** (`Curator/Features/ChatInput/ChatInputViewModel.swift`)
   - `@MainActor @Observable final class ChatInputViewModel`
   - Properties: `inputText: String`, `isSubmitting: Bool`, `agentJob: AgentJob?`
   - Init: `init(dependencies: AppDependencies)`
   - Methods: `submitInput()`, `submitQuickCommand(_:)`, `cancelExecution()`
   - Computed: `isAgentRunning: Bool`, `isInputEnabled: Bool`, `quickCommandsVisible: Bool`
