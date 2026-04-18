import Foundation

/// A page of photo asset results from a paginated query.
///
/// Contains the assets for the current page and a flag indicating
/// whether more results are available.
struct AssetPage: Sendable {
    let assets: [PhotoAsset]
    let hasMore: Bool
}
