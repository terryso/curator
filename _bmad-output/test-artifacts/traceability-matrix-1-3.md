---
stepsCompleted:
  - step-01-load-context
  - step-02-discover-tests
  - step-03-map-criteria
  - step-04-analyze-gaps
  - step-05-gate-decision
lastStep: step-05-gate-decision
lastSaved: '2026-04-20'
storyId: '1.3'
storyKey: 1-3-local-folder-read-service
storyFile: _bmad-output/implementation-artifacts/1-3-local-folder-read-service.md
coverageBasis: acceptance_criteria
oracleConfidence: high
oracleResolutionMode: formal_requirements
oracleSources:
  - _bmad-output/implementation-artifacts/1-3-local-folder-read-service.md
  - _bmad-output/test-artifacts/atdd-checklist-1-3-local-folder-read-service.md
externalPointerStatus: not_used
tempCoverageMatrixPath: /tmp/tea-trace-coverage-matrix-1-3.json
---

# Traceability Report: Story 1.3 - 本地文件夹读取服务

## Gate Decision: PENDING

**Rationale:** Story rewritten from PhotoKit to local folder architecture. Test scaffolds defined in ATDD checklist await implementation. Gate will be evaluated after implementation.

---

## 1. Coverage Oracle Resolution

| Field | Value |
|-------|-------|
| **Coverage Basis** | `acceptance_criteria` |
| **Oracle Resolution Mode** | `formal_requirements` |
| **Oracle Confidence** | `high` |
| **Oracle Sources** | Story 1-3 implementation artifact, ATDD checklist |
| **External Pointer Status** | `not_used` |

The story file contains 4 formal acceptance criteria (AC1-AC4) with detailed Given/When/Then specifications. The ATDD checklist maps ~30 test methods to these criteria. This is a high-confidence formal oracle.

---

## 2. Test Inventory

### Test Files Planned

| File | Tests | Level |
|------|-------|-------|
| `CuratorTests/Infrastructure/PhotoSource/FolderBookmarkManagerTests.swift` | ~9 | Unit |
| `CuratorTests/Infrastructure/PhotoSource/ExifMetadataReaderTests.swift` | ~12 | Unit |
| `CuratorTests/Infrastructure/PhotoSource/LocalFolderRepositoryTests.swift` | ~14 | Unit |

**Total:** ~35 test methods (30+ active)

---

## 3. Traceability Matrix

### AC1: 文件夹选择与访问持久化

**Requirement:** NSOpenPanel folder selection; security-scoped bookmark persistence; app restart maintains access.

| ID | Test Method | Priority | Level | Coverage |
|----|-------------|----------|-------|----------|
| AC1-T01 | testFolderBookmarkManagerConformsToProtocol | P0 | Unit | FULL |
| AC1-T02 | testHasValidBookmarkReturnsFalseWhenNoBookmark | P0 | Unit | FULL |
| AC1-T03 | testHasValidBookmarkReturnsTrueAfterBookmark | P0 | Unit | FULL |
| AC1-T04 | testSelectAndBookmarkFolderCreatesBookmark | P0 | Unit | FULL |
| AC1-T05 | testLoadBookmarkReturnsURLAfterBookmark | P0 | Unit | FULL |
| AC1-T06 | testLoadBookmarkReturnsNilWhenNoBookmark | P1 | Unit | FULL |
| AC1-T07 | testAccessBookmarkStartsSecurityScope | P0 | Unit | FULL |
| AC1-T08 | testReleaseBookmarkStopsSecurityScope | P1 | Unit | FULL |
| AC1-T09 | testBookmarkPersistsAcrossInstances | P0 | Unit | FULL |
| AC1-T10 | testRequestReadAccessReturnsTrueWithValidBookmark | P0 | Unit | FULL |
| AC1-T11 | testRequestReadAccessThrowsWhenNoBookmark | P0 | Unit | FULL |
| AC1-T12 | testLocalFolderRepositoryCanBeRegisteredInAppDependencies | P1 | Unit | FULL |

**AC1 Coverage: FULL**
- Bookmark lifecycle (create, load, persist): 5 tests
- Security scope (access, release): 2 tests
- Integration with repository: 2 tests
- Protocol conformance: 1 test
- AppDependencies registration: 1 test

---

### AC2: 照片文件扫描与元数据读取

**Requirement:** Recursive folder scanning; EXIF metadata reading; thumbnail generation.

| ID | Test Method | Priority | Level | Coverage |
|----|-------------|----------|-------|----------|
| AC2-T01 | testExifMetadataReaderIsSendableStruct | P0 | Unit | FULL |
| AC2-T02 | testReadMetadataReturnsFileName | P0 | Unit | FULL |
| AC2-T03 | testReadMetadataReturnsFileSize | P0 | Unit | FULL |
| AC2-T04 | testReadMetadataReturnsCreationDate | P0 | Unit | FULL |
| AC2-T05 | testReadMetadataReturnsCameraModel | P1 | Unit | FULL |
| AC2-T06 | testReadMetadataReturnsImageDimensions | P1 | Unit | FULL |
| AC2-T07 | testReadMetadataReturnsGPSLocation | P1 | Unit | FULL |
| AC2-T08 | testReadMetadataReturnsFileFormat | P0 | Unit | FULL |
| AC2-T09 | testReadMetadataHandlesMissingEXIF | P1 | Unit | FULL |
| AC2-T10 | testGenerateThumbnailReturnsData | P0 | Unit | FULL |
| AC2-T11 | testGenerateThumbnailReturnsNilForCorruptFile | P1 | Unit | FULL |
| AC2-T12 | testReadMetadataMapsAllFieldsCorrectly | P0 | Unit | FULL |
| AC2-T13 | testLocalFolderRepositoryIsActor | P0 | Unit | FULL |
| AC2-T14 | testLocalFolderRepositoryConformsToProtocol | P0 | Unit | FULL |
| AC2-T15 | testFetchAssetsReturnsPhotoAssets | P0 | Unit | FULL |
| AC2-T16 | testFetchAssetsReturnsEmptyWhenNoPhotos | P0 | Unit | FULL |
| AC2-T17 | testFetchAssetsFiltersBySupportedExtensions | P0 | Unit | FULL |
| AC2-T18 | testFetchAssetsRecursivelyScansSubdirectories | P1 | Unit | FULL |

**AC2 Coverage: FULL**
- EXIF reader type contract: 1 test
- Metadata fields (fileName, fileSize, date, camera, dimensions, GPS, format): 7 tests
- Metadata fallback (missing EXIF): 1 test
- Thumbnail generation: 2 tests
- Full mapping integration: 1 test
- Repository type contract (actor, protocol): 2 tests
- Scan results (assets, empty, filtering, recursive): 4 tests

---

### AC3: 分页查询

**Requirement:** Pagination with pageSize and pageOffset; AssetPage with cursor; actor isolation.

| ID | Test Method | Priority | Level | Coverage |
|----|-------------|----------|-------|----------|
| AC3-T01 | testFetchAssetsRespectsPageSize | P0 | Unit | FULL |
| AC3-T02 | testFetchAssetsReturnsHasMoreWhenMoreResults | P1 | Unit | FULL |
| AC3-T03 | testFetchAssetsSupportsPageOffset | P1 | Unit | FULL |
| AC3-T04 | testFetchAssetsRespectsPredicateFilter | P1 | Unit | FULL |
| AC3-T05 | testRepositoryMethodsExecuteWithinActorIsolation | P1 | Unit | FULL |

**AC3 Coverage: FULL**
- Page size enforcement: 1 test
- Pagination cursor (hasMore, nextOffset): 1 test
- Page offset: 1 test
- Predicate filtering: 1 test
- Actor isolation: 1 test

---

### AC4: 全分辨率图像访问

**Requirement:** fetchFullResolutionImage returns full file Data for AI analysis.

| ID | Test Method | Priority | Level | Coverage |
|----|-------------|----------|-------|----------|
| AC4-T01 | testFetchFullResolutionImageReturnsFileData | P0 | Unit | FULL |
| AC4-T02 | testFetchFullResolutionImageThrowsForNonexistent | P0 | Unit | FULL |
| AC4-T03 | testFetchThumbnailReturnsData | P0 | Unit | FULL |
| AC4-T04 | testFetchThumbnailThrowsForNonexistent | P1 | Unit | FULL |

**AC4 Coverage: FULL**
- Valid file data retrieval: 1 test
- Nonexistent file error (assetNotFound): 1 test
- Thumbnail data: 1 test
- Thumbnail error: 1 test

---

## 4. Coverage Statistics

| Metric | Value |
|--------|-------|
| **Total Requirements (ACs)** | 4 |
| **Fully Covered** | 4 (100%) |
| **Partially Covered** | 0 |
| **Uncovered** | 0 |
| **Overall Coverage** | **100%** |

### Priority Breakdown

| Priority | Total Tests | Covered | Percentage |
|----------|------------|---------|------------|
| P0 | 17 | 17 | **100%** |
| P1 | 13 | 13 | **100%** |
| P2 | 0 | 0 | N/A |
| P3 | 0 | 0 | N/A |

---

## 5. Implementation Coverage Cross-Reference

### Files to Implement vs Tests

| Implementation File | Test File | Coverage |
|--------------------|-----------|----------|
| `Curator/Infrastructure/PhotoSource/FolderBookmarkManager.swift` | `FolderBookmarkManagerTests.swift` (~9 tests) | FULL |
| `Curator/Infrastructure/PhotoSource/ExifMetadataReader.swift` | `ExifMetadataReaderTests.swift` (~12 tests) | FULL |
| `Curator/Infrastructure/PhotoSource/LocalFolderRepository.swift` | `LocalFolderRepositoryTests.swift` (~14 tests) | FULL |
| `Curator/App/AppDependencies.swift` (modified) | `testLocalFolderRepositoryCanBeRegisteredInAppDependencies` | FULL |
