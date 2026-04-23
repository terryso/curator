import Foundation
import XCTest

@testable import Curator

/// ATDD Tests for Story 5.1 — Hash Cache Manager
///
/// Tests verify:
/// - AC5: Hash persistence and cache (disk-based JSON in Application Support)
/// - Cache loading, saving, invalidation, and clearing
final class HashCacheManagerTests: XCTestCase {

    private var tempCacheDir: URL!
    private var cacheManager: HashCacheManager!

    override func setUp() {
        super.setUp()
        // Use a unique temp directory for each test to avoid interference
        tempCacheDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("HashCacheTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempCacheDir!, withIntermediateDirectories: true)
        cacheManager = HashCacheManager(cacheDirectory: tempCacheDir)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempCacheDir)
        super.tearDown()
    }

    // MARK: - AC5: Hash Persistence and Cache (NFR5)

    /// [P1] Loading cache from a fresh install returns empty dictionary.
    ///
    /// AC5: Given no previous cache file exists,
    /// When loading the cache,
    /// Then an empty dictionary is returned.
    func testLoadCacheReturnsEmptyForNewInstall() async throws {
        // Given: No cache file exists (fresh temp directory)
        // When: Loading cache
        let cache = try await cacheManager.loadCache()

        // Then: Returns empty dictionary
        XCTAssertTrue(cache.isEmpty, "Fresh install should have empty cache")
    }

    /// [P1] Saving and loading cache round-trip preserves data.
    ///
    /// AC5: Given hash values are saved to cache,
    /// When loading the cache,
    /// Then all saved hash values are preserved correctly.
    func testSaveAndLoadCacheRoundTrip() async throws {
        // Given: A set of hash values to cache
        let hashes: [String: UInt64] = [
            "/photos/sunset.jpg": 0xABCDEF0123456789,
            "/photos/beach.jpg": 0xFEDCBA9876543210,
            "/photos/mountain.jpg": 42,
        ]

        // When: Saving and reloading
        try await cacheManager.saveCache(hashes)
        let loaded = try await cacheManager.loadCache()

        // Then: All values are preserved
        XCTAssertEqual(loaded.count, 3, "Should load all 3 cached entries")
        XCTAssertEqual(loaded["/photos/sunset.jpg"], 0xABCDEF0123456789)
        XCTAssertEqual(loaded["/photos/beach.jpg"], 0xFEDCBA9876543210)
        XCTAssertEqual(loaded["/photos/mountain.jpg"], 42)
    }

    /// [P1] Invalidating cache removes specific entries.
    ///
    /// AC5: Given a populated cache,
    /// When invalidating specific asset IDs,
    /// Then only those entries are removed, others remain.
    func testInvalidateCacheRemovesSpecificEntries() async throws {
        // Given: A populated cache
        let hashes: [String: UInt64] = [
            "/photos/a.jpg": 111,
            "/photos/b.jpg": 222,
            "/photos/c.jpg": 333,
        ]
        try await cacheManager.saveCache(hashes)

        // When: Invalidating specific entries
        try await cacheManager.invalidateCache(for: [
            AssetID(rawValue: "/photos/a.jpg"),
            AssetID(rawValue: "/photos/c.jpg"),
        ])

        // Then: Only those entries are removed
        let loaded = try await cacheManager.loadCache()
        XCTAssertEqual(loaded.count, 1, "Should have 1 remaining entry")
        XCTAssertEqual(loaded["/photos/b.jpg"], 222, "b.jpg should still be cached")
        XCTAssertNil(loaded["/photos/a.jpg"], "a.jpg should be invalidated")
        XCTAssertNil(loaded["/photos/c.jpg"], "c.jpg should be invalidated")
    }

    /// [P1] Clearing cache removes all entries.
    ///
    /// AC5: Given a populated cache,
    /// When clearing the cache,
    /// Then all entries are removed (配合 NFR13).
    func testClearCacheRemovesAllEntries() async throws {
        // Given: A populated cache
        let hashes: [String: UInt64] = [
            "/photos/x.jpg": 999,
            "/photos/y.jpg": 888,
        ]
        try await cacheManager.saveCache(hashes)

        // When: Clearing the cache
        try await cacheManager.clearCache()

        // Then: Cache is empty
        let loaded = try await cacheManager.loadCache()
        XCTAssertTrue(loaded.isEmpty, "Cache should be empty after clearCache()")
    }

    /// [P1] Cache file is stored in Application Support directory.
    ///
    /// AC5: Cache file should be at `~/Library/Application Support/Curator/phash_cache.json`
    /// (in test, we verify the file exists in the configured directory).
    func testCacheStoredInApplicationSupportDirectory() async throws {
        // Given: Save some cache data
        let hashes: [String: UInt64] = ["/test.jpg": 123]
        try await cacheManager.saveCache(hashes)

        // When: Checking for the cache file
        let expectedPath = tempCacheDir!.appendingPathComponent("phash_cache.json")

        // Then: Cache file exists at the expected location
        let fileExists = FileManager.default.fileExists(atPath: expectedPath.path)
        XCTAssertTrue(fileExists, "Cache file should exist at phash_cache.json in the configured directory")

        // And: File contains valid JSON
        let data = try Data(contentsOf: expectedPath)
        let decoded = try JSONDecoder().decode([String: UInt64].self, from: data)
        XCTAssertEqual(decoded["/test.jpg"], 123)
    }
}
