import AppKit
import CoreGraphics
import Foundation
import UniformTypeIdentifiers

/// Actor implementing thumbnail generation using CoreGraphics.
///
/// Generates JPEG-compressed thumbnails at specified sizes for photo assets.
/// Uses CoreGraphics for image scaling to avoid main-thread dependencies.
/// Individual asset failures are handled gracefully in batch mode.
actor ThumbnailGenerator: ThumbnailGeneratorProtocol {
    /// Default thumbnail target size.
    static let defaultTargetSize = CGSize(width: 200, height: 200)

    /// JPEG compression quality for thumbnails (0.0 to 1.0).
    private let compressionQuality: CGFloat

    /// Creates a new ThumbnailGenerator.
    ///
    /// - Parameter compressionQuality: JPEG compression quality (default: 0.7).
    init(compressionQuality: CGFloat = 0.7) {
        self.compressionQuality = compressionQuality
    }

    /// Generates a thumbnail for a single asset.
    ///
    /// Fetches the full-resolution image from the repository, scales it to
    /// the target size using CoreGraphics, and returns JPEG-compressed data.
    func generateThumbnail(
        for assetID: AssetID,
        repository: PhotoLibraryRepository,
        targetSize: CGSize
    ) async throws -> Data {
        let imageData = try await repository.fetchFullResolutionImage(for: assetID)
        return try scaleAndCompress(imageData: imageData, targetSize: targetSize)
    }

    /// Generates thumbnails for multiple assets in batch.
    ///
    /// Individual failures are skipped — the returned dictionary only contains
    /// entries for assets that were successfully processed.
    func generateThumbnails(
        for assets: [PhotoAsset],
        repository: PhotoLibraryRepository,
        targetSize: CGSize
    ) async -> [AssetID: Data] {
        var result: [AssetID: Data] = [:]

        for asset in assets {
            if Task.isCancelled { break }

            do {
                let thumbnailData = try await generateThumbnail(
                    for: asset.id,
                    repository: repository,
                    targetSize: targetSize
                )
                result[asset.id] = thumbnailData
            } catch {
                // Skip failed assets in batch mode
                continue
            }
        }

        return result
    }

    // MARK: - Private

    /// Scales image data to the target size and compresses as JPEG.
    ///
    /// - Parameters:
    ///   - imageData: Raw image data (JPEG, PNG, etc.).
    ///   - targetSize: Target dimensions for the thumbnail.
    /// - Returns: JPEG-compressed thumbnail data.
    /// - Throws: `DomainError.analysisFailed` if the image cannot be decoded or processed.
    private func scaleAndCompress(imageData: Data, targetSize: CGSize) throws -> Data {
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw DomainError.analysisFailed(reason: "Failed to decode image data for thumbnail generation")
        }

        let scaledImage = try scaleCGImage(cgImage, to: targetSize)

        guard let mutableData = CFDataCreateMutable(nil, 0),
              let destination = CGImageDestinationCreateWithData(
                mutableData,
                UTType.jpeg.identifier as CFString,
                1,
                nil
              ) else {
            throw DomainError.analysisFailed(reason: "Failed to create image destination for thumbnail")
        }

        CGImageDestinationAddImage(destination, scaledImage, [
            kCGImageDestinationLossyCompressionQuality: compressionQuality,
        ] as CFDictionary)

        guard CGImageDestinationFinalize(destination) else {
            throw DomainError.analysisFailed(reason: "Failed to finalize thumbnail JPEG compression")
        }

        return mutableData as Data
    }

    /// Scales a CGImage to the target size using CGContext.
    ///
    /// Maintains aspect ratio by fitting within the target size.
    /// - Throws: `DomainError.analysisFailed` if the scaled image cannot be created.
    private func scaleCGImage(_ image: CGImage, to targetSize: CGSize) throws -> CGImage {
        let sourceWidth = CGFloat(image.width)
        let sourceHeight = CGFloat(image.height)

        // Calculate aspect-fit scaling
        let scaleWidth = targetSize.width / sourceWidth
        let scaleHeight = targetSize.height / sourceHeight
        let scale = min(scaleWidth, scaleHeight)

        let newWidth = Int(sourceWidth * scale)
        let newHeight = Int(sourceHeight * scale)

        // Use RGB color space for JPEG output
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: newWidth,
            height: newHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else {
            throw DomainError.analysisFailed(reason: "Failed to create CGContext for thumbnail scaling")
        }

        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))

        guard let scaledImage = context.makeImage() else {
            throw DomainError.analysisFailed(reason: "Failed to render scaled thumbnail image")
        }

        return scaledImage
    }
}
