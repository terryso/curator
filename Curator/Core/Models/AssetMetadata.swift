import Foundation

/// Location coordinates extracted from photo EXIF GPS data.
struct LocationData: Sendable, Equatable {
    let latitude: Double
    let longitude: Double
}

/// Metadata associated with a photo asset from file system / EXIF data.
///
/// All fields are optional because metadata availability depends on
/// the source file — camera model may not exist for screenshots,
/// GPS may be stripped, etc.
struct AssetMetadata: Sendable, Equatable {
    let fileName: String
    let fileSize: Int64?
    let creationDate: Date?
    let cameraModel: String?
    let imageWidth: Int?
    let imageHeight: Int?
    let gpsLocation: LocationData?
    let fileFormat: FileFormat?
}
