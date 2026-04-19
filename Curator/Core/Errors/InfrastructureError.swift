import Foundation

/// Infrastructure-layer errors wrapping external system failures.
///
/// These errors originate from PhotoKit, network calls, cache, etc.
/// They must be mapped to DomainError before propagating to the Domain layer.
enum InfrastructureError: Error, Sendable {
    case photoKitAccessDenied
    case photoKitFetchFailed(reason: String)
    case llmProviderUnavailable(provider: String)
    case llmProviderError(provider: String, statusCode: Int, message: String)
    case networkError(underlying: any Error)
    case rateLimitExceeded(provider: String, retryAfter: TimeInterval)
    case cacheError(reason: String)
}
