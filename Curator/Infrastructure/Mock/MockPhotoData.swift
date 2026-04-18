import AppKit
import CoreGraphics
import Foundation

enum MockPhotoData {

    static let samplePhotos: [PhotoAsset] = (0..<20).map { i in
        let baseDate = Date(timeIntervalSince1970: 1_700_000_000)
        let date = baseDate.addingTimeInterval(Double(i) * 86400 * 7)

        return PhotoAsset(
            id: AssetID(rawValue: "mock-photo-\(i)"),
            metadata: AssetMetadata(
                creationDate: date,
                title: titles[i % titles.count],
                description: "Sample photo \(i + 1) for UI testing",
                keywords: Array(keywords[i % keywords.count]),
                location: LocationData(latitude: 37.7749 + Double(i) * 0.01, longitude: -122.4194 + Double(i) * 0.01)
            ),
            thumbnailData: generateThumbnail(hue: CGFloat(i) / 20.0, size: 120)
        )
    }

    static func generateThumbnail(hue: CGFloat, size: CGFloat) -> Data {
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()

        let color = NSColor(hue: hue, saturation: 0.6, brightness: 0.8, alpha: 1.0)
        color.setFill()
        NSRect(x: 0, y: 0, width: size, height: size).fill()

        let label = "\(Int(hue * 20))"
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: size * 0.4, weight: .bold),
            .foregroundColor: NSColor.white,
        ]
        let str = NSAttributedString(string: label, attributes: attrs)
        let strSize = str.size()
        let strRect = NSRect(
            x: (size - strSize.width) / 2,
            y: (size - strSize.height) / 2,
            width: strSize.width,
            height: strSize.height
        )
        str.draw(in: strRect)

        image.unlockFocus()

        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:])
        else { return Data() }

        return pngData
    }

    private static let titles = [
        "Sunset at Beach",
        "Mountain Hike",
        "City Skyline",
        "Coffee Morning",
        "Garden Bloom",
        nil,
        "Family Dinner",
        nil,
        "Road Trip",
        "Snowy Peak",
    ]

    private static let keywords: [[String]] = [
        ["vacation", "beach"],
        ["hiking", "nature"],
        ["urban", "architecture"],
        ["food", "morning"],
        ["flowers", "garden"],
        ["family", "dinner"],
        ["travel", "car"],
        ["winter", "mountain"],
    ]
}
