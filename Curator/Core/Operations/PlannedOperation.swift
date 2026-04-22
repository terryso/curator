import Foundation

/// Parameters for a specific operation type.
///
/// Each case carries the data needed to execute that operation.
/// Uses associated values to ensure type-safe parameter binding.
enum OperationParameters: Sendable, Codable, Equatable {
    case rename(newTitle: String)
    case delete
    case move(targetDirectory: String)
    case metadataChange
}

/// Describes a single operation to be performed on a photo asset.
///
/// Used as input to `OperationManager.beginBatch(operations:)`.
/// Combines the operation type, target asset, and parameters.
struct PlannedOperation: Sendable, Codable, Equatable {
    let operationType: OperationType
    let assetID: AssetID
    let parameters: OperationParameters
}
