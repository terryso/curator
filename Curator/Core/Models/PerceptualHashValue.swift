import Foundation

/// Value type representing the perceptual hash (pHash) of a photo asset.
///
/// Stores the computed 64-bit hash value along with the associated asset ID
/// and timestamp. Provides a static method for computing Hamming distance
/// between two hash values for similarity comparison.
struct PerceptualHashValue: Sendable, Codable, Equatable, Hashable {
    /// The asset this hash was computed for.
    let assetID: AssetID

    /// The 64-bit perceptual hash value.
    let hash: UInt64

    /// When this hash was computed.
    let computedAt: Date

    /// Computes the Hamming distance between two 64-bit hash values.
    ///
    /// The Hamming distance is the number of differing bits between the two values.
    /// A distance of 0 means identical hashes; a distance of 64 means completely different.
    ///
    /// - Parameters:
    ///   - a: First hash value.
    ///   - b: Second hash value.
    /// - Returns: The number of differing bits (0-64).
    static func hammingDistance(_ a: UInt64, _ b: UInt64) -> Int {
        // XOR gives us 1s in positions where bits differ
        let xor = a ^ b
        // Count the number of 1-bits (population count)
        return xor.nonzeroBitCount
    }

    /// Checks whether this hash value is similar to another within a given threshold.
    ///
    /// - Parameters:
    ///   - other: The other hash value to compare against.
    ///   - threshold: Maximum Hamming distance to be considered similar (default: 10).
    /// - Returns: `true` if the Hamming distance is within the threshold.
    func isSimilar(to other: PerceptualHashValue, threshold: Int = 10) -> Bool {
        Self.hammingDistance(self.hash, other.hash) <= threshold
    }
}
