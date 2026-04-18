import Foundation
import AppKit
import Photos

extension NSImage {
    func jpegData(compression: CGFloat = 0.85) -> Data? {
        guard let tiff = tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff)
        else { return nil }
        return bitmap.representation(using: .jpeg, properties: [.compressionFactor: compression])
    }
}

/// Concrete implementation of PhotoLibraryRepository using PhotoKit.
///
/// All PhotoKit operations are serialized within this actor to ensure
/// thread safety. Infrastructure errors are mapped to DomainError
/// before propagating to the Domain layer.
actor PhotoKitRepository: PhotoLibraryRepository {

    // MARK: - Dependencies

    /// Manages photo library permission requests.
    /// Marked `nonisolated(unsafe)` because PhotoPermissionManager is a
    /// Sendable value type — safe to access from any isolation domain.
    nonisolated(unsafe) var permissionManager: PhotoPermissionManager

    /// In-memory thumbnail cache. 100MB limit per UX-DR13 / Story 1.4 AC.
    private let thumbnailCache: NSCache<NSString, NSData> = {
        let cache = NSCache<NSString, NSData>()
        cache.totalCostLimit = 100 * 1024 * 1024 // 100 MB
        return cache
    }()

    // MARK: - Initialization

    /// Creates a new PhotoKitRepository.
    /// - Parameter permissionManager: The permission manager to use for access checks.
    init(permissionManager: PhotoPermissionManager = PhotoPermissionManager()) {
        self.permissionManager = permissionManager
    }

    // MARK: - PhotoLibraryRepository Conformance

    /// Requests read access to the photo library.
    ///
    /// Delegates to PhotoPermissionManager and maps errors through
    /// the InfrastructureError -> DomainError chain.
    /// - Returns: `true` if read access was granted.
    /// - Throws: `DomainError.insufficientPermission` if access is denied.
    func requestReadAccess() async throws -> Bool {
        do {
            return try await permissionManager.requestReadAccess()
        } catch let error as InfrastructureError {
            throw error.toDomainError()
        }
    }

    /// Requests write access to the photo library.
    ///
    /// Placeholder implementation — write access is not supported in this story.
    /// Will be implemented in Story 4.1 (Write Permission Progressive).
    /// - Returns: Always returns `false`.
    func requestWriteAccess() async throws -> Bool {
        return false
    }

    /// Fetches a page of photo assets matching the given predicate.
    ///
    /// Uses PHFetchOptions with fetchOffset/fetchLimit for pagination.
    /// All PHAsset objects are mapped to domain PhotoAsset values via PHAssetMapper.
    ///
    /// - Parameters:
    ///   - predicate: Filter criteria for the query.
    ///   - pageSize: Maximum number of assets per page.
    /// - Returns: An AssetPage containing the current page's assets and pagination info.
    /// - Throws: `DomainError.insufficientPermission` if no read access, or
    ///           `DomainError.invalidState` if PhotoKit fetch fails.
    func fetchAssets(predicate: PhotoPredicate, pageSize: Int, pageOffset: Int = 0) async throws -> AssetPage {
        // Verify permission before fetching
        let status = permissionManager.checkCurrentStatus()
        guard status == .authorized || status == .limited else {
            throw DomainError.insufficientPermission(required: .read)
        }

        // Configure fetch options — no fetchLimit so we get total count
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

        // Apply date range filter if present
        if let dateRange = predicate.dateRange {
            options.predicate = NSPredicate(
                format: "creationDate >= %@ AND creationDate <= %@",
                dateRange.from as NSDate,
                dateRange.to as NSDate
            )
        }

        // Determine PHAssetMediaType based on predicate
        let fetchResult: PHFetchResult<PHAsset>
        switch predicate.mediaType {
        case .image:
            fetchResult = PHAsset.fetchAssets(with: .image, options: options)
        case .video:
            fetchResult = PHAsset.fetchAssets(with: .video, options: options)
        case .all:
            fetchResult = PHAsset.fetchAssets(with: options)
        }

        let totalCount = fetchResult.count

        // Slice the requested page from the full result
        let endIndex = min(pageOffset + pageSize, totalCount)
        let fetchedCount = max(0, endIndex - pageOffset)

        // Map PHAssets to domain PhotoAssets (without thumbnails for performance)
        var assets: [PhotoAsset] = []
        assets.reserveCapacity(fetchedCount)

        for index in pageOffset..<endIndex {
            let phAsset = fetchResult.object(at: index)
            let photoAsset = PHAssetMapper.map(phAsset, thumbnailData: nil)
            assets.append(photoAsset)
        }

        let currentOffset = pageOffset + fetchedCount
        let hasMore = fetchedCount == pageSize && totalCount > 0
        let nextOffset = hasMore ? currentOffset : nil

        return AssetPage(assets: assets, hasMore: hasMore, nextOffset: nextOffset)
    }

    /// Fetches the full-resolution image data for a given asset.
    ///
    /// Uses PHImageManager to request the original image data.
    /// Handles iCloud photos gracefully — returns nil data for undownloaded assets.
    ///
    /// - Parameter assetID: The identifier of the asset to fetch.
    /// - Returns: The full-resolution image data.
    /// - Throws: `DomainError.assetNotFound` if the asset does not exist,
    ///           `DomainError.invalidState` if image data cannot be retrieved.
    func fetchFullResolutionImage(for assetID: AssetID) async throws -> Data {
        // Verify permission
        let status = permissionManager.checkCurrentStatus()
        guard status == .authorized || status == .limited else {
            throw DomainError.insufficientPermission(required: .read)
        }

        // Fetch the PHAsset by localIdentifier
        let fetchResult = PHAsset.fetchAssets(
            withLocalIdentifiers: [assetID.rawValue],
            options: nil
        )

        guard fetchResult.firstObject != nil else {
            throw DomainError.assetNotFound(assetID)
        }

        let phAsset = fetchResult.firstObject!

        // Request full-resolution image data using async wrapper
        let data = try await requestImageData(for: phAsset)

        guard let imageData = data, !imageData.isEmpty else {
            throw DomainError.invalidState(
                reason: "Image data not available (possibly not downloaded from iCloud)"
            )
        }

        return imageData
    }

    /// Fetches a thumbnail image for a given asset at the specified size.
    ///
    /// Uses an in-memory NSCache (100MB) to avoid redundant PHImageManager calls.
    /// Returns a downscaled JPEG suitable for grid display.
    ///
    /// - Parameters:
    ///   - assetID: The identifier of the asset.
    ///   - size: Target thumbnail size in points.
    /// - Returns: JPEG image data for the thumbnail.
    /// - Throws: `DomainError.assetNotFound` or `DomainError.invalidState`.
    func fetchThumbnail(for assetID: AssetID, size: CGSize) async throws -> Data {
        let cacheKey = "\(assetID.rawValue)-\(Int(size.width))x\(Int(size.height))" as NSString

        // Check cache first
        if let cached = thumbnailCache.object(forKey: cacheKey) as? Data {
            return cached
        }

        // Fetch PHAsset
        let fetchResult = PHAsset.fetchAssets(
            withLocalIdentifiers: [assetID.rawValue],
            options: nil
        )
        guard let phAsset = fetchResult.firstObject else {
            throw DomainError.assetNotFound(assetID)
        }

        // Request thumbnail from PHImageManager
        let image = try await requestThumbnailImage(for: phAsset, targetSize: size)

        guard let data = image?.jpegData() else {
            throw DomainError.invalidState(reason: "Failed to generate thumbnail")
        }

        // Store in cache
        thumbnailCache.setObject(data as NSData, forKey: cacheKey, cost: data.count)

        return data
    }

    // MARK: - Private PHImageManager Async Wrappers

    /// Wraps PHImageManager thumbnail request in async/await.
    private func requestThumbnailImage(for asset: PHAsset, targetSize: CGSize) async throws -> NSImage? {
        try await withCheckedThrowingContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = false
            options.isSynchronous = false

            var hasResumed = false
            let lock = NSLock()

            PHImageManager.default().requestImage(
                for: asset,
                targetSize: CGSize(
                    width: targetSize.width * 3,  // 3x for crisp Retina
                    height: targetSize.height * 3
                ),
                contentMode: .aspectFill,
                options: options
            ) { image, _ in
                lock.lock()
                defer { lock.unlock() }

                guard !hasResumed else { return }
                hasResumed = true
                continuation.resume(returning: image)
            }
        }
    }

    /// Wraps PHImageManager image data request in async/await.
    ///
    /// Uses a flag to ensure the continuation is resumed only once,
    /// since PHImageManager may call the completion handler multiple times.
    private func requestImageData(for asset: PHAsset) async throws -> Data? {
        try await withCheckedThrowingContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = false
            options.isSynchronous = false

            var hasResumed = false
            let lock = NSLock()

            PHImageManager.default().requestImageDataAndOrientation(
                for: asset,
                options: options
            ) { data, _, _, _ in
                lock.lock()
                defer { lock.unlock() }

                guard !hasResumed else { return }
                hasResumed = true
                continuation.resume(returning: data)
            }
        }
    }
}
