import Accelerate
import CoreGraphics
import Foundation
import ImageIO

/// Actor implementing the perceptual hash (pHash) computation engine.
///
/// Uses Apple's Accelerate framework (vImage for image resize/grayscale,
/// vDSP for DCT-II) to compute a 64-bit perceptual hash for each photo.
/// The hash is robust against resizing, minor brightness/contrast changes,
/// and lossy compression.
actor PerceptualHasher: PerceptualHasherProtocol, Sendable {

    /// Size to resize images to before computing DCT.
    private static let resizeDimension = 32

    /// Size of the low-frequency DCT block to use for hashing.
    private static let hashBlockSize = 8

    /// Batch size for batch computation.
    private static let batchSize = 20

    /// Cache manager for persistent hash storage.
    private let cacheManager: HashCacheManager?

    /// Creates a new PerceptualHasher.
    ///
    /// - Parameter cacheManager: Optional cache manager for disk-based hash persistence.
    init(cacheManager: HashCacheManager? = nil) {
        self.cacheManager = cacheManager
    }

    // MARK: - PerceptualHasherProtocol

    func computeHash(for imageData: Data) async throws -> UInt64 {
        guard !imageData.isEmpty else {
            throw DomainError.analysisFailed(reason: "Image data is empty")
        }

        // Step 1: Decode image data to CGImage
        guard let cgImage = decodeToCGImage(imageData) else {
            throw DomainError.analysisFailed(
                reason: "Failed to decode image data — unsupported or corrupted format"
            )
        }

        // Step 2: Convert to 32x32 grayscale using vImage
        let grayscale = resizeAndGrayscale(cgImage)

        // Step 3: Apply 2D DCT-II via vDSP
        let dctCoefficients = computeDCT(grayscale)

        // Step 4: Extract top-left 8x8 low-frequency coefficients
        let lowFreq = extractLowFrequency(dctCoefficients)

        // Step 5: Compute median and generate 64-bit hash
        let hash = binarizeToHash(lowFreq)

        return hash
    }

    func computeHashes(
        for assets: [PhotoAsset],
        repository: PhotoLibraryRepository
    ) async throws -> [PerceptualHashValue] {
        // Step 1: Load cached hashes
        var cachedHashes: [String: UInt64] = [:]
        if let cacheManager {
            do {
                cachedHashes = try await cacheManager.loadCache()
            } catch {
                // Cache corruption — discard and recompute all hashes
                print("[PerceptualHasher] Warning: Failed to load cache, will recompute hashes: \(error)")
            }
        }

        // Step 2: Separate cached and uncached assets
        var results: [PerceptualHashValue] = []
        var uncachedAssets: [PhotoAsset] = []

        for asset in assets {
            if let cachedHash = cachedHashes[asset.id.rawValue] {
                // Note: `computedAt` is set to now because the cache format only stores
                // the hash value, not the original computation timestamp.
                // TODO: Enhance cache format to include computedAt for accurate timestamps.
                results.append(PerceptualHashValue(
                    assetID: asset.id,
                    hash: cachedHash,
                    computedAt: Date()
                ))
            } else {
                uncachedAssets.append(asset)
            }
        }

        // Step 3: Process uncached assets in batches
        var newHashes: [String: UInt64] = [:]

        for batchStart in stride(from: 0, to: uncachedAssets.count, by: Self.batchSize) {
            // Check for cancellation
            if Task.isCancelled {
                break
            }

            let batchEnd = min(batchStart + Self.batchSize, uncachedAssets.count)
            let batch = Array(uncachedAssets[batchStart..<batchEnd])

            for asset in batch {
                if Task.isCancelled {
                    break
                }

                do {
                    let imageData = try await repository.fetchFullResolutionImage(for: asset.id)
                    let hashValue = try await computeHash(for: imageData)

                    let result = PerceptualHashValue(
                        assetID: asset.id,
                        hash: hashValue,
                        computedAt: Date()
                    )
                    results.append(result)
                    newHashes[asset.id.rawValue] = hashValue
                } catch {
                    // Skip failed images, continue with remaining assets
                    continue
                }
            }
        }

        // Step 4: Save new hashes to cache
        if let cacheManager, !newHashes.isEmpty {
            do {
                try await cacheManager.saveCache(newHashes)
            } catch {
                print("[PerceptualHasher] Warning: Failed to save cache, hashes will need recomputation on next launch: \(error)")
            }
        }

        return results
    }

    func findSimilarPairs(
        hashes: [PerceptualHashValue],
        threshold: Int
    ) async -> [PairwiseSimilarity] {
        var pairs: [PairwiseSimilarity] = []

        for i in 0..<hashes.count {
            for j in (i + 1)..<hashes.count {
                let distance = PerceptualHashValue.hammingDistance(
                    hashes[i].hash,
                    hashes[j].hash
                )
                let isSimilar = distance <= threshold
                if isSimilar {
                    pairs.append(PairwiseSimilarity(
                        assetID1: hashes[i].assetID,
                        assetID2: hashes[j].assetID,
                        hammingDistance: distance,
                        isSimilar: isSimilar
                    ))
                }
            }
        }

        return pairs.sorted()
    }

    // MARK: - Private Helpers

    /// Decodes image data (JPEG, PNG, HEIC, TIFF) into a CGImage.
    private func decodeToCGImage(_ data: Data) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return nil
        }
        return CGImageSourceCreateImageAtIndex(source, 0, [
            kCGImageSourceShouldCache: false,
        ] as CFDictionary)
    }

    /// Resizes the image to 32x32 and converts to grayscale.
    ///
    /// Uses CoreGraphics for resizing and manual luminance calculation for grayscale conversion.
    private func resizeAndGrayscale(_ cgImage: CGImage) -> [Float] {
        let destWidth = Self.resizeDimension
        let destHeight = Self.resizeDimension

        // Create a 32x32 grayscale context
        let colorSpace = CGColorSpaceCreateDeviceGray()
        guard let context = CGContext(
            data: nil,
            width: destWidth,
            height: destHeight,
            bitsPerComponent: 8,
            bytesPerRow: destWidth,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            return [Float](repeating: 0, count: destWidth * destHeight)
        }

        // Draw the image scaled down to 32x32
        context.interpolationQuality = .high
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: destWidth, height: destHeight))

        // Extract the pixel data
        guard let dataPtr = context.data else {
            return [Float](repeating: 0, count: destWidth * destHeight)
        }

        let buffer = dataPtr.assumingMemoryBound(to: UInt8.self)
        var floatPixels = [Float](repeating: 0, count: destWidth * destHeight)
        for i in 0..<(destWidth * destHeight) {
            floatPixels[i] = Float(buffer[i])
        }

        return floatPixels
    }

    /// Computes a 2D DCT-II on the 32x32 grayscale matrix using vDSP.
    private func computeDCT(_ pixels: [Float]) -> [Float] {
        let n = Self.resizeDimension
        let totalSize = n * n

        // Setup DCT-II
        let setup = vDSP.DCT(
            count: n,
            transformType: .II
        )!

        // Apply 1D DCT to each row
        var rowDCT = [Float](repeating: 0, count: totalSize)
        for row in 0..<n {
            let rowStart = row * n
            let inputSlice = Array(pixels[rowStart..<rowStart + n])
            var outputSlice = [Float](repeating: 0, count: n)
            setup.transform(inputSlice, result: &outputSlice)
            for col in 0..<n {
                rowDCT[row * n + col] = outputSlice[col]
            }
        }

        // Apply 1D DCT to each column (second pass for 2D DCT)
        var result = [Float](repeating: 0, count: totalSize)
        for col in 0..<n {
            var colInput = [Float](repeating: 0, count: n)
            for row in 0..<n {
                colInput[row] = rowDCT[row * n + col]
            }
            var colOutput = [Float](repeating: 0, count: n)
            setup.transform(colInput, result: &colOutput)
            for row in 0..<n {
                result[row * n + col] = colOutput[row]
            }
        }

        return result
    }

    /// Extracts the top-left 8x8 low-frequency DCT coefficients.
    private func extractLowFrequency(_ dctCoefficients: [Float]) -> [Float] {
        let blockSize = Self.hashBlockSize
        var lowFreq = [Float](repeating: 0, count: blockSize * blockSize)

        for row in 0..<blockSize {
            for col in 0..<blockSize {
                lowFreq[row * blockSize + col] = dctCoefficients[row * Self.resizeDimension + col]
            }
        }

        return lowFreq
    }

    /// Binarizes the 64 low-frequency coefficients into a 64-bit hash.
    ///
    /// Computes the median of the coefficients, then sets each bit to 1
    /// if the coefficient is strictly above the median, 0 otherwise.
    /// Note: The DC coefficient (position [0,0]) is included; this makes the hash
    /// slightly sensitive to overall brightness, but the median binarization provides
    /// robustness for typical brightness adjustments.
    private func binarizeToHash(_ coefficients: [Float]) -> UInt64 {
        precondition(coefficients.count == 64, "Expected 64 coefficients for 64-bit hash")

        // Compute the median
        let sorted = coefficients.sorted()
        let median = (sorted[31] + sorted[32]) / 2.0

        // Generate hash bits
        var hash: UInt64 = 0
        for (index, coeff) in coefficients.enumerated() {
            if coeff > median {
                hash |= (1 as UInt64) << UInt64(index)
            }
        }

        return hash
    }
}
