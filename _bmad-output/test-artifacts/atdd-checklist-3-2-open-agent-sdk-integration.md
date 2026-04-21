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
storyId: '3.2'
storyKey: 3-2-open-agent-sdk-integration
storyFile: _bmad-output/implementation-artifacts/3-2-open-agent-sdk-integration.md
atddChecklistPath: _bmad-output/test-artifacts/atdd-checklist-3-2-open-agent-sdk-integration.md
generatedTestFiles:
  - CuratorTests/Core/Agent/AgentToolRegistryTests.swift
  - CuratorTests/Core/Agent/SDKMessageBridgeTests.swift
  - CuratorTests/Core/Agent/CuratorAgentTests.swift
---

# ATDD Checklist: Story 3.2 - OpenAgentSDK Integration

## TDD Red Phase (Current)

Tests are written as **compilation-failing** test scaffolds (TDD red phase). They reference types that do not yet exist and will not compile until the implementation is created.

- **Total Test Files:** 3
- **Total Test Methods:** 29
- **Stack:** backend (Swift/XCTest)

## Test Files Created

| File | Tests | AC Coverage | Priority |
|------|-------|-------------|----------|
| `CuratorTests/Core/Agent/AgentToolRegistryTests.swift` | 9 | AC1, AC4 | P0+P1 |
| `CuratorTests/Core/Agent/SDKMessageBridgeTests.swift` | 11 | AC3 | P0+P1 |
| `CuratorTests/Core/Agent/CuratorAgentTests.swift` | 9 | AC2, AC5 | P0+P1 |

## Acceptance Criteria Coverage

### AC1: AgentToolRegistry Tool Registration (FR9, FR13)

| Test | Level | Priority | Status |
|------|-------|----------|--------|
| `testToolRegistration` | Unit | P0 | RED |
| `testToolLookupByName` | Unit | P0 | RED |
| `testToolLookupByNameReturnsNilForMissing` | Unit | P0 | RED |
| `testMultipleToolRegistration` | Unit | P1 | RED |
| `testDefineToolCreatesValidToolProtocol` | Unit | P0 | RED |
| `testToolProtocolConformance` | Unit | P0 | RED |
| `testScanLibraryToolAnnotations` | Unit | P1 | RED |

### AC2: SDK Agent Loop Start & Instruction Processing (FR8, FR9)

| Test | Level | Priority | Status |
|------|-------|----------|--------|
| `testCuratorAgentCreation` | Unit | P0 | RED |
| `testCuratorAgentCancel` | Unit | P0 | RED |
| `testCuratorAgentRegistersTools` | Unit | P0 | RED |
| `testCuratorAgentExecuteReturnsAsyncStream` | Unit | P0 | RED |

### AC3: SDK Message Bridge to AgentEvent (FR16, NFR3)

| Test | Level | Priority | Status |
|------|-------|----------|--------|
| `testSDKMessageBridgeToolUse` | Unit | P0 | RED |
| `testSDKMessageBridgeToolResult` | Unit | P0 | RED |
| `testSDKMessageBridgeToolResultError` | Unit | P0 | RED |
| `testSDKMessageBridgeResultSuccess` | Unit | P0 | RED |
| `testSDKMessageBridgeResultError` | Unit | P0 | RED |
| `testSDKMessageBridgeAssistantReasoning` | Unit | P1 | RED |
| `testSDKMessageBridgeCancellation` | Unit | P1 | RED |
| `testSDKMessageBridgePartialMessageIgnored` | Unit | P1 | RED |
| `testSDKMessageBridgeSystemIgnored` | Unit | P1 | RED |
| `testBridgeMaintainsStepIDMapping` | Unit | P0 | RED |
| `testBridgeMultipleToolMappings` | Unit | P1 | RED |

### AC4: Tool Execution & Infrastructure Integration (FR13)

| Test | Level | Priority | Status |
|------|-------|----------|--------|
| `testScanLibraryToolExecution` | Unit | P0 | RED |
| `testToolUsesInjectedRepository` | Unit | P0 | RED |

### AC5: Agent Bridge Layer Configuration (FR43, FR44)

| Test | Level | Priority | Status |
|------|-------|----------|--------|
| `testAgentUsesConfiguredParameters` | Unit | P0 | RED |
| `testCuratorSystemPrompt` | Unit | P1 | RED |
| `testCuratorAgentFactoryCreation` | Unit | P0 | RED |
| `testCuratorAgentFactoryUsesGatewayConfig` | Unit | P1 | RED |
| `testAppDependenciesRegistersAgentInfrastructure` | Unit | P1 | RED |

## Implementation Types Required

These types must be created for the tests to compile and pass:

| Type | File | Layer |
|------|------|-------|
| `AgentToolRegistry` | `Curator/Core/Agent/AgentToolRegistry.swift` | Core/Agent |
| `SDKMessageBridge` | `Curator/Core/Agent/SDKMessageBridge.swift` | Core/Agent |
| `CuratorAgent` | `Curator/Core/Agent/CuratorAgent.swift` | Core/Agent |
| `CuratorAgentFactory` | `Curator/Core/Agent/CuratorAgentFactory.swift` | Core/Agent |
| `ScanLibraryTool` | `Curator/Infrastructure/SDKTools/ScanLibraryTool.swift` | Infrastructure |
| `AppDependencies` additions | `Curator/App/AppDependencies.swift` (modify) | App |

## Next Steps (Task-by-Task Activation)

During implementation of each task:

1. Implement the type referenced by the test (e.g., `AgentToolRegistry`)
2. Build the project to verify compilation
3. Run tests: `xcodebuild test -scheme Curator -destination 'platform=macOS'`
4. Verify activated tests pass (green phase)
5. If any tests fail, fix implementation or test as needed
6. Commit passing tests

## Key Risks & Assumptions

1. **SDK API types** (`ToolUseData`, `ToolResultData`, `ResultData`, `AssistantData`, `PartialData`, `SystemData`, `ToolContext`) must match the actual OpenAgentSDKSwift API. The story's Dev Notes section documents these types from SDK source analysis.
2. **LLMProvider enum** - The test uses `.anthropic` and `.openai` which must match the SDK's `LLMProvider` enum cases.
3. **`@MainActor` on CuratorAgent** - The story specifies CuratorAgent as an `actor`, not `@MainActor`. Tests calling `await` methods should work correctly.
4. **`ToolProtocol.call(input:context:)` signature** - Must match SDK's actual method signature. The story notes `call(input: Any, context: ToolContext) async -> ToolResult`.
5. **No regression** - All 410+ existing tests must continue to pass after implementation.
