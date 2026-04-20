import Foundation
import SwiftData

/// SwiftData persistent model for LLM call cost records.
///
/// Stores individual LLM call cost data for querying and aggregation
/// by CostTracker. Fields mirror CostRecord value type for easy mapping.
@Model
final class CostRecordEntity {
    @Attribute(.unique) var id: UUID
    var providerName: String
    var modelID: String
    var inputTokens: Int
    var outputTokens: Int
    var costUSD: Double
    var timestamp: Date
    var sessionID: String

    init(
        id: UUID = UUID(),
        providerName: String,
        modelID: String,
        inputTokens: Int,
        outputTokens: Int,
        costUSD: Double,
        timestamp: Date = Date(),
        sessionID: String
    ) {
        self.id = id
        self.providerName = providerName
        self.modelID = modelID
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.costUSD = costUSD
        self.timestamp = timestamp
        self.sessionID = sessionID
    }
}
