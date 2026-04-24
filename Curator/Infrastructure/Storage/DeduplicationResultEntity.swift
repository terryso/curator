import Foundation
import SwiftData

/// SwiftData persistent model for deduplication result history records.
///
/// Stores summary statistics of completed dedup operations for historical
/// review. Fields mirror DeduplicationResult value type for easy mapping.
@Model
final class DeduplicationResultEntity {
    @Attribute(.unique) var id: UUID
    var date: Date
    var removedCount: Int
    var totalGroups: Int
    var savedSpaceBytes: Int64
    var durationSeconds: Double

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        removedCount: Int,
        totalGroups: Int,
        savedSpaceBytes: Int64,
        durationSeconds: Double
    ) {
        self.id = id
        self.date = date
        self.removedCount = removedCount
        self.totalGroups = totalGroups
        self.savedSpaceBytes = savedSpaceBytes
        self.durationSeconds = durationSeconds
    }

    /// Converts this entity to a DeduplicationResult value type.
    func toDeduplicationResult() -> DeduplicationResult {
        DeduplicationResult(
            id: id,
            date: date,
            removedCount: removedCount,
            totalGroups: totalGroups,
            savedSpaceBytes: savedSpaceBytes,
            durationSeconds: durationSeconds
        )
    }

    /// Creates an entity from a DeduplicationResult value type.
    static func from(_ result: DeduplicationResult) -> DeduplicationResultEntity {
        DeduplicationResultEntity(
            id: result.id,
            date: result.date,
            removedCount: result.removedCount,
            totalGroups: result.totalGroups,
            savedSpaceBytes: result.savedSpaceBytes,
            durationSeconds: result.durationSeconds
        )
    }
}
