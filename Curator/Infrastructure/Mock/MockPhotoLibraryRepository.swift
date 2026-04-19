import Foundation

struct MockPhotoLibraryRepository: PhotoLibraryRepository {

    private let photos: [PhotoAsset]

    init(photos: [PhotoAsset] = MockPhotoData.samplePhotos) {
        self.photos = photos
    }

    func requestReadAccess() async throws -> Bool { true }

    func requestWriteAccess() async throws -> Bool { true }

    func fetchAssets(predicate: PhotoPredicate, pageSize: Int, pageOffset: Int) async throws -> AssetPage {
        let startIndex = pageOffset
        let endIndex = min(startIndex + pageSize, photos.count)
        let page = Array(photos[startIndex..<endIndex])
        let hasMore = endIndex < photos.count
        return AssetPage(assets: page, hasMore: hasMore, nextOffset: hasMore ? endIndex : nil)
    }

    func fetchFullResolutionImage(for assetID: AssetID) async throws -> Data {
        guard let photo = photos.first(where: { $0.id == assetID }) else {
            throw DomainError.assetNotFound(assetID)
        }
        if let idx = photos.firstIndex(where: { $0.id == assetID }) {
            return MockPhotoData.generateThumbnail(hue: CGFloat(idx) / CGFloat(photos.count), size: 400)
        }
        return photo.thumbnailData ?? Data()
    }

    func fetchThumbnail(for assetID: AssetID, size: CGSize) async throws -> Data {
        guard let photo = photos.first(where: { $0.id == assetID }) else {
            throw DomainError.assetNotFound(assetID)
        }
        return photo.thumbnailData ?? Data()
    }

    func updateAsset(_ assetID: AssetID, title: String?) async throws {
        // Mock: no-op
    }

    func deleteAssets(_ assetIDs: [AssetID]) async throws {
        // Mock: no-op
    }

    func moveAssets(_ assetIDs: [AssetID], to directory: String) async throws {
        // Mock: no-op
    }

    func observeSourceChanges() -> AsyncStream<SourceChange> {
        AsyncStream { _ in }
    }
}
