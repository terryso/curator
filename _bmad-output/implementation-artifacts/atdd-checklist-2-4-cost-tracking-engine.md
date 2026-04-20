---
stepsCompleted: ['step-01-preflight-and-context', 'step-02-generation-mode', 'step-03-test-strategy', 'step-04-generate-tests']
lastStep: 'step-04-generate-tests'
lastSaved: '2026-04-20'
storyId: '2.4'
storyKey: '2-4-cost-tracking-engine'
storyFile: '_bmad-output/implementation-artifacts/2-4-cost-tracking-engine.md'
atddChecklistPath: '_bmad-output/implementation-artifacts/atdd-checklist-2-4-cost-tracking-engine.md'
generatedTestFiles:
  - 'CuratorTests/Infrastructure/LLM/CostTrackerTests.swift'
  - 'CuratorTests/Infrastructure/LLM/CostTrackerIntegrationTests.swift'
  - 'CuratorTests/Core/Models/CostRecordTests.swift'
inputDocuments:
  - '_bmad-output/implementation-artifacts/2-4-cost-tracking-engine.md'
  - 'Curator/Infrastructure/LLM/LLMGateway.swift'
  - 'Curator/Core/Models/CostEstimate.swift'
  - 'Curator/Core/Models/LLMResponse.swift'
  - 'Curator/Infrastructure/LLM/LLMModels.swift'
detected_stack: backend
generation_mode: ai-generation
---

# ATDD Checklist: Story 2.4 — 成本追踪引擎

## Stack Detection

- **Detected Stack**: `backend` (Swift/macOS, XCTest)
- **Test Framework**: XCTest
- **Generation Mode**: AI Generation (standard scenarios, clear acceptance criteria)

## Test Strategy

### Test Levels

| Level | Usage | Rationale |
|-------|-------|-----------|
| Unit | CostRecord/CostSummary 值类型、成本计算逻辑 | 纯函数，快速验证 |
| Integration | CostTracker + SwiftData、LLMGateway + CostTracker 集成 | 验证持久化和跨组件协作 |

### Priority Matrix

| Priority | Criteria | Coverage Target |
|----------|----------|-----------------|
| P0 | 阻塞核心流程 — 成本记录、月度汇总、LLMGateway 集成 | 100% |
| P1 | 重要边界条件 — 空数据、跨月隔离、费用预估增强 | 80% |
| P2 | 次要场景 — 未知模型定价、高并发记录 | 50% |

## Acceptance Criteria → Test Mapping

### AC1: CostTracker 记录每次 LLM 调用成本（FR47）

| ID | Test Scenario | Level | Priority | Red Phase |
|----|---------------|-------|----------|-----------|
| AC1-T1 | CostTracker.record() 存储单条成本记录到 SwiftData | Integration | P0 | XCTSkip |
| AC1-T2 | 记录包含正确的 providerName, modelID, tokens, costUSD | Unit | P0 | XCTSkip |
| AC1-T3 | LLMGateway 成功调用后自动通过 CostTracker 记录成本 | Integration | P0 | XCTSkip |
| AC1-T4 | 多条记录按时间戳正确存储 | Integration | P1 | XCTSkip |
| AC1-T5 | 成本计算基于 LLMModelID pricing 正确计算 | Unit | P0 | XCTSkip |

### AC2: 费用预估计算（FR46）

| ID | Test Scenario | Level | Priority | Red Phase |
|----|---------------|-------|----------|-----------|
| AC2-T1 | CostEstimate 包含 estimatedAPICalls 和 currency 字段 | Unit | P1 | XCTSkip |
| AC2-T2 | estimateCost 基于照片数量和模型返回正确预估 | Unit | P0 | XCTSkip |
| AC2-T3 | 未知模型使用默认保守估算 | Unit | P2 | XCTSkip |

### AC3: 月度成本查询（FR47）

| ID | Test Scenario | Level | Priority | Red Phase |
|----|---------------|-------|----------|-----------|
| AC3-T1 | monthlySummary() 返回当月所有记录的汇总 | Integration | P0 | XCTSkip |
| AC3-T2 | monthlySummary() 按供应商聚合成本明细 | Integration | P0 | XCTSkip |
| AC3-T3 | sessionSummary() 返回指定会话的成本汇总 | Integration | P0 | XCTSkip |
| AC3-T4 | 空数据时 monthlySummary() 返回零值 | Unit | P1 | XCTSkip |
| AC3-T5 | 跨月份记录不出现在当月汇总 | Integration | P1 | XCTSkip |
| AC3-T6 | sessionSummary() 不存在的 sessionID 返回零值 | Unit | P1 | XCTSkip |

## Generated Test Files

1. **CostTrackerTests.swift** — CostTracker actor 单元/集成测试（AC1, AC3）
2. **CostTrackerIntegrationTests.swift** — LLMGateway + CostTracker 集成测试（AC1-T3）
3. **CostRecordTests.swift** — CostRecord/CostSummary 值类型测试（AC1-T2, AC1-T5）

## TDD Red Phase Compliance

- [x] All tests use `throw XCTSkip()` — will be activated during dev-story
- [x] All tests assert EXPECTED behavior (not current behavior)
- [x] Activated tests will FAIL until feature is implemented
- [x] No active passing tests generated
