import Foundation

/// Status of a duplicate group throughout its lifecycle.
enum DuplicateGroupStatus: Sendable, Equatable {
    /// Group detected but not yet reviewed.
    case pending
    /// User confirmed the group as true duplicates.
    case confirmed
    /// User rejected the group (not duplicates).
    case rejected
    /// Analysis failed for this group (LLM error, image decode failure, etc.).
    case analysisFailed

    /// Stable string representation for JSON serialization.
    var stringValue: String {
        switch self {
        case .pending: return "pending"
        case .confirmed: return "confirmed"
        case .rejected: return "rejected"
        case .analysisFailed: return "analysisFailed"
        }
    }
}

/// Value type representing a group of duplicate photos identified by the analysis pipeline.
///
/// Contains the photo assets in the group, a similarity score, an optional LLM-provided
/// reason explaining why these photos are duplicates, thumbnail data for preview,
/// and the current status of the group.
struct DuplicateGroup: Sendable, Identifiable {
    /// Unique identifier for this duplicate group.
    let id: UUID

    /// The photo assets that belong to this duplicate group.
    let assets: [PhotoAsset]

    /// Similarity score for this group (0.0 to 1.0).
    /// Higher scores indicate greater similarity.
    let similarityScore: Double

    /// Optional LLM-provided explanation for why these photos are considered duplicates.
    let reason: String?

    /// Thumbnail data keyed by AssetID for quick preview.
    let thumbnails: [AssetID: Data]

    /// Current status of this duplicate group.
    let status: DuplicateGroupStatus

    /// Creates a new DuplicateGroup.
    ///
    /// - Parameters:
    ///   - id: Unique identifier (auto-generated if not provided).
    ///   - assets: Photo assets in this group.
    ///   - similarityScore: Similarity score (0.0 to 1.0).
    ///   - reason: Optional LLM-provided match reason.
    ///   - thumbnails: Thumbnail data keyed by asset ID.
    ///   - status: Current group status.
    init(
        id: UUID = UUID(),
        assets: [PhotoAsset],
        similarityScore: Double,
        reason: String? = nil,
        thumbnails: [AssetID: Data] = [:],
        status: DuplicateGroupStatus
    ) {
        self.id = id
        self.assets = assets
        self.similarityScore = similarityScore
        self.reason = reason
        self.thumbnails = thumbnails
        self.status = status
    }
}

// MARK: - Comparable (sorted by similarityScore descending)

extension DuplicateGroup: Comparable {
    static func < (lhs: DuplicateGroup, rhs: DuplicateGroup) -> Bool {
        lhs.similarityScore > rhs.similarityScore
    }

    static func == (lhs: DuplicateGroup, rhs: DuplicateGroup) -> Bool {
        lhs.id == rhs.id
    }
}
