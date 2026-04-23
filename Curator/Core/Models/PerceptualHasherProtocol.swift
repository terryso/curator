import Foundation

/// Protocol defining the perceptual hash computation interface.
///
/// Defined in the Domain layer; concrete implementations reside in
/// the Infrastructure layer. Supports test-time replacement with mock implementations.
protocol PerceptualHasherProtocol: Sendable {
    /// Computes the perceptual hash for a single image.
    ///
    /// - Parameter imageData: Raw image data (JPEG, PNG, HEIC, TIFF, etc.).
    /// - Returns: A 64-bit hash value.
    /// - Throws: `DomainError.analysisFailed` if the image cannot be decoded.
    func computeHash(for imageData: Data) async throws -> UInt64

    /// Computes perceptual hashes for a batch of photo assets.
    ///
    /// Loads cached hashes from disk, fetches images for uncached assets,
    /// and computes their hashes. Supports cancellation — partial results
    /// are returned if cancelled mid-batch.
    ///
    /// - Parameters:
    ///   - assets: Array of photo assets to hash.
    ///   - repository: Repository to fetch full-resolution image data from.
    /// - Returns: Array of computed hash values (including cached ones).
    /// - Throws: `DomainError.analysisFailed` if a critical error occurs.
    func computeHashes(
        for assets: [PhotoAsset],
        repository: PhotoLibraryRepository
    ) async throws -> [PerceptualHashValue]

    /// Finds all pairs of similar photos from a set of hash values.
    ///
    /// Performs an O(n^2) comparison of all pairs and returns those
    /// with Hamming distance below the given threshold.
    ///
    /// - Parameters:
    ///   - hashes: Array of computed hash values.
    ///   - threshold: Maximum Hamming distance to be considered similar.
    /// - Returns: Array of PairwiseSimilarity sorted by Hamming distance ascending.
    func findSimilarPairs(
        hashes: [PerceptualHashValue],
        threshold: Int
    ) async -> [PairwiseSimilarity]
}
