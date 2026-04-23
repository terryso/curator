import Foundation

/// Manages persistent disk-based caching of perceptual hash values.
///
/// Stores hash values as a JSON file in the Application Support directory.
/// The cache maps asset ID raw values (file paths) to their computed UInt64 hash values.
actor HashCacheManager: Sendable {

    /// The file name used for the cache file.
    static let cacheFileName = "phash_cache.json"

    /// The directory where the cache file is stored.
    let cacheDirectory: URL

    /// Full URL to the cache file.
    var cacheFileURL: URL {
        cacheDirectory.appendingPathComponent(Self.cacheFileName)
    }

    /// Creates a HashCacheManager with the specified cache directory.
    ///
    /// - Parameter cacheDirectory: Directory to store the cache file in.
    ///   Defaults to `~/Library/Application Support/Curator/`.
    init(cacheDirectory: URL? = nil) {
        if let cacheDirectory {
            self.cacheDirectory = cacheDirectory
        } else {
            let appSupport = FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first!
            self.cacheDirectory = appSupport.appendingPathComponent("Curator", isDirectory: true)
        }
    }

    /// Loads the cached hash values from disk.
    ///
    /// - Returns: A dictionary mapping asset ID raw values to their cached hash values.
    ///   Returns an empty dictionary if no cache file exists.
    func loadCache() async throws -> [String: UInt64] {
        let fileManager = FileManager.default

        guard fileManager.fileExists(atPath: cacheFileURL.path) else {
            return [:]
        }

        let data = try Data(contentsOf: cacheFileURL)
        let decoded = try JSONDecoder().decode([String: UInt64].self, from: data)
        return decoded
    }

    /// Saves hash values to the cache file.
    ///
    /// Merges the provided hashes with any existing cached values,
    /// overwriting entries with the same asset ID.
    ///
    /// - Parameter hashes: Dictionary of asset ID raw values to hash values to save.
    func saveCache(_ hashes: [String: UInt64]) async throws {
        let fileManager = FileManager.default

        // Ensure directory exists
        try fileManager.createDirectory(
            at: cacheDirectory,
            withIntermediateDirectories: true
        )

        // Load existing cache and merge
        var existing: [String: UInt64] = [:]
        if fileManager.fileExists(atPath: cacheFileURL.path) {
            let data = try Data(contentsOf: cacheFileURL)
            existing = try JSONDecoder().decode([String: UInt64].self, from: data)
        }

        // Merge new hashes (overwriting existing entries with same key)
        existing.merge(hashes) { _, new in new }

        // Write back
        let encoder = JSONEncoder()
        let data = try encoder.encode(existing)
        try data.write(to: cacheFileURL, options: .atomic)
    }

    /// Invalidates (removes) cached entries for the specified asset IDs.
    ///
    /// - Parameter assetIDs: Array of asset IDs whose cache entries should be removed.
    func invalidateCache(for assetIDs: [AssetID]) async throws {
        let fileManager = FileManager.default

        guard fileManager.fileExists(atPath: cacheFileURL.path) else {
            return
        }

        var cache = try await loadCache()
        let keysToRemove = Set(assetIDs.map(\.rawValue))
        for key in keysToRemove {
            cache.removeValue(forKey: key)
        }

        let encoder = JSONEncoder()
        let data = try encoder.encode(cache)
        try data.write(to: cacheFileURL, options: .atomic)
    }

    /// Clears the entire cache.
    ///
    /// Removes all cached hash values by deleting the cache file.
    func clearCache() async throws {
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: cacheFileURL.path) {
            try fileManager.removeItem(at: cacheFileURL)
        }
    }
}
