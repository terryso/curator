import Foundation

/// Protocol defining the thumbnail generation interface.
///
/// Defined in the Domain layer; concrete implementations reside in
/// the Infrastructure layer. Supports test-time replacement with mock implementations.
protocol ThumbnailGeneratorProtocol: Sendable {
    /// Generates a thumbnail for a single asset.
    ///
    /// - Parameters:
    ///   - assetID: The asset to generate a thumbnail for.
    ///   - repository: Repository to fetch the full-resolution image from.
    ///   - targetSize: The target size for the thumbnail.
    /// - Returns: JPEG-compressed thumbnail data.
    /// - Throws: `DomainError.analysisFailed` if the image cannot be decoded or processed.
    func generateThumbnail(
        for assetID: AssetID,
        repository: PhotoLibraryRepository,
        targetSize: CGSize
    ) async throws -> Data

    /// Generates thumbnails for multiple assets in batch.
    ///
    /// Individual failures are skipped gracefully — the returned dictionary
    /// only contains entries for successfully processed assets.
    ///
    /// - Parameters:
    ///   - assets: Array of photo assets to generate thumbnails for.
    ///   - repository: Repository to fetch full-resolution images from.
    ///   - targetSize: The target size for thumbnails.
    /// - Returns: Dictionary mapping AssetID to thumbnail data (only successful ones).
    func generateThumbnails(
        for assets: [PhotoAsset],
        repository: PhotoLibraryRepository,
        targetSize: CGSize
    ) async -> [AssetID: Data]
}
