import Foundation

/// A batch of related operations executed together with snapshot tracking.
///
/// Contains the list of OperationSnapshots capturing the before-state of
/// each affected asset, enabling full rollback if any operation fails.
struct BatchOperation: Sendable, Codable, Equatable {
    let id: UUID
    let createdAt: Date
    let snapshots: [OperationSnapshot]
    let status: BatchStatus
}
