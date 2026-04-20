import XCTest
@testable import Curator

/// ATDD Unit Tests for Story 2.4 - CostRecord 和 CostSummary 值类型
///
/// Tests verify:
/// - AC1: CostRecord 包含正确字段
/// - AC2: CostEstimate 增强字段
final class CostRecordTests: XCTestCase {

    // MARK: - AC1: CostRecord 值类型

    /// [P0] 记录包含正确的 providerName, modelID, tokens, costUSD (AC1-T2)
    func testCostRecordContainsCorrectFields() {
        let id = UUID()
        let now = Date()
        let record = CostRecord(
            id: id,
            providerName: "Anthropic",
            modelID: "claude-sonnet-4-20250514",
            inputTokens: 1000,
            outputTokens: 500,
            costUSD: 0.0105,
            timestamp: now,
            sessionID: "session-1"
        )

        XCTAssertEqual(record.id, id)
        XCTAssertEqual(record.providerName, "Anthropic")
        XCTAssertEqual(record.modelID, "claude-sonnet-4-20250514")
        XCTAssertEqual(record.inputTokens, 1000)
        XCTAssertEqual(record.outputTokens, 500)
        XCTAssertEqual(record.costUSD, 0.0105)
        XCTAssertEqual(record.timestamp, now)
        XCTAssertEqual(record.sessionID, "session-1")
    }

    /// [P0] 成本计算基于 LLMModelID pricing 正确计算 (AC1-T5)
    func testCostCalculationWithKnownModelPricing() {
        // Claude Haiku: input $0.80/M, output $4.0/M
        let cost = CostTracker.calculateCost(
            model: "claude-haiku-4-20250506",
            inputTokens: 2000,
            outputTokens: 1000
        )
        let expected = (2000.0 * 0.80 / 1_000_000.0) + (1000.0 * 4.0 / 1_000_000.0)
        XCTAssertEqual(cost, expected, accuracy: 0.000001)
    }

    // MARK: - AC2: CostEstimate 增强

    /// [P1] CostEstimate 包含 estimatedAPICalls 和 currency 字段 (AC2-T1)
    func testCostEstimateContainsEnhancedFields() {
        let estimate = CostEstimate(
            estimatedTokens: 5000,
            estimatedCost: 0.05,
            modelID: "claude-sonnet-4-20250514",
            providerName: "Anthropic",
            estimatedAPICalls: 3,
            currency: "USD"
        )
        XCTAssertEqual(estimate.estimatedAPICalls, 3)
        XCTAssertEqual(estimate.currency, "USD")
    }

    /// [P1] CostSummary 聚合计算正确
    func testCostSummaryAggregation() {
        let summary = CostSummary(
            totalCost: 0.05,
            totalInputTokens: 5000,
            totalOutputTokens: 2500,
            callCount: 5,
            byProvider: ["Anthropic": 0.03, "OpenAI": 0.02],
            bySession: ["s1": 0.05],
            dateRange: nil
        )
        XCTAssertEqual(summary.totalCost, 0.05)
        XCTAssertEqual(summary.callCount, 5)
        XCTAssertEqual(summary.byProvider["Anthropic"], 0.03)
        XCTAssertEqual(summary.byProvider["OpenAI"], 0.02)
    }

    /// [P1] CostSummary.zero 返回空值汇总
    func testCostSummaryZero() {
        let zero = CostSummary.zero
        XCTAssertEqual(zero.totalCost, 0)
        XCTAssertEqual(zero.callCount, 0)
        XCTAssertTrue(zero.byProvider.isEmpty)
        XCTAssertTrue(zero.bySession.isEmpty)
    }
}
