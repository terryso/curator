import Foundation
import SwiftData

/// Cost tracker for LLM API calls, using SwiftData for persistence.
///
/// Records individual call costs and provides aggregated summaries by month
/// and by session. Uses `@unchecked Sendable` because `ModelContext` is
/// MainActor-isolated in SwiftData — all mutations go through the shared
/// context created on the main actor during app startup.
final class CostTracker: CostTrackerProtocol, @unchecked Sendable {

    /// The SwiftData model context for persisting cost records.
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - CostTrackerProtocol

    /// Records a completed LLM call's cost to SwiftData.
    func record(_ record: CostRecord) async throws {
        let entity = CostRecordEntity(
            id: record.id,
            providerName: record.providerName,
            modelID: record.modelID,
            inputTokens: record.inputTokens,
            outputTokens: record.outputTokens,
            costUSD: record.costUSD,
            timestamp: record.timestamp,
            sessionID: record.sessionID
        )
        modelContext.insert(entity)
        try modelContext.save()
    }

    /// Returns the cost summary for the current calendar month.
    func monthlySummary() async throws -> CostSummary {
        let calendar = Calendar.current
        let now = Date()
        guard let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) else {
            return .zero
        }
        guard let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth) else {
            return .zero
        }

        let descriptor = FetchDescriptor<CostRecordEntity>(
            predicate: #Predicate { $0.timestamp >= startOfMonth && $0.timestamp < endOfMonth }
        )
        let records = try modelContext.fetch(descriptor)
        return buildSummary(from: records, start: startOfMonth, end: endOfMonth)
    }

    /// Returns the cost summary for a specific session.
    func sessionSummary(_ sessionID: String) async throws -> CostSummary {
        let descriptor = FetchDescriptor<CostRecordEntity>(
            predicate: #Predicate { $0.sessionID == sessionID }
        )
        let records = try modelContext.fetch(descriptor)

        if let first = records.min(by: { $0.timestamp < $1.timestamp }),
           let last = records.max(by: { $0.timestamp < $1.timestamp }) {
            return buildSummary(from: records, start: first.timestamp, end: last.timestamp)
        }
        return .zero
    }

    // MARK: - Story 2.6 Extensions

    /// Returns the aggregated cost summary for all recorded calls (all time).
    func allTimeSummary() async throws -> CostSummary {
        let descriptor = FetchDescriptor<CostRecordEntity>(
            sortBy: [SortDescriptor(\.timestamp, order: .forward)]
        )
        let records = try modelContext.fetch(descriptor)

        if let first = records.min(by: { $0.timestamp < $1.timestamp }),
           let last = records.max(by: { $0.timestamp < $1.timestamp }) {
            return buildSummary(from: records, start: first.timestamp, end: last.timestamp)
        }
        return .zero
    }

    /// Returns the most recent cost records, ordered by timestamp descending.
    ///
    /// When `limit` is 0, returns an empty array. Otherwise returns at most
    /// `limit` records sorted by timestamp descending (most recent first).
    func recentRecords(limit: Int) async throws -> [CostRecord] {
        // Edge case: limit 0 means return nothing
        guard limit > 0 else { return [] }

        var descriptor = FetchDescriptor<CostRecordEntity>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        let entities = try modelContext.fetch(descriptor)

        return entities.map { entity in
            CostRecord(
                id: entity.id,
                providerName: entity.providerName,
                modelID: entity.modelID,
                inputTokens: entity.inputTokens,
                outputTokens: entity.outputTokens,
                costUSD: entity.costUSD,
                timestamp: entity.timestamp,
                sessionID: entity.sessionID
            )
        }
    }

    // MARK: - Private Helpers

    private func buildSummary(from records: [CostRecordEntity], start: Date, end: Date) -> CostSummary {
        var totalCost: Double = 0
        var totalInputTokens: Int = 0
        var totalOutputTokens: Int = 0
        var byProvider: [String: Double] = [:]
        var bySession: [String: Double] = [:]

        for record in records {
            totalCost += record.costUSD
            totalInputTokens += record.inputTokens
            totalOutputTokens += record.outputTokens
            byProvider[record.providerName, default: 0] += record.costUSD
            bySession[record.sessionID, default: 0] += record.costUSD
        }

        return CostSummary(
            totalCost: totalCost,
            totalInputTokens: totalInputTokens,
            totalOutputTokens: totalOutputTokens,
            callCount: records.count,
            byProvider: byProvider,
            bySession: bySession,
            dateRange: DateInterval(start: start, end: end)
        )
    }

    // MARK: - Cost Calculation

    /// Calculates the actual cost of an LLM call based on token usage and model pricing.
    static func calculateCost(model: String, inputTokens: Int, outputTokens: Int) -> Double {
        guard let modelID = LLMModelID(rawValue: model) else {
            return Double(inputTokens + outputTokens) * 0.003 / 1000.0
        }
        let inputCost = Double(inputTokens) * modelID.inputPricePerMillionTokens / 1_000_000.0
        let outputCost = Double(outputTokens) * modelID.outputPricePerMillionTokens / 1_000_000.0
        return inputCost + outputCost
    }
}
