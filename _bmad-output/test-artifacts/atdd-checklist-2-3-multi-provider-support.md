---
stepsCompleted:
  - step-01-preflight-and-context
  - step-02-generation-mode
  - step-03-test-strategy
  - step-04c-aggregate
  - step-05-validate-and-complete
lastStep: step-05-validate-and-complete
lastSaved: '2026-04-19'
storyId: '2.3'
storyKey: 2-3-multi-provider-support
storyFile: _bmad-output/implementation-artifacts/2-3-multi-provider-support.md
atddChecklistPath: _bmad-output/test-artifacts/atdd-checklist-2-3-multi-provider-support.md
generatedTestFiles:
  - CuratorTests/Infrastructure/LLM/OpenAICompatibleProviderTests.swift
  - CuratorTests/Infrastructure/LLM/MultiProviderFailoverTests.swift
  - CuratorTests/Core/Models/LLMConfigMultiProviderTests.swift
inputDocuments:
  - _bmad-output/implementation-artifacts/2-3-multi-provider-support.md
  - _bmad/tea/config.yaml
  - Curator/Infrastructure/LLM/LLMGateway.swift
  - Curator/Infrastructure/LLM/AnthropicProvider.swift
  - Curator/Infrastructure/LLM/LLMModels.swift
  - Curator/Core/Models/LLMProvider.swift
  - Curator/Core/Models/LLMConfig.swift
  - Curator/Core/Models/LLMGatewayProtocol.swift
  - Curator/Core/Models/LLMResponse.swift
  - Curator/Core/Models/CostEstimate.swift
  - Curator/Core/Errors/InfrastructureError.swift
  - Curator/App/AppDependencies.swift
  - CuratorTests/Infrastructure/LLM/LLMGatewayTests.swift
  - CuratorTests/Core/Models/LLMConfigTests.swift
---

# ATDD Checklist: Story 2.3 - Multi-Provider Support

## TDD Red Phase (Current)

Red-phase test scaffolds generated. All tests assert EXPECTED behavior against types/APIs that do not yet exist. Activated tests will FAIL until the feature is implemented.

## Test Strategy

- **Stack:** backend (Swift/XCTest)
- **Generation Mode:** AI Generation (no browser recording needed)
- **Test Levels:** Unit (model types, protocol conformance, request construction), Integration (LLMGateway failover with mock providers), DI (AppDependencies multi-provider registration)

## Acceptance Criteria Coverage

| AC # | Description | Test Scenarios | Priority | Level |
|------|-------------|----------------|----------|-------|
| AC1 | Primary 5xx triggers automatic failover to fallback | 5xx failover, failover within 10s (NFR21) | P0 | Integration |
| AC2 | OpenAICompatibleProvider supports any OpenAI-compatible API | Request URL, Bearer auth, request body, image encoding, text prompt, response parsing, custom base URL, cost estimation | P0/P1 | Unit |
| AC3 | Rate limit handling (429 retry then failover) | 429 retry then failover, retry-after respect, all providers rate limited | P0/P1 | Integration |
| AC3 | 4xx client errors directly failover (no retry) | 401 direct failover without retry | P1 | Integration |
| AC4 | LLMConfig multi-provider config | Primary+fallback storage, save/load, backward compat migration, Codable round-trip | P1 | Unit |
| AC1 | AppDependencies multi-provider registration | Both providers registered, only primary when no fallback | P1 | DI |
| AC2 | LLMModelID OpenAI-compatible models | Model identifiers exist, pricing info | P1 | Unit |

## Generated Test Files

### 1. `CuratorTests/Infrastructure/LLM/OpenAICompatibleProviderTests.swift`
- **Level:** Unit (request construction, response parsing, error mapping)
- **Tests:** 13 tests
- **覆盖:** AC2 (OpenAI Chat Completions API format)
- **优先级:** P0 (4), P1 (9)

### 2. `CuratorTests/Infrastructure/LLM/MultiProviderFailoverTests.swift`
- **Level:** Integration (failover behavior with mock providers), DI (AppDependencies)
- **Tests:** 10 tests
- **覆盖:** AC1 (failover), AC3 (rate limit), AC2 (model IDs)
- **优先级:** P0 (2), P1 (8)

### 3. `CuratorTests/Core/Models/LLMConfigMultiProviderTests.swift`
- **Level:** Unit (model types, Codable, persistence)
- **Tests:** 15 tests
- **覆盖:** AC4 (multi-provider config, backward compatibility)
- **优先级:** P1 (15)

## Summary Statistics

- **Total Tests:** 38
- **P0 Tests:** 6
- **P1 Tests:** 32
- **All tests skipped:** Yes (TDD RED PHASE)
- **Expected to fail:** Yes (types/APIs not yet implemented)
- **Knowledge fragments used:** data-factories, component-tdd, test-quality, test-healing-patterns

## Implementation Guidance

### Types to Create

1. `Curator/Core/Models/LLMProviderConfig.swift` -- Single provider config value type (providerType, baseURL, apiKey, modelID, displayName)
2. `Curator/Core/Models/LLMProviderType.swift` -- Enum: .anthropic, .openAICompatible (String, Codable, Sendable, CaseIterable)
3. `Curator/Infrastructure/LLM/OpenAICompatibleProvider.swift` -- LLMProvider implementation for OpenAI-compatible APIs

### Types to Modify

4. `Curator/Core/Models/LLMConfig.swift` -- Extend from single-provider to primary + fallback multi-provider with backward compat migration
5. `Curator/Infrastructure/LLM/LLMGateway.swift` -- Enhance analyzeWithRetry to distinguish 429 (retry then failover) from 5xx (failover) from 4xx (direct failover)
6. `Curator/Infrastructure/LLM/LLMModels.swift` -- Add gpt-4o, gpt-4o-mini, deepseek-chat model cases with pricing
7. `Curator/App/AppDependencies.swift` -- registerLLMGateway() reads multi-provider config and creates both AnthropicProvider + OpenAICompatibleProvider

## Next Steps (Task-by-Task Activation)

During implementation of each task:

1. Remove `try XCTSkip()` from the current test file or test method
2. Run tests: `xcodebuild test -project Curator.xcodeproj -scheme Curator -destination 'platform=macOS,arch=arm64'`
3. Verify the activated test fails first, then passes after implementation (green phase)
4. If any activated tests still fail unexpectedly:
   - Either fix implementation (feature bug)
   - Or fix test (test bug)
5. Commit passing tests

## Key Risks and Assumptions

1. **OpenAI API Format Compliance:** Tests assume standard OpenAI Chat Completions API format. Provider-specific quirks (e.g., DeepSeek differences) may need additional test coverage in future stories.
2. **Mock Provider Error Types:** Tests use `InfrastructureError` for simulated errors, matching the actual error mapping chain. Real HTTP errors will be mapped by provider implementations.
3. **Backward Compatibility:** Old `LLMConfig` format migration assumes single-provider JSON with `baseURL/apiKey/modelID` keys, auto-migrating to `.anthropic` provider type.
4. **No New Third-Party Dependencies:** All implementations use Foundation only (URLSession + JSONSerialization).
5. **Sendable Compliance:** All new types must conform to Sendable for Swift 6 strict concurrency.
6. **LLMGateway Retry Logic Enhancement:** The failover enhancement changes error handling in `analyzeWithRetry` to differentiate error types. Existing tests should not regress.

## Handoff for dev-story

- **Checklist:** `_bmad-output/test-artifacts/atdd-checklist-2-3-multi-provider-support.md`
- **Test files:**
  - `CuratorTests/Infrastructure/LLM/OpenAICompatibleProviderTests.swift`
  - `CuratorTests/Infrastructure/LLM/MultiProviderFailoverTests.swift`
  - `CuratorTests/Core/Models/LLMConfigMultiProviderTests.swift`
- **Story file:** `_bmad-output/implementation-artifacts/2-3-multi-provider-support.md`
