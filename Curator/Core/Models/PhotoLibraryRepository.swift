import Foundation

/// Repository protocol for accessing photo sources.
///
/// Defined in the Domain layer; concrete implementations reside in
/// the Infrastructure layer (e.g., LocalFolderRepository for MVP,
/// PhotoKitRepository for post-MVP).
/// Supports test-time replacement with mock implementations.
protocol PhotoLibraryRepository: Sendable {
    func currentBasePath() async -> String?

    func requestReadAccess() async throws -> Bool
    func requestWriteAccess() async throws -> Bool
    func fetchAssets(predicate: PhotoPredicate, pageSize: Int, pageOffset: Int) async throws -> AssetPage
    func fetchFullResolutionImage(for assetID: AssetID) async throws -> Data
    func fetchThumbnail(for assetID: AssetID, size: CGSize) async throws -> Data
    func metadata(for assetID: AssetID) async throws -> AssetMetadata

    // Write operations (Epic 4 full implementation)
    func updateAsset(_ assetID: AssetID, title: String?) async throws
    func deleteAssets(_ assetIDs: [AssetID]) async throws
    func moveAssets(_ assetIDs: [AssetID], to directory: String) async throws

    // Source change monitoring
    func observeSourceChanges() -> AsyncStream<SourceChange>
}
