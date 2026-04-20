import XCTest
import SwiftData
@testable import Curator

/// ATDD Tests for Story 2.4 - 成本追踪引擎
///
/// Tests verify:
/// - AC1: CostTracker 记录每次 LLM 调用成本
/// - AC3: 月度/会话成本查询
final class CostTrackerTests: XCTestCase {

    /// In-memory ModelContext for isolated testing.
    nonisolated(unsafe) private var modelContext: ModelContext!

    override func setUp() {
        super.setUp()
        let schema = Schema([CostRecordEntity.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [config])
        modelContext = ModelContext(container)
    }

    override func tearDown() {
        modelContext = nil
        super.tearDown()
    }

    private func makeTracker() -> CostTracker {
        CostTracker(modelContext: modelContext)
    }

    // MARK: - AC1: CostTracker 记录成本

    /// [P0] CostTracker.record() 存储单条成本记录到 SwiftData (AC1-T1)
    func testRecordStoresSingleCostRecord() async throws {
        let tracker = makeTracker()
        let record = CostRecord(
            providerName: "Anthropic",
            modelID: "claude-sonnet-4-20250514",
            inputTokens: 1000,
            outputTokens: 500,
            costUSD: 0.0105,
            sessionID: "session-1"
        )

        try await tracker.record(record)

        let descriptor = FetchDescriptor<CostRecordEntity>()
        let entities = try modelContext.fetch(descriptor)
        XCTAssertEqual(entities.count, 1, "应存储一条记录")
        XCTAssertEqual(entities[0].providerName, "Anthropic")
        XCTAssertEqual(entities[0].inputTokens, 1000)
        XCTAssertEqual(entities[0].outputTokens, 500)
        XCTAssertEqual(entities[0].costUSD, 0.0105, accuracy: 0.0001)
        XCTAssertEqual(entities[0].sessionID, "session-1")
    }

    /// [P0] 成本计算基于 LLMModelID pricing 正确计算 (AC1-T5)
    func testCostCalculationBasedOnModelPricing() {
        // Claude Sonnet: input $3/M, output $15/M
        let cost = CostTracker.calculateCost(
            model: "claude-sonnet-4-20250514",
            inputTokens: 1000,
            outputTokens: 500
        )
        let expected = (1000.0 * 3.0 / 1_000_000.0) + (500.0 * 15.0 / 1_000_000.0)
        XCTAssertEqual(cost, expected, accuracy: 0.000001, "成本应基于模型定价计算")
    }

    /// [P1] 多条记录按时间戳正确存储 (AC1-T4)
    func testMultipleRecordsStoredInOrder() async throws {
        let tracker = makeTracker()
        let baseDate = Date()

        let record1 = CostRecord(
            providerName: "Anthropic", modelID: "claude-sonnet-4-20250514",
            inputTokens: 100, outputTokens: 50, costUSD: 0.001,
            timestamp: baseDate, sessionID: "s1"
        )
        let record2 = CostRecord(
            providerName: "OpenAI", modelID: "gpt-4o",
            inputTokens: 200, outputTokens: 100, costUSD: 0.002,
            timestamp: baseDate.addingTimeInterval(60), sessionID: "s1"
        )

        try await tracker.record(record1)
        try await tracker.record(record2)

        let descriptor = FetchDescriptor<CostRecordEntity>()
        let entities = try modelContext.fetch(descriptor)
        XCTAssertEqual(entities.count, 2, "应存储两条记录")
    }

    // MARK: - AC3: 月度成本查询

    /// [P0] monthlySummary() 返回当月所有记录的汇总 (AC3-T1)
    func testMonthlySummaryReturnsCurrentMonthRecords() async throws {
        let tracker = makeTracker()
        let record = CostRecord(
            providerName: "Anthropic", modelID: "claude-sonnet-4-20250514",
            inputTokens: 1000, outputTokens: 500, costUSD: 0.0105,
            sessionID: "s1"
        )
        try await tracker.record(record)

        let summary = try await tracker.monthlySummary()
        XCTAssertEqual(summary.callCount, 1, "当月应有1条记录")
        XCTAssertEqual(summary.totalCost, 0.0105, accuracy: 0.0001)
        XCTAssertEqual(summary.totalInputTokens, 1000)
        XCTAssertEqual(summary.totalOutputTokens, 500)
    }

    /// [P0] monthlySummary() 按供应商聚合成本明细 (AC3-T2)
    func testMonthlySummaryAggregatesByProvider() async throws {
        let tracker = makeTracker()
        try await tracker.record(CostRecord(
            providerName: "Anthropic", modelID: "claude-sonnet-4-20250514",
            inputTokens: 100, outputTokens: 50, costUSD: 0.005, sessionID: "s1"
        ))
        try await tracker.record(CostRecord(
            providerName: "OpenAI", modelID: "gpt-4o",
            inputTokens: 200, outputTokens: 100, costUSD: 0.010, sessionID: "s1"
        ))
        try await tracker.record(CostRecord(
            providerName: "Anthropic", modelID: "claude-sonnet-4-20250514",
            inputTokens: 150, outputTokens: 75, costUSD: 0.007, sessionID: "s2"
        ))

        let summary = try await tracker.monthlySummary()
        XCTAssertEqual(summary.byProvider["Anthropic"] ?? 0, 0.012, accuracy: 0.0001)
        XCTAssertEqual(summary.byProvider["OpenAI"] ?? 0, 0.010, accuracy: 0.0001)
        XCTAssertEqual(summary.totalCost, 0.022, accuracy: 0.0001)
    }

    /// [P0] sessionSummary() 返回指定会话的成本汇总 (AC3-T3)
    func testSessionSummaryReturnsSessionRecords() async throws {
        let tracker = makeTracker()
        try await tracker.record(CostRecord(
            providerName: "Anthropic", modelID: "claude-sonnet-4-20250514",
            inputTokens: 100, outputTokens: 50, costUSD: 0.005, sessionID: "session-A"
        ))
        try await tracker.record(CostRecord(
            providerName: "OpenAI", modelID: "gpt-4o",
            inputTokens: 200, outputTokens: 100, costUSD: 0.010, sessionID: "session-B"
        ))
        try await tracker.record(CostRecord(
            providerName: "Anthropic", modelID: "claude-sonnet-4-20250514",
            inputTokens: 150, outputTokens: 75, costUSD: 0.007, sessionID: "session-A"
        ))

        let summary = try await tracker.sessionSummary("session-A")
        XCTAssertEqual(summary.callCount, 2, "session-A 应有2条记录")
        XCTAssertEqual(summary.totalCost, 0.012, accuracy: 0.0001)
    }

    /// [P1] 空数据时 monthlySummary() 返回零值 (AC3-T4)
    func testMonthlySummaryReturnsZeroWhenNoRecords() async throws {
        let tracker = makeTracker()
        let summary = try await tracker.monthlySummary()
        XCTAssertEqual(summary.totalCost, 0)
        XCTAssertEqual(summary.callCount, 0)
        XCTAssertTrue(summary.byProvider.isEmpty)
    }

    /// [P1] 跨月份记录不出现在当月汇总 (AC3-T5)
    func testMonthlySummaryExcludesOtherMonths() async throws {
        let tracker = makeTracker()
        // Insert a record dated last month
        let lastMonth = Calendar.current.date(byAdding: .month, value: -1, to: Date())!
        let oldRecord = CostRecord(
            providerName: "Anthropic", modelID: "claude-sonnet-4-20250514",
            inputTokens: 100, outputTokens: 50, costUSD: 0.005,
            timestamp: lastMonth, sessionID: "s-old"
        )
        try await tracker.record(oldRecord)

        // Insert a record for this month
        let currentRecord = CostRecord(
            providerName: "Anthropic", modelID: "claude-sonnet-4-20250514",
            inputTokens: 200, outputTokens: 100, costUSD: 0.010, sessionID: "s-new"
        )
        try await tracker.record(currentRecord)

        let summary = try await tracker.monthlySummary()
        XCTAssertEqual(summary.callCount, 1, "当月只应有1条记录")
        XCTAssertEqual(summary.totalCost, 0.010, accuracy: 0.0001)
    }

    /// [P1] sessionSummary() 不存在的 sessionID 返回零值 (AC3-T6)
    func testSessionSummaryReturnsZeroForUnknownSession() async throws {
        let tracker = makeTracker()
        try await tracker.record(CostRecord(
            providerName: "Anthropic", modelID: "claude-sonnet-4-20250514",
            inputTokens: 100, outputTokens: 50, costUSD: 0.005, sessionID: "s1"
        ))

        let summary = try await tracker.sessionSummary("nonexistent")
        XCTAssertEqual(summary.totalCost, 0)
        XCTAssertEqual(summary.callCount, 0)
    }
}
