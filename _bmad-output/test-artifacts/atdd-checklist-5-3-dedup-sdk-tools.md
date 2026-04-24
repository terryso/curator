---
stepsCompleted:
  - step-01-preflight-and-context
  - step-02-generation-mode
  - step-03-test-strategy
  - step-04c-aggregate
  - step-05-validate-and-complete
lastStep: step-05-validate-and-complete
lastSaved: '2026-04-24'
storyId: '5.3'
storyKey: 5-3-dedup-sdk-tools
storyFile: _bmad-output/implementation-artifacts/5-3-dedup-sdk-tools.md
atddChecklistPath: _bmad-output/test-artifacts/atdd-checklist-5-3-dedup-sdk-tools.md
generatedTestFiles:
  - CuratorTests/Infrastructure/SDKTools/AnalyzeDuplicatesToolTests.swift
  - CuratorTests/Infrastructure/SDKTools/DeleteAssetsToolTests.swift
  - CuratorTests/Infrastructure/SDKTools/EstimateCostToolTests.swift
  - CuratorTests/Infrastructure/SDKTools/DedupToolRegistrationTests.swift
---

# ATDD Checklist: Story 5.3 -- Deduplication SDK Tools

## TDD Red Phase (Current)

Red-phase test scaffolds generated. All tests use `XCTSkipIf(true, "ATDD Red Phase")` and will be skipped until implementation removes the skip guards.

- **Unit/Integration Tests:** 18 tests (all skipped via XCTSkip)
- **E2E Tests:** N/A (backend project, no browser testing)

## Test Strategy

| Test Level | Tests | Purpose |
|---|---|---|
| Unit | AnalyzeDuplicatesTool, EstimateCostTool | Mock dependencies, verify tool logic in isolation |
| Integration | DeleteAssetsTool (uses OperationManager) | Verify beginBatch + executeBatch integration |
| Registration | DedupToolRegistrationTests | Verify DI wiring, tool annotations, system prompt |

## Acceptance Criteria Coverage

### AC1: ScanLibraryTool (FR18) -- Covered in existing tests

- Verified via `testScanLibraryToolRegistered` (registration check)
- Full tests exist in `AgentToolRegistryTests.swift` (Story 3.2)

### AC2: AnalyzeDuplicatesTool (FR19, FR20) -- 5 tests

| Test | Priority | File |
|---|---|---|
| `testAnalyzeDuplicatesReturnsGroups` | P0 | AnalyzeDuplicatesToolTests.swift |
| `testAnalyzeDuplicatesWithEmptyLibrary` | P0 | AnalyzeDuplicatesToolTests.swift |
| `testAnalyzeDuplicatesToolAnnotations` | P1 | AnalyzeDuplicatesToolTests.swift |
| `testAnalyzeDuplicatesHandlesPipelineError` | P1 | AnalyzeDuplicatesToolTests.swift |
| `testAnalyzeDuplicatesRespectsMaxPhotos` | P1 | AnalyzeDuplicatesToolTests.swift |

### AC3: DeleteAssetsTool (FR22, FR33) -- 4 tests

| Test | Priority | File |
|---|---|---|
| `testDeleteAssetsCreatesSnapshotAndExecutes` | P0 | DeleteAssetsToolTests.swift |
| `testDeleteAssetsRollsBackOnFailure` | P0 | DeleteAssetsToolTests.swift |
| `testDeleteAssetsToolAnnotations` | P1 | DeleteAssetsToolTests.swift |
| `testDeleteAssetsHandlesInvalidAssetIDs` | P1 | DeleteAssetsToolTests.swift |

### AC4: EstimateCostTool (FR46) -- 4 tests

| Test | Priority | File |
|---|---|---|
| `testEstimateCostReturnsCostEstimate` | P0 | EstimateCostToolTests.swift |
| `testEstimateCostDifferentOperations` | P1 | EstimateCostToolTests.swift |
| `testEstimateCostToolAnnotations` | P1 | EstimateCostToolTests.swift |
| `testEstimateCostHandlesMissingParameters` | P1 | EstimateCostToolTests.swift |

### AC5: Tool Registration (FR13) -- 5 tests

| Test | Priority | File |
|---|---|---|
| `testAllDedupToolsRegisteredInRegistry` | P1 | DedupToolRegistrationTests.swift |
| `testScanLibraryToolRegistered` | P1 | DedupToolRegistrationTests.swift |
| `testToolAnnotationsCorrect` | P1 | DedupToolRegistrationTests.swift |
| `testSystemPromptIncludesDedupTools` | P1 | DedupToolRegistrationTests.swift |
| `testSystemPromptIncludesDedupWorkflowGuidance` | P1 | DedupToolRegistrationTests.swift |

### AC6: Error Handling & Fault Tolerance (NFR20, NFR23) -- 3 tests

| Test | Priority | File |
|---|---|---|
| `testAnalyzeDuplicatesHandlesPipelineError` | P1 | AnalyzeDuplicatesToolTests.swift |
| `testDeleteAssetsHandlesInvalidAssetIDs` | P1 | DeleteAssetsToolTests.swift |
| `testEstimateCostHandlesMissingParameters` | P1 | EstimateCostToolTests.swift |

## Priority Summary

| Priority | Count | Description |
|---|---|---|
| P0 | 5 | Critical happy paths -- must pass for story completion |
| P1 | 13 | Error handling, annotations, registration -- should pass |
| P2 | 0 | Nice-to-have edge cases |
| P3 | 0 | Performance/stress tests |

## Mock Strategy

All tests use protocol-based mocks following existing project patterns:

- `MockToolAnalysisPipeline` (ImageAnalysisPipelineProtocol) -- returns preset DuplicateGroups
- `MockToolTestRepository` (PhotoLibraryRepository) -- returns preset PhotoAssets
- `TrackingMockToolRepository` (PhotoLibraryRepository) -- tracks fetchAssets parameters
- `TrackingMockOperationManager` (OperationManaging) -- tracks beginBatch/executeBatch calls
- `FailingMockOperationManager` (OperationManaging) -- simulates execution failure
- `MockToolLLMGateway` (LLMGatewayProtocol) -- returns preset CostEstimate
- `TrackingMockLLMGateway` (LLMGatewayProtocol) -- tracks estimateCost parameters

## Next Steps (Task-by-Task Activation)

During implementation of each task:

1. Remove `XCTSkipIf(true, "ATDD Red Phase")` from the tests for the current task
2. Run tests: `xcodebuild test` or via Xcode
3. Verify the activated test fails first, then passes after implementation (green phase)
4. If any activated tests still fail unexpectedly:
   - Either fix implementation (feature bug)
   - Or fix test (test bug)
5. Commit passing tests

Recommended activation order (matches story tasks):

1. **Task 1 (AnalyzeDuplicatesTool):** Activate `testAnalyzeDuplicatesReturnsGroups`, `testAnalyzeDuplicatesWithEmptyLibrary`, `testAnalyzeDuplicatesToolAnnotations`, `testAnalyzeDuplicatesHandlesPipelineError`, `testAnalyzeDuplicatesRespectsMaxPhotos`
2. **Task 2 (DeleteAssetsTool):** Activate `testDeleteAssetsCreatesSnapshotAndExecutes`, `testDeleteAssetsRollsBackOnFailure`, `testDeleteAssetsToolAnnotations`, `testDeleteAssetsHandlesInvalidAssetIDs`
3. **Task 3 (EstimateCostTool):** Activate `testEstimateCostReturnsCostEstimate`, `testEstimateCostDifferentOperations`, `testEstimateCostToolAnnotations`, `testEstimateCostHandlesMissingParameters`
4. **Task 4-5 (Registration & System Prompt):** Activate all DedupToolRegistrationTests

## Implementation Files to Create

Per story specification:

- `Curator/Infrastructure/SDKTools/AnalyzeDuplicatesTool.swift` -- Task 1
- `Curator/Infrastructure/SDKTools/DeleteAssetsTool.swift` -- Task 2
- `Curator/Infrastructure/SDKTools/EstimateCostTool.swift` -- Task 3
- `Curator/App/AppDependencies.swift` -- Task 4 (add registerDeduplicationTools)
- `Curator/Core/Agent/CuratorAgent.swift` -- Task 5 (update system prompt)
- `Curator/ContentView.swift` -- Task 4 (add registration call)

## Key Risks and Assumptions

1. **DefineTool() signature:** Tests assume `defineTool()` accepts `isReadOnly` and `annotations` parameters (matching ScanLibraryTool pattern)
2. **Tool.call() interface:** Tests use `tool.call(input:context:)` which is the OpenAgentSDK ToolProtocol interface
3. **Error handling:** Tests assume tools catch errors internally and return `result.isError = true` with structured JSON, rather than throwing
4. **OperationManager mock:** Uses actor-based mocks matching the production OperationManager actor pattern
5. **DeleteAssetsTool DI:** Story specifies injection of `operationManager` and `repository` -- factory function signature may vary slightly during implementation
