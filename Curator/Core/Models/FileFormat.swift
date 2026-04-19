import Foundation

/// Supported photo file formats.
enum FileFormat: String, Sendable, Equatable, Codable {
    case jpeg
    case png
    case heic
    case tiff
    case raw
    case unknown

    /// Infers format from a file path extension.
    static func from(pathExtension: String) -> FileFormat {
        let ext = pathExtension.lowercased()
        switch ext {
        case "jpg", "jpeg": return .jpeg
        case "png": return .png
        case "heic": return .heic
        case "tiff", "tif": return .tiff
        case "cr2", "nef", "arw", "dng", "raw", "orf", "rw2": return .raw
        default: return .unknown
        }
    }

    /// File extensions recognized as photo files.
    static let supportedExtensions: Set<String> = [
        "jpg", "jpeg", "png", "heic", "tiff", "tif",
        "cr2", "nef", "arw", "dng", "raw", "orf", "rw2"
    ]
}
