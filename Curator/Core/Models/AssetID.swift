import Foundation

/// Unique identifier for a photo asset, wrapping its file system path.
///
/// Provides type safety over raw string identifiers and supports
/// Hashable (for Set/Dictionary use) and Codable (for serialization).
struct AssetID: Sendable, Hashable, Codable {
    let rawValue: String
}
