import Foundation

// MARK: - InfrastructureError → DomainError Mapping

extension InfrastructureError {
    /// Maps an infrastructure-layer error to a domain-layer error.
    ///
    /// Infrastructure errors must be converted to DomainError before
    /// propagating upward. This ensures the Domain layer remains
    /// independent of infrastructure concerns.
    func toDomainError() -> DomainError {
        switch self {
        case .photoKitAccessDenied:
            return .insufficientPermission(required: .read)
        case .photoKitFetchFailed:
            return .invalidState(reason: "Unable to fetch photo library data")
        case .llmProviderUnavailable:
            return .analysisFailed(reason: "AI service is currently unavailable")
        case .llmProviderError:
            return .analysisFailed(reason: "AI analysis failed")
        case .networkError:
            return .analysisFailed(reason: "Network connection failed")
        case .rateLimitExceeded:
            return .analysisFailed(reason: "AI service rate limit reached")
        case .cacheError:
            return .invalidState(reason: "Cache operation failed")
        }
    }
}

// MARK: - DomainError → UserFacingError Mapping

extension DomainError {
    /// Maps a domain-layer error to a user-facing error suitable for UI display.
    ///
    /// Never exposes technical details such as error domains, HTTP status codes,
    /// or internal identifiers. All messages are user-friendly.
    func toUserFacingError() -> UserFacingError {
        switch self {
        case .assetNotFound:
            return .readOnly(
                title: "Photo Not Found",
                message: "The requested photo could not be found in your library."
            )
        case .analysisFailed:
            return .retryable(
                title: "Analysis Unavailable",
                message: "Unable to analyze the photo. Please try again later."
            )
        case .insufficientPermission:
            return .permissionRequired(
                title: "Access Required",
                action: "Please grant access in System Settings"
            )
        case .operationCancelled:
            return .readOnly(
                title: "Cancelled",
                message: "The operation was cancelled."
            )
        case .invalidState:
            return .retryable(
                title: "Something Went Wrong",
                message: "An unexpected error occurred. Please try again."
            )
        }
    }
}
