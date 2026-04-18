import Foundation

/// Domain-layer errors representing business rule violations and domain concerns.
///
/// These errors are used within the Domain layer and propagated upward.
/// Infrastructure errors are mapped to DomainError before crossing layer boundaries.
enum DomainError: Error, Sendable {
    case assetNotFound(AssetID)
    case analysisFailed(reason: String)
    case insufficientPermission(required: PermissionLevel)
    case operationCancelled
    case invalidState(reason: String)
}
