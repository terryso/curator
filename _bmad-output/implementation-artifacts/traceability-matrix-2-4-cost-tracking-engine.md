---
stepsCompleted: ['step-01-load-context', 'step-02-discover-tests', 'step-03-trace', 'step-04-gate']
lastStep: 'step-04-gate'
lastSaved: '2026-04-20'
coverageBasis: 'acceptance_criteria'
oracleConfidence: 'high'
oracleResolutionMode: 'formal_requirements'
oracleSources: ['_bmad-output/implementation-artifacts/2-4-cost-tracking-engine.md']
externalPointerStatus: 'not_used'
---

# Traceability Matrix: Story 2.4 — 成本追踪引擎

## Coverage Oracle

- **Basis:** Acceptance Criteria from Story 2-4
- **Confidence:** High — 3 ACs with clear BDD criteria
- **Resolution:** Formal requirements from story file

## Traceability Matrix

| AC | Requirement | Test(s) | File | Priority | Status |
|----|-------------|---------|------|----------|--------|
| AC1 | CostTracker 记录每次 LLM 调用成本 | testRecordStoresSingleCostRecord | CostTrackerTests.swift | P0 | ✅ PASS |
| AC1 | 记录包含正确字段 | testCostRecordContainsCorrectFields | CostRecordTests.swift | P0 | ✅ PASS |
| AC1 | LLMGateway 成功调用后自动记录 | testLLMGatewayRecordsCostAfterSuccessfulCall | CostTrackerIntegrationTests.swift | P0 | ✅ PASS |
| AC1 | 多条记录按时间戳存储 | testMultipleRecordsStoredInOrder | CostTrackerTests.swift | P1 | ✅ PASS |
| AC1 | 成本计算基于 LLMModelID pricing | testCostCalculationBasedOnModelPricing | CostTrackerTests.swift | P0 | ✅ PASS |
| AC1 | 成本计算多模型验证 | testCostCalculationWithKnownModelPricing | CostRecordTests.swift | P0 | ✅ PASS |
| AC2 | CostEstimate 包含 estimatedAPICalls 和 currency | testCostEstimateContainsEnhancedFields | CostRecordTests.swift | P1 | ✅ PASS |
| AC2 | estimateCost 返回正确预估 | testEstimateCostReturnsCorrectEstimate | CostTrackerIntegrationTests.swift | P0 | ✅ PASS |
| AC2 | 未知模型默认估算 | testEstimateCostUsesDefaultForUnknownModel | CostTrackerIntegrationTests.swift | P2 | ✅ PASS |
| AC3 | monthlySummary 返回当月汇总 | testMonthlySummaryReturnsCurrentMonthRecords | CostTrackerTests.swift | P0 | ✅ PASS |
| AC3 | monthlySummary 按供应商聚合 | testMonthlySummaryAggregatesByProvider | CostTrackerTests.swift | P0 | ✅ PASS |
| AC3 | sessionSummary 返回会话汇总 | testSessionSummaryReturnsSessionRecords | CostTrackerTests.swift | P0 | ✅ PASS |
| AC3 | 空数据返回零值 | testMonthlySummaryReturnsZeroWhenNoRecords | CostTrackerTests.swift | P1 | ✅ PASS |
| AC3 | 跨月份记录隔离 | testMonthlySummaryExcludesOtherMonths | CostTrackerTests.swift | P1 | ✅ PASS |
| AC3 | 不存在 sessionID 返回零值 | testSessionSummaryReturnsZeroForUnknownSession | CostTrackerTests.swift | P1 | ✅ PASS |
| — | LLMGateway 失败不记录成本 | testLLMGatewayDoesNotRecordCostOnFailure | CostTrackerIntegrationTests.swift | P1 | ✅ PASS |
| — | LLMGateway 故障转移后记录成功供应商 | testLLMGatewayRecordsCostAfterFailover | CostTrackerIntegrationTests.swift | P1 | ✅ PASS |
| — | CostSummary 聚合计算 | testCostSummaryAggregation | CostRecordTests.swift | P1 | ✅ PASS |
| — | CostSummary.zero | testCostSummaryZero | CostRecordTests.swift | P1 | ✅ PASS |

## Coverage Summary

- **Total ACs:** 3
- **Total Test Cases:** 19 (direct) + 325 (regression)
- **P0 Tests:** 9 — all pass
- **P1 Tests:** 8 — all pass
- **P2 Tests:** 2 — all pass
- **AC Coverage:** 100% (3/3 ACs fully covered)

## Quality Gate Decision

### Gate: ✅ PASS

**Rationale:**
- All 3 acceptance criteria have P0 test coverage
- 19 direct tests + 325 regression tests pass with 0 failures
- AC1 (成本记录): 6 tests covering record storage, field correctness, LLMGateway integration, cost calculation
- AC2 (费用预估): 3 tests covering enhanced fields, correct estimation, unknown model fallback
- AC3 (月度查询): 6 tests covering monthly/session summary, aggregation, zero values, cross-month isolation
- 2 additional negative/edge tests (failure recording, failover recording)

**Confidence:** High — no gaps in AC coverage, edge cases tested.
