import Foundation

/// Repository protocol for accessing the photo library.
///
/// Defined in the Domain layer; concrete implementations reside in
/// the Infrastructure layer (e.g., PhotoKitPhotoLibraryRepository).
/// Supports test-time replacement with mock implementations.
protocol PhotoLibraryRepository: Sendable {
    func requestReadAccess() async throws -> Bool
    func requestWriteAccess() async throws -> Bool
    func fetchAssets(predicate: PhotoPredicate, pageSize: Int, pageOffset: Int) async throws -> AssetPage
    func fetchFullResolutionImage(for assetID: AssetID) async throws -> Data
}
