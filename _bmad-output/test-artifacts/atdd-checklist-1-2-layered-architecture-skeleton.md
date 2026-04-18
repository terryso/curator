---
stepsCompleted:
  - 'step-01-preflight-and-context'
  - 'step-02-generation-mode'
  - 'step-03-test-strategy'
  - 'step-04c-aggregate'
  - 'step-05-validate-and-complete'
lastStep: 'step-05-validate-and-complete'
lastSaved: '2026-04-18'
storyId: '1.2'
storyKey: '1-2-layered-architecture-skeleton'
storyFile: '_bmad-output/implementation-artifacts/1-2-layered-architecture-skeleton.md'
atddChecklistPath: '_bmad-output/test-artifacts/atdd-checklist-1-2-layered-architecture-skeleton.md'
generatedTestFiles:
  - 'CuratorTests/Core/Errors/ErrorTypeTests.swift'
  - 'CuratorTests/Core/Models/CoreModelsTests.swift'
  - 'CuratorTests/DependencyInjectionTests.swift'
inputDocuments:
  - '_bmad-output/implementation-artifacts/1-2-layered-architecture-skeleton.md'
  - '_bmad-output/planning-artifacts/architecture.md'
  - '.claude/skills/bmad-testarch-atdd/resources/knowledge/data-factories.md'
  - '.claude/skills/bmad-testarch-atdd/resources/knowledge/component-tdd.md'
  - '.claude/skills/bmad-testarch-atdd/resources/knowledge/test-quality.md'
  - '.claude/skills/bmad-testarch-atdd/resources/knowledge/test-healing-patterns.md'
  - '.claude/skills/bmad-testarch-atdd/resources/knowledge/test-levels-framework.md'
  - '.claude/skills/bmad-testarch-atdd/resources/knowledge/test-priorities-matrix.md'
---

# ATDD Checklist - Epic 1, Story 1.2: 分层架构骨架

**Date:** 2026-04-18
**Author:** Nick
**Primary Test Level:** Unit (type existence, conformance, value semantics)

---

## Story Summary

本 Story 建立分层架构的 Domain 层和 Application 层核心骨架，包括：错误类型体系（DomainError、InfrastructureError、UserFacingError 及跨层映射）、领域模型（PhotoAsset、AssetMetadata、AssetID、LoadingState<T>）、以及依赖注入容器（AppDependencies + PhotoLibraryRepository/LLMProvider 协议）。

**As a** 开发者
**I want** 建立分层架构的基础类型和错误体系
**So that** 后续功能模块可以遵循一致的架构模式开发

---

## Acceptance Criteria

| AC # | Criterion | Status |
|------|-----------|--------|
| AC1  | 错误类型体系：DomainError、InfrastructureError、UserFacingError 枚举已定义，映射规则完整 | RED |
| AC2  | 领域模型：PhotoAsset、AssetMetadata 值类型（Sendable）、LoadingState<T> 已定义 | RED |
| AC3  | 依赖注入容器：AppDependencies 提供协议到具体实现绑定，支持 mock 替换 | RED |

---

## TDD Red Phase (Current)

### Test Scaffolds Generated: 3 files, 43 test methods

All tests are RED phase -- they will fail to compile until the feature types are implemented.

| File | Tests | AC Coverage | Priority Spread |
|------|-------|-------------|-----------------|
| `CuratorTests/Core/Errors/ErrorTypeTests.swift` | 17 | AC1 | P0: 8, P1: 9 |
| `CuratorTests/Core/Models/CoreModelsTests.swift` | 14 | AC2 | P0: 8, P1: 6 |
| `CuratorTests/DependencyInjectionTests.swift` | 12 | AC3 | P0: 7, P1: 5 |

---

## Acceptance Criteria Coverage Matrix

### AC1: 错误类型体系

| Test ID | Test Method | Priority | What It Verifies |
|---------|-------------|----------|------------------|
| AC1-T01 | `testDomainErrorConformsToError` | P0 | DomainError has all required cases and conforms to Error |
| AC1-T02 | `testDomainErrorAssetNotFoundCarriesAssetID` | P0 | assetNotFound case carries AssetID |
| AC1-T03 | `testDomainErrorAnalysisFailedCarriesReason` | P0 | analysisFailed case carries reason string |
| AC1-T04 | `testDomainErrorInsufficientPermissionCarriesLevel` | P1 | insufficientPermission carries PermissionLevel |
| AC1-T05 | `testDomainErrorOperationCancelledExists` | P1 | operationCancelled case exists |
| AC1-T06 | `testDomainErrorInvalidStateCarriesReason` | P1 | invalidState carries reason string |
| AC1-T07 | `testInfrastructureErrorConformsToError` | P0 | InfrastructureError has all required cases |
| AC1-T08 | `testInfrastructureErrorPhotoKitAccessDenied` | P0 | photoKitAccessDenied case exists |
| AC1-T09 | `testInfrastructureErrorLLMProviderErrorCarriesDetails` | P1 | llmProviderError carries provider/statusCode/message |
| AC1-T10 | `testInfrastructureErrorRateLimitExceededCarriesRetryAfter` | P1 | rateLimitExceeded carries retryAfter interval |
| AC1-T11 | `testUserFacingErrorExistsWithRequiredCases` | P0 | UserFacingError has readOnly/retryable/permissionRequired |
| AC1-T12 | `testUserFacingErrorReadOnlyCarriesTitleAndMessage` | P1 | readOnly carries title and message |
| AC1-T13 | `testUserFacingErrorPermissionRequiredCarriesAction` | P1 | permissionRequired carries title and action |
| AC1-T14 | `testInfrastructureErrorMapsToDomainError` | P0 | Infrastructure -> Domain error mapping exists |
| AC1-T15 | `testDomainErrorMapsToUserFacingError` | P0 | Domain -> UserFacing error mapping exists |
| AC1-T16 | `testErrorMappingNeverExposesTechnicalDetails` | P1 | No technical strings in user-facing errors |
| AC1-T17 | `testPhotoKitAccessDeniedMapsCorrectly` | P1 | photoKitAccessDenied -> insufficientPermission |

### AC2: 领域模型

| Test ID | Test Method | Priority | What It Verifies |
|---------|-------------|----------|------------------|
| AC2-T01 | `testAssetIDExistsWithRawValue` | P0 | AssetID wraps rawValue string |
| AC2-T02 | `testAssetIDIsHashable` | P0 | AssetID is Hashable (Set/Dict usable) |
| AC2-T03 | `testAssetIDIsCodable` | P1 | AssetID is Codable (JSON round-trip) |
| AC2-T04 | `testLocationDataExistsWithCoordinates` | P1 | LocationData stores lat/long |
| AC2-T05 | `testAssetMetadataExistsWithAllFields` | P0 | AssetMetadata has date/title/desc/keywords/location |
| AC2-T06 | `testAssetMetadataAllowsNilOptionals` | P1 | All optional fields can be nil |
| AC2-T07 | `testPhotoAssetExistsAsValueType` | P0 | PhotoAsset struct with id/metadata/thumbnailData |
| AC2-T08 | `testPhotoAssetIsIdentifiable` | P0 | PhotoAsset conforms to Identifiable |
| AC2-T09 | `testPhotoAssetSupportsThumbnailData` | P1 | PhotoAsset carries optional thumbnail Data |
| AC2-T10 | `testLoadingStateIdleCase` | P0 | LoadingState<T>.idle exists |
| AC2-T11 | `testLoadingStateLoadingCase` | P0 | LoadingState<T>.loading exists |
| AC2-T12 | `testLoadingStateLoadedCase` | P0 | LoadingState<T>.loaded(T) carries value |
| AC2-T13 | `testLoadingStateFailedCase` | P0 | LoadingState<T>.failed(DomainError) carries error |
| AC2-T14 | `testLoadingStateGenericOverDifferentTypes` | P1 | LoadingState works with different generic types |

### AC3: 依赖注入容器

| Test ID | Test Method | Priority | What It Verifies |
|---------|-------------|----------|------------------|
| AC3-T01 | `testAppDependenciesCanBeInstantiated` | P0 | AppDependencies can be created on MainActor |
| AC3-T02 | `testAppDependenciesIsObservableObject` | P0 | Conforms to ObservableObject |
| AC3-T03 | `testAppDependenciesHasPhotoRepositoryProperty` | P0 | Has optional photoRepository |
| AC3-T04 | `testAppDependenciesHasLLMProviderProperty` | P0 | Has optional llmProvider |
| AC3-T05 | `testPhotoLibraryRepositoryProtocolExists` | P0 | PhotoLibraryRepository protocol is defined |
| AC3-T06 | `testPhotoLibraryRepositoryHasRequestReadAccess` | P1 | Protocol has requestReadAccess() async throws -> Bool |
| AC3-T07 | `testPhotoLibraryRepositoryHasRequestWriteAccess` | P1 | Protocol has requestWriteAccess() async throws -> Bool |
| AC3-T08 | `testLLMProviderProtocolExists` | P0 | LLMProvider protocol is defined |
| AC3-T09 | `testLLMProviderHasNameProperty` | P1 | Protocol has name: String { get } |
| AC3-T10 | `testAppDependenciesSupportsMockPhotoRepository` | P0 | photoRepository replaceable with mock |
| AC3-T11 | `testAppDependenciesSupportsMockLLMProvider` | P0 | llmProvider replaceable with mock |
| AC3-T12 | `testReplacedMockPhotoRepoIsCallable` | P1 | Replaced mock is callable through protocol |

---

## Types to Implement (Red Phase Checklist)

The following types must be created for tests to compile. Each is listed with its expected file location.

### Error Types (Core/Errors/)

- [ ] `DomainError` enum (Error) -- assetNotFound, analysisFailed, insufficientPermission, operationCancelled, invalidState
- [ ] `InfrastructureError` enum (Error) -- photoKitAccessDenied, photoKitFetchFailed, llmProviderUnavailable, llmProviderError, networkError, rateLimitExceeded, keychainError, cacheError
- [ ] `UserFacingError` enum -- readOnly, retryable, permissionRequired
- [ ] `ErrorMapping` extension -- `InfrastructureError.toDomainError()`, `DomainError.toUserFacingError()`
- [ ] `PermissionLevel` enum -- read, write (minimum)

### Domain Models (Core/Models/)

- [ ] `AssetID` struct (Sendable, Hashable, Codable) -- rawValue: String
- [ ] `LocationData` struct (Sendable) -- latitude: Double, longitude: Double
- [ ] `AssetMetadata` struct (Sendable) -- creationDate, title, description, keywords, location
- [ ] `PhotoAsset` struct (Sendable, Identifiable) -- id: AssetID, metadata: AssetMetadata, thumbnailData: Data?
- [ ] `LoadingState<T>` enum -- idle, loading, loaded(T), failed(DomainError)

### Protocols (Core/Models/)

- [ ] `PhotoLibraryRepository` protocol (Sendable) -- requestReadAccess, requestWriteAccess, fetchAssets, fetchFullResolutionImage
- [ ] `LLMProvider` protocol (Sendable) -- name, analyze, estimateCost
- [ ] `PhotoPredicate` type (for fetchAssets)
- [ ] `AssetPage` type (for fetchAssets)
- [ ] `LLMResponse` type (for analyze)
- [ ] `CostEstimate` type (for estimateCost)

### DI Container (App/)

- [ ] `AppDependencies` class (@MainActor, ObservableObject) -- photoRepository, llmProvider

---

## Implementation Guidance

### Files to Create/Modify

```
Curator/
├── App/
│   └── AppDependencies.swift          # Rewrite: DI container
├── Core/
│   ├── Errors/
│   │   ├── DomainError.swift          # New
│   │   ├── InfrastructureError.swift  # New
│   │   ├── UserFacingError.swift      # New
│   │   └── ErrorMapping.swift         # New
│   ├── Models/
│   │   ├── AssetID.swift              # New
│   │   ├── AssetMetadata.swift        # New (includes LocationData)
│   │   ├── PhotoAsset.swift           # New
│   │   ├── LoadingState.swift         # New
│   │   ├── PhotoLibraryRepository.swift  # New (protocol)
│   │   └── LLMProvider.swift          # New (protocol)
│   └── Extensions/
│       └── LoadableState.swift        # New (LoadingState SwiftUI extension)
```

### Key Constraints

1. Swift 6 strict concurrency: ALL types must be Sendable
2. Domain layer has zero dependencies on other layers
3. Never name a type `Task` (Swift Concurrency conflict)
4. Error mapping: Infrastructure -> Domain -> UserFacing (never skip layers)
5. Never expose technical error messages to users

---

## Next Steps (Task-by-Task Activation)

During implementation of each task:

1. Implement the types listed above in the specified file locations
2. Run tests: `xcodebuild test -scheme Curator -destination 'platform=macOS,arch=arm64'`
3. Verify tests transition from compile errors (RED) to passing (GREEN)
4. Ensure Story 1.1's 4 existing tests still pass (no regression)
5. Commit passing tests

---

## Regression Note

Story 1.1 established 4 ATDD tests that must continue to pass:
- `BuildConfigurationTests` (1 test)
- `SPMDependencyTests` (2 tests)
- `EntitlementsTests` (1 test)
- `DirectoryStructureTests` (1 test)

Total existing tests: 5. After this story: 5 (existing) + 43 (new) = 48 tests expected.
