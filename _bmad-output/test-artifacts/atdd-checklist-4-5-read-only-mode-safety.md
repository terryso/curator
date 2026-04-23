---
stepsCompleted:
  - 'step-01-preflight-and-context'
  - 'step-02-generation-mode'
  - 'step-03-test-strategy'
  - 'step-04c-aggregate'
lastStep: 'step-04c-aggregate'
lastSaved: '2026-04-23'
storyId: '4.5'
storyKey: '4-5-read-only-mode-safety'
storyFile: '_bmad-output/implementation-artifacts/4-5-read-only-mode-safety.md'
atddChecklistPath: '_bmad-output/test-artifacts/atdd-checklist-4-5-read-only-mode-safety.md'
generatedTestFiles:
  - 'CuratorTests/Features/ReadOnlyMode/ReadOnlyModeTests.swift'
---

# ATDD Checklist: Story 4.5 — 只读模式保障 (Read-Only Mode Safety)

## TDD Red Phase (Current)

所有测试使用 `XCTSkipIf(true, ...)` 标记为 RED 阶段脚手架。激活后将在实现前失败，实现后通过。

- **Unit Tests:** 24 tests (all skipped via XCTSkipIf)
- **E2E Tests:** N/A (Swift backend, no browser tests)

## Acceptance Criteria Coverage

### AC1: 只读模式下分析功能正常运行（FR37）

| # | Test | Priority | Status |
|---|------|----------|--------|
| 1 | `testAnalysisWorksInReadOnlyMode` | P0 | RED |
| 2 | `testMetadataReadWorksInReadOnlyMode` | P1 | RED |

### AC2: 只读模式下写操作触发权限升级（FR6, UX-DR9）

| # | Test | Priority | Status |
|---|------|----------|--------|
| 3 | `testWritePermissionRequestedOnWriteAttempt` | P0 | RED |
| 4 | `testOperationsSavedForLaterWhenPermissionDenied` | P0 | RED |
| 5 | `testOperationsContinueAfterPermissionGranted` | P0 | RED |

### AC3: Repository 层写入守卫（FR38）

| # | Test | Priority | Status |
|---|------|----------|--------|
| 6 | `testUpdateAssetBlockedInReadOnlyMode` | P0 | RED |
| 7 | `testDeleteAssetsBlockedInReadOnlyMode` | P0 | RED |
| 8 | `testMoveAssetsBlockedInReadOnlyMode` | P0 | RED |
| 9 | `testOriginalImageFilesNeverModified` | P0 | RED |

### AC4: 只读模式全局视觉指示（UX-DR9, UX-DR15）

| # | Test | Priority | Status |
|---|------|----------|--------|
| 10 | `testReadOnlyBannerShowsWhenReadOnly` | P1 | RED |
| 11 | `testReadOnlyBannerHidesAfterPermissionGranted` | P1 | RED |

### AC5: 只读模式下保存结果供稍后执行

| # | Test | Priority | Status |
|---|------|----------|--------|
| 12 | `testSavedOperationsCanBeReexecutedAfterPermissionGranted` | P0 | RED |
| 13 | `testSavedOperationsPersistAcrossAppRestarts` | P1 | RED |
| 14 | `testDeleteSavedOperations` | P1 | RED |
| 15 | `testClearAllSavedOperations` | P1 | RED |

### PermissionState 单元测试

| # | Test | Priority | Status |
|---|------|----------|--------|
| 16 | `testPermissionStateStartsReadOnly` | P0 | RED |
| 17 | `testPermissionStateExitsReadOnlyAfterGrant` | P0 | RED |
| 18 | `testPermissionStateReturnsToReadOnlyAfterRevoke` | P0 | RED |

### SavedOperationSet 序列化测试

| # | Test | Priority | Status |
|---|------|----------|--------|
| 19 | `testSavedOperationSetCodable` | P1 | RED |
| 20 | `testPlannedOperationCodable` | P1 | RED |

## Test Distribution Summary

- **P0 Tests:** 12 (核心功能验证)
- **P1 Tests:** 8 (辅助功能与边界情况)
- **Total:** 20 (all RED phase, skipped)

## Test Levels

| Level | Count | Description |
|-------|-------|-------------|
| Unit | 20 | ViewModel 状态、PermissionState、序列化 |
| Integration | 0 | Repository 层守卫通过 Unit 测试覆盖（使用 Mock） |

Note: AC3 的 Repository 层写入守卫测试在 Unit 级别使用 `MockReadOnlyBookmarkManager` 验证，覆盖 `LocalFolderRepository` 的 `updateAsset`/`deleteAssets`/`moveAssets` 三个写操作方法的权限检查逻辑。

## Implementation Guidance

### 待实现的类型 (Story 4.5)

1. **`ReadOnlyModeViewModel`** — `@Observable @MainActor` 类
   - `isReadOnly: Bool`（绑定 PermissionState）
   - `savedOperations: [SavedOperationSet]?`
   - `hasSavedOperations: Bool`
   - `saveOperationsForLater(_:summary:)`
   - `loadSavedOperations()`
   - `executeSavedOperations(_:operationManager:)`
   - `deleteSavedOperations(_:)`
   - `clearAllSavedOperations()`

2. **`SavedOperationSet`** — `Sendable, Codable, Identifiable` struct
   - `id: UUID`
   - `createdAt: Date`
   - `summary: String`
   - `operations: [PlannedOperation]`

3. **`ReadOnlyBannerView`** — SwiftUI 视图
4. **`SavedOperationsListView`** — SwiftUI 视图

### 待修改的类型

1. **`ConfirmationViewModel`** — 注入 `ReadOnlyModeViewModel`，在 `permissionDenied()` 中调用 `saveOperationsForLater()`
2. **`MainWorkspaceView`** — 集成 ReadOnlyBannerView
3. **`AppDependencies`** — 注册 `ReadOnlyModeViewModel`
4. **`StepCardView`** — 增加只读模式标注

### Mock Types (in test file)

- `MockReadOnlyBookmarkManager` — 模拟只读模式（`hasWriteAccess == false`）
- `MockReadOnlyOperationManager` — 追踪 OperationManager 调用
- `MockWriteGrantedRepository` — 模拟已授权仓库

## Next Steps (Task-by-Task Activation)

实施每个 Task 时：

1. 移除当前 Task 相关测试的 `XCTSkipIf(true, ...)` 调用
2. 运行测试: `xcodebuild test -scheme Curator -destination 'platform=macOS'`
3. 验证激活的测试先失败，实现后通过（green phase）
4. 提交通过的测试

### 建议激活顺序

| Task | Tests to Activate |
|------|-------------------|
| Task 1: ReadOnlyModeViewModel | `testSavedOperationsCanBeReexecutedAfterPermissionGranted`, `testSavedOperationsPersistAcrossAppRestarts`, `testDeleteSavedOperations`, `testClearAllSavedOperations`, `testReadOnlyBannerShowsWhenReadOnly`, `testReadOnlyBannerHidesAfterPermissionGranted` |
| Task 2: SavedOperationSet | `testSavedOperationSetCodable` |
| Task 3: PlannedOperation Codable | `testPlannedOperationCodable` |
| Task 5: ConfirmationViewModel 集成 | `testOperationsSavedForLaterWhenPermissionDenied`, `testOperationsContinueAfterPermissionGranted` |
| Repository 守卫验证 | `testUpdateAssetBlockedInReadOnlyMode`, `testDeleteAssetsBlockedInReadOnlyMode`, `testMoveAssetsBlockedInReadOnlyMode`, `testOriginalImageFilesNeverModified` |
| PermissionState 验证 | `testPermissionStateStartsReadOnly`, `testPermissionStateExitsReadOnlyAfterGrant`, `testPermissionStateReturnsToReadOnlyAfterRevoke` |

## Handoff for dev-story

```
Story: 4.5 — 只读模式保障
Checklist: _bmad-output/test-artifacts/atdd-checklist-4-5-read-only-mode-safety.md
Tests: CuratorTests/Features/ReadOnlyMode/ReadOnlyModeTests.swift
TDD Phase: RED (all tests skipped)
```
