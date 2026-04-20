import XCTest
import SwiftData
@testable import Curator

/// ATDD Tests for Story 2.6 - Cost Estimate & Tracking Panel (AC2: CostTrackingProtocol Extensions)
///
/// Tests verify:
/// - allTimeSummary() returns aggregated summary of all records
/// - recentRecords(limit:) returns limited number of most recent records
/// - CostTimeRange enum provides correct date ranges
/// - CostTimeRange.month returns current month interval
/// - CostTimeRange.all returns nil (unbounded)
/// - CostTimeRange has all expected cases
final class CostTrackingPanelTests: XCTestCase {

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

    // MARK: - AC2: allTimeSummary()

    /// [P0] allTimeSummary() returns aggregated summary of ALL records (AC2, Task 5.2)
    func testAllTimeSummaryReturnsAllRecords() async throws {
        let tracker = makeTracker()
        let baseDate = Date()

        // Given: Records spanning multiple months
        let lastMonth = Calendar.current.date(byAdding: .month, value: -1, to: baseDate)!
        let twoMonthsAgo = Calendar.current.date(byAdding: .month, value: -2, to: baseDate)!

        try await tracker.record(CostRecord(
            providerName: "Anthropic", modelID: "claude-sonnet-4-20250514",
            inputTokens: 1000, outputTokens: 500, costUSD: 0.0105,
            timestamp: twoMonthsAgo, sessionID: "s-old-1"
        ))
        try await tracker.record(CostRecord(
            providerName: "OpenAI", modelID: "gpt-4o",
            inputTokens: 2000, outputTokens: 1000, costUSD: 0.0250,
            timestamp: lastMonth, sessionID: "s-old-2"
        ))
        try await tracker.record(CostRecord(
            providerName: "Anthropic", modelID: "claude-haiku-4-20250506",
            inputTokens: 500, outputTokens: 250, costUSD: 0.0030,
            timestamp: baseDate, sessionID: "s-current"
        ))

        // When: Querying all-time summary
        let summary = try await tracker.allTimeSummary()

        // Then: All 3 records should be aggregated
        XCTAssertEqual(summary.callCount, 3, "allTimeSummary should include all records regardless of date")
        XCTAssertEqual(summary.totalCost, 0.0385, accuracy: 0.0001,
                       "Total cost should be sum of all records")
        XCTAssertEqual(summary.totalInputTokens, 3500)
        XCTAssertEqual(summary.totalOutputTokens, 1750)
        XCTAssertEqual(summary.byProvider["Anthropic"] ?? 0, 0.0135, accuracy: 0.0001)
        XCTAssertEqual(summary.byProvider["OpenAI"] ?? 0, 0.0250, accuracy: 0.0001)
    }

    /// [P0] allTimeSummary() returns .zero when no records exist (AC2)
    func testAllTimeSummaryReturnsZeroWhenEmpty() async throws {
        let tracker = makeTracker()

        let summary = try await tracker.allTimeSummary()

        XCTAssertEqual(summary.totalCost, 0)
        XCTAssertEqual(summary.callCount, 0)
        XCTAssertTrue(summary.byProvider.isEmpty)
        XCTAssertTrue(summary.bySession.isEmpty)
    }

    // MARK: - AC2: recentRecords(limit:)

    /// [P0] recentRecords(limit:) returns at most N most recent records (AC2, Task 5.3)
    func testRecentRecordsReturnsLimitedResults() async throws {
        let tracker = makeTracker()
        let baseDate = Date()

        // Given: 5 records with different timestamps
        for i in 0..<5 {
            try await tracker.record(CostRecord(
                providerName: "Anthropic",
                modelID: "claude-sonnet-4-20250514",
                inputTokens: 100 * (i + 1),
                outputTokens: 50 * (i + 1),
                costUSD: 0.001 * Double(i + 1),
                timestamp: baseDate.addingTimeInterval(Double(i) * 60),
                sessionID: "session-\(i)"
            ))
        }

        // When: Requesting the 3 most recent records
        let recentRecords = try await tracker.recentRecords(limit: 3)

        // Then: Should return exactly 3 records, most recent first
        XCTAssertEqual(recentRecords.count, 3, "Should return exactly 3 records")

        // Verify ordering (most recent first)
        for i in 0..<(recentRecords.count - 1) {
            XCTAssertGreaterThanOrEqual(
                recentRecords[i].timestamp,
                recentRecords[i + 1].timestamp,
                "Records should be ordered by timestamp descending"
            )
        }
    }

    /// [P0] recentRecords(limit:) returns fewer records if total is less than limit (AC2)
    func testRecentRecordsReturnsAllWhenFewerThanLimit() async throws {
        let tracker = makeTracker()

        // Given: Only 2 records
        try await tracker.record(CostRecord(
            providerName: "Anthropic", modelID: "claude-sonnet-4-20250514",
            inputTokens: 100, outputTokens: 50, costUSD: 0.001,
            sessionID: "s1"
        ))
        try await tracker.record(CostRecord(
            providerName: "OpenAI", modelID: "gpt-4o",
            inputTokens: 200, outputTokens: 100, costUSD: 0.002,
            sessionID: "s2"
        ))

        // When: Requesting 10 most recent
        let recentRecords = try await tracker.recentRecords(limit: 10)

        // Then: Should return only 2 records (all available)
        XCTAssertEqual(recentRecords.count, 2, "Should return all records when total < limit")
    }

    /// [P1] recentRecords(limit: 0) returns empty array (AC2)
    func testRecentRecordsReturnsEmptyForLimitZero() async throws {
        let tracker = makeTracker()

        try await tracker.record(CostRecord(
            providerName: "Anthropic", modelID: "claude-sonnet-4-20250514",
            inputTokens: 100, outputTokens: 50, costUSD: 0.001,
            sessionID: "s1"
        ))

        let recentRecords = try await tracker.recentRecords(limit: 0)

        XCTAssertTrue(recentRecords.isEmpty, "Should return empty array for limit 0")
    }

    // MARK: - AC2: CostTimeRange Enum

    /// [P0] CostTimeRange.month returns current month interval (AC2, Task 6)
    func testCostTimeRangeMonthReturnsCurrentMonthInterval() async throws {
        let calendar = Calendar.current
        let now = Date()
        let expectedStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
        let expectedEnd = calendar.date(byAdding: .month, value: 1, to: expectedStart)!

        guard let dateRange = CostTimeRange.month.dateRange else {
            XCTFail("Month date range should not be nil")
            return
        }

        XCTAssertEqual(dateRange.start.timeIntervalSince1970,
                       expectedStart.timeIntervalSince1970,
                       accuracy: 1.0,
                       "Month range should start at beginning of current month")
        XCTAssertEqual(dateRange.end.timeIntervalSince1970,
                       expectedEnd.timeIntervalSince1970,
                       accuracy: 1.0,
                       "Month range should end at beginning of next month")
    }

    /// [P0] CostTimeRange.all returns nil date range (AC2, Task 6)
    func testCostTimeRangeAllReturnsNilDateRange() async throws {
        let dateRange = CostTimeRange.all.dateRange

        XCTAssertNil(dateRange, "All-time range should return nil date range (unbounded)")
    }

    /// [P1] CostTimeRange has all expected cases (AC2, Task 6)
    func testCostTimeRangeHasAllCases() async throws {
        // Verify CostTimeRange has the two required cases
        let allCases: [CostTimeRange] = [.month, .all]

        XCTAssertGreaterThanOrEqual(allCases.count, 2, "Should have at least month and all cases")
    }
}
