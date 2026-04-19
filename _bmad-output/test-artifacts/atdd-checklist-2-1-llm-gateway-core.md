---
stepsCompleted:
  - step-01-preflight-and-context
  - step-02-generation-mode
  - step-03-test-strategy
  - step-04-generate-tests
storyId: '2.1'
storyKey: '2-1-llm-gateway-core'
storyFile: '_bmad-output/implementation-artifacts/2-1-llm-gateway-core.md'
atddChecklistPath: '_bmad-output/test-artifacts/atdd-checklist-2-1-llm-gateway-core.md'
generatedTestFiles:
  - CuratorTests/Infrastructure/LLM/LLMGatewayTests.swift
inputDocuments:
  - _bmad-output/implementation-artifacts/2-1-llm-gateway-core.md
  - Curator/Core/Models/LLMProvider.swift
  - Curator/Core/Models/LLMResponse.swift
  - Curator/Core/Models/CostEstimate.swift
  - Curator/Core/Errors/InfrastructureError.swift
  - Curator/Core/Errors/ErrorMapping.swift
  - Curator/App/AppDependencies.swift
lastStep: step-04-generate-tests
lastSaved: '2026-04-19'
---

# ATDD Checklist: Story 2-1 LLM Gateway Core

## Stack Detection

- **Type:** Backend (Swift/macOS, XCTest)
- **Framework:** XCTest via Xcode (xcodegen project.yml auto-discovery)

## Generation Mode

- **Mode:** AI Generation (backend — no browser recording)

## Test Strategy

| AC | Test Level | Priority | Test Scenario |
|----|-----------|----------|---------------|
| AC1 | Unit | P0 | LLMGatewayProtocol exists with analyze/estimateCost |
| AC1 | Unit | P0 | LLMGateway actor instantiable with provider list |
| AC1 | Unit | P0 | LLMGateway is actor (compile-time) |
| AC1 | Unit | P1 | LLMGateway conforms to LLMGatewayProtocol |
| AC1 | Unit | P0 | LLMProvider protocol has analyze() method |
| AC1 | Unit | P0 | LLMProvider protocol has estimateCost() method |
| AC1 | Unit | P0 | LLMResponse has modelID field |
| AC1 | Unit | P0 | LLMResponse has providerName field |
| AC1 | Unit | P1 | LLMResponse has token usage fields |
| AC1 | Unit | P0 | CostEstimate has modelID field |
| AC1 | Unit | P0 | CostEstimate has providerName field |
| AC1 | Unit | P0 | Gateway delegates analyze() to primary |
| AC1 | Unit | P0 | Gateway delegates estimateCost() to primary |
| AC2 | Unit | P1 | AnthropicProvider constructs correct URL |
| AC2 | Unit | P1 | AnthropicProvider sets required headers |
| AC2 | Unit | P1 | AnthropicProvider constructs JSON body |
| AC2 | Unit | P1 | AnthropicProvider encodes images as base64 |
| AC2 | Unit | P1 | AnthropicProvider parses successful response |
| AC2 | Unit | P1 | AnthropicProvider maps HTTP errors |
| AC2 | Unit | P1 | AnthropicProvider estimates cost |
| AC2 | Unit | P1 | LLMModelID defines Claude models |
| AC2 | Unit | P1 | LLMModelID has pricing information |
| AC3 | Unit | P0 | Gateway fails over to backup provider |
| AC3 | Unit | P0 | Gateway throws when all providers fail |
| AC3 | Unit | P0 | Gateway retries primary 3 times before failover |
| AC3 | Unit | P0 | Gateway succeeds when provider recovers |
| AC3 | Unit | P1 | Gateway failover completes within 10s (NFR21) |
| AC3 | Unit | P1 | AnthropicProvider handles 429 rate limit |
| AC1 | Unit | P1 | LLMResponse conforms to Sendable |
| AC1 | Unit | P1 | CostEstimate conforms to Sendable |
| AC1 | Unit | P1 | InfrastructureError conforms to Sendable |
| AC1 | Integration | P1 | AppDependencies registers LLMGateway |

## Test File

`CuratorTests/Infrastructure/LLM/LLMGatewayTests.swift`

## Coverage Summary

- **Total test methods:** 32
- **P0 tests:** 15
- **P1 tests:** 17
- **AC coverage:** AC1 (16 tests), AC2 (8 tests), AC3 (5 tests), Cross-cutting (3 tests)

## Red Phase Verification

All tests will fail at compile time until these types are created:

1. `LLMGatewayProtocol` (Core/Models/) — new protocol
2. `LLMGateway` actor (Infrastructure/LLM/) — new actor
3. `AnthropicProvider` (Infrastructure/LLM/) — new class
4. `LLMModelID` enum (Infrastructure/LLM/) — new enum with pricing
5. `LLMResponse` extended fields: `modelID`, `providerName`, `inputTokens`, `outputTokens`
6. `CostEstimate` extended fields: `modelID`, `providerName`
7. `URLSessionProtocol` (in AnthropicProvider or test helpers) — protocol for testability
8. `AppDependencies.llmGateway` property

## Implementation Dependencies (Must Exist for Tests to Compile)

### Domain Layer (Core/Models/)

| File | Change |
|------|--------|
| `LLMResponse.swift` | Add `modelID`, `providerName`, `inputTokens`, `outputTokens` fields |
| `CostEstimate.swift` | Add `modelID`, `providerName` fields |
| `LLMGatewayProtocol.swift` | New file: protocol with `analyze()` and `estimateCost()` |

### Infrastructure Layer (Infrastructure/LLM/)

| File | Change |
|------|--------|
| `LLMGateway.swift` | New file: actor implementing LLMGatewayProtocol |
| `AnthropicProvider.swift` | New file: class implementing LLMProvider |
| `LLMModels.swift` | New file: `LLMModelID` enum with pricing |

### App Layer (App/)

| File | Change |
|------|--------|
| `AppDependencies.swift` | Add `llmGateway` property |
