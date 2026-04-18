import Foundation

/// Location coordinates for a photo asset.
///
/// Wraps latitude and longitude as a simple Sendable value type.
struct LocationData: Sendable, Equatable {
    let latitude: Double
    let longitude: Double
}

/// Metadata associated with a photo asset.
///
/// All fields are optional because metadata may not be available
/// for all assets (e.g., photos without GPS data or titles).
struct AssetMetadata: Sendable, Equatable {
    let creationDate: Date?
    let title: String?
    let description: String?
    let keywords: [String]
    let location: LocationData?
}
