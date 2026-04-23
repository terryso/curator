---
stepsCompleted: ['step-01-preflight-and-context', 'step-02-generation-mode', 'step-03-test-strategy', 'step-04-generate-tests', 'step-04c-aggregate']
lastStep: 'step-04c-aggregate'
lastSaved: '2026-04-24'
storyId: '5.2'
storyKey: '5-2-image-analysis-pipeline'
storyFile: '_bmad-output/implementation-artifacts/5-2-image-analysis-pipeline.md'
atddChecklistPath: '_bmad-output/test-artifacts/atdd-checklist-5-2-image-analysis-pipeline.md'
generatedTestFiles:
  - 'CuratorTests/Infrastructure/Analysis/ImageAnalysisPipelineTests.swift'
  - 'CuratorTests/Infrastructure/Analysis/ThumbnailGeneratorTests.swift'
---

# ATDD Checklist: Story 5.2 — Image Analysis Pipeline

## TDD Red Phase (Current)

Red-phase test scaffolds generated. All tests use `XCTSkipIf(true)` to skip until implementation is complete.

- **Unit/Integration Tests:** 16 tests (all skipped)
  - ImageAnalysisPipelineTests: 11 tests
  - ThumbnailGeneratorTests: 5 tests

## Acceptance Criteria Coverage

| AC | Description | Tests | Priority |
|----|-------------|-------|----------|
| AC1 | Two-stage analysis flow (FR20) | testTwoStageAnalysisProducesDuplicateGroups, testLLMConfirmationFiltersFalsePositives, testConnectedComponentClustering, testProgressHandlerReportsStages | P0/P1 |
| AC2 | Thumbnail generation (FR21) | testThumbnailGenerationForDuplicateGroups, testGenerateThumbnailReturnsJPEGData, testBatchGenerateThumbnailsForMultipleAssets, testThumbnailSizeIsReasonable | P0 |
| AC3 | LLM match reason (FR20, FR21) | testDuplicateGroupContainsReason, testSimilarityScoreOrdering | P0/P1 |
| AC4 | Cancellation support (FR17) | testAnalysisCancellationRetainsResults | P0 |
| AC5 | Error handling and fault tolerance (NFR23) | testLLMFailureSkipsGroupGracefully, testThumbnailGenerationHandlesCorruptImage, testBatchThumbnailGenerationSkipsCorruptImages | P0/P1 |
| AC6 | Memory control (NFR6) | testThumbnailSizeIsReasonable, testDuplicateGroupSendableAndIdentifiable, testDuplicateGroupStatusCases, testAnalysisProgressFields, testAnalysisStageCases | P1 |

## Test Details

### ImageAnalysisPipelineTests.swift (11 tests)

| # | Test Method | AC | Priority | Level |
|---|-------------|----|----------|-------|
| 1 | testTwoStageAnalysisProducesDuplicateGroups | AC1 | P0 | Integration |
| 2 | testLLMConfirmationFiltersFalsePositives | AC1, AC5 | P0 | Integration |
| 3 | testDuplicateGroupContainsReason | AC3 | P0 | Integration |
| 4 | testAnalysisCancellationRetainsResults | AC4 | P0 | Integration |
| 5 | testLLMFailureSkipsGroupGracefully | AC5 | P0 | Integration |
| 6 | testConnectedComponentClustering | AC1 | P1 | Unit |
| 7 | testProgressHandlerReportsStages | AC1 | P1 | Integration |
| 8 | testSimilarityScoreOrdering | AC3 | P1 | Integration |
| 9 | testThumbnailGenerationForDuplicateGroups | AC2 | P0 | Integration |
| 10 | testDuplicateGroupSendableAndIdentifiable | AC6 | P1 | Unit |
| 11 | testDuplicateGroupStatusCases | AC6 | P1 | Unit |
| 12 | testAnalysisProgressFields | AC1 | P1 | Unit |
| 13 | testAnalysisStageCases | AC1 | P1 | Unit |

### ThumbnailGeneratorTests.swift (5 tests)

| # | Test Method | AC | Priority | Level |
|---|-------------|----|----------|-------|
| 1 | testGenerateThumbnailReturnsJPEGData | AC2 | P0 | Unit |
| 2 | testBatchGenerateThumbnailsForMultipleAssets | AC2 | P0 | Unit |
| 3 | testThumbnailSizeIsReasonable | AC2, AC6 | P0 | Unit |
| 4 | testThumbnailGenerationHandlesCorruptImage | AC5 | P1 | Unit |
| 5 | testBatchThumbnailGenerationSkipsCorruptImages | AC5 | P1 | Unit |

## Mock Infrastructure

The following mock types are defined within test files:

- **MockAnalysisPerceptualHasher** — Returns pre-configured similar pairs (in ImageAnalysisPipelineTests.swift)
- **MockAnalysisLLMGateway** — Returns pre-configured LLM responses with optional delay and per-call failure (in ImageAnalysisPipelineTests.swift)
- **MockAnalysisThumbnailGenerator** — Returns fixed thumbnail data (in ImageAnalysisPipelineTests.swift)
- **MockAnalysisTestRepository** — Returns synthetic JPEG images (in ImageAnalysisPipelineTests.swift)
- **MockThumbnailTestRepository** — Returns valid JPEG images (in ThumbnailGeneratorTests.swift)
- **MockThumbnailCorruptRepository** — Returns invalid data (in ThumbnailGeneratorTests.swift)
- **MockThumbnailMixedRepository** — Returns invalid data for specific assetIDs (in ThumbnailGeneratorTests.swift)

## Next Steps (Task-by-Task Activation)

During implementation of each task:

1. Implement the required types: `DuplicateGroup`, `DuplicateGroupStatus`, `AnalysisProgress`, `AnalysisStage`, `ThumbnailGeneratorProtocol`, `ImageAnalysisPipelineProtocol`
2. Implement `ThumbnailGenerator` actor
3. Implement `ImageAnalysisPipeline` actor
4. Remove `XCTSkipIf(true, ...)` from the relevant test
5. Run tests: `xcodebuild test` or `swift build`
6. Verify the activated test fails first (confirms red phase), then passes after implementation (green phase)
7. Commit passing tests

## Implementation Guidance

### New Files to Create (Source)

1. `Curator/Core/Models/DuplicateGroup.swift` — Value type for duplicate groups
2. `Curator/Core/Models/AnalysisProgress.swift` — Progress reporting value type
3. `Curator/Core/Models/ImageAnalysisPipelineProtocol.swift` — Pipeline protocol
4. `Curator/Core/Models/ThumbnailGeneratorProtocol.swift` — Thumbnail protocol
5. `Curator/Infrastructure/Analysis/ImageAnalysisPipeline.swift` — Pipeline actor
6. `Curator/Infrastructure/Analysis/ThumbnailGenerator.swift` — Thumbnail actor

### Files to Modify

1. `Curator/App/AppDependencies.swift` — Add `imageAnalysisPipeline` and `thumbnailGenerator` properties

### Types Referenced from Story 5.1 (Reuse)

- `PerceptualHasherProtocol`, `PerceptualHasher`, `PerceptualHashValue`, `PairwiseSimilarity`, `HashCacheManager`
- `LLMGatewayProtocol`, `LLMGateway`, `LLMResponse`
- `PhotoLibraryRepository`, `PhotoAsset`, `AssetID`, `DomainError`
