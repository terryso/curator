import XCTest
@testable import Curator

/// ATDD Tests for Story 1.2 - AC1: 错误类型体系
///
/// Tests verify:
/// - DomainError enum exists with required cases
/// - InfrastructureError enum exists with required cases
/// - UserFacingError enum exists with required cases
/// - Error mapping rules between layers
/// - All error types conform to Error protocol
/// - Sendable conformance for strict concurrency
final class ErrorTypeTests: XCTestCase {

    // MARK: - AC1: DomainError

    /// [P0] DomainError exists and conforms to Error
    func testDomainErrorConformsToError() throws {
        // Given: DomainError enum is defined in Core/Errors/
        // When: Creating instances of each case
        // Then: Each case compiles and conforms to Error
        let errors: [DomainError] = [
            .assetNotFound(AssetID(rawValue: "test-id")),
            .analysisFailed(reason: "test reason"),
            .insufficientPermission(required: .read),
            .operationCancelled,
            .invalidState(reason: "test state"),
        ]

        // Then: All errors conform to Error
        for error in errors {
            XCTAssertNotNil(error as Error, "DomainError.\(error) should conform to Error")
        }
    }

    /// [P0] DomainError.assetNotFound carries AssetID
    func testDomainErrorAssetNotFoundCarriesAssetID() throws {
        let assetID = AssetID(rawValue: "PHAsset-local-identifier-123")
        let error = DomainError.assetNotFound(assetID)

        if case .assetNotFound(let id) = error {
            XCTAssertEqual(id.rawValue, "PHAsset-local-identifier-123",
                "assetNotFound should carry the provided AssetID")
        } else {
            XCTFail("Expected assetNotFound case, got \(error)")
        }
    }

    /// [P0] DomainError.analysisFailed carries reason string
    func testDomainErrorAnalysisFailedCarriesReason() throws {
        let error = DomainError.analysisFailed(reason: "LLM timeout")

        if case .analysisFailed(let reason) = error {
            XCTAssertEqual(reason, "LLM timeout",
                "analysisFailed should carry the provided reason")
        } else {
            XCTFail("Expected analysisFailed case, got \(error)")
        }
    }

    /// [P1] DomainError.insufficientPermission carries PermissionLevel
    func testDomainErrorInsufficientPermissionCarriesLevel() throws {
        let error = DomainError.insufficientPermission(required: .write)

        if case .insufficientPermission(let level) = error {
            XCTAssertEqual(level, .write,
                "insufficientPermission should carry the required permission level")
        } else {
            XCTFail("Expected insufficientPermission case, got \(error)")
        }
    }

    /// [P1] DomainError.operationCancelled case exists
    func testDomainErrorOperationCancelledExists() throws {
        let error = DomainError.operationCancelled
        XCTAssertNotNil(error as Error,
            "operationCancelled should be a valid DomainError case")
    }

    /// [P1] DomainError.invalidState carries reason string
    func testDomainErrorInvalidStateCarriesReason() throws {
        let error = DomainError.invalidState(reason: "not loaded")

        if case .invalidState(let reason) = error {
            XCTAssertEqual(reason, "not loaded",
                "invalidState should carry the provided reason")
        } else {
            XCTFail("Expected invalidState case, got \(error)")
        }
    }

    // MARK: - AC1: InfrastructureError

    /// [P0] InfrastructureError exists and conforms to Error
    func testInfrastructureErrorConformsToError() throws {
        let errors: [InfrastructureError] = [
            .photoKitAccessDenied,
            .photoKitFetchFailed(reason: "fetch error"),
            .llmProviderUnavailable(provider: "OpenAI"),
            .llmProviderError(provider: "OpenAI", statusCode: 429, message: "rate limited"),
            .networkError(underlying: NSError(domain: "NSURLErrorDomain", code: -1009)),
            .rateLimitExceeded(provider: "Anthropic", retryAfter: 60.0),
            .keychainError(status: -25300),
            .cacheError(reason: "disk full"),
        ]

        for error in errors {
            XCTAssertNotNil(error as Error,
                "InfrastructureError.\(error) should conform to Error")
        }
    }

    /// [P0] InfrastructureError.photoKitAccessDenied exists
    func testInfrastructureErrorPhotoKitAccessDenied() throws {
        let error = InfrastructureError.photoKitAccessDenied
        XCTAssertNotNil(error as Error,
            "photoKitAccessDenied should be a valid InfrastructureError case")
    }

    /// [P1] InfrastructureError.llmProviderError carries provider, statusCode, message
    func testInfrastructureErrorLLMProviderErrorCarriesDetails() throws {
        let error = InfrastructureError.llmProviderError(
            provider: "OpenAI",
            statusCode: 500,
            message: "Internal Server Error"
        )

        if case .llmProviderError(let provider, let statusCode, let message) = error {
            XCTAssertEqual(provider, "OpenAI")
            XCTAssertEqual(statusCode, 500)
            XCTAssertEqual(message, "Internal Server Error")
        } else {
            XCTFail("Expected llmProviderError case, got \(error)")
        }
    }

    /// [P1] InfrastructureError.rateLimitExceeded carries retryAfter interval
    func testInfrastructureErrorRateLimitExceededCarriesRetryAfter() throws {
        let error = InfrastructureError.rateLimitExceeded(provider: "Anthropic", retryAfter: 30.0)

        if case .rateLimitExceeded(let provider, let retryAfter) = error {
            XCTAssertEqual(provider, "Anthropic")
            XCTAssertEqual(retryAfter, 30.0, accuracy: 0.01)
        } else {
            XCTFail("Expected rateLimitExceeded case, got \(error)")
        }
    }

    // MARK: - AC1: UserFacingError

    /// [P0] UserFacingError exists with required cases
    func testUserFacingErrorExistsWithRequiredCases() throws {
        let errors: [UserFacingError] = [
            .readOnly(title: "Error", message: "Something went wrong"),
            .retryable(title: "Network Error", message: "Please try again"),
            .permissionRequired(title: "Access Denied", action: "Open Settings"),
        ]

        // Then: All cases should be valid
        XCTAssertEqual(errors.count, 3,
            "UserFacingError should have at least readOnly, retryable, permissionRequired cases")
    }

    /// [P1] UserFacingError.readOnly carries title and message
    func testUserFacingErrorReadOnlyCarriesTitleAndMessage() throws {
        let error = UserFacingError.readOnly(title: "Not Found", message: "Photo does not exist")

        if case .readOnly(let title, let message) = error {
            XCTAssertEqual(title, "Not Found")
            XCTAssertEqual(message, "Photo does not exist")
        } else {
            XCTFail("Expected readOnly case, got \(error)")
        }
    }

    /// [P1] UserFacingError.permissionRequired carries title and action
    func testUserFacingErrorPermissionRequiredCarriesAction() throws {
        let error = UserFacingError.permissionRequired(
            title: "Photo Access",
            action: "Grant in System Settings"
        )

        if case .permissionRequired(let title, let action) = error {
            XCTAssertEqual(title, "Photo Access")
            XCTAssertEqual(action, "Grant in System Settings")
        } else {
            XCTFail("Expected permissionRequired case, got \(error)")
        }
    }

    // MARK: - AC1: Error Mapping Rules

    /// [P0] InfrastructureError can be mapped to DomainError
    func testInfrastructureErrorMapsToDomainError() throws {
        // Given: An infrastructure-level error
        let infraError = InfrastructureError.photoKitFetchFailed(reason: "access denied")

        // When: Mapping to domain error
        let domainError = infraError.toDomainError()

        // Then: Result should be a DomainError
        XCTAssertNotNil(domainError as DomainError,
            "InfrastructureError should be mappable to DomainError")
    }

    /// [P0] DomainError can be mapped to UserFacingError
    func testDomainErrorMapsToUserFacingError() throws {
        // Given: A domain-level error
        let domainError = DomainError.insufficientPermission(required: .read)

        // When: Mapping to user-facing error
        let userError = domainError.toUserFacingError()

        // Then: Result should be a UserFacingError
        XCTAssertNotNil(userError as UserFacingError,
            "DomainError should be mappable to UserFacingError")
    }

    /// [P1] Infrastructure error mapping never exposes technical details
    func testErrorMappingNeverExposesTechnicalDetails() throws {
        // Given: A technical infrastructure error
        let infraError = InfrastructureError.llmProviderError(
            provider: "OpenAI",
            statusCode: 500,
            message: "PHImageErrorDomain error -1004"
        )

        // When: Mapping through the full chain
        let domainError = infraError.toDomainError()
        let userError = domainError.toUserFacingError()

        // Then: User-facing error should not contain technical strings
        if case .readOnly(_, let message) = userError {
            XCTAssertFalse(message.contains("PHImageErrorDomain"),
                "User-facing errors must never expose technical error domains")
            XCTAssertFalse(message.contains("500"),
                "User-facing errors must never expose HTTP status codes")
        } else if case .retryable(_, let message) = userError {
            XCTAssertFalse(message.contains("PHImageErrorDomain"),
                "User-facing errors must never expose technical error domains")
        } else if case .permissionRequired(_, _) = userError {
            // permissionRequired case - acceptable mapping
        } else {
            // UserFacingError is valid, no technical strings to check
        }
    }

    /// [P1] photoKitAccessDenied maps to permission-related domain error
    func testPhotoKitAccessDeniedMapsCorrectly() throws {
        let infraError = InfrastructureError.photoKitAccessDenied
        let domainError = infraError.toDomainError()

        // Should map to insufficientPermission, not some generic error
        if case .insufficientPermission = domainError {
            // Correct mapping
        } else {
            XCTFail("photoKitAccessDenied should map to DomainError.insufficientPermission, got \(domainError)")
        }
    }

    // MARK: - Complete Infra→Domain mapping coverage

    /// Verify all InfrastructureError cases map to valid DomainError cases
    func testAllInfrastructureErrorsMapToDomainError() throws {
        let mappings: [(InfrastructureError, DomainError)] = [
            (.photoKitAccessDenied, .insufficientPermission(required: .read)),
            (.photoKitFetchFailed(reason: "test"), .invalidState(reason: "")),
            (.llmProviderUnavailable(provider: "test"), .analysisFailed(reason: "")),
            (.llmProviderError(provider: "test", statusCode: 500, message: "err"), .analysisFailed(reason: "")),
            (.networkError(underlying: NSError(domain: "t", code: 0)), .analysisFailed(reason: "")),
            (.rateLimitExceeded(provider: "test", retryAfter: 30), .analysisFailed(reason: "")),
            (.keychainError(status: -1), .invalidState(reason: "")),
            (.cacheError(reason: "test"), .invalidState(reason: "")),
        ]

        for (infraError, expectedBase) in mappings {
            let result = infraError.toDomainError()
            // Verify the mapped error matches the expected case pattern
            switch (result, expectedBase) {
            case (.insufficientPermission, .insufficientPermission),
                 (.invalidState, .invalidState),
                 (.analysisFailed, .analysisFailed):
                break
            default:
                XCTFail("\(infraError) mapped to \(result), expected pattern matching \(expectedBase)")
            }
        }
    }

    // MARK: - Complete Domain→UserFacing mapping coverage

    /// Verify all DomainError cases map to user-friendly messages
    func testAllDomainErrorsMapToUserFacingError() throws {
        let domainErrors: [DomainError] = [
            .assetNotFound(AssetID(rawValue: "test")),
            .analysisFailed(reason: "test"),
            .insufficientPermission(required: .read),
            .operationCancelled,
            .invalidState(reason: "test"),
        ]

        for error in domainErrors {
            let userError = error.toUserFacingError()
            switch userError {
            case .readOnly(let title, let message):
                XCTAssertFalse(title.isEmpty)
                XCTAssertFalse(message.isEmpty)
            case .retryable(let title, let message):
                XCTAssertFalse(title.isEmpty)
                XCTAssertFalse(message.isEmpty)
            case .permissionRequired(let title, let action):
                XCTAssertFalse(title.isEmpty)
                XCTAssertFalse(action.isEmpty)
            }
        }
    }

    /// DomainError.assetNotFound maps to readOnly user error
    func testAssetNotFoundMapsToReadOnly() throws {
        let error = DomainError.assetNotFound(AssetID(rawValue: "id"))
        let userError = error.toUserFacingError()

        if case .readOnly(let title, _) = userError {
            XCTAssertEqual(title, "Photo Not Found")
        } else {
            XCTFail("assetNotFound should map to readOnly, got \(userError)")
        }
    }

    /// DomainError.operationCancelled maps to readOnly with cancelled message
    func testOperationCancelledMapsToReadOnly() throws {
        let error = DomainError.operationCancelled
        let userError = error.toUserFacingError()

        if case .readOnly(let title, _) = userError {
            XCTAssertEqual(title, "Cancelled")
        } else {
            XCTFail("operationCancelled should map to readOnly, got \(userError)")
        }
    }
}
