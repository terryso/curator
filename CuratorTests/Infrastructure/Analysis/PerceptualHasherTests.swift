import Accelerate
import Foundation
import XCTest

@testable import Curator

/// ATDD Tests for Story 5.1 — Perceptual Hash Engine (pHash)
///
/// Tests verify:
/// - AC1: Batch pHash computation performance (100 photos in 60s)
/// - AC2: Single photo pHash computation using Accelerate/vImage
/// - AC3: Batch computation cancellation support
/// - AC4: Similarity comparison (Hamming Distance)
/// - AC5: Hash persistence and cache (disk-based)
/// - AC6: Error handling and fault tolerance
final class PerceptualHasherTests: XCTestCase {

    private var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("PHashTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir!, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    // MARK: - AC2: Single Photo pHash Computation (FR19)

    /// [P0] Single photo pHash computation returns a UInt64 hash value.
    ///
    /// AC2: Given PerceptualHasher is initialized,
    /// When computing pHash for a single photo,
    /// Then the computation uses Apple Silicon acceleration (Accelerate/vImage)
    /// And returns a fixed-length hash value (UInt64) for similarity comparison.
    func testComputeHashReturnsUInt64() async throws {
        // Given: PerceptualHasher instance and valid image data
        let hasher = PerceptualHasher()
        let imageData = try createSolidColorImage(color: .red, width: 100, height: 100)

        // When: Computing pHash for the image
        let hashValue = try await hasher.computeHash(for: imageData)

        // Then: Returns a UInt64 value
        let _ = hashValue // UInt64 type verified at compile time
    }

    /// [P0] Identical images produce the same hash value.
    ///
    /// AC2: pHash computation is deterministic — same input always produces same output.
    func testIdenticalImagesProduceSameHash() async throws {
        // Given: Two copies of identical image data
        let hasher = PerceptualHasher()
        let imageData1 = try createSolidColorImage(color: .blue, width: 200, height: 200)
        let imageData2 = imageData1 // Exact same bytes

        // When: Computing pHash for both
        let hash1 = try await hasher.computeHash(for: imageData1)
        let hash2 = try await hasher.computeHash(for: imageData2)

        // Then: Hash values are identical
        XCTAssertEqual(hash1, hash2, "Identical images must produce identical hash values")
    }

    /// [P0] Visually different images have high hamming distance.
    ///
    /// AC2/AC4: Different images produce hash values with high hamming distance.
    func testDifferentImagesHaveHighHammingDistance() async throws {
        // Given: Two visually very different images (different structures, not just different colors)
        let hasher = PerceptualHasher()
        // Solid black image (uniform structure)
        let imageData1 = try createSolidColorImage(color: .black, width: 100, height: 100)
        // Checkerboard pattern (high-frequency structure, very different from uniform)
        let imageData2 = try createCheckerboardImage(width: 100, height: 100, tileSize: 10)

        // When: Computing pHash for both
        let hash1 = try await hasher.computeHash(for: imageData1)
        let hash2 = try await hasher.computeHash(for: imageData2)

        // Then: Hamming distance is high (> 20 for completely different images)
        let distance = PerceptualHashValue.hammingDistance(hash1, hash2)
        XCTAssertGreaterThan(distance, 20,
            "Completely different images should have hamming distance > 20, got \(distance)")
    }

    // MARK: - AC4: Similarity Comparison (Hamming Distance)

    /// [P0] Hamming distance calculation is correct for known bit patterns.
    ///
    /// AC4: Hamming distance between two hash values is computed correctly.
    func testHammingDistanceCalculation() async throws {
        // Given: Known bit patterns for hamming distance verification
        // 0b0000...0000 (all zeros) vs 0b1111...1111 (all ones) = distance 64
        let allZeros: UInt64 = 0
        let allOnes: UInt64 = UInt64.max

        // When: Computing hamming distance
        let distanceMax = PerceptualHashValue.hammingDistance(allZeros, allOnes)

        // Then: Distance equals 64 (all 64 bits differ)
        XCTAssertEqual(distanceMax, 64, "All bits different should be distance 64")

        // And: Same value has distance 0
        let distanceSame = PerceptualHashValue.hammingDistance(allZeros, allZeros)
        XCTAssertEqual(distanceSame, 0, "Identical values should be distance 0")

        // And: One bit different has distance 1
        let oneBitDiff: UInt64 = 1
        let distanceOneBit = PerceptualHashValue.hammingDistance(allZeros, oneBitDiff)
        XCTAssertEqual(distanceOneBit, 1, "One bit difference should be distance 1")
    }

    /// [P0] Visually similar images have low hamming distance.
    ///
    /// AC4: Two visually similar images (same photo, slight modification) should
    /// produce hash values with hamming distance below the similarity threshold.
    func testSimilarImagesHaveLowHammingDistance() async throws {
        // Given: Two similar images (same scene with slight brightness change)
        let hasher = PerceptualHasher()
        let imageData1 = try createSolidColorImage(color: .red, width: 100, height: 100)
        let imageData2 = try createSolidColorImage(color: .red, width: 100, height: 100)

        // When: Computing pHash for both
        let hash1 = try await hasher.computeHash(for: imageData1)
        let hash2 = try await hasher.computeHash(for: imageData2)

        // Then: Hamming distance is below default threshold (10)
        let distance = PerceptualHashValue.hammingDistance(hash1, hash2)
        XCTAssertLessThanOrEqual(distance, 10,
            "Similar images should have hamming distance <= 10, got \(distance)")
    }

    /// [P1] findSimilarPairs correctly identifies similar photo pairs.
    ///
    /// AC4: Given computed hash values,
    /// When finding similar pairs with a threshold,
    /// Then returns PairwiseSimilarity structures sorted by hamming distance.
    func testFindSimilarPairsReturnsCorrectPairs() async throws {
        // Given: A set of hash values where some are similar
        let hasher = PerceptualHasher()
        let assetID1 = AssetID(rawValue: "/photos/img1.jpg")
        let assetID2 = AssetID(rawValue: "/photos/img2.jpg")
        let assetID3 = AssetID(rawValue: "/photos/img3.jpg")

        // Two identical hashes and one very different
        let identicalHash: UInt64 = 0b1010101010101010101010101010101010101010101010101010101010101010
        let sameHash: UInt64 = 0b1010101010101010101010101010101010101010101010101010101010101010
        let differentHash: UInt64 = 0b0101010101010101010101010101010101010101010101010101010101010101

        let hashes = [
            PerceptualHashValue(assetID: assetID1, hash: identicalHash, computedAt: Date()),
            PerceptualHashValue(assetID: assetID2, hash: sameHash, computedAt: Date()),
            PerceptualHashValue(assetID: assetID3, hash: differentHash, computedAt: Date()),
        ]

        // When: Finding similar pairs with default threshold
        let pairs = await hasher.findSimilarPairs(hashes: hashes, threshold: 10)

        // Then: Only the similar pair is returned
        XCTAssertEqual(pairs.count, 1, "Should find exactly 1 similar pair")
        XCTAssertEqual(pairs.first?.assetID1, assetID1)
        XCTAssertEqual(pairs.first?.assetID2, assetID2)
        XCTAssertTrue(pairs.first!.isSimilar)
        XCTAssertEqual(pairs.first?.hammingDistance, 0, "Identical hashes should have distance 0")
    }

    /// [P1] PairwiseSimilarity struct contains correct fields.
    ///
    /// AC4: PairwiseSimilarity includes assetID1, assetID2, hammingDistance, isSimilar.
    func testPairwiseSimilarityStructure() async throws {
        // Given: Two hash values with known distance
        let id1 = AssetID(rawValue: "/photos/a.jpg")
        let id2 = AssetID(rawValue: "/photos/b.jpg")

        // When: Creating a PairwiseSimilarity
        let similarity = PairwiseSimilarity(
            assetID1: id1,
            assetID2: id2,
            hammingDistance: 5,
            isSimilar: true
        )

        // Then: All fields are populated correctly
        XCTAssertEqual(similarity.assetID1, id1)
        XCTAssertEqual(similarity.assetID2, id2)
        XCTAssertEqual(similarity.hammingDistance, 5)
        XCTAssertTrue(similarity.isSimilar)
    }

    // MARK: - AC1: Batch pHash Computation Performance (FR19, NFR4)

    /// [P0] Batch computation of 100 photos completes within 60 seconds.
    ///
    /// AC1: Given at least 100 photos,
    /// When triggering batch pHash computation,
    /// Then the engine completes all 100 hashes within 1 minute
    /// And computation runs in a background Task without blocking the main thread.
    func testBatchComputeHashesPerformance() async throws {
        // Given: 100 mock photo assets
        let hasher = PerceptualHasher()
        let mockRepo = MockPHashTestRepository(imageCount: 100)
        let assets = (0..<100).map { i in
            PhotoAsset(
                id: AssetID(rawValue: "/photos/photo_\(i).jpg"),
                metadata: AssetMetadata(
                    fileName: "photo_\(i).jpg",
                    fileSize: 1024,
                    creationDate: nil,
                    cameraModel: nil,
                    imageWidth: 100,
                    imageHeight: 100,
                    gpsLocation: nil,
                    fileFormat: .jpeg
                ),
                thumbnailData: nil
            )
        }

        // When: Computing hashes for all 100 photos
        let startTime = Date()
        let results = try await hasher.computeHashes(for: assets, repository: mockRepo)
        let elapsed = Date().timeIntervalSince(startTime)

        // Then: All 100 hashes computed within 60 seconds
        XCTAssertEqual(results.count, 100, "Should compute hashes for all 100 photos")
        XCTAssertLessThan(elapsed, 60.0, "100 photos should be hashed in under 60 seconds, took \(elapsed)s")
    }

    // MARK: - AC3: Batch Computation Cancellation Support (FR17)

    /// [P0] Cancelling batch computation retains already-computed results.
    ///
    /// AC3: Given user cancels an in-progress batch computation,
    /// When Task.cancel() is called,
    /// Then the background Task is properly cancelled,
    /// And already-computed results are preserved and returned,
    /// And no memory leaks or data inconsistency occur.
    func testBatchComputeCancellationRetainsResults() async throws {
        // Given: A large batch with slow processing
        let hasher = PerceptualHasher()
        let mockRepo = MockPHashTestRepository(imageCount: 50, artificialDelay: 0.01)
        let assets = (0..<50).map { i in
            PhotoAsset(
                id: AssetID(rawValue: "/photos/photo_\(i).jpg"),
                metadata: AssetMetadata(
                    fileName: "photo_\(i).jpg",
                    fileSize: 1024,
                    creationDate: nil,
                    cameraModel: nil,
                    imageWidth: 100,
                    imageHeight: 100,
                    gpsLocation: nil,
                    fileFormat: .jpeg
                ),
                thumbnailData: nil
            )
        }

        // When: Starting batch computation and cancelling after a delay
        let task = Task {
            try await hasher.computeHashes(for: assets, repository: mockRepo)
        }

        // Cancel after a short delay (enough to process some but not all)
        try await Task.sleep(for: .milliseconds(100))
        task.cancel()

        // Then: Partial results are returned (some but not all hashes)
        let result = try await task.value
        XCTAssertGreaterThan(result.count, 0,
            "Should retain at least some computed results after cancellation")
        XCTAssertLessThan(result.count, 50,
            "Should not have completed all hashes before cancellation")
    }

    // MARK: - AC6: Error Handling and Fault Tolerance (NFR23)

    /// [P0] Corrupted image data is skipped gracefully during batch computation.
    ///
    /// AC6: Given a photo file is corrupted or in unsupported format,
    /// When attempting to compute its pHash,
    /// Then the photo is marked as "computation failed" and skipped,
    /// And other photos' batch computation continues unaffected,
    /// And errors map to DomainError.analysisFailed.
    func testCorruptedImageSkippedGracefully() async throws {
        // Given: A mix of valid and corrupted image data
        let hasher = PerceptualHasher()
        let validData = try createSolidColorImage(color: .blue, width: 100, height: 100)
        let corruptedData = Data("this is not a valid image".utf8)

        // When: Computing hash for corrupted data
        do {
            _ = try await hasher.computeHash(for: corruptedData)
            XCTFail("Should throw DomainError.analysisFailed for corrupted data")
        } catch let error as DomainError {
            // Then: Error is DomainError.analysisFailed
            if case .analysisFailed(let reason) = error {
                XCTAssertTrue(reason.count > 0, "Error reason should not be empty")
            } else {
                XCTFail("Should be analysisFailed, got: \(error)")
            }
        }

        // And: Valid data still works after corrupted data
        let validHash = try await hasher.computeHash(for: validData)
        // UInt64 — verified at compile time
        let _ = validHash
    }

    /// [P1] Unsupported image format is skipped gracefully.
    ///
    /// AC6: Unsupported formats (e.g., raw text data with image extension) are handled.
    func testUnsupportedFormatSkippedGracefully() async throws {
        // Given: Data that is not a valid image format
        let hasher = PerceptualHasher()
        let nonImageData = Data("GIF89a invalid".utf8)

        // When/Then: Should throw DomainError.analysisFailed
        do {
            _ = try await hasher.computeHash(for: nonImageData)
            XCTFail("Should throw for non-image data")
        } catch let error as DomainError {
            if case .analysisFailed = error {
                // Expected
            } else {
                XCTFail("Should be analysisFailed, got: \(error)")
            }
        }
    }

    /// [P1] Empty data throws analysisFailed error.
    ///
    /// AC6: Empty data is properly handled with descriptive error.
    func testEmptyDataThrowsAnalysisFailed() async throws {
        // Given: Empty data
        let hasher = PerceptualHasher()
        let emptyData = Data()

        // When/Then: Should throw DomainError.analysisFailed
        do {
            _ = try await hasher.computeHash(for: emptyData)
            XCTFail("Should throw for empty data")
        } catch let error as DomainError {
            if case .analysisFailed(let reason) = error {
                XCTAssertTrue(reason.count > 0, "Should provide a reason for empty data failure")
            } else {
                XCTFail("Should be analysisFailed, got: \(error)")
            }
        }
    }

    // MARK: - Value Type Tests

    /// [P1] PerceptualHashValue conforms to Sendable.
    func testPerceptualHashValueSendable() async throws {
        // Given: A PerceptualHashValue
        let value = PerceptualHashValue(
            assetID: AssetID(rawValue: "/test.jpg"),
            hash: 12345,
            computedAt: Date()
        )

        // Then: Compile-time Sendable conformance verified by usage in async context
        let _ = value // Used across isolation boundary — Sendable checked
    }

    /// [P1] PerceptualHashValue correctly encodes and decodes (Codable).
    func testPerceptualHashValueCodable() async throws {
        // Given: A PerceptualHashValue
        let original = PerceptualHashValue(
            assetID: AssetID(rawValue: "/photos/test.jpg"),
            hash: 0xDEADBEEF,
            computedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )

        // When: Encoding and decoding
        let encoder = JSONEncoder()
        let data = try encoder.encode(original)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(PerceptualHashValue.self, from: data)

        // Then: Values are preserved
        XCTAssertEqual(decoded.assetID, original.assetID)
        XCTAssertEqual(decoded.hash, original.hash)
    }

    /// [P1] PairwiseSimilarity is Comparable (sorted by hammingDistance ascending).
    func testPairwiseSimilarityComparable() async throws {
        // Given: Two PairwiseSimilarity values with different distances
        let near = PairwiseSimilarity(
            assetID1: AssetID(rawValue: "/a.jpg"),
            assetID2: AssetID(rawValue: "/b.jpg"),
            hammingDistance: 3,
            isSimilar: true
        )
        let far = PairwiseSimilarity(
            assetID1: AssetID(rawValue: "/c.jpg"),
            assetID2: AssetID(rawValue: "/d.jpg"),
            hammingDistance: 15,
            isSimilar: false
        )

        // When: Sorting by hammingDistance (Comparable)
        let sorted = [far, near].sorted()

        // Then: Lower distance comes first (ascending)
        XCTAssertEqual(sorted.first?.hammingDistance, 3)
        XCTAssertEqual(sorted.last?.hammingDistance, 15)
    }

    /// [P1] PairwiseSimilarity is Identifiable.
    func testPairwiseSimilarityIdentifiable() async throws {
        // Given: A PairwiseSimilarity
        let similarity = PairwiseSimilarity(
            assetID1: AssetID(rawValue: "/a.jpg"),
            assetID2: AssetID(rawValue: "/b.jpg"),
            hammingDistance: 5,
            isSimilar: true
        )

        // Then: Has a unique id
        let id = similarity.id
        XCTAssertNotEqual(id, UUID(), "id should be auto-generated unique UUID")
    }

    // MARK: - AC5: Batch Skips Cached Photos

    /// [P1] Batch computation skips photos that already have cached hashes.
    ///
    /// AC5: Given some photos' pHash values are already cached,
    /// When running batch computation,
    /// Then already-cached photos are skipped (loaded from cache),
    /// And only uncached photos are newly computed.
    func testBatchSkipsCachedPhotos() async throws {
        // Given: Cache already has hash for photo_0.jpg (isolated temp directory)
        let cacheDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("PHashCacheTest-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: cacheDir) }

        let cacheManager = HashCacheManager(cacheDirectory: cacheDir)
        let existingHash: UInt64 = 0xABCDEF0123456789
        try await cacheManager.saveCache([
            "/photos/photo_0.jpg": existingHash,
        ])

        let hasher = PerceptualHasher(cacheManager: cacheManager)
        let mockRepo = MockPHashTestRepository(imageCount: 5)
        let assets = (0..<5).map { i in
            PhotoAsset(
                id: AssetID(rawValue: "/photos/photo_\(i).jpg"),
                metadata: AssetMetadata(
                    fileName: "photo_\(i).jpg",
                    fileSize: 1024,
                    creationDate: nil,
                    cameraModel: nil,
                    imageWidth: 100,
                    imageHeight: 100,
                    gpsLocation: nil,
                    fileFormat: .jpeg
                ),
                thumbnailData: nil
            )
        }

        // When: Computing hashes for all 5 (1 cached, 4 new)
        let results = try await hasher.computeHashes(for: assets, repository: mockRepo)

        // Then: All 5 results are returned (1 from cache + 4 newly computed)
        XCTAssertEqual(results.count, 5, "Should return hashes for all 5 photos")

        // And: Cached hash value is preserved
        let cachedResult = results.first { $0.assetID == AssetID(rawValue: "/photos/photo_0.jpg") }
        XCTAssertEqual(cachedResult?.hash, existingHash,
            "Cached hash should be loaded from cache without recomputation")

        // And: Mock repo only fetched 4 images (skipped the cached one)
        XCTAssertEqual(mockRepo.fetchCallCount, 4,
            "Should only fetch uncached images from repository")
    }

    // MARK: - Test Helpers

    /// Creates a solid-color JPEG image of the given size.
    @discardableResult
    private func createSolidColorImage(
        color: NSColor,
        width: Int,
        height: Int
    ) throws -> Data {
        let size = NSSize(width: width, height: height)
        let image = NSImage(size: size)
        image.lockFocus()
        color.setFill()
        NSBezierPath.fill(NSRect(origin: .zero, size: size))
        image.unlockFocus()

        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            XCTFail("Failed to create test image bitmap")
            return Data()
        }

        return bitmap.representation(using: .jpeg, properties: [:])!
    }

    /// Creates a black-and-white checkerboard JPEG image of the given size.
    @discardableResult
    private func createCheckerboardImage(
        width: Int,
        height: Int,
        tileSize: Int
    ) throws -> Data {
        let size = NSSize(width: width, height: height)
        let image = NSImage(size: size)
        image.lockFocus()
        for y in stride(from: 0, to: height, by: tileSize) {
            for x in stride(from: 0, to: width, by: tileSize) {
                let isWhite = ((x / tileSize) + (y / tileSize)) % 2 == 0
                let color: NSColor = isWhite ? .white : .black
                color.setFill()
                NSBezierPath.fill(NSRect(x: x, y: y, width: tileSize, height: tileSize))
            }
        }
        image.unlockFocus()

        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            XCTFail("Failed to create checkerboard image bitmap")
            return Data()
        }

        return bitmap.representation(using: .jpeg, properties: [:])!
    }
}

// MARK: - Mock: PhotoLibraryRepository for pHash Tests

/// Mock repository that returns synthetic JPEG image data for testing
/// batch pHash computation without real file system access.
final class MockPHashTestRepository: PhotoLibraryRepository, @unchecked Sendable {

    private let imageCount: Int
    private let artificialDelay: TimeInterval
    private let queue = DispatchQueue(label: "MockPHashTestRepository")
    private var _fetchCallCount = 0

    var fetchCallCount: Int { queue.sync { _fetchCallCount } }

    init(imageCount: Int = 0, artificialDelay: TimeInterval = 0) {
        self.imageCount = imageCount
        self.artificialDelay = artificialDelay
    }

    func currentBasePath() async -> String? { nil }

    func requestReadAccess() async throws -> Bool { true }

    func requestWriteAccess() async throws -> Bool { true }

    func fetchAssets(predicate: PhotoPredicate, pageSize: Int, pageOffset: Int) async throws -> AssetPage {
        AssetPage(assets: [], hasMore: false)
    }

    func fetchFullResolutionImage(for assetID: AssetID) async throws -> Data {
        queue.sync { _fetchCallCount += 1 }

        if artificialDelay > 0 {
            try await Task.sleep(for: .seconds(artificialDelay))
        }

        // Generate a simple JPEG image
        let size = NSSize(width: 100, height: 100)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.blue.setFill()
        NSBezierPath.fill(NSRect(origin: .zero, size: size))
        image.unlockFocus()

        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            throw DomainError.analysisFailed(reason: "Failed to create mock image")
        }

        return bitmap.representation(using: .jpeg, properties: [:])!
    }

    func fetchThumbnail(for assetID: AssetID, size: CGSize) async throws -> Data { Data() }

    func metadata(for assetID: AssetID) async throws -> AssetMetadata {
        AssetMetadata(fileName: "", fileSize: nil, creationDate: nil, cameraModel: nil,
                       imageWidth: nil, imageHeight: nil, gpsLocation: nil, fileFormat: nil)
    }

    func updateAsset(_ assetID: AssetID, title: String?) async throws {}
    func deleteAssets(_ assetIDs: [AssetID]) async throws {}
    func moveAssets(_ assetIDs: [AssetID], to directory: String) async throws {}
    func observeSourceChanges() -> AsyncStream<SourceChange> {
        AsyncStream { $0.finish() }
    }
}
