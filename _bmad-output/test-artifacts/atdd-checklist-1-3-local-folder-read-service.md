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
storyId: '1.3'
storyKey: 1-3-local-folder-read-service
storyFile: _bmad-output/implementation-artifacts/1-3-local-folder-read-service.md
atddChecklistPath: _bmad-output/test-artifacts/atdd-checklist-1-3-local-folder-read-service.md
generatedTestFiles:
  - CuratorTests/Infrastructure/PhotoSource/FolderBookmarkManagerTests.swift
  - CuratorTests/Infrastructure/PhotoSource/ExifMetadataReaderTests.swift
  - CuratorTests/Infrastructure/PhotoSource/LocalFolderRepositoryTests.swift
---

# ATDD Checklist: Story 1.3 - 本地文件夹读取服务

## TDD Red Phase (Current)

RED-phase test scaffolds generated. All tests reference types that do not exist yet
(FolderBookmarkManager, ExifMetadataReader, LocalFolderRepository). Build will fail until
implementation is complete. This is intentional (TDD red phase).

- **Unit Tests**: ~30 test methods across 3 test files (all XCTSkip red-phase)
- **E2E Tests**: N/A (backend Swift project, no browser testing)
- **Build Status**: FAILS (expected -- types not implemented yet)

## Acceptance Criteria Coverage

### AC1: 文件夹选择与访问持久化

| Test File | Test Method | Priority | Status |
|-----------|-------------|----------|--------|
| FolderBookmarkManagerTests | testFolderBookmarkManagerConformsToProtocol | P0 | RED |
| FolderBookmarkManagerTests | testHasValidBookmarkReturnsFalseWhenNoBookmark | P0 | RED |
| FolderBookmarkManagerTests | testHasValidBookmarkReturnsTrueAfterBookmark | P0 | RED |
| FolderBookmarkManagerTests | testSelectAndBookmarkFolderCreatesBookmark | P0 | RED |
| FolderBookmarkManagerTests | testLoadBookmarkReturnsURLAfterBookmark | P0 | RED |
| FolderBookmarkManagerTests | testLoadBookmarkReturnsNilWhenNoBookmark | P1 | RED |
| FolderBookmarkManagerTests | testAccessBookmarkStartsSecurityScope | P0 | RED |
| FolderBookmarkManagerTests | testReleaseBookmarkStopsSecurityScope | P1 | RED |
| FolderBookmarkManagerTests | testBookmarkPersistsAcrossInstances | P0 | RED |
| LocalFolderRepositoryTests | testRequestReadAccessReturnsTrueWithValidBookmark | P0 | RED |
| LocalFolderRepositoryTests | testRequestReadAccessThrowsWhenNoBookmark | P0 | RED |
| LocalFolderRepositoryTests | testLocalFolderRepositoryCanBeRegisteredInAppDependencies | P1 | RED |

### AC2: 照片文件扫描与元数据读取

| Test File | Test Method | Priority | Status |
|-----------|-------------|----------|--------|
| ExifMetadataReaderTests | testExifMetadataReaderIsSendableStruct | P0 | RED |
| ExifMetadataReaderTests | testReadMetadataReturnsFileName | P0 | RED |
| ExifMetadataReaderTests | testReadMetadataReturnsFileSize | P0 | RED |
| ExifMetadataReaderTests | testReadMetadataReturnsCreationDate | P0 | RED |
| ExifMetadataReaderTests | testReadMetadataReturnsCameraModel | P1 | RED |
| ExifMetadataReaderTests | testReadMetadataReturnsImageDimensions | P1 | RED |
| ExifMetadataReaderTests | testReadMetadataReturnsGPSLocation | P1 | RED |
| ExifMetadataReaderTests | testReadMetadataReturnsFileFormat | P0 | RED |
| ExifMetadataReaderTests | testReadMetadataHandlesMissingEXIF | P1 | RED |
| ExifMetadataReaderTests | testGenerateThumbnailReturnsData | P0 | RED |
| ExifMetadataReaderTests | testGenerateThumbnailReturnsNilForCorruptFile | P1 | RED |
| LocalFolderRepositoryTests | testLocalFolderRepositoryIsActor | P0 | RED |
| LocalFolderRepositoryTests | testLocalFolderRepositoryConformsToProtocol | P0 | RED |
| LocalFolderRepositoryTests | testFetchAssetsReturnsPhotoAssets | P0 | RED |
| LocalFolderRepositoryTests | testFetchAssetsReturnsEmptyWhenNoPhotos | P0 | RED |
| LocalFolderRepositoryTests | testFetchAssetsFiltersBySupportedExtensions | P0 | RED |
| LocalFolderRepositoryTests | testFetchAssetsRecursivelyScansSubdirectories | P1 | RED |
| ExifMetadataReaderTests | testReadMetadataMapsAllFieldsCorrectly | P0 | RED |

### AC3: 分页查询

| Test File | Test Method | Priority | Status |
|-----------|-------------|----------|--------|
| LocalFolderRepositoryTests | testFetchAssetsRespectsPageSize | P0 | RED |
| LocalFolderRepositoryTests | testFetchAssetsReturnsHasMoreWhenMoreResults | P1 | RED |
| LocalFolderRepositoryTests | testFetchAssetsSupportsPageOffset | P1 | RED |
| LocalFolderRepositoryTests | testFetchAssetsRespectsPredicateFilter | P1 | RED |
| LocalFolderRepositoryTests | testRepositoryMethodsExecuteWithinActorIsolation | P1 | RED |

### AC4: 全分辨率图像访问

| Test File | Test Method | Priority | Status |
|-----------|-------------|----------|--------|
| LocalFolderRepositoryTests | testFetchFullResolutionImageReturnsFileData | P0 | RED |
| LocalFolderRepositoryTests | testFetchFullResolutionImageThrowsForNonexistent | P0 | RED |
| LocalFolderRepositoryTests | testFetchThumbnailReturnsData | P0 | RED |
| LocalFolderRepositoryTests | testFetchThumbnailThrowsForNonexistent | P1 | RED |

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

1. **Task 1: Implement FolderBookmarkManager** (AC1)
   - Create `Curator/Infrastructure/PhotoSource/FolderBookmarkManager.swift`
   - Remove `XCTSkip()` from FolderBookmarkManagerTests
   - Run tests: `xcodebuild test -scheme Curator -destination 'platform=macOS,arch=arm64' -only-testing:CuratorTests/FolderBookmarkManagerTests`
   - Verify tests pass (GREEN phase)

2. **Task 2: Implement ExifMetadataReader** (AC2)
   - Create `Curator/Infrastructure/PhotoSource/ExifMetadataReader.swift`
   - Remove `XCTSkip()` from ExifMetadataReaderTests
   - Run tests: `xcodebuild test -scheme Curator -destination 'platform=macOS,arch=arm64' -only-testing:CuratorTests/ExifMetadataReaderTests`
   - Verify tests pass (GREEN phase)

3. **Task 3: Implement LocalFolderRepository actor** (AC1, AC2, AC3, AC4)
   - Create `Curator/Infrastructure/PhotoSource/LocalFolderRepository.swift`
   - Remove `XCTSkip()` from LocalFolderRepositoryTests
   - Run tests: `xcodebuild test -scheme Curator -destination 'platform=macOS,arch=arm64' -only-testing:CuratorTests/LocalFolderRepositoryTests`
   - Verify tests pass (GREEN phase)

4. **Task 4: Register in AppDependencies** (AC1, AC2)
   - Update `Curator/App/AppDependencies.swift`
   - Run all tests to confirm no regression

## Implementation Guidance

### Types to Implement

1. **FolderBookmarkManager** (struct, FolderBookmarkManaging, @unchecked Sendable)
   - `var hasValidBookmark: Bool { get async }`
   - `var currentFolderURL: URL? { get async }`
   - `func selectAndBookmarkFolder() async throws -> URL`
   - `func loadBookmark() async throws -> URL?`
   - `func accessBookmark(_ url: URL) throws -> Bool`
   - `func releaseBookmark(_ url: URL)`

2. **ExifMetadataReader** (struct, Sendable)
   - `static func readMetadata(from url: URL) -> AssetMetadata`
   - `static func generateThumbnail(from url: URL, targetSize: CGSize) -> Data?`

3. **LocalFolderRepository** (actor, PhotoLibraryRepository)
   - `func requestReadAccess() async throws -> Bool`
   - `func requestWriteAccess() async throws -> Bool`
   - `func fetchAssets(predicate:pageSize:pageOffset:) async throws -> AssetPage`
   - `func fetchFullResolutionImage(for:) async throws -> Data`
   - `func fetchThumbnail(for:size:) async throws -> Data`
   - `func observeSourceChanges() -> AsyncStream<SourceChange>`

### Execution Commands

```bash
# Run all tests
xcodebuild test -scheme Curator -destination 'platform=macOS,arch=arm64'

# Run specific test file
xcodebuild test -scheme Curator -destination 'platform=macOS,arch=arm64' -only-testing:CuratorTests/FolderBookmarkManagerTests

# Build only (check compilation)
xcodebuild build -scheme Curator -destination 'platform=macOS,arch=arm64'
```

## Key Risks and Assumptions

1. **NSOpenPanel in tests**: NSOpenPanel requires UI context. FolderBookmarkManager tests will mock the NSOpenPanel interaction by testing bookmark persistence/recovery independently from the panel itself.
2. **Security-scoped bookmark testing**: Bookmarks created in test context may behave differently than in sandboxed app. Tests focus on the data flow (bookmark creation → storage → recovery → access).
3. **EXIF data variability**: Test photos created programmatically may lack full EXIF data. Tests should handle missing metadata gracefully and verify the fallback to file attributes.
4. **RAW file support**: RAW format support depends on system codecs. Tests should use common formats (JPEG, PNG, HEIC) and note RAW as environment-dependent.
5. **Actor isolation**: Thread safety tests are structural (compile-time verification) rather than runtime.
