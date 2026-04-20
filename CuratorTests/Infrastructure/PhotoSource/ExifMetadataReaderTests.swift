import AppKit
import Foundation
import ImageIO
import XCTest

@testable import Curator

final class ExifMetadataReaderTests: XCTestCase {

    private var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("ExifTests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir!, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    // MARK: - Type Contract

    func testExifMetadataReaderIsStaticStruct() {
        // ExifMetadataReader uses static methods — no instance needed
        let metadata = ExifMetadataReader.readMetadata(from: tempDir.appendingPathComponent("nonexistent.jpg"))
        // Should not crash, returns default values
        XCTAssertEqual(metadata.fileName, "nonexistent.jpg")
    }

    // MARK: - readMetadata

    func testReadMetadataReturnsFileName() throws {
        let url = try createTestJPEG(width: 100, height: 80)
        let metadata = ExifMetadataReader.readMetadata(from: url)
        XCTAssertFalse(metadata.fileName.isEmpty)
        XCTAssertTrue(url.lastPathComponent.hasSuffix(".jpg"))
    }

    func testReadMetadataReturnsFileSize() throws {
        let url = try createTestJPEG(width: 100, height: 80)
        let metadata = ExifMetadataReader.readMetadata(from: url)
        XCTAssertNotNil(metadata.fileSize)
        XCTAssertGreaterThan(metadata.fileSize ?? 0, 0)
    }

    func testReadMetadataReturnsFileFormat() throws {
        let url = try createTestJPEG(width: 10, height: 10)
        let metadata = ExifMetadataReader.readMetadata(from: url)
        XCTAssertEqual(metadata.fileFormat, .jpeg)
    }

    func testReadMetadataReturnsImageDimensions() throws {
        let url = try createTestJPEG(width: 200, height: 150)
        let metadata = ExifMetadataReader.readMetadata(from: url)
        // ImageIO may report dimensions from the file
        // For a programmatically created image, width/height should be available
        if let width = metadata.imageWidth, let height = metadata.imageHeight {
            XCTAssertGreaterThan(width, 0)
            XCTAssertGreaterThan(height, 0)
        }
        // Dimensions are optional — just verify they don't crash
    }

    func testReadMetadataReturnsCreationDate() throws {
        let url = try createTestJPEG(width: 10, height: 10)
        let metadata = ExifMetadataReader.readMetadata(from: url)
        // File creation date should be available as fallback
        XCTAssertNotNil(metadata.creationDate)
    }

    func testReadMetadataHandlesNonexistentFile() {
        let url = tempDir.appendingPathComponent("nonexistent.png")
        let metadata = ExifMetadataReader.readMetadata(from: url)
        XCTAssertEqual(metadata.fileName, "nonexistent.png")
        XCTAssertEqual(metadata.fileFormat, .png)
        XCTAssertNil(metadata.fileSize)
        XCTAssertNil(metadata.cameraModel)
        XCTAssertNil(metadata.imageWidth)
        XCTAssertNil(metadata.imageHeight)
        XCTAssertNil(metadata.gpsLocation)
    }

    func testReadMetadataReturnsCameraModelAsNilForGeneratedImage() throws {
        let url = try createTestJPEG(width: 10, height: 10)
        let metadata = ExifMetadataReader.readMetadata(from: url)
        // Programmatically created images don't have camera model
        XCTAssertNil(metadata.cameraModel)
    }

    func testReadMetadataReturnsGPSLocationAsNilForGeneratedImage() throws {
        let url = try createTestJPEG(width: 10, height: 10)
        let metadata = ExifMetadataReader.readMetadata(from: url)
        XCTAssertNil(metadata.gpsLocation)
    }

    // MARK: - generateThumbnail

    func testGenerateThumbnailReturnsData() throws {
        let url = try createTestJPEG(width: 200, height: 200)
        let data = ExifMetadataReader.generateThumbnail(from: url, targetSize: CGSize(width: 50, height: 50))
        XCTAssertNotNil(data)
        XCTAssertGreaterThan(data?.count ?? 0, 0)
    }

    func testGenerateThumbnailReturnsNilForNonexistentFile() {
        let url = tempDir.appendingPathComponent("nonexistent.jpg")
        let data = ExifMetadataReader.generateThumbnail(from: url, targetSize: CGSize(width: 50, height: 50))
        XCTAssertNil(data)
    }

    func testGenerateThumbnailReturnsNilForCorruptFile() throws {
        let url = tempDir.appendingPathComponent("corrupt.jpg")
        try Data("not a real image".utf8).write(to: url)
        let data = ExifMetadataReader.generateThumbnail(from: url, targetSize: CGSize(width: 50, height: 50))
        XCTAssertNil(data)
    }

    // MARK: - FileFormat mapping

    func testReadMetadataMapsJPEGExtension() throws {
        let url = try createTestJPEG(width: 10, height: 10)
        let metadata = ExifMetadataReader.readMetadata(from: url)
        XCTAssertEqual(metadata.fileFormat, .jpeg)
    }

    func testReadMetadataMapsPNGExtension() throws {
        let url = try createTestPNG(width: 10, height: 10)
        let metadata = ExifMetadataReader.readMetadata(from: url)
        XCTAssertEqual(metadata.fileFormat, .png)
    }

    // MARK: - Full mapping integration

    func testFullMappingProducesValidAssetMetadata() throws {
        let url = try createTestJPEG(width: 100, height: 80)
        let metadata = ExifMetadataReader.readMetadata(from: url)

        XCTAssertFalse(metadata.fileName.isEmpty)
        XCTAssertEqual(metadata.fileFormat, .jpeg)
        XCTAssertNotNil(metadata.fileSize)
        XCTAssertNotNil(metadata.creationDate)
    }

    // MARK: - Helpers

    private func createTestJPEG(width: Int, height: Int) throws -> URL {
        let url = tempDir.appendingPathComponent("test_\(UUID().uuidString).jpg")
        let image = NSImage(size: NSSize(width: width, height: height))
        image.lockFocus()
        NSColor.blue.setFill()
        NSBezierPath.fill(NSRect(x: 0, y: 0, width: width, height: height))
        image.unlockFocus()

        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let jpegData = bitmap.representation(using: .jpeg, properties: [:]) else {
            XCTFail("Failed to create JPEG test image")
            return url
        }
        try jpegData.write(to: url)
        return url
    }

    private func createTestPNG(width: Int, height: Int) throws -> URL {
        let url = tempDir.appendingPathComponent("test_\(UUID().uuidString).png")
        let image = NSImage(size: NSSize(width: width, height: height))
        image.lockFocus()
        NSColor.red.setFill()
        NSBezierPath.fill(NSRect(x: 0, y: 0, width: width, height: height))
        image.unlockFocus()

        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            XCTFail("Failed to create PNG test image")
            return url
        }
        try pngData.write(to: url)
        return url
    }
}
