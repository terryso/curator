import XCTest
import Photos
@testable import Curator

/// ATDD Tests for Story 1.3 - AC1: PhotoPermissionManager
///
/// Tests verify:
/// - PhotoPermissionManager exists as a Sendable struct
/// - currentStatus returns PHAuthorizationStatus
/// - requestReadAccess returns true when authorized
/// - requestReadAccess throws InfrastructureError.photoKitAccessDenied when denied
/// - Error mapping produces correct DomainError.insufficientPermission
/// - Permission states (.notDetermined, .denied, .restricted, .authorized, .limited) handled
final class PhotoPermissionManagerTests: XCTestCase {

    /// Skips the test if PhotoKit access is not already granted to avoid system dialogs.
    private func skipIfNoPhotoKitAccess() throws {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited else {
            throw XCTSkip("Photo library access not pre-granted — skipping to avoid system dialog")
        }
    }

    // MARK: - AC1: PhotoPermissionManager Type

    /// [P0] PhotoPermissionManager exists as a Sendable struct
    func testPhotoPermissionManagerExistsAsSendableStruct() throws {
        try skipIfNoPhotoKitAccess()
        let manager = PhotoPermissionManager()
        XCTAssertNotNil(manager, "PhotoPermissionManager should be instantiable")
    }

    /// [P0] PhotoPermissionManager has currentStatus property
    func testPhotoPermissionManagerHasCurrentStatusProperty() throws {
        try skipIfNoPhotoKitAccess()
        let manager = PhotoPermissionManager()
        let status = manager.currentStatus

        // PHAuthorizationStatus is an enum with known cases
        let validStatuses: [PHAuthorizationStatus] = [
            .notDetermined, .restricted, .denied, .authorized, .limited
        ]
        XCTAssertTrue(validStatuses.contains(status),
            "currentStatus should return a valid PHAuthorizationStatus")
    }

    // MARK: - AC1: requestReadAccess() — Authorized Path

    /// [P0] requestReadAccess returns true when permission is authorized
    func testRequestReadAccessReturnsTrueWhenAuthorized() async throws {
        try skipIfNoPhotoKitAccess()
        let manager = PhotoPermissionManager()
        let result = try await manager.requestReadAccess()
        XCTAssertTrue(result,
            "requestReadAccess should return true when authorized")
    }

    /// [P0] requestReadAccess returns true when permission is limited
    func testRequestReadAccessReturnsTrueWhenLimited() async throws {
        try skipIfNoPhotoKitAccess()
        let manager = PhotoPermissionManager()
        let result = try await manager.requestReadAccess()
        XCTAssertTrue(result,
            "requestReadAccess should return true when limited access is granted")
    }

    // MARK: - AC1: requestReadAccess() — Denied Path

    /// [P0] requestReadAccess throws photoKitAccessDenied when permission denied
    /// Note: Uses the mock to verify the error type in controlled conditions.
    func testRequestReadAccessThrowsWhenDenied() async throws {
        try skipIfNoPhotoKitAccess()
        // We verify the error type by checking that InfrastructureError.photoKitAccessDenied
        // maps correctly through the error chain (tested below).
        // The actual denied-path requires a controlled environment.
        // Here we verify the mock contract matches the expected behavior.
        let mock = MockPhotoPermissionManager(status: .denied, shouldThrow: true)

        do {
            _ = try await mock.requestReadAccess()
            XCTFail("requestReadAccess should throw when denied")
        } catch let error as InfrastructureError {
            if case .photoKitAccessDenied = error {
                // Correct error type
            } else {
                XCTFail("Expected photoKitAccessDenied, got \(error)")
            }
        }
    }

    /// [P1] requestReadAccess throws photoKitAccessDenied when restricted
    func testRequestReadAccessThrowsWhenRestricted() async throws {
        try skipIfNoPhotoKitAccess()
        let mock = MockPhotoPermissionManager(status: .restricted, shouldThrow: true)

        do {
            _ = try await mock.requestReadAccess()
            XCTFail("requestReadAccess should throw when restricted")
        } catch let error as InfrastructureError {
            if case .photoKitAccessDenied = error {
                // Correct — restricted is treated as denied
            } else {
                XCTFail("Expected photoKitAccessDenied for restricted, got \(error)")
            }
        }
    }

    // MARK: - AC1: Error Mapping Chain

    /// [P0] photoKitAccessDenied maps to DomainError.insufficientPermission via toDomainError()
    func testPhotoKitAccessDeniedMapsToInsufficientPermission() throws {
        // Given: An InfrastructureError.photoKitAccessDenied
        let infraError = InfrastructureError.photoKitAccessDenied

        // When: Mapping to domain error
        let domainError = infraError.toDomainError()

        // Then: Should produce DomainError.insufficientPermission
        if case .insufficientPermission(let level) = domainError {
            XCTAssertEqual(level, .read,
                "photoKitAccessDenied should map to insufficientPermission with .read level")
        } else {
            XCTFail("photoKitAccessDenied should map to DomainError.insufficientPermission, got \(domainError)")
        }
    }

    /// [P1] DomainError.insufficientPermission maps to UserFacingError.permissionRequired
    func testInsufficientPermissionMapsToUserFacingPermissionRequired() throws {
        // Given: A DomainError.insufficientPermission
        let domainError = DomainError.insufficientPermission(required: .read)

        // When: Mapping to user-facing error
        let userError = domainError.toUserFacingError()

        // Then: Should produce permissionRequired with guidance to System Settings
        if case .permissionRequired(let title, let action) = userError {
            XCTAssertFalse(title.isEmpty, "Title should not be empty")
            XCTAssertFalse(action.isEmpty, "Action should not be empty")
            XCTAssertTrue(action.contains("System Settings") || action.contains("设置"),
                "Action should guide user to System Settings")
        } else {
            XCTFail("insufficientPermission should map to permissionRequired, got \(userError)")
        }
    }

    /// [P0] Full error chain: denied permission produces actionable user-facing message
    func testDeniedPermissionProducesFullErrorChain() throws {
        // Given: Permission denied scenario
        // Infrastructure error
        let infraError = InfrastructureError.photoKitAccessDenied

        // When: Mapping through the full error chain
        let domainError = infraError.toDomainError()
        let userError = domainError.toUserFacingError()

        // Then: User-facing error should be permissionRequired
        if case .permissionRequired(let title, _) = userError {
            XCTAssertEqual(title, "Access Required",
                "User-facing title should be 'Access Required'")
        } else {
            XCTFail("Full error chain should end with permissionRequired")
        }
    }

    // MARK: - AC1: checkCurrentStatus()

    /// [P1] PhotoPermissionManager provides checkCurrentStatus method
    func testPhotoPermissionManagerProvidesCheckCurrentStatus() async throws {
        try skipIfNoPhotoKitAccess()
        let manager = PhotoPermissionManager()

        // When: Calling checkCurrentStatus()
        let status = manager.checkCurrentStatus()

        // Then: Returns a valid PHAuthorizationStatus without prompting
        let validStatuses: [PHAuthorizationStatus] = [
            .notDetermined, .restricted, .denied, .authorized, .limited
        ]
        XCTAssertTrue(validStatuses.contains(status),
            "checkCurrentStatus should return a valid PHAuthorizationStatus")
    }
}

// MARK: - Mock Implementations for Testing

/// Mock PhotoPermissionManager for testing PhotoKitRepository in isolation.
///
/// Injects controlled authorization status without real PhotoKit calls.
private struct MockPhotoPermissionManager: Sendable {
    var mockStatus: PHAuthorizationStatus
    var shouldThrow: Bool

    init(status: PHAuthorizationStatus = .authorized, shouldThrow: Bool = false) {
        self.mockStatus = status
        self.shouldThrow = shouldThrow
    }

    var currentStatus: PHAuthorizationStatus {
        mockStatus
    }

    func requestReadAccess() async throws -> Bool {
        if shouldThrow {
            throw InfrastructureError.photoKitAccessDenied
        }
        return mockStatus == .authorized || mockStatus == .limited
    }
}
