---
stepsCompleted:
  - step-01-preflight-and-context
  - step-02-generation-mode
  - step-03-test-strategy
  - step-04-generate-tests
  - step-04c-aggregate
  - step-05-validate-and-complete
lastStep: step-05-validate-and-complete
lastSaved: '2026-04-18'
storyId: '1.3'
storyKey: 1-3-photokit-read-service
storyFile: _bmad-output/implementation-artifacts/1-3-photokit-read-service.md
atddChecklistPath: _bmad-output/test-artifacts/atdd-checklist-1-3-photokit-read-service.md
generatedTestFiles:
  - CuratorTests/Infrastructure/PhotoKit/PHAssetMapperTests.swift
  - CuratorTests/Infrastructure/PhotoKit/PhotoPermissionManagerTests.swift
  - CuratorTests/Infrastructure/PhotoKit/PhotoKitRepositoryTests.swift
---

# ATDD Checklist: Story 1.3 - PhotoKit Read Service

## TDD Red Phase (Current)

RED-phase test scaffolds generated. All tests reference types that do not exist yet
(PHAssetMapper, PhotoPermissionManager, PhotoKitRepository). Build will fail until
implementation is complete. This is intentional (TDD red phase).

- **Unit Tests**: 30 test methods across 3 test files (all XCTSkip red-phase)
- **E2E Tests**: N/A (backend Swift project, no browser testing)
- **Build Status**: FAILS (expected -- types not implemented yet)

## Acceptance Criteria Coverage

### AC1: Read Permission Request

| Test File | Test Method | Priority | Status |
|-----------|-------------|----------|--------|
| PhotoPermissionManagerTests | testPhotoPermissionManagerExistsAsSendableStruct | P0 | RED |
| PhotoPermissionManagerTests | testPhotoPermissionManagerHasCurrentStatusProperty | P0 | RED |
| PhotoPermissionManagerTests | testRequestReadAccessReturnsTrueWhenAuthorized | P0 | RED |
| PhotoPermissionManagerTests | testRequestReadAccessReturnsTrueWhenLimited | P0 | RED |
| PhotoPermissionManagerTests | testRequestReadAccessThrowsWhenDenied | P0 | RED |
| PhotoPermissionManagerTests | testRequestReadAccessThrowsWhenRestricted | P1 | RED |
| PhotoPermissionManagerTests | testPhotoKitAccessDeniedMapsToInsufficientPermission | P0 | GREEN* |
| PhotoPermissionManagerTests | testInsufficientPermissionMapsToUserFacingPermissionRequired | P1 | GREEN* |
| PhotoPermissionManagerTests | testDeniedPermissionProducesFullErrorChain | P0 | GREEN* |
| PhotoPermissionManagerTests | testPhotoPermissionManagerProvidesCheckCurrentStatus | P1 | RED |
| PhotoKitRepositoryTests | testRequestReadAccessReturnsTrueWhenAuthorized | P0 | RED |
| PhotoKitRepositoryTests | testRequestReadAccessThrowsWhenDenied | P0 | RED |

*GREEN = tests that use existing domain model types (already compile). These verify the error mapping chain that Story 1.2 established and that Story 1.3 must integrate with.

### AC2: Photo Asset Fetch and Mapping

| Test File | Test Method | Priority | Status |
|-----------|-------------|----------|--------|
| PHAssetMapperTests | testPHAssetMapperExistsAsSendableStruct | P0 | RED |
| PHAssetMapperTests | testMapMapsLocalIdentifierToAssetID | P0 | RED |
| PHAssetMapperTests | testMapProducesPhotoAssetWithNilThumbnailWhenNoneProvided | P1 | RED |
| PHAssetMapperTests | testMapProducesPhotoAssetWithThumbnailWhenProvided | P1 | RED |
| PHAssetMapperTests | testMapMetadataMapsCreationDate | P0 | RED |
| PHAssetMapperTests | testMapMetadataMapsKeywords | P1 | RED |
| PHAssetMapperTests | testMapMetadataHandlesNilCreationDate | P1 | RED |
| PHAssetMapperTests | testMapMetadataReturnsEmptyKeywordsWhenNone | P1 | RED |
| PHAssetMapperTests | testMapLocationMapsPHAssetLocationToLocationData | P1 | RED |
| PHAssetMapperTests | testMapLocationReturnsNilWhenNoLocation | P1 | RED |
| PHAssetMapperTests | testFullMappingProducesValidDomainModel | P0 | RED |
| PhotoKitRepositoryTests | testPhotoKitRepositoryExistsAsActor | P0 | RED |
| PhotoKitRepositoryTests | testPhotoKitRepositoryConformsToProtocol | P0 | RED |
| PhotoKitRepositoryTests | testPhotoKitRepositoryIsActor | P0 | RED |
| PhotoKitRepositoryTests | testFetchAssetsReturnsAssetPage | P0 | RED |
| PhotoKitRepositoryTests | testFetchAssetsReturnsEmptyPageWhenNoPhotos | P0 | RED |
| PhotoKitRepositoryTests | testFetchAssetsThrowsWithoutPermission | P0 | RED |
| PhotoKitRepositoryTests | testPhotoKitRepositoryCanBeRegisteredInAppDependencies | P1 | RED |

### AC3: Paginated Query

| Test File | Test Method | Priority | Status |
|-----------|-------------|----------|--------|
| PhotoKitRepositoryTests | testFetchAssetsRespectsPageSize | P1 | RED |
| PhotoKitRepositoryTests | testFetchAssetsReturnsHasMoreWhenMoreResultsExist | P1 | RED |
| PhotoKitRepositoryTests | testRepositoryMethodsExecuteWithinActorIsolation | P1 | RED |

### AC4: Full Resolution Image Access

| Test File | Test Method | Priority | Status |
|-----------|-------------|----------|--------|
| PhotoKitRepositoryTests | testFetchFullResolutionImageReturnsData | P0 | RED |
| PhotoKitRepositoryTests | testFetchFullResolutionImageThrowsForNonexistentAssetID | P0 | RED |
| PhotoKitRepositoryTests | testFetchFullResolutionImageHandlesUndownloadedCloudPhotos | P1 | RED |

## Test Priority Distribution

| Priority | Count | Description |
|----------|-------|-------------|
| P0 | 17 | Must pass before merge |
| P1 | 13 | Should pass, non-blocking |
| P2 | 0 | Nice to have |
| P3 | 0 | Future consideration |
| **Total** | **30** | |

## Next Steps (Task-by-Task Activation)

During implementation of each task in Story 1.3:

1. **Task 1: Implement PHAssetMapper** (AC2)
   - Create `Curator/Infrastructure/PhotoKit/PHAssetMapper.swift`
   - Remove `XCTSkip()` from PHAssetMapperTests
   - Run tests: `xcodebuild test -scheme Curator -destination 'platform=macOS,arch=arm64' -only-testing:CuratorTests/PHAssetMapperTests`
   - Verify tests pass (GREEN phase)

2. **Task 2: Implement PhotoPermissionManager** (AC1)
   - Create `Curator/Infrastructure/PhotoKit/PhotoPermissionManager.swift`
   - Remove `XCTSkip()` from PhotoPermissionManagerTests
   - Run tests: `xcodebuild test -scheme Curator -destination 'platform=macOS,arch=arm64' -only-testing:CuratorTests/PhotoPermissionManagerTests`
   - Verify tests pass (GREEN phase)

3. **Task 3: Implement PhotoKitRepository actor** (AC2, AC3, AC4)
   - Create `Curator/Infrastructure/PhotoKit/PhotoKitRepository.swift`
   - Remove `XCTSkip()` from PhotoKitRepositoryTests
   - Run tests: `xcodebuild test -scheme Curator -destination 'platform=macOS,arch=arm64' -only-testing:CuratorTests/PhotoKitRepositoryTests`
   - Verify tests pass (GREEN phase)

4. **Task 4: Extend PhotoPredicate and AssetPage** (AC3)
   - Update `Curator/Core/Models/PhotoPredicate.swift`
   - Update `Curator/Core/Models/AssetPage.swift`
   - Run all tests to confirm no regression

5. **Task 5: Register PhotoKitRepository in AppDependencies** (AC1, AC2)
   - Update `Curator/App/AppDependencies.swift`
   - Run full test suite: `xcodebuild test -scheme Curator -destination 'platform=macOS,arch=arm64'`
   - Verify all 48 (existing) + 30 (new) tests pass

## Implementation Guidance

### Types to Implement

1. **PHAssetMapper** (struct, Sendable)
   - `static func map(_ phAsset: PHAsset, thumbnailData: Data?) -> PhotoAsset`
   - `static func mapMetadata(_ phAsset: PHAsset) -> AssetMetadata`
   - `static func mapLocation(_ phAsset: PHAsset) -> LocationData?`

2. **PhotoPermissionManager** (struct, Sendable)
   - `var currentStatus: PHAuthorizationStatus`
   - `func requestReadAccess() async throws -> Bool`
   - `func checkCurrentStatus() -> PHAuthorizationStatus`

3. **PhotoKitRepository** (actor, PhotoLibraryRepository)
   - `func requestReadAccess() async throws -> Bool`
   - `func requestWriteAccess() async throws -> Bool`
   - `func fetchAssets(predicate:pageSize:) async throws -> AssetPage`
   - `func fetchFullResolutionImage(for:) async throws -> Data`

### Execution Commands

```bash
# Run all tests
xcodebuild test -scheme Curator -destination 'platform=macOS,arch=arm64'

# Run specific test file
xcodebuild test -scheme Curator -destination 'platform=macOS,arch=arm64' -only-testing:CuratorTests/PHAssetMapperTests

# Build only (check compilation)
xcodebuild build -scheme Curator -destination 'platform=macOS,arch=arm64'
```

## Key Risks and Assumptions

1. **PHAsset mockability**: PHAsset is a system class that is difficult to mock. Tests may need integration testing with real PhotoKit or protocol-level mocking.
2. **XCTSkip pattern**: Swift doesn't have `test.skip()` like JS. Tests use `XCTSkip()` but still require types to exist for compilation. The build will fail until implementation types are created.
3. **Permission testing**: Real permission dialogs cannot be tested in unit tests. Error mapping chain tests (GREEN*) validate the downstream handling.
4. **iCloud photos**: NFR23 requires graceful handling of undownloaded cloud photos. Test is scaffolded but may need adjustment based on actual PhotoKit behavior.
5. **Actor isolation**: Thread safety tests are structural (compile-time verification) rather than runtime.

## ATDD Artifacts

- **Checklist**: `_bmad-output/test-artifacts/atdd-checklist-1-3-photokit-read-service.md`
- **API Tests**: `CuratorTests/Infrastructure/PhotoKit/PHAssetMapperTests.swift`
- **API Tests**: `CuratorTests/Infrastructure/PhotoKit/PhotoPermissionManagerTests.swift`
- **API Tests**: `CuratorTests/Infrastructure/PhotoKit/PhotoKitRepositoryTests.swift`
