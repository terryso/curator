---
stepsCompleted:
  - step-01-preflight-and-context
  - step-02-generation-mode
  - step-03-test-strategy
  - step-04c-aggregate
  - step-05-validate-and-complete
lastStep: step-05-validate-and-complete
lastSaved: '2026-04-25'
storyId: '6.2'
storyKey: 6-2-rename-sdk-tools
storyFile: _bmad-output/implementation-artifacts/6-2-rename-sdk-tools.md
atddChecklistPath: _bmad-output/test-artifacts/atdd-checklist-6-2-rename-sdk-tools.md
generatedTestFiles:
  - CuratorTests/Infrastructure/SDKTools/RenameAssetsToolTests.swift
---

# ATDD Checklist: Story 6.2 -- Rename SDK Tools

## TDD Red Phase (Current)

Red-phase test scaffolds generated. Tests reference `createRenameAssetsTool()` which does not exist yet.
All tests will fail to compile until the implementation is created.

- **Unit/Integration Tests:** 11 tests (all reference not-yet-implemented `createRenameAssetsTool`)
- **E2E Tests:** N/A (backend project, no browser testing)
- **Total test suite:** tests will compile once `RenameAssetsTool.swift` is created

## Test Strategy

| Test Level | Tests | Purpose |
|---|---|---|
| Integration | RenameAssetsTool with mocked OperationManager + Repository | Tool wiring, beginBatch/executeBatch flow, JSON output |
| Unit | Tool annotations, input validation | Properties, empty input rejection |
| Integration | AgentToolRegistry registration | Tool registration alongside estimate_cost |

## Acceptance Criteria Coverage

### AC1: RenameAssetsTool Executes Batch Rename (FR28) -- 6 tests

| Test | Priority | File |
|---|---|---|
| `testRenameAssetsToolReturnsSuccess` | P0 | RenameAssetsToolTests.swift |
| `testRenameAssetsToolCreatesSnapshots` | P0 | RenameAssetsToolTests.swift |
| `testRenameAssetsToolHandlesPartialFailure` | P0 | RenameAssetsToolTests.swift |
| `testRenameAssetsToolRejectsEmptyInput` | P0 | RenameAssetsToolTests.swift |
| `testRenameAssetsToolPreservesMetadata` | P0 | RenameAssetsToolTests.swift |
| `testRenameAssetsToolJSONSerialization` | P1 | RenameAssetsToolTests.swift |

### AC2: Cost Estimate Integration -- 2 tests

| Test | Priority | File |
|---|---|---|
| `testRenameAssetsToolAnnotations` | P1 | RenameAssetsToolTests.swift |
| `testRenameAssetsToolRegisteredInRegistry` | P1 | RenameAssetsToolTests.swift |

### AC3: Partial Failure Tolerance -- 1 test

| Test | Priority | File |
|---|---|---|
| `testRenameAssetsToolRollbackOnTotalFailure` | P1 | RenameAssetsToolTests.swift |

### Edge Cases -- 2 tests

| Test | Priority | File |
|---|---|---|
| `testRenameAssetsToolHandlesSpecialCharacters` | P1 | RenameAssetsToolTests.swift |
| `testRenameAssetsToolHandlesLargeBatch` | P1 | RenameAssetsToolTests.swift |

## Priority Summary

| Priority | Count | Description |
|---|---|---|
| P0 | 5 | Critical happy paths: success, snapshots, partial failure, validation, metadata |
| P1 | 6 | Annotations, registration, rollback, JSON format, edge cases |
| P2 | 0 | Nice-to-have edge cases |
| P3 | 0 | Performance/stress tests |

## Mock Strategy

All tests use protocol-based mocks following existing project patterns (aligned with DeleteAssetsToolTests):

- `TrackingRenameMockOperationManager` (OperationManaging) -- tracks beginBatch/executeBatch calls
- `OperationsCapturingMockOperationManager` (OperationManaging) -- captures PlannedOperations for parameter verification
- `FailingRenameMockOperationManager` (OperationManaging) -- succeeds on beginBatch, fails on executeBatch
- `SimpleRenameMockOperationManager` (OperationManaging) -- minimal mock for annotation/property tests
- `MockRenameTestRepository` (PhotoLibraryRepository) -- standard repository mock
- `MockRenameLLMGateway` (LLMGatewayProtocol) -- for registry integration tests

## Next Steps (Task-by-Task Activation)

During implementation of each task:

1. Create `Curator/Infrastructure/SDKTools/RenameAssetsTool.swift` with `createRenameAssetsTool()` factory
2. Run tests: `xcodebuild test` or via Xcode
3. Verify tests fail first (red), then pass after implementation (green)
4. Commit passing tests

Recommended activation order (matches story tasks):

1. **Task 1 (RenameAssetsTool):** All tests in `RenameAssetsToolTests.swift` -- the tool must exist first
2. **Task 2 (Registration):** `testRenameAssetsToolRegisteredInRegistry` -- register in AgentToolRegistry

## Implementation Files to Create

Per story specification:

- `Curator/Infrastructure/SDKTools/RenameAssetsTool.swift` -- Task 1 (main tool implementation)

## Files That May Need Modification

- `Curator/Core/Agent/AgentToolRegistry.swift` -- Task 2 (registration, if registry has a dedicated registration method)

## Key Risks and Assumptions

1. **createRenameAssetsTool signature:** Tests assume the factory function takes `(operationManager: OperationManaging, repository: PhotoLibraryRepository)` matching the DeleteAssetsTool pattern
2. **Input schema:** Tests assume input is `[String: Any]` with a "suggestions" key containing an array of dictionaries with `assetID`, `suggestedName`, `originalFileName` keys
3. **defineTool() pattern:** Tests assume `createRenameAssetsTool` follows the same `defineTool()` factory pattern as `createDeleteAssetsTool`
4. **PlannedOperation .rename case:** Tests rely on the existing `.rename` operation type with `.rename(newTitle:)` parameters
5. **Error handling:** Tests assume the tool catches errors and returns `result.isError = true` matching DeleteAssetsTool behavior
6. **JSON output format:** Tests expect the result to be parseable JSON with `success`, `batchID`, and `renamedCount` fields
7. **No #if false guards needed:** Unlike Story 6.1 which introduced new types, Story 6.2 reuses all existing types (PlannedOperation, OperationParameters, OperationManaging, AssetID) -- only `createRenameAssetsTool` is new, so tests will compile once that function exists
