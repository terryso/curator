---
stepsCompleted: ['step-01-preflight-and-context', 'step-02-generation-mode', 'step-03-test-strategy', 'step-04-generate-tests']
lastStep: 'step-04-generate-tests'
lastSaved: '2026-04-22'
storyId: '4.2'
storyKey: '4-2-operation-manager-core'
storyFile: '_bmad-output/implementation-artifacts/4-2-operation-manager-core.md'
atddChecklistPath: '_bmad-output/implementation-artifacts/atdd-checklist-4-2-operation-manager-core.md'
generatedTestFiles:
  - 'CuratorTests/Core/Operations/OperationManagerTests.swift'
inputDocuments:
  - '_bmad-output/implementation-artifacts/4-2-operation-manager-core.md'
  - 'Curator/Core/Models/PhotoLibraryRepository.swift'
  - 'Curator/Core/Models/AssetMetadata.swift'
  - 'Curator/Core/Models/AssetID.swift'
  - 'Curator/Core/Errors/DomainError.swift'
  - 'Curator/Core/Errors/InfrastructureError.swift'
  - 'Curator/Infrastructure/Storage/SwiftDataModels.swift'
  - 'Curator/Infrastructure/Storage/SwiftDataManager.swift'
  - 'Curator/App/AppDependencies.swift'
detected_stack: backend
generation_mode: ai-generation
---

# ATDD Checklist: Story 4.2 — Operation Manager Core

## Stack Detection

- **Detected Stack**: `backend` (Swift/macOS, XCTest)
- **Test Framework**: XCTest
- **Generation Mode**: AI Generation (backend project, no browser testing needed)

## Test Strategy

### Test Levels

| Level | Usage | Rationale |
|-------|-------|-----------|
| Unit | OperationType, BatchStatus, OperationSnapshot, BatchOperation, PlannedOperation value types | Pure type conformance, Codable/Sendable verification |
| Integration | OperationManager + SwiftData persistence, beginBatch/executeBatch/rollbackBatch flows | Cross-component interaction with SwiftData and mock repository |

### Priority Matrix

| Priority | Criteria | Coverage Target |
|----------|----------|-----------------|
| P0 | Core types exist, beginBatch creates snapshots, executeBatch works, NFR15, auto-rollback, actor isolation, error handling | 100% |
| P1 | SwiftData persistence, detectIncompleteBatches, rollback restores state, rollbackLastBatch, all operation types | 80% |
| P2 | Edge cases, high concurrency | 50% |

## Acceptance Criteria -> Test Mapping

### AC1: OperationManager actor implementation (FR35)

| ID | Test Scenario | Level | Priority | Red Phase |
|----|---------------|-------|----------|-----------|
| AC1-T1 | OperationManager is an actor conforming to OperationManaging | Unit | P0 | XCTSkip |
| AC1-T2 | OperationManaging protocol exists with required methods | Unit | P0 | XCTSkip |
| AC1-T3 | beginBatch creates an OperationSnapshot for each planned operation | Integration | P0 | XCTSkip |
| AC1-T4 | beginBatch snapshots contain correct beforeState metadata | Integration | P0 | XCTSkip |
| AC1-T5 | Actor isolation: concurrent beginBatch calls serialized correctly | Integration | P0 | XCTSkip |

### AC2: OperationSnapshot model definition

| ID | Test Scenario | Level | Priority | Red Phase |
|----|---------------|-------|----------|-----------|
| AC2-T1 | OperationType enum with .rename/.delete/.move/.metadataChange, Sendable, Codable | Unit | P0 | XCTSkip |
| AC2-T2 | BatchStatus enum with .pending/.executing/.completed/.failed/.rolledBack | Unit | P0 | XCTSkip |
| AC2-T3 | OperationSnapshot value type with id, timestamp, operationType, assetID, beforeState | Unit | P0 | XCTSkip |
| AC2-T4 | OperationSnapshot conforms to Sendable and Codable | Unit | P0 | XCTSkip |
| AC2-T5 | BatchOperation value type with snapshots association and status | Unit | P0 | XCTSkip |
| AC2-T6 | BatchOperation conforms to Sendable and Codable | Unit | P0 | XCTSkip |
| AC2-T7 | PlannedOperation with operationType, assetID, parameters (all 4 types) | Unit | P0 | XCTSkip |
| AC2-T8 | PlannedOperation conforms to Sendable and Codable | Unit | P1 | XCTSkip |

### AC3: Batch operation execution and recording (FR38, NFR15)

| ID | Test Scenario | Level | Priority | Red Phase |
|----|---------------|-------|----------|-----------|
| AC3-T1 | executeBatch calls repository.updateAsset for rename operations | Integration | P0 | XCTSkip |
| AC3-T2 | executeBatch does not modify original image pixel data (NFR15) | Integration | P0 | XCTSkip |
| AC3-T3 | executeBatch with delete calls repository.deleteAssets | Integration | P1 | XCTSkip |
| AC3-T4 | executeBatch with move calls repository.moveAssets | Integration | P1 | XCTSkip |

### AC4: Batch operation partial failure auto-rollback (FR36)

| ID | Test Scenario | Level | Priority | Red Phase |
|----|---------------|-------|----------|-----------|
| AC4-T1 | Partial failure during executeBatch triggers auto-rollback | Integration | P0 | XCTSkip |
| AC4-T2 | rollbackBatch restores original state for rename operations | Integration | P1 | XCTSkip |
| AC4-T3 | rollbackLastBatch rolls back the most recent completed batch | Integration | P1 | XCTSkip |

### AC5: Operation log persistence (NFR17)

| ID | Test Scenario | Level | Priority | Red Phase |
|----|---------------|-------|----------|-----------|
| AC5-T1 | Snapshots persist to SwiftData and can be re-queried | Integration | P1 | XCTSkip |
| AC5-T2 | detectIncompleteBatches returns batches with .executing status | Integration | P1 | XCTSkip |

### Error Handling

| ID | Test Scenario | Level | Priority | Red Phase |
|----|---------------|-------|----------|-----------|
| EH-T1 | beginBatch with empty operations throws DomainError.invalidState | Unit | P0 | XCTSkip |
| EH-T2 | executeBatch with unknown batch ID throws DomainError.invalidState | Unit | P0 | XCTSkip |
| EH-T3 | rollbackBatch with unknown batch ID throws DomainError.invalidState | Unit | P1 | XCTSkip |
| EH-T4 | rollbackLastBatch with no completed batches throws error | Unit | P1 | XCTSkip |

## Generated Test Files

1. **OperationManagerTests.swift** — All AC tests in single file (XCTest pattern)
   - Domain model conformance tests (AC2)
   - OperationManager actor tests (AC1)
   - Batch execution tests (AC3)
   - Auto-rollback tests (AC4)
   - Persistence tests (AC5)
   - Error handling tests

## TDD Red Phase Compliance

- [x] All tests use `throw XCTSkip("RED: ...")` — will be activated during dev-story
- [x] All tests assert EXPECTED behavior (not current behavior)
- [x] Activated tests will FAIL until feature is implemented
- [x] No active passing tests generated
- [x] Mock implementations provided (MockPhotoLibraryRepositoryForOperations, MockOperationManager)

## Mock Infrastructure

| Mock | Purpose | Location |
|------|---------|----------|
| MockPhotoLibraryRepositoryForOperations | Tracks updateAsset/deleteAssets/moveAssets calls, supports failure injection | Inline in test file |
| MockOperationManager | Verifies OperationManaging protocol conformance | Inline in test file |

## NFR Coverage

| NFR | Test Coverage |
|-----|---------------|
| NFR15 (Zero file corruption) | AC3-T2: Verifies imageDataModified is false after all operation types |
| NFR16 (5s rollback) | Covered by rollbackBatch tests; performance validation deferred to integration |
| NFR17 (Crash recovery) | AC5-T2: detectIncompleteBatches API contract verified |

## Implementation Guidance

### Files to create:
- `Curator/Core/Operations/OperationType.swift`
- `Curator/Core/Operations/OperationSnapshot.swift`
- `Curator/Core/Operations/BatchOperation.swift`
- `Curator/Core/Operations/BatchStatus.swift`
- `Curator/Core/Operations/PlannedOperation.swift`
- `Curator/Core/Operations/OperationManaging.swift`
- `Curator/Core/Operations/OperationManager.swift`

### Files to modify:
- `Curator/Infrastructure/Storage/SwiftDataModels.swift` (add OperationSnapshotEntity, BatchOperationEntity)
- `Curator/Infrastructure/Storage/SwiftDataManager.swift` (add entities to Schema)
- `Curator/App/AppDependencies.swift` (register OperationManager)

### Task-by-Task Activation:

During implementation of each task:

1. Remove `throw XCTSkip(...)` from the relevant test(s)
2. Run tests: `xcodebuild test` or `swift test`
3. Verify the activated test fails first, then passes after implementation (green phase)
4. If any activated tests still fail unexpectedly:
   - Either fix implementation (feature bug)
   - Or fix test (test bug)
5. Commit passing tests

### Suggested activation order:

1. Task 1 (domain models) -> Activate AC2 tests (testOperationTypeExistsWithRequiredCases, etc.)
2. Task 2 (SwiftData entities) -> Update makeInMemoryContext helper, activate AC5-T1
3. Task 3 (OperationManager actor) -> Activate AC1, AC3, AC4 tests
4. Task 4 (DI registration) -> Verify no regressions
