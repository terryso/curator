---
stepsCompleted:
  - step-01-preflight-and-context
  - step-02-generation-mode
  - step-03-test-strategy
  - step-04-generate-tests
  - step-04c-aggregate
lastStep: step-04c-aggregate
lastSaved: '2026-04-22'
storyId: '3.6'
storyKey: 3-6-agent-streaming-comm
storyFile: _bmad-output/implementation-artifacts/3-6-agent-streaming-comm.md
atddChecklistPath: _bmad-output/test-artifacts/atdd-checklist-3-6-agent-streaming-comm.md
generatedTestFiles:
  - CuratorTests/Core/Agent/SDKMessageBridgeTests.swift
  - CuratorTests/Core/Extensions/AsyncStreamMergeTests.swift
---

# ATDD Checklist: Story 3.6 - Agent Real-time Streaming Communication

## TDD Red Phase (Current)

Red-phase test scaffolds generated. All tests use `XCTSkipIf(true)` to skip until implementation is complete.

- **Total Test Files:** 2 (1 updated, 1 new)
- **Total New Test Methods:** 12
- **Stack:** backend (Swift/XCTest)

## Test Files

| File | Tests | AC Coverage | Priority | Status |
|------|-------|-------------|----------|--------|
| `CuratorTests/Core/Agent/SDKMessageBridgeTests.swift` | 4 new (partialMessage) | AC3, AC4 | P0 | RED |
| `CuratorTests/Core/Extensions/AsyncStreamMergeTests.swift` | 8 | AC2 | P0+P1 | RED |

## Acceptance Criteria Coverage

### AC1: AsyncStream End-to-End Pipeline (FR16, NFR3)

**Coverage:** Covered indirectly by AC2 and AC3 tests. The end-to-end pipeline (AsyncStream<AgentEvent> -> AgentJob -> AgentExecutionViewModel -> SwiftUI) is already tested in existing `AgentJobTests` (Story 3.1) and `AgentExecutionViewModelTests` (Story 3.4). Story 3.6 adds the merge step in CuratorAgent.execute() which is validated by AC2 tests.

| Test | Level | Priority | Status |
|------|-------|----------|--------|
| (Existing coverage in AgentJobTests) | Unit | P0 | GREEN |
| (Existing coverage in AgentExecutionViewModelTests) | Unit | P0 | GREEN |

### AC2: Event Merge Prevents Over-Rendering (NFR7)

| Test | Level | Priority | Status |
|------|-------|----------|--------|
| `testMergeConsecutiveProgressEvents` | Unit | P0 | RED |
| `testMergePreservesNonProgressEvents` | Unit | P0 | RED |
| `testMergePreservesOrdering` | Unit | P0 | RED |
| `testMergeDebounceWindow` | Unit | P1 | RED |
| `testCancelCleansUpStream` | Unit | P1 | RED |
| `testMergeTracksMultipleStepIDs` | Unit | P1 | RED |
| `testMergeEmptyStream` | Unit | P1 | RED |

### AC3: Streaming Text Rendering (partialMessage)

| Test | Level | Priority | Status |
|------|-------|----------|--------|
| `testPartialMessageMapToStepReasoning` | Unit | P0 | RED |
| `testPartialMessageAccumulation` | Unit | P0 | RED |
| `testPartialMessageFlushOnResult` | Unit | P0 | RED |
| `testPartialMessageBufferCleanup` | Unit | P0 | RED |

### AC4: AsyncStream Cleanup on Cancel (FR17)

**Coverage:** `testCancelCleansUpStream` in AsyncStreamMergeTests validates stream cleanup. `testPartialMessageBufferCleanup` validates SDKMessageBridge buffer cleanup. Existing `AgentJobTests.testAgentJobCancellationFromRunning` already validates AgentJob cancellation. ReasoningBubbleView is a SwiftUI view (not directly unit-testable without ViewInspector).

| Test | Level | Priority | Status |
|------|-------|----------|--------|
| `testCancelCleansUpStream` | Unit | P1 | RED |
| `testPartialMessageBufferCleanup` | Unit | P0 | RED |
| (Existing coverage in AgentJobTests) | Unit | P0 | GREEN |

### AC5: ReasoningBubbleView Streaming Rendering Optimization

**Coverage:** ReasoningBubbleView streaming is a SwiftUI view behavior (isStreaming flag, cursor animation, auto-scroll). These are UI-layer changes best validated via:
1. Manual visual verification during development
2. Build verification (compiler catches type errors)
3. Preview testing in Xcode previews

No new unit tests for AC5 because:
- `isStreaming` parameter is a simple boolean passed from StepCardView
- Blink cursor animation uses SwiftUI `.symbolEffect`
- Auto-scroll is handled by existing `.onChange` modifier pattern
- SwiftUI view tests require ViewInspector which is not a project dependency

| Test | Level | Priority | Status |
|------|-------|----------|--------|
| Build verification | Compile | P0 | PENDING |
| Manual visual verification | Manual | P1 | PENDING |

## Test Strategy Summary

| Test Level | Count | Notes |
|------------|-------|-------|
| Unit (XCTest) | 12 | Core logic: merge + partialMessage mapping |
| Compile | 1 | Build verification for SwiftUI view changes |
| Manual | 1 | Visual verification for streaming animation |

## Priority Distribution

| Priority | Count | Percentage |
|----------|-------|------------|
| P0 | 7 | 58% |
| P1 | 5 | 42% |
| Total | 12 | 100% |

## Implementation Tasks -> Test Activation Map

During implementation, activate tests task-by-task:

| Task | Activate Test | Remove Skip |
|------|--------------|-------------|
| Task 1: SDKMessageBridge partialMessage | `testPartialMessageMapToStepReasoning`, `testPartialMessageAccumulation`, `testPartialMessageFlushOnResult`, `testPartialMessageBufferCleanup` | Change `XCTSkipIf(true, ...)` to remove skip |
| Task 2: AsyncStream+Extensions merge | `testMergeConsecutiveProgressEvents`, `testMergePreservesNonProgressEvents`, `testMergePreservesOrdering`, `testMergeDebounceWindow`, `testMergeTracksMultipleStepIDs`, `testMergeEmptyStream` | Change `XCTSkipIf(true, ...)` to remove skip |
| Task 3: CuratorAgent integration | `testCancelCleansUpStream` | Change `XCTSkipIf(true, ...)` to remove skip |
| Task 4: ReasoningBubbleView | Build verification | Ensure `xcodebuild build` succeeds |
| Task 5: Cancellation cleanup | (Covered by Task 1 + Task 3 tests) | Already activated above |

## Files to Create/Modify for Implementation

### New Files
- `Curator/Core/Extensions/AsyncStream+Extensions.swift` -- mergeProgressEvents()

### Modified Files
- `Curator/Core/Agent/SDKMessageBridge.swift` -- partialMessage mapping + buffer
- `Curator/Core/Agent/CuratorAgent.swift` -- integrate merge in execute()
- `Curator/Features/AgentExecution/ReasoningBubbleView.swift` -- isStreaming flag
- `Curator/Features/AgentExecution/StepCardView.swift` -- pass isStreaming to ReasoningBubbleView
- `Curator/Features/AgentExecution/AgentExecutionPanel.swift` -- auto-scroll on reasoning changes

## Next Steps

1. Implement Task 1 (SDKMessageBridge partialMessage handling)
2. Remove `XCTSkipIf` from partialMessage tests -> verify they fail -> implement -> verify they pass
3. Implement Task 2 (AsyncStream+Extensions mergeProgressEvents)
4. Remove `XCTSkipIf` from merge tests -> verify they fail -> implement -> verify they pass
5. Implement Task 3 (CuratorAgent integration)
6. Remove `XCTSkipIf` from cancel test -> verify -> implement -> verify
7. Implement Task 4 (ReasoningBubbleView streaming)
8. Implement Task 5 (Cancellation cleanup verification)
9. Run full test suite to confirm no regressions
10. Commit all changes
