import XCTest
@testable import Curator

/// ATDD Tests for Story 1.2 - AC1: 错误类型体系
///
/// Tests verify:
/// - DomainError 枚举存在且包含所需 case
/// - InfrastructureError 枚举包含文件系统错误变体
/// - UserFacingError 枚举存在且包含所需 case
/// - 错误映射规则正确
/// - 所有错误类型遵循 Error 协议和 Sendable
final class ErrorTypeTests: XCTestCase {

    // MARK: - AC1: DomainError

    /// [P0] DomainError exists and conforms to Error
    func testDomainErrorConformsToError() throws {
        let errors: [DomainError] = [
            .assetNotFound(AssetID(rawValue: "test-id")),
            .analysisFailed(reason: "test reason"),
            .insufficientPermission(required: .read),
            .operationCancelled,
            .invalidState(reason: "test state"),
        ]

        for error in errors {
            XCTAssertNotNil(error as Error, "DomainError.\(error) should conform to Error")
        }
    }

    /// [P0] DomainError.assetNotFound carries AssetID
    func testDomainErrorAssetNotFoundCarriesAssetID() throws {
        let assetID = AssetID(rawValue: "/Users/mock/Photos/photo_1.jpg")
        let error = DomainError.assetNotFound(assetID)

        if case .assetNotFound(let id) = error {
            XCTAssertEqual(id.rawValue, "/Users/mock/Photos/photo_1.jpg",
                "assetNotFound should carry the provided AssetID")
        } else {
            XCTFail("Expected assetNotFound case, got \(error)")
        }
    }

    /// [P0] DomainError.analysisFailed carries reason string
    func testDomainErrorAnalysisFailedCarriesReason() throws {
        let error = DomainError.analysisFailed(reason: "LLM timeout")

        if case .analysisFailed(let reason) = error {
            XCTAssertEqual(reason, "LLM timeout")
        } else {
            XCTFail("Expected analysisFailed case, got \(error)")
        }
    }

    /// [P1] DomainError.insufficientPermission carries PermissionLevel
    func testDomainErrorInsufficientPermissionCarriesLevel() throws {
        let error = DomainError.insufficientPermission(required: .write)

        if case .insufficientPermission(let level) = error {
            XCTAssertEqual(level, .write)
        } else {
            XCTFail("Expected insufficientPermission case, got \(error)")
        }
    }

    /// [P1] DomainError.operationCancelled case exists
    func testDomainErrorOperationCancelledExists() throws {
        let error = DomainError.operationCancelled
        XCTAssertNotNil(error as Error)
    }

    /// [P1] DomainError.invalidState carries reason string
    func testDomainErrorInvalidStateCarriesReason() throws {
        let error = DomainError.invalidState(reason: "not loaded")

        if case .invalidState(let reason) = error {
            XCTAssertEqual(reason, "not loaded")
        } else {
            XCTFail("Expected invalidState case, got \(error)")
        }
    }

    // MARK: - AC1: InfrastructureError (文件系统)

    /// [P0] InfrastructureError exists with file system error variants
    func testInfrastructureErrorConformsToError() throws {
        let errors: [InfrastructureError] = [
            .folderAccessDenied(reason: "权限被拒绝"),
            .folderScanFailed(reason: "扫描失败"),
            .fileNotFound(path: "/tmp/missing.jpg"),
            .fileWriteFailed(path: "/tmp/test.jpg", reason: "磁盘满"),
            .bookmarkAccessFailed(reason: "书签失效"),
            .llmProviderUnavailable(provider: "OpenAI"),
            .llmProviderError(provider: "OpenAI", statusCode: 429, message: "rate limited"),
            .networkError(underlying: NSError(domain: "NSURLErrorDomain", code: -1009)),
            .rateLimitExceeded(provider: "Anthropic", retryAfter: 60.0),
            .cacheError(reason: "disk full"),
        ]

        for error in errors {
            XCTAssertNotNil(error as Error,
                "InfrastructureError.\(error) should conform to Error")
        }
    }

    /// [P0] InfrastructureError.fileNotFound carries path
    func testInfrastructureErrorFileNotFoundCarriesPath() throws {
        let error = InfrastructureError.fileNotFound(path: "/Users/test/photo.jpg")

        if case .fileNotFound(let path) = error {
            XCTAssertEqual(path, "/Users/test/photo.jpg")
        } else {
            XCTFail("Expected fileNotFound case, got \(error)")
        }
    }

    /// [P1] InfrastructureError.llmProviderError carries details
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

    /// [P1] InfrastructureError.rateLimitExceeded carries retryAfter
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

        XCTAssertEqual(errors.count, 3)
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
            action: "选择照片文件夹"
        )

        if case .permissionRequired(let title, let action) = error {
            XCTAssertEqual(title, "Photo Access")
            XCTAssertEqual(action, "选择照片文件夹")
        } else {
            XCTFail("Expected permissionRequired case, got \(error)")
        }
    }

    // MARK: - AC1: Error Mapping Rules

    /// [P0] InfrastructureError can be mapped to DomainError
    func testInfrastructureErrorMapsToDomainError() throws {
        let infraError = InfrastructureError.folderScanFailed(reason: "扫描失败")
        let domainError = infraError.toDomainError()

        XCTAssertNotNil(domainError as DomainError)
    }

    /// [P0] DomainError can be mapped to UserFacingError
    func testDomainErrorMapsToUserFacingError() throws {
        let domainError = DomainError.insufficientPermission(required: .read)
        let userError = domainError.toUserFacingError()

        XCTAssertNotNil(userError as UserFacingError)
    }

    /// [P1] Error mapping never exposes technical details
    func testErrorMappingNeverExposesTechnicalDetails() throws {
        let infraError = InfrastructureError.llmProviderError(
            provider: "OpenAI",
            statusCode: 500,
            message: "PHImageErrorDomain error -1004"
        )

        let domainError = infraError.toDomainError()
        let userError = domainError.toUserFacingError()

        switch userError {
        case .readOnly(_, let message):
            XCTAssertFalse(message.contains("PHImageErrorDomain"))
            XCTAssertFalse(message.contains("500"))
        case .retryable(_, let message):
            XCTAssertFalse(message.contains("PHImageErrorDomain"))
        case .permissionRequired:
            break
        }
    }

    /// [P0] folderAccessDenied maps to insufficientPermission
    func testFolderAccessDeniedMapsCorrectly() throws {
        let infraError = InfrastructureError.folderAccessDenied(reason: "权限被拒绝")
        let domainError = infraError.toDomainError()

        if case .insufficientPermission = domainError {
            // Correct mapping
        } else {
            XCTFail("folderAccessDenied should map to DomainError.insufficientPermission, got \(domainError)")
        }
    }

    /// [P0] fileNotFound maps to assetNotFound
    func testFileNotFoundMapsCorrectly() throws {
        let path = "/Users/test/photo.jpg"
        let infraError = InfrastructureError.fileNotFound(path: path)
        let domainError = infraError.toDomainError()

        if case .assetNotFound(let id) = domainError {
            XCTAssertEqual(id.rawValue, path)
        } else {
            XCTFail("fileNotFound should map to DomainError.assetNotFound, got \(domainError)")
        }
    }

    /// [P0] bookmarkAccessFailed maps to insufficientPermission
    func testBookmarkAccessFailedMapsCorrectly() throws {
        let infraError = InfrastructureError.bookmarkAccessFailed(reason: "书签过期")
        let domainError = infraError.toDomainError()

        if case .insufficientPermission = domainError {
            // Correct mapping
        } else {
            XCTFail("bookmarkAccessFailed should map to DomainError.insufficientPermission, got \(domainError)")
        }
    }

    // MARK: - Complete Infra→Domain mapping coverage

    /// Verify all InfrastructureError cases map to valid DomainError cases
    func testAllInfrastructureErrorsMapToDomainError() throws {
        let mappings: [(InfrastructureError, DomainError)] = [
            (.folderAccessDenied(reason: "test"), .insufficientPermission(required: .read)),
            (.folderScanFailed(reason: "test"), .invalidState(reason: "")),
            (.fileNotFound(path: "/t"), .assetNotFound(AssetID(rawValue: ""))),
            (.fileWriteFailed(path: "/t", reason: "test"), .invalidState(reason: "")),
            (.bookmarkAccessFailed(reason: "test"), .insufficientPermission(required: .read)),
            (.llmProviderUnavailable(provider: "test"), .analysisFailed(reason: "")),
            (.llmProviderError(provider: "test", statusCode: 500, message: "err"), .analysisFailed(reason: "")),
            (.networkError(underlying: NSError(domain: "t", code: 0)), .analysisFailed(reason: "")),
            (.rateLimitExceeded(provider: "test", retryAfter: 30), .analysisFailed(reason: "")),
            (.cacheError(reason: "test"), .invalidState(reason: "")),
        ]

        for (infraError, expectedBase) in mappings {
            let result = infraError.toDomainError()
            switch (result, expectedBase) {
            case (.insufficientPermission, .insufficientPermission),
                 (.invalidState, .invalidState),
                 (.analysisFailed, .analysisFailed),
                 (.assetNotFound, .assetNotFound):
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
            XCTAssertEqual(title, "未找到照片")
        } else {
            XCTFail("assetNotFound should map to readOnly, got \(userError)")
        }
    }

    /// DomainError.operationCancelled maps to readOnly
    func testOperationCancelledMapsToReadOnly() throws {
        let error = DomainError.operationCancelled
        let userError = error.toUserFacingError()

        if case .readOnly(let title, _) = userError {
            XCTAssertEqual(title, "已取消")
        } else {
            XCTFail("operationCancelled should map to readOnly, got \(userError)")
        }
    }
}
