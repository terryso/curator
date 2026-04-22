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
storyId: '3.4'
storyKey: 3-4-agent-execution-panel
storyFile: _bmad-output/implementation-artifacts/3-4-agent-execution-panel.md
atddChecklistPath: _bmad-output/test-artifacts/atdd-checklist-3-4-agent-execution-panel.md
generatedTestFiles:
  - CuratorTests/Features/AgentExecution/AgentExecutionViewModelTests.swift
---

# ATDD Checklist: Story 3.4 - Agent Execution Panel

## TDD Green Phase (Current)

All tests pass. Implementation complete.

- **Total Test Files:** 1
- **Total Test Methods:** 30
- **Stack:** backend (Swift/XCTest)

## Test Files Created

| File | Tests | AC Coverage | Priority |
|------|-------|-------------|----------|
| `CuratorTests/Features/AgentExecution/AgentExecutionViewModelTests.swift` | 30 | AC1-AC5 | P0+P1 |

## Acceptance Criteria Coverage

### AC1: StepCardView Step Card Rendering (FR14, UX-DR3)

| Test | Level | Priority | Status |
|------|-------|----------|--------|
| `testStepProgressDataForRendering` | Unit | P1 | GREEN |

### AC2: ReasoningBubbleView Reasoning Bubbles (FR15, UX-DR10)

| Test | Level | Priority | Status |
|------|-------|----------|--------|
| `testReasoningMessages` | Unit | P0 | GREEN |
| `testReasoningMessagesEmptyWhenNoAgentJob` | Unit | P0 | GREEN |
| `testStepReasoningMessagesAccessible` | Unit | P1 | GREEN |

### AC3: Real-Time UI Updates (FR16, NFR3)

| Test | Level | Priority | Status |
|------|-------|----------|--------|
| `testRealTimeEventUpdates` | Unit | P1 | GREEN |

### AC4: AgentExecutionViewModel State Management

| Test | Level | Priority | Status |
|------|-------|----------|--------|
| `testAgentExecutionViewModelExists` | Unit | P0 | GREEN |
| `testInitialAgentJobIsNil` | Unit | P0 | GREEN |
| `testInitialDisplayStateIsEmpty` | Unit | P0 | GREEN |
| `testInitialIsRunningIsFalse` | Unit | P0 | GREEN |
| `testDisplayStateRunning` | Unit | P0 | GREEN |
| `testDisplayStateCompleted` | Unit | P0 | GREEN |
| `testDisplayStateFailed` | Unit | P0 | GREEN |
| `testDisplayStateCancelled` | Unit | P0 | GREEN |
| `testDisplayStateReview` | Unit | P0 | GREEN |
| `testDisplayStateConfirmIsExecuting` | Unit | P0 | GREEN |
| `testDisplayStatePlanningIsEmpty` | Unit | P0 | GREEN |
| `testStepsFromAgentJob` | Unit | P0 | GREEN |
| `testStepsEmptyWhenNoAgentJob` | Unit | P0 | GREEN |
| `testFormattedSummary` | Unit | P0 | GREEN |
| `testFormattedSummaryNilWhenNoSummary` | Unit | P0 | GREEN |
| `testExecutionDisplayStateCases` | Unit | P0 | GREEN |
| `testIsRunningTrueWhenExecuting` | Unit | P0 | GREEN |
| `testIsRunningFalseWhenCompleted` | Unit | P0 | GREEN |
| `testIsRunningFalseWhenFailed` | Unit | P0 | GREEN |
| `testEmptyAgentJobAfterPreviousJob` | Unit | P1 | GREEN |
| `testFormattedDurationSeconds` | Unit | P1 | GREEN |
| `testFormattedDurationMinutes` | Unit | P1 | GREEN |
| `testFormattedDurationNilWhenNoSummary` | Unit | P1 | GREEN |
| `testViewModelTracksMultipleTransitions` | Unit | P1 | GREEN |

### AC5: MainWorkspaceView Integration

| Test | Level | Priority | Status |
|------|-------|----------|--------|
| `testViewModelObservesChatInputAgentJob` | Unit | P1 | GREEN |

## Generation Mode

- **Mode:** AI Generation (sequential)
- **Reason:** Swift/XCTest backend project; acceptance criteria are clear; standard ViewModel testing patterns; no browser-based UI testing needed

## Test Strategy

- **Level:** Unit tests (AgentExecutionViewModel is a @MainActor ViewModel)
- **Mock Strategy:** No mocks needed -- AgentJob (already implemented in Story 3.1) is @Observable @MainActor and can be directly created and driven through state transitions in tests
- **No UI Tests:** SwiftUI View testing (StepCardView, ReasoningBubbleView, AgentExecutionPanel) requires Xcode Preview or ViewInspector; UI correctness verified via ViewModel state exposure
- **Integration Point:** Test verifying ChatInputViewModel.agentJob flows through to AgentExecutionViewModel validates the MainWorkspaceView integration contract

## Priority Distribution

| Priority | Count | Percentage |
|----------|-------|------------|
| P0       | 21    | 70%        |
| P1       | 9     | 30%        |
| P2       | 0     | 0%         |
| P3       | 0     | 0%         |
| **Total**| **30**| **100%**   |

## FR/NFR Coverage

| Requirement | Tests |
|-------------|-------|
| FR14 (Agent execution progress) | testDisplayStateRunning, testStepsFromAgentJob, testStepProgressDataForRendering |
| FR15 (Agent decision reasoning) | testReasoningMessages, testStepReasoningMessagesAccessible |
| FR16 (Real-time UI updates) | testRealTimeEventUpdates, testViewModelTracksMultipleTransitions |
| NFR3 (500ms update latency) | testRealTimeEventUpdates (validates @Observable reactivity) |
| NFR7 (UI not blocked) | testRealTimeEventUpdates (async event processing) |
| UX-DR3 (step card status icons) | testStepProgressDataForRendering |
| UX-DR10 (reasoning bubble display) | testStepReasoningMessagesAccessible |

## Input Documents

- _bmad-output/implementation-artifacts/3-4-agent-execution-panel.md (story file)
- _bmad-output/planning-artifacts/epics.md (Epic 3, Story 3.4)
- Curator/Core/Agent/AgentJob.swift (Story 3.1 prerequisite - @Observable state machine)
- Curator/Core/Agent/AgentJobState.swift (Story 3.1 prerequisite - 7 states)
- Curator/Core/Agent/AgentEvent.swift (Story 3.1 prerequisite - 8 events)
- Curator/Core/Agent/AgentStep.swift (Story 3.1 prerequisite - step model)
- Curator/Core/Agent/ExecutionSummary.swift (Story 3.1 prerequisite - summary model)
- Curator/Core/Errors/DomainError.swift (error types)
- Curator/Features/ChatInput/ChatInputViewModel.swift (Story 3.3 prerequisite - agentJob source)
- CuratorTests/Core/Agent/AgentJobTests.swift (existing test pattern reference)
- CuratorTests/Features/ChatInput/ChatInputViewModelTests.swift (existing test pattern reference)

## Next Steps (Task-by-Task Activation)

During implementation of each task in Story 3.4:

1. Implement `AgentExecutionViewModel` with `ExecutionDisplayState` enum (Task 1)
2. Run tests: `xcodebuild test -scheme Curator -destination 'platform=macOS'`
3. Verify tests transition from GREEN to GREEN as ViewModel implementation progresses
4. Implement `StepCardView` (Task 2) - no unit tests; verified via SwiftUI Preview
5. Implement `ReasoningBubbleView` (Task 3) - no unit tests; verified via SwiftUI Preview
6. Implement `AgentExecutionPanel` (Task 4) - no unit tests; verified via SwiftUI Preview
7. Update `MainWorkspaceView` integration (Task 5)
8. Full test suite must pass (existing tests + 30 new tests)

## Implementation Guidance

Types to implement for tests to compile:

1. **ExecutionDisplayState** (enum, defined within or alongside AgentExecutionViewModel)
   - Cases: `empty`, `executing`, `review`, `completed`, `failed`, `cancelled`

2. **AgentExecutionViewModel** (`Curator/Features/AgentExecution/AgentExecutionViewModel.swift`)
   - `@MainActor @Observable final class AgentExecutionViewModel`
   - Properties: `agentJob: AgentJob?`
   - Computed: `displayState: ExecutionDisplayState`, `steps: [AgentStep]`, `reasoningMessages: [String]`, `formattedSummary: String?`, `formattedDuration: String?`, `isRunning: Bool`
   - Init: `init()` (no parameters needed)
   - Mapping logic:
     - `nil` -> `.empty`
     - `.planning` -> `.empty`
     - `.running` / `.confirm` -> `.executing`
     - `.review` -> `.review`
     - `.completed` -> `.completed`
     - `.failed` -> `.failed`
     - `.cancelled` -> `.cancelled`
