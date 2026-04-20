import AppKit
import Foundation
import ImageIO

/// Reads EXIF metadata and generates thumbnails from photo files using ImageIO.
///
/// Static-only struct with no mutable state. Maps CGImageSource properties
/// to the domain AssetMetadata model, falling back to file attributes when
/// EXIF data is unavailable.
struct ExifMetadataReader: Sendable {

    /// Reads file system and EXIF metadata from a photo file.
    ///
    /// Falls back to FileManager file attributes for fields not available
    /// in EXIF (e.g., screenshots without camera metadata).
    static func readMetadata(from url: URL) -> AssetMetadata {
        let fileName = url.lastPathComponent
        let pathExtension = url.pathExtension
        let fileFormat = FileFormat.from(pathExtension: pathExtension)
        let fileSize = readFileSize(url: url)
        let fileCreationDate = readFileCreationDate(url: url)

        var cameraModel: String?
        var creationDate: Date?
        var imageWidth: Int?
        var imageHeight: Int?
        var gpsLocation: LocationData?

        if let source = CGImageSourceCreateWithURL(url as CFURL, nil) {
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any]

            if let tiff = properties?[kCGImagePropertyTIFFDictionary as String] as? [String: Any] {
                cameraModel = tiff[kCGImagePropertyTIFFModel as String] as? String
            }

            if let exif = properties?[kCGImagePropertyExifDictionary as String] as? [String: Any] {
                if let dateStr = exif[kCGImagePropertyExifDateTimeOriginal as String] as? String {
                    creationDate = parseExifDate(dateStr)
                }
            }

            imageWidth = properties?[kCGImagePropertyPixelWidth as String] as? Int
            imageHeight = properties?[kCGImagePropertyPixelHeight as String] as? Int

            if let gps = properties?[kCGImagePropertyGPSDictionary as String] as? [String: Any] {
                if let lat = gps[kCGImagePropertyGPSLatitude as String] as? Double,
                   let lon = gps[kCGImagePropertyGPSLongitude as String] as? Double {
                    gpsLocation = LocationData(latitude: lat, longitude: lon)
                }
            }
        }

        return AssetMetadata(
            fileName: fileName,
            fileSize: fileSize,
            creationDate: creationDate ?? fileCreationDate,
            cameraModel: cameraModel,
            imageWidth: imageWidth,
            imageHeight: imageHeight,
            gpsLocation: gpsLocation,
            fileFormat: fileFormat
        )
    }

    /// Generates a thumbnail image at the specified size using ImageIO.
    ///
    /// Returns nil if the file cannot be read or decoded.
    static func generateThumbnail(from url: URL, targetSize: CGSize) -> Data? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }

        let maxDimension = max(targetSize.width, targetSize.height)
        let options: [CFString: Any] = [
            kCGImageSourceThumbnailMaxPixelSize: maxDimension,
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true
        ]

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }

        let nsImage = NSImage(cgImage: cgImage, size: targetSize)
        guard let tiffData = nsImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            return nil
        }

        return pngData
    }

    // MARK: - Private Helpers

    private static let exifDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy:MM:dd HH:mm:ss"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    private static func parseExifDate(_ string: String) -> Date? {
        exifDateFormatter.date(from: string)
    }

    private static func readFileSize(url: URL) -> Int64? {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attrs[.size] as? Int64 else {
            return nil
        }
        return size
    }

    private static func readFileCreationDate(url: URL) -> Date? {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let date = attrs[.creationDate] as? Date else {
            return nil
        }
        return date
    }
}
