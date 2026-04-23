---
stepsCompleted:
  - 'step-01-preflight-and-context'
  - 'step-02-generation-mode'
  - 'step-03-test-strategy'
  - 'step-04-generate-tests'
  - 'step-05-validate-and-complete'
lastStep: 'step-05-validate-and-complete'
lastSaved: '2026-04-24'
storyId: '5.1'
storyKey: '5-1-perceptual-hash-engine'
storyFile: '_bmad-output/implementation-artifacts/5-1-perceptual-hash-engine.md'
atddChecklistPath: '_bmad-output/test-artifacts/atdd-checklist-5-1-perceptual-hash-engine.md'
generatedTestFiles:
  - 'CuratorTests/Infrastructure/Analysis/PerceptualHasherTests.swift'
  - 'CuratorTests/Infrastructure/Analysis/HashCacheManagerTests.swift'
inputDocuments:
  - '_bmad-output/implementation-artifacts/5-1-perceptual-hash-engine.md'
  - 'Curator/Core/Errors/DomainError.swift'
  - 'Curator/Core/Models/PhotoAsset.swift'
  - 'Curator/Core/Models/AssetID.swift'
  - 'Curator/Core/Models/AssetMetadata.swift'
  - 'Curator/Core/Models/PhotoLibraryRepository.swift'
  - 'Curator/App/AppDependencies.swift'
  - 'CuratorTests/Infrastructure/PhotoSource/LocalFolderRepositoryTests.swift'
  - 'CuratorTests/Features/ReadOnlyMode/ReadOnlyModeTests.swift'
  - '.claude/skills/bmad-testarch-atdd/resources/knowledge/data-factories.md'
  - '.claude/skills/bmad-testarch-atdd/resources/knowledge/component-tdd.md'
  - '.claude/skills/bmad-testarch-atdd/resources/knowledge/test-quality.md'
  - '.claude/skills/bmad-testarch-atdd/resources/knowledge/test-healing-patterns.md'
  - '.claude/skills/bmad-testarch-atdd/resources/knowledge/test-levels-framework.md'
  - '.claude/skills/bmad-testarch-atdd/resources/knowledge/test-priorities-matrix.md'
---

# ATDD Checklist: Story 5.1 — Perceptual Hash Engine (pHash)

## TDD Red Phase (Current)

All tests use `throw XCTSkip("...")` to mark as RED phase scaffolds. Once activated, they will fail before implementation and pass after implementation.

- **Unit Tests:** 20 tests in PerceptualHasherTests + 5 tests in HashCacheManagerTests (all skipped)
- **Integration Tests:** Included within PerceptualHasherTests (actor + repository interaction)
- **E2E Tests:** N/A (Swift backend, no browser tests)

## Stack Detection

- **Detected Stack:** `backend` (Swift/macOS, XCTest, project.yml, no frontend test framework)
- **Test Framework:** XCTest (native Swift testing)
- **Generation Mode:** AI Generation (backend stack, no browser recording needed)
- **Execution Mode:** Sequential (single agent)

## Acceptance Criteria Coverage

### AC1: Batch pHash Computation Performance (FR19, NFR4)

| # | Test | Priority | Level | Status |
|---|------|----------|-------|--------|
| 1 | `testComputeHashReturnsUInt64` | P0 | Unit | RED |
| 2 | `testBatchComputeHashesPerformance` | P0 | Integration | RED |

### AC2: Single Photo pHash Computation (FR19)

| # | Test | Priority | Level | Status |
|---|------|----------|-------|--------|
| 3 | `testComputeHashReturnsUInt64` | P0 | Unit | RED |
| 4 | `testIdenticalImagesProduceSameHash` | P0 | Unit | RED |
| 5 | `testDifferentImagesHaveHighHammingDistance` | P0 | Unit | RED |

### AC3: Batch Computation Cancellation Support (FR17)

| # | Test | Priority | Level | Status |
|---|------|----------|-------|--------|
| 6 | `testBatchComputeCancellationRetainsResults` | P0 | Integration | RED |

### AC4: Similarity Comparison (Hamming Distance)

| # | Test | Priority | Level | Status |
|---|------|----------|-------|--------|
| 7 | `testHammingDistanceCalculation` | P0 | Unit | RED |
| 8 | `testSimilarImagesHaveLowHammingDistance` | P0 | Unit | RED |
| 9 | `testFindSimilarPairsReturnsCorrectPairs` | P1 | Unit | RED |
| 10 | `testPairwiseSimilarityStructure` | P1 | Unit | RED |

### AC5: Hash Persistence and Cache (NFR5)

| # | Test | Priority | Level | Status |
|---|------|----------|-------|--------|
| 11 | `testHashCachePersistAndLoad` | P1 | Integration | RED |
| 12 | `testHashCacheInvalidation` | P1 | Integration | RED |
| 13 | `testBatchSkipsCachedPhotos` | P1 | Integration | RED |

### AC6: Error Handling and Fault Tolerance (NFR23)

| # | Test | Priority | Level | Status |
|---|------|----------|-------|--------|
| 14 | `testCorruptedImageSkippedGracefully` | P0 | Unit | RED |
| 15 | `testUnsupportedFormatSkippedGracefully` | P1 | Unit | RED |
| 16 | `testEmptyDataThrowsAnalysisFailed` | P1 | Unit | RED |

### Value Type Tests

| # | Test | Priority | Level | Status |
|---|------|----------|-------|--------|
| 17 | `testPerceptualHashValueSendable` | P1 | Unit | RED |
| 18 | `testPerceptualHashValueCodable` | P1 | Unit | RED |
| 19 | `testPairwiseSimilarityComparable` | P1 | Unit | RED |
| 20 | `testPairwiseSimilarityIdentifiable` | P1 | Unit | RED |

### HashCacheManager Tests

| # | Test | Priority | Level | Status |
|---|------|----------|-------|--------|
| 21 | `testLoadCacheReturnsEmptyForNewInstall` | P1 | Unit | RED |
| 22 | `testSaveAndLoadCacheRoundTrip` | P1 | Integration | RED |
| 23 | `testInvalidateCacheRemovesSpecificEntries` | P1 | Unit | RED |
| 24 | `testClearCacheRemovesAllEntries` | P1 | Unit | RED |
| 25 | `testCacheStoredInApplicationSupportDirectory` | P1 | Integration | RED |

---

## Test Strategy

### Test Level Selection

- **Unit:** Pure logic (hamming distance, hash computation on synthetic images, value type conformance)
- **Integration:** Actor + repository interaction (batch compute with mock repository), cache file I/O
- **No E2E:** Backend-only story, no UI involved

### Priority Rationale

- **P0:** Core algorithm correctness (hash computation, hamming distance), performance SLA, cancellation, fault tolerance -- these are the critical path for the feature
- **P1:** Value type conformance, cache persistence, cache invalidation, similar pair finding -- important but secondary to core algorithm

---

## Mock Requirements

### MockPhotoLibraryRepository

A mock `PhotoLibraryRepository` that returns pre-configured image data for testing batch hash computation without real file system access. Pattern follows `MockWriteGrantedRepository` from Story 4.5 tests.

### Test Image Helpers

Synthetic image generation using NSImage/NSBitmapImageRep (pattern from `LocalFolderRepositoryTests.createTestImage`) to create:
- Identical images for same-hash verification
- Visually similar images (slight color shift) for low hamming distance
- Visually different images for high hamming distance
- Corrupted data for error handling tests

---

## Implementation Checklist

### Test: testComputeHashReturnsUInt64 (P0)

**Tasks to make this test pass:**
- [ ] Create `PerceptualHashValue` struct in `Curator/Core/Models/`
- [ ] Create `PerceptualHasherProtocol` in `Curator/Core/Models/`
- [ ] Create `PerceptualHasher` actor in `Curator/Infrastructure/Analysis/`
- [ ] Implement `computeHash(for:)` with DCT-based pHash algorithm
- [ ] Run test: `xcodebuild test -project Curator.xcodeproj -scheme Curator -only-testing:CuratorTests/PerceptualHasherTests/testComputeHashReturnsUInt64`

### Test: testIdenticalImagesProduceSameHash (P0)

**Tasks:**
- [ ] Ensure `computeHash(for:)` is deterministic for same input
- [ ] Run test and verify identical data produces same UInt64 hash

### Test: testSimilarImagesHaveLowHammingDistance (P0)

**Tasks:**
- [ ] Implement pHash algorithm correctly (DCT-based)
- [ ] Verify similar images produce hashes with hamming distance < threshold

### Test: testDifferentImagesHaveHighHammingDistance (P0)

**Tasks:**
- [ ] Verify visually different images produce hashes with hamming distance > threshold

### Test: testHammingDistanceCalculation (P0)

**Tasks:**
- [ ] Implement `PerceptualHashValue.hammingDistance(_:_:)` static method
- [ ] Test with known bit patterns (e.g., 0b0000 vs 0b1111 = distance 4)

### Test: testBatchComputeHashesPerformance (P0)

**Tasks:**
- [ ] Implement `computeHashes(for:repository:)` batch method
- [ ] Support batch processing with Task.isCancelled checks
- [ ] Verify 100 images complete in under 60 seconds

### Test: testBatchComputeCancellationRetainsResults (P0)

**Tasks:**
- [ ] Implement `withTaskCancellationHandler` in batch compute
- [ ] Return already-computed results when cancelled
- [ ] Verify partial results are returned on cancellation

### Test: testCorruptedImageSkippedGracefully (P0)

**Tasks:**
- [ ] Wrap `computeHash(for:)` in try-catch within batch loop
- [ ] Map image decode failures to `DomainError.analysisFailed`
- [ ] Skip failed images, continue processing remaining

### Test: testFindSimilarPairsReturnsCorrectPairs (P1)

**Tasks:**
- [ ] Implement `findSimilarPairs(hashes:threshold:)` method
- [ ] Return `PairwiseSimilarity` list sorted by hamming distance

### Test: testHashCachePersistAndLoad (P1)

**Tasks:**
- [ ] Create `HashCacheManager` in `Curator/Infrastructure/Analysis/`
- [ ] Implement `loadCache()` and `saveCache(_:)` methods
- [ ] Use JSON encoding in Application Support directory

### Test: testHashCacheInvalidation (P1)

**Tasks:**
- [ ] Implement `invalidateCache(for:)` method
- [ ] Remove specified entries from cache file

### Test: testBatchSkipsCachedPhotos (P1)

**Tasks:**
- [ ] Load cache at start of batch compute
- [ ] Filter out already-cached assets
- [ ] Merge new results into cache

---

## Running Tests

```bash
# Run all tests for this story
xcodebuild test -project Curator.xcodeproj -scheme Curator \
  -only-testing:CuratorTests/PerceptualHasherTests \
  -only-testing:CuratorTests/HashCacheManagerTests

# Run specific test
xcodebuild test -project Curator.xcodeproj -scheme Curator \
  -only-testing:CuratorTests/PerceptualHasherTests/testComputeHashReturnsUInt64

# Run all project tests
xcodebuild test -project Curator.xcodeproj -scheme Curator
```

---

## Red-Green-Refactor Workflow

### RED Phase (Complete)

- All tests written as red-phase scaffolds with `throw XCTSkip(...)`
- Mock infrastructure defined (MockPhotoLibraryRepository, test image helpers)
- Implementation checklist created
- Each test documents its acceptance criterion and priority

### GREEN Phase (DEV Team - Next Steps)

1. Pick one P0 test from the implementation checklist
2. Remove `throw XCTSkip(...)` for that test and confirm it fails
3. Read the test to understand expected behavior
4. Implement minimal code to make that specific test pass
5. Run the test to verify it now passes (green)
6. Move to next test and repeat

### REFACTOR Phase

1. Verify all tests pass
2. Review code for quality, readability, performance
3. Extract common patterns (image creation helpers)
4. Ensure Swift 6 strict concurrency compliance
5. Ensure no memory leaks in actor-based implementation

---

## Test Design Quality

- Tests are **deterministic**: Same image data always produces same hash
- Tests are **isolated**: Each test creates its own temp directory and data
- Tests are **explicit**: Assertions clearly state expected behavior
- Tests are **focused**: One primary assertion per test
- Tests use **Given-When-Then** structure with clear comments
- **No hard waits**: Uses async/await, no sleep or timeouts
- **Self-cleaning**: tempDir cleanup via `defer` blocks

---

## Knowledge Base References Applied

- **data-factories.md** — Test image creation patterns (synthetic image generation)
- **test-quality.md** — Deterministic, isolated, explicit, focused tests
- **test-levels-framework.md** — Unit vs integration test level selection
- **test-priorities-matrix.md** — P0/P1 priority assignment rationale
- **test-healing-patterns.md** — Patterns for robust test maintenance

---

## Notes

- PerceptualHasher is an **actor** (not class or struct) for thread safety
- Protocol defined in Domain layer (`Core/Models/`), implementation in Infrastructure (`Infrastructure/Analysis/`)
- All new types are `Sendable` (Swift 6 strict concurrency)
- Uses Apple Accelerate/vImage/vDSP exclusively (no third-party dependencies)
- Default hamming distance threshold: 10 (configurable)
- Cache stored at `Application Support/Curator/phash_cache.json`
- xcodegen auto-discovers new test files via `sources: - CuratorTests` in project.yml

---

**Generated by BMad TEA Agent** — 2026-04-24
