import Foundation
import Photos

/// Maps PHAsset from PhotoKit to domain model PhotoAsset.
///
/// Provides static mapping methods to convert PhotoKit types into
/// the project's domain value types. All mapped types are Sendable,
/// ensuring safe transfer across concurrency domains.
struct PHAssetMapper: Sendable {

    /// Maps a PHAsset to a PhotoAsset with optional thumbnail data.
    ///
    /// - Parameters:
    ///   - phAsset: The PhotoKit asset to map.
    ///   - thumbnailData: Optional pre-fetched thumbnail image data.
    /// - Returns: A domain-level PhotoAsset.
    static func map(_ phAsset: PHAsset, thumbnailData: Data?) -> PhotoAsset {
        PhotoAsset(
            id: AssetID(rawValue: phAsset.localIdentifier),
            metadata: mapMetadata(phAsset),
            thumbnailData: thumbnailData
        )
    }

    /// Maps PHAsset properties to AssetMetadata.
    ///
    /// PHAsset does not directly provide `title` or `description` fields.
    /// These are left as nil and may be populated in a future story via
    /// PHAssetResource or other PhotoKit APIs.
    ///
    /// - Parameter phAsset: The PhotoKit asset whose metadata to extract.
    /// - Returns: An AssetMetadata with all available fields populated.
    static func mapMetadata(_ phAsset: PHAsset) -> AssetMetadata {
        AssetMetadata(
            creationDate: phAsset.creationDate,
            title: nil,
            description: nil,
            keywords: [],
            location: mapLocation(phAsset)
        )
    }

    /// Maps PHAsset.location to LocationData.
    ///
    /// - Parameter phAsset: The PhotoKit asset whose location to extract.
    /// - Returns: A LocationData if location metadata exists, nil otherwise.
    static func mapLocation(_ phAsset: PHAsset) -> LocationData? {
        guard let location = phAsset.location else { return nil }
        return LocationData(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude
        )
    }
}
