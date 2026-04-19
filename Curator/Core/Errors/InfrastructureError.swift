import Foundation

/// Infrastructure-layer errors wrapping external system failures.
///
/// These errors originate from file system operations, network calls, cache, etc.
/// They must be mapped to DomainError before propagating to the Domain layer.
enum InfrastructureError: Error, Sendable {
    // File system errors (local folder photo source)
    case folderAccessDenied(reason: String)
    case folderScanFailed(reason: String)
    case fileNotFound(path: String)
    case fileWriteFailed(path: String, reason: String)
    case bookmarkAccessFailed(reason: String)

    // LLM provider errors
    case llmProviderUnavailable(provider: String)
    case llmProviderError(provider: String, statusCode: Int, message: String)
    case networkError(underlying: any Error & Sendable)
    case rateLimitExceeded(provider: String, retryAfter: TimeInterval)

    // Cache errors
    case cacheError(reason: String)
}
