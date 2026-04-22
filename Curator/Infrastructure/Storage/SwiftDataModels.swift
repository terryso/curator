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

// MARK: - Operation Snapshot Entity

/// SwiftData persistent model for operation snapshots.
///
/// Captures the before-state of a single asset operation so it can be
/// rolled back. Each snapshot belongs to a BatchOperationEntity.
@Model
final class OperationSnapshotEntity {
    @Attribute(.unique) var id: UUID
    var timestamp: Date
    var operationType: String  // OperationType raw value
    var assetID: String        // AssetID rawValue
    var beforeStateFileName: String
    var beforeStateFilePath: String
    var beforeStateFileSize: Int64
    var beforeStateCreationDate: Date?
    var isExecuted: Bool
    var isRolledBack: Bool

    /// Planned operation parameters encoded as JSON data for rollback reconstruction.
    var plannedOperationData: Data?

    /// Post-operation file path, populated after execution for rollback.
    var afterStateFilePath: String?

    var batch: BatchOperationEntity?

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        operationType: String,
        assetID: String,
        beforeStateFileName: String,
        beforeStateFilePath: String,
        beforeStateFileSize: Int64 = 0,
        beforeStateCreationDate: Date? = nil,
        isExecuted: Bool = false,
        isRolledBack: Bool = false,
        plannedOperationData: Data? = nil,
        afterStateFilePath: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.operationType = operationType
        self.assetID = assetID
        self.beforeStateFileName = beforeStateFileName
        self.beforeStateFilePath = beforeStateFilePath
        self.beforeStateFileSize = beforeStateFileSize
        self.beforeStateCreationDate = beforeStateCreationDate
        self.isExecuted = isExecuted
        self.isRolledBack = isRolledBack
        self.plannedOperationData = plannedOperationData
        self.afterStateFilePath = afterStateFilePath
    }

    /// Converts this entity to an OperationSnapshot value type.
    func toOperationSnapshot() -> OperationSnapshot {
        OperationSnapshot(
            id: id,
            timestamp: timestamp,
            operationType: OperationType(rawValue: operationType) ?? .metadataChange,
            assetID: AssetID(rawValue: assetID),
            beforeState: AssetMetadata(
                fileName: beforeStateFileName,
                fileSize: beforeStateFileSize,
                creationDate: beforeStateCreationDate,
                cameraModel: nil,
                imageWidth: nil,
                imageHeight: nil,
                gpsLocation: nil,
                fileFormat: nil
            )
        )
    }
}

// MARK: - Batch Operation Entity

/// SwiftData persistent model for batch operations.
///
/// Groups multiple OperationSnapshotEntities together and tracks
/// the overall batch lifecycle (pending -> executing -> completed/failed/rolledBack).
@Model
final class BatchOperationEntity {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var completedAt: Date?
    var status: String  // BatchStatus raw value

    @Relationship(deleteRule: .cascade)
    var snapshots: [OperationSnapshotEntity] = []

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        completedAt: Date? = nil,
        status: String = BatchStatus.pending.rawValue
    ) {
        self.id = id
        self.createdAt = createdAt
        self.completedAt = completedAt
        self.status = status
    }

    /// Converts this entity (with its snapshots) to a BatchOperation value type.
    func toBatchOperation() -> BatchOperation {
        BatchOperation(
            id: id,
            createdAt: createdAt,
            snapshots: snapshots.map { $0.toOperationSnapshot() },
            status: BatchStatus(rawValue: status) ?? .pending
        )
    }
}
