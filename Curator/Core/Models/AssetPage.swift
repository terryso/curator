import Foundation

/// A page of photo asset results from a paginated query.
///
/// Contains the assets for the current page, a flag indicating
/// whether more results are available, and an optional cursor for
/// fetching the next page.
struct AssetPage: Sendable {
    let assets: [PhotoAsset]
    let hasMore: Bool

    /// Offset for the next page of results, used as a cursor.
    /// Nil when `hasMore` is false (no further pages).
    let nextOffset: Int?

    /// Creates an AssetPage with explicit pagination info.
    /// - Parameters:
    ///   - assets: The photo assets in this page.
    ///   - hasMore: Whether more results exist beyond this page.
    ///   - nextOffset: The fetch offset to use for the next page request.
    init(assets: [PhotoAsset], hasMore: Bool, nextOffset: Int? = nil) {
        self.assets = assets
        self.hasMore = hasMore
        self.nextOffset = nextOffset
    }
}
