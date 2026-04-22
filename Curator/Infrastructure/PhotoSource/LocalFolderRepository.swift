import Foundation

/// Concrete implementation of PhotoLibraryRepository using local folder file system.
///
/// All file system operations are serialized within this actor. Scans the
/// bookmarked folder recursively, filtering to supported photo formats.
/// Results are paginated via AssetPage with offset-based cursors.
actor LocalFolderRepository: PhotoLibraryRepository {
    private let bookmarkManager: FolderBookmarkManaging
    private var folderURL: URL?
    private var accessedURL: URL?
    private var cachedFileURLs: [URL]?
    private var cachedPredicate: PhotoPredicate?

    private let initialFolderURL: URL?

    init(bookmarkManager: FolderBookmarkManaging = FolderBookmarkManager(), initialFolderURL: URL? = nil) {
        self.bookmarkManager = bookmarkManager
        self.initialFolderURL = initialFolderURL
        self.folderURL = initialFolderURL
    }

    func currentBasePath() async -> String? { folderURL?.path }

    deinit {
        if let url = accessedURL {
            bookmarkManager.releaseBookmark(url)
        }
    }

    func requestReadAccess() async throws -> Bool {
        if folderURL != nil { return true }

        if let url = try await bookmarkManager.loadBookmark() {
            if bookmarkManager.accessBookmark(url) {
                releaseCurrentAccess()
                accessedURL = url
                folderURL = url
                return true
            }
        }

        let url = try await bookmarkManager.selectAndBookmarkFolder()
        if bookmarkManager.accessBookmark(url) {
            releaseCurrentAccess()
            accessedURL = url
            folderURL = url
            return true
        }
        return false
    }

    private func releaseCurrentAccess() {
        if let old = accessedURL {
            bookmarkManager.releaseBookmark(old)
            accessedURL = nil
        }
    }

    func requestWriteAccess() async throws -> Bool {
        // If already granted, return true immediately
        if await bookmarkManager.hasWriteAccess { return true }
        // Attempt to grant — in production this may present UI for user consent.
        // The bookmark manager decides whether to grant or refuse.
        return await bookmarkManager.requestWriteConsent()
    }

    func metadata(for assetID: AssetID) async throws -> AssetMetadata {
        let url = URL(fileURLWithPath: assetID.rawValue)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw InfrastructureError.fileNotFound(path: assetID.rawValue).toDomainError()
        }
        return ExifMetadataReader.readMetadata(from: url)
    }

    func updateAsset(_ assetID: AssetID, title: String?) async throws {
        guard await bookmarkManager.hasWriteAccess else {
            throw DomainError.insufficientPermission(required: .write)
        }
        guard let newTitle = title, !newTitle.isEmpty else { return }
        guard !newTitle.contains("/") && !newTitle.contains(":") else {
            throw DomainError.invalidState(reason: "文件名不能包含 / 或 :")
        }
        let sourceURL = URL(fileURLWithPath: assetID.rawValue)
        let directory = sourceURL.deletingLastPathComponent()
        let ext = sourceURL.pathExtension
        let fileName = ext.isEmpty ? newTitle : "\(newTitle).\(ext)"
        let destURL = directory.appendingPathComponent(fileName)
        guard !FileManager.default.fileExists(atPath: destURL.path) else {
            throw DomainError.invalidState(reason: "文件名已被占用: \(fileName)")
        }
        do {
            try FileManager.default.moveItem(at: sourceURL, to: destURL)
        } catch let error as NSError {
            throw InfrastructureError.fileWriteFailed(
                path: assetID.rawValue,
                reason: error.localizedDescription
            ).toDomainError()
        }
        cachedFileURLs = nil
    }

    func deleteAssets(_ assetIDs: [AssetID]) async throws {
        guard await bookmarkManager.hasWriteAccess else {
            throw DomainError.insufficientPermission(required: .write)
        }
        guard !assetIDs.isEmpty else { return }
        for assetID in assetIDs {
            let url = URL(fileURLWithPath: assetID.rawValue)
            guard FileManager.default.fileExists(atPath: url.path) else {
                throw InfrastructureError.fileNotFound(path: assetID.rawValue).toDomainError()
            }
            var resultURL: NSURL?
            do {
                try FileManager.default.trashItem(at: url, resultingItemURL: &resultURL)
            } catch let error as NSError {
                throw InfrastructureError.fileWriteFailed(
                    path: assetID.rawValue,
                    reason: error.localizedDescription
                ).toDomainError()
            }
        }
        cachedFileURLs = nil
    }

    func moveAssets(_ assetIDs: [AssetID], to directory: String) async throws {
        guard await bookmarkManager.hasWriteAccess else {
            throw DomainError.insufficientPermission(required: .write)
        }
        guard !assetIDs.isEmpty else { return }
        guard !directory.contains("..") else {
            throw DomainError.invalidState(reason: "目录路径不能包含 ..")
        }
        guard let baseFolder = folderURL else {
            throw InfrastructureError.folderAccessDenied(reason: "未选择照片文件夹").toDomainError()
        }
        let destDir = baseFolder.appendingPathComponent(directory, isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)
        } catch let error as NSError {
            throw InfrastructureError.fileWriteFailed(
                path: destDir.path,
                reason: error.localizedDescription
            ).toDomainError()
        }
        for assetID in assetIDs {
            let sourceURL = URL(fileURLWithPath: assetID.rawValue)
            let destURL = destDir.appendingPathComponent(sourceURL.lastPathComponent)
            do {
                try FileManager.default.moveItem(at: sourceURL, to: destURL)
            } catch let error as NSError {
                throw InfrastructureError.fileWriteFailed(
                    path: assetID.rawValue,
                    reason: error.localizedDescription
                ).toDomainError()
            }
        }
        cachedFileURLs = nil
    }

    nonisolated func observeSourceChanges() -> AsyncStream<SourceChange> {
        AsyncStream { _ in }
    }

    func fetchAssets(predicate: PhotoPredicate, pageSize: Int, pageOffset: Int) async throws -> AssetPage {
        guard folderURL != nil else {
            throw InfrastructureError.folderAccessDenied(reason: "未选择照片文件夹").toDomainError()
        }

        let urls: [URL]
        do {
            urls = try scannedFileURLs(predicate: predicate)
        } catch let error as InfrastructureError {
            throw error.toDomainError()
        }

        let startIndex = max(pageOffset, 0)
        guard startIndex < urls.count else {
            return AssetPage(assets: [], hasMore: false, nextOffset: nil)
        }
        let endIndex = min(startIndex + max(pageSize, 1), urls.count)
        let pageURLs = Array(urls[startIndex..<endIndex])
        let hasMore = endIndex < urls.count

        let assets = pageURLs.map { fileURL -> PhotoAsset in
            let metadata = ExifMetadataReader.readMetadata(from: fileURL)
            return PhotoAsset(id: AssetID(rawValue: fileURL.path), metadata: metadata, thumbnailData: nil)
        }

        return AssetPage(assets: assets, hasMore: hasMore, nextOffset: hasMore ? endIndex : nil)
    }

    func fetchFullResolutionImage(for assetID: AssetID) async throws -> Data {
        let url = URL(fileURLWithPath: assetID.rawValue)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw InfrastructureError.fileNotFound(path: assetID.rawValue).toDomainError()
        }
        do {
            return try Data(contentsOf: url)
        } catch let error as InfrastructureError {
            throw error.toDomainError()
        } catch {
            throw InfrastructureError.folderScanFailed(reason: "无法读取文件: \(error.localizedDescription)").toDomainError()
        }
    }

    func fetchThumbnail(for assetID: AssetID, size: CGSize) async throws -> Data {
        let url = URL(fileURLWithPath: assetID.rawValue)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw InfrastructureError.fileNotFound(path: assetID.rawValue).toDomainError()
        }
        guard let data = ExifMetadataReader.generateThumbnail(from: url, targetSize: size) else {
            throw InfrastructureError.folderScanFailed(reason: "无法生成缩略图").toDomainError()
        }
        return data
    }

    // MARK: - Private

    private func scannedFileURLs(predicate: PhotoPredicate) throws -> [URL] {
        if let cached = cachedFileURLs, cachedPredicate == predicate {
            return cached
        }

        guard let folder = folderURL else {
            throw InfrastructureError.folderAccessDenied(reason: "未选择照片文件夹")
        }

        guard let enumerator = FileManager.default.enumerator(
            at: folder,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            throw InfrastructureError.folderScanFailed(reason: "无法枚举文件夹")
        }

        var urls: [URL] = []
        for case let fileURL as URL in enumerator {
            let ext = fileURL.pathExtension.lowercased()
            guard FileFormat.supportedExtensions.contains(ext) else { continue }
            urls.append(fileURL)
        }

        // Prefetch creation dates once to avoid O(N log N) stat calls in sort
        let creationDates: [URL: Date] = Dictionary(
            uniqueKeysWithValues: urls.compactMap { url in
                guard let date = (try? FileManager.default.attributesOfItem(atPath: url.path)[.creationDate] as? Date) else {
                    return nil
                }
                return (url, date)
            }
        )

        urls.sort { u1, u2 in
            let d1 = creationDates[u1] ?? .distantPast
            let d2 = creationDates[u2] ?? .distantPast
            return d1 > d2
        }

        let filtered = applyPredicate(predicate, to: urls, creationDates: creationDates)
        cachedFileURLs = filtered
        cachedPredicate = predicate
        return filtered
    }

    private func applyPredicate(_ predicate: PhotoPredicate, to urls: [URL], creationDates: [URL: Date]) -> [URL] {
        var result = urls

        if let dateRange = predicate.dateRange {
            result = result.filter { u in
                guard let date = creationDates[u] else { return false }
                return date >= dateRange.from && date <= dateRange.to
            }
        }

        switch predicate.fileFormat {
        case .all:
            break
        case .images:
            result = result.filter { FileFormat.from(pathExtension: $0.pathExtension) != .unknown }
        case .heic:
            result = result.filter { FileFormat.from(pathExtension: $0.pathExtension) == .heic }
        case .raw:
            result = result.filter { FileFormat.from(pathExtension: $0.pathExtension) == .raw }
        }

        return result
    }
}
