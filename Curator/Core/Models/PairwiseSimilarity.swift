import Foundation

/// Value type representing the similarity comparison result between two photos.
///
/// Contains the IDs of both photos, the computed Hamming distance between their
/// perceptual hashes, and whether they are considered similar based on the threshold.
struct PairwiseSimilarity: Sendable, Identifiable, Comparable, Equatable {
    /// Unique identifier for this similarity record.
    let id: UUID

    /// The first photo's asset ID.
    let assetID1: AssetID

    /// The second photo's asset ID.
    let assetID2: AssetID

    /// The Hamming distance between the two photos' perceptual hashes (0-64).
    let hammingDistance: Int

    /// Whether the two photos are considered similar (within the threshold).
    let isSimilar: Bool

    /// Creates a new PairwiseSimilarity with an auto-generated UUID.
    init(
        assetID1: AssetID,
        assetID2: AssetID,
        hammingDistance: Int,
        isSimilar: Bool
    ) {
        self.id = UUID()
        self.assetID1 = assetID1
        self.assetID2 = assetID2
        self.hammingDistance = hammingDistance
        self.isSimilar = isSimilar
    }

    // Comparable: sorted by hammingDistance ascending (lower distance = more similar = comes first)
    static func < (lhs: PairwiseSimilarity, rhs: PairwiseSimilarity) -> Bool {
        lhs.hammingDistance < rhs.hammingDistance
    }
}
