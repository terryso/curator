---
stepsCompleted: ['step-01-preflight-and-context', 'step-02-generation-mode', 'step-03-test-strategy', 'step-04-generate-tests', 'step-04c-aggregate', 'step-05-validate-and-complete']
lastStep: 'step-05-validate-and-complete'
lastSaved: '2026-04-22'
storyId: '4.1'
storyKey: '4-1-write-permission-progressive'
storyFile: '_bmad-output/implementation-artifacts/4-1-write-permission-progressive.md'
atddChecklistPath: '_bmad-output/test-artifacts/atdd-checklist-4-1-write-permission-progressive.md'
generatedTestFiles:
  - 'CuratorTests/Infrastructure/PhotoSource/WritePermissionTests.swift'
---

# ATDD Checklist: Story 4.1 — 写入权限渐进授权

## TDD Red Phase Status

**Phase:** RED
**Total Tests:** 19 (all skipped)
**Test File:** `CuratorTests/Infrastructure/PhotoSource/WritePermissionTests.swift`
**Full Suite Result:** 571 tests, 19 skipped, 0 failures (no regressions)

## Acceptance Criteria Coverage

| AC | Description | Tests | Priority | Status |
|----|------------|-------|----------|--------|
| AC1 | 只读默认启动 (FR37) | testReadOnlyDefaultOnStartup, testReadOnlyModeAllowsAnalysisOperations | P0, P1 | RED |
| AC2 | 按需写入权限升级 (FR6) | testRequestWriteAccessUpgradesBookmark, testWriteOperationSucceedsWithPermission, testFolderBookmarkManagerHasWriteAccessProperty, testFolderBookmarkManagerWriteAccessAfterGrant | P0 | RED |
| AC3 | 权限拒绝降级处理 (UX-DR9) | testWriteOperationWithoutPermissionThrows, testWritePermissionRefusedReturnsGracefully, testWritePermissionErrorMapsDistinctly, testReadAndWriteErrorsMapDifferently | P0, P1 | RED |
| AC4 | 写操作实现 (FR38, NFR15) | testUpdateAssetRenamesFile, testUpdateAssetWithNilTitleIsNoOp, testDeleteAssetsMovesToTrash, testDeleteAssetsThrowsForNonExistentFile, testMoveAssetsCreatesDirectoryAndMoves, testDeleteAssetsWithoutPermissionThrows, testMoveAssetsWithoutPermissionThrows | P0, P1 | RED |
| AC5 | 权限状态 UI 指示 (FR37) | testPermissionStateIsReadOnlyByDefault, testPermissionStateChangesAfterGrant | P1 | RED |

## Test Inventory

### P0 Tests (11)

| Test Method | AC | Description | Activation |
|-------------|-----|-------------|------------|
| testReadOnlyDefaultOnStartup | AC1 | requestWriteAccess returns false by default | Remove `XCTSkipIf(true, ...)` |
| testRequestWriteAccessUpgradesBookmark | AC2 | requestWriteAccess returns true after grant | Change `#if false` to `#if true` |
| testWriteOperationSucceedsWithPermission | AC2 | updateAsset succeeds with write permission | Remove `XCTSkipIf(true, ...)` |
| testWriteOperationWithoutPermissionThrows | AC3 | updateAsset throws without write permission | Remove `XCTSkipIf(true, ...)` |
| testUpdateAssetRenamesFile | AC4 | updateAsset renames file, preserves data (NFR15) | Remove `XCTSkipIf(true, ...)` |
| testUpdateAssetWithNilTitleIsNoOp | AC4 | updateAsset with nil title is no-op | Remove `XCTSkipIf(true, ...)` |
| testDeleteAssetsMovesToTrash | AC4 | deleteAssets uses trashItem, not removeItem | Remove `XCTSkipIf(true, ...)` |
| testDeleteAssetsThrowsForNonExistentFile | AC4 | deleteAssets throws assetNotFound for missing file | Remove `XCTSkipIf(true, ...)` |
| testMoveAssetsCreatesDirectoryAndMoves | AC4 | moveAssets creates dir and moves files (NFR15) | Remove `XCTSkipIf(true, ...)` |
| testWritePermissionErrorMapsDistinctly | AC3 | insufficientPermission(.write) -> writePermissionRequired | Change `#if false` to `#if true` |
| testFolderBookmarkManagerHasWriteAccessProperty | AC2 | hasWriteAccess is false initially | Change `#if false` to `#if true` |

### P1 Tests (8)

| Test Method | AC | Description | Activation |
|-------------|-----|-------------|------------|
| testReadOnlyModeAllowsAnalysisOperations | AC1 | fetchAssets works in read-only mode | Remove `XCTSkipIf(true, ...)` |
| testWritePermissionRefusedReturnsGracefully | AC3 | User refuses write; graceful degradation | Remove `XCTSkipIf(true, ...)` |
| testDeleteAssetsWithoutPermissionThrows | AC4 | deleteAssets throws without permission | Remove `XCTSkipIf(true, ...)` |
| testMoveAssetsWithoutPermissionThrows | AC4 | moveAssets throws without permission | Remove `XCTSkipIf(true, ...)` |
| testPermissionStateIsReadOnlyByDefault | AC5 | PermissionState starts read-only | Change `#if false` to `#if true` |
| testPermissionStateChangesAfterGrant | AC5 | PermissionState changes after grant | Change `#if false` to `#if true` |
| testReadAndWriteErrorsMapDifferently | AC3 | Read/write errors map to different cases | Change `#if false` to `#if true` |
| testFolderBookmarkManagerWriteAccessAfterGrant | AC2 | hasWriteAccess true after grant | Change `#if false` to `#if true` |

## Activation Strategy (Task-by-Task)

Tests reference types that do not yet exist. Activate them in this order as implementation progresses:

### Task 1: FolderBookmarkManager write access
**New types needed:** `hasWriteAccess` property, `grantWriteAccess()` method on `FolderBookmarkManaging`
**Activate:**
1. `testFolderBookmarkManagerHasWriteAccessProperty` — change `#if false` to `#if true`
2. `testFolderBookmarkManagerWriteAccessAfterGrant` — change `#if false` to `#if true`

### Task 2: LocalFolderRepository write operations
**New behavior:** `requestWriteAccess()` returns true/false, write methods implemented
**Activate (remove `XCTSkipIf`):**
1. `testReadOnlyDefaultOnStartup`
2. `testWriteOperationWithoutPermissionThrows`
3. `testUpdateAssetRenamesFile`
4. `testUpdateAssetWithNilTitleIsNoOp`
5. `testDeleteAssetsMovesToTrash`
6. `testDeleteAssetsThrowsForNonExistentFile`
7. `testMoveAssetsCreatesDirectoryAndMoves`
8. `testDeleteAssetsWithoutPermissionThrows`
9. `testMoveAssetsWithoutPermissionThrows`
10. `testRequestWriteAccessUpgradesBookmark` — change `#if false` to `#if true`
11. `testWriteOperationSucceedsWithPermission`
12. `testReadOnlyModeAllowsAnalysisOperations`
13. `testWritePermissionRefusedReturnsGracefully`

### Task 3: PermissionState model
**New types needed:** `PermissionState` class in `Core/Models/`
**Activate:**
1. `testPermissionStateIsReadOnlyByDefault` — change `#if false` to `#if true`
2. `testPermissionStateChangesAfterGrant` — change `#if false` to `#if true`

### Task 4: Error mapping update
**New types needed:** `UserFacingError.writePermissionRequired` case
**Activate:**
1. `testWritePermissionErrorMapsDistinctly` — change `#if false` to `#if true`
2. `testReadAndWriteErrorsMapDifferently` — change `#if false` to `#if true`

## Key Risks & Assumptions

1. **Scheme A vs B:** Tests assume "方案 A" where entitlements already grant read-write access and the app controls write state via a boolean flag. If "方案 B" (re-NSOpenPanel) is needed, testRequestWriteAccessUpgradesBookmark will require adjustment.
2. **PermissionState tests** reference `@MainActor @Observable` class — tests must run on main actor.
3. **trashItem behavior:** `testDeleteAssetsMovesToTrash` verifies the file leaves the original location but does not verify the trash destination (hard to verify in test environment).
4. **NFR15 (zero corruption):** Tests compare file data before/after move/rename operations to verify pixel data is untouched.

## Generated Files

- `CuratorTests/Infrastructure/PhotoSource/WritePermissionTests.swift` — 19 test methods covering AC1-AC5

## Input Documents

- `_bmad-output/implementation-artifacts/4-1-write-permission-progressive.md` (story file)
- `Curator/Core/Models/FolderBookmarkManaging.swift` (current protocol)
- `Curator/Infrastructure/PhotoSource/FolderBookmarkManager.swift` (current implementation)
- `Curator/Infrastructure/PhotoSource/LocalFolderRepository.swift` (current implementation)
- `Curator/Core/Errors/DomainError.swift` (current error types)
- `Curator/Core/Errors/UserFacingError.swift` (current UI error types)
- `Curator/Core/Errors/ErrorMapping.swift` (current error mapping)
- `Curator/Core/Errors/PermissionLevel.swift` (read/write enum)
- `Curator/Core/Models/PhotoLibraryRepository.swift` (repository protocol)
- `Curator/Infrastructure/Mock/MockPhotoLibraryRepository.swift` (mock)
- `Curator/App/AppDependencies.swift` (DI container)
- `CuratorTests/Infrastructure/PhotoSource/LocalFolderRepositoryTests.swift` (existing tests + TestBookmarkManager)

## Next Recommended Workflow

Run `bmad-dev-story 4-1` to implement the feature. During implementation, activate tests task-by-task following the activation strategy above.
