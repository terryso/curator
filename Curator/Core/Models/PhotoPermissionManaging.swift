import Photos

/// Protocol for photo library permission management.
///
/// Defined in the Domain layer to support test-time injection of mock
/// implementations that don't trigger system permission dialogs.
protocol PhotoPermissionManaging: Sendable {
    var currentStatus: PHAuthorizationStatus { get }
    func checkCurrentStatus() -> PHAuthorizationStatus
    func requestReadAccess() async throws -> Bool
}
