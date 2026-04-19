import Foundation
import Photos

/// Manages PhotoKit authorization status and permission requests.
///
/// Provides read/write permission checking and request methods.
/// Errors are mapped to InfrastructureError for consistent error handling
/// across the three-layer error chain (Infrastructure -> Domain -> UserFacing).
struct PhotoPermissionManager: Sendable {

    /// Current authorization status for photo library access.
    var currentStatus: PHAuthorizationStatus {
        PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }

    /// Requests read access to the photo library.
    ///
    /// Calls PHPhotoLibrary.requestAuthorization and maps the result:
    /// - `.authorized` / `.limited` -> returns `true`
    /// - `.denied` / `.restricted` -> throws `InfrastructureError.photoKitAccessDenied`
    /// - `.notDetermined` -> triggers the system permission dialog
    ///
    /// - Returns: `true` if read access was granted.
    /// - Throws: `InfrastructureError.photoKitAccessDenied` when access is denied or restricted.
    func requestReadAccess() async throws -> Bool {
        let current = checkCurrentStatus()
        if current == .authorized || current == .limited {
            return true
        }

        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)

        switch status {
        case .authorized, .limited:
            return true
        case .denied, .restricted:
            throw InfrastructureError.photoKitAccessDenied
        case .notDetermined:
            // User dismissed the dialog without choosing — treat as denied
            throw InfrastructureError.photoKitAccessDenied
        @unknown default:
            throw InfrastructureError.photoKitAccessDenied
        }
    }

    /// Queries the current permission status without presenting a dialog.
    ///
    /// - Returns: The current `PHAuthorizationStatus` for readWrite access.
    func checkCurrentStatus() -> PHAuthorizationStatus {
        PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }
}
