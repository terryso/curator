import Foundation

/// A photo asset value type representing a single photo in the library.
///
/// Designed as a Sendable value type for safe use across concurrency domains.
/// The thumbnailData is optional and loaded on demand.
struct PhotoAsset: Sendable, Identifiable {
    let id: AssetID
    let metadata: AssetMetadata
    var thumbnailData: Data?
}
