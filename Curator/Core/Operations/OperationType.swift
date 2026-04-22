import Foundation

/// Types of operations that can be performed on photo assets.
///
/// Each case corresponds to a specific file-system or metadata operation.
/// Used by OperationSnapshot and PlannedOperation to classify operations.
enum OperationType: String, Sendable, Codable, Equatable {
    case rename
    case delete
    case move
    case metadataChange
}
