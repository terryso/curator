import XCTest
import OpenAgentSDK

@testable import Curator

/// ATDD Tests for Story 5.3 -- AnalyzeDuplicatesTool (AC2, AC6)
///
/// Tests verify:
/// - AC2: AnalyzeDuplicatesTool chains ImageAnalysisPipeline for two-stage analysis (FR19, FR20)
/// - AC6: Error handling returns structured JSON errors (NFR20, NFR23)
///
/// TDD RED PHASE: All tests use XCTSkip("ATDD Red Phase") to skip until
/// the feature is implemented. Remove skips one-by-one during implementation.
final class AnalyzeDuplicatesToolTests: XCTestCase {

    // MARK: - AC2: AnalyzeDuplicatesTool Returns Duplicate Groups (FR19, FR20)

    /// [P0] AnalyzeDuplicatesTool returns DuplicateGroup list from pipeline analysis.
    ///
    /// AC2: Given a library with duplicate photos,
    /// When Agent calls AnalyzeDuplicatesTool,
    /// Then tool internally calls ImageAnalysisPipeline.analyze(),
    /// And returns JSON with DuplicateGroup data (id, assetIDs, similarityScore, reason).
    func testAnalyzeDuplicatesReturnsGroups() async throws {
        // Given: Mock pipeline returning 2 duplicate groups
        let assets = Self.makeTestAssets(count: 4)
        let groups = [
            DuplicateGroup(
                assets: [assets[0], assets[1]],
                similarityScore: 0.95,
                reason: "Same scene, different compression",
                status: .pending
            ),
            DuplicateGroup(
                assets: [assets[2], assets[3]],
                similarityScore: 0.88,
                reason: "Identical composition, slight crop difference",
                status: .pending
            ),
        ]
        let mockPipeline = MockToolAnalysisPipeline(groups: groups)
        let mockRepo = MockToolTestRepository(assets: assets)

        let tool = createAnalyzeDuplicatesTool(
            pipeline: mockPipeline,
            repository: mockRepo
        )

        // When: Calling the tool
        let result = try await tool.call(
            input: [:] as [String: Any],
            context: ToolContext(cwd: "/tmp")
        )

        // Then: Result contains duplicate group data
        XCTAssertFalse(result.isError,
            "AnalyzeDuplicatesTool should execute without error")
        XCTAssertTrue(result.content.contains("similarityScore"),
            "Result should contain similarityScore field")
        XCTAssertTrue(result.content.contains("assetIDs"),
            "Result should contain assetIDs field")
    }

    /// [P0] AnalyzeDuplicatesTool with empty library returns empty results.
    ///
    /// AC2: Given an empty photo library,
    /// When Agent calls AnalyzeDuplicatesTool,
    /// Then tool returns an empty list without errors.
    func testAnalyzeDuplicatesWithEmptyLibrary() async throws {
        // Given: Empty library
        let mockPipeline = MockToolAnalysisPipeline(groups: [])
        let mockRepo = MockToolTestRepository(assets: [])

        let tool = createAnalyzeDuplicatesTool(
            pipeline: mockPipeline,
            repository: mockRepo
        )

        // When: Calling the tool
        let result = try await tool.call(
            input: [:] as [String: Any],
            context: ToolContext(cwd: "/tmp")
        )

        // Then: Empty result, no error
        XCTAssertFalse(result.isError,
            "Tool should succeed with empty library")
        XCTAssertTrue(result.content.contains("[]") || result.content.contains("groups"),
            "Empty library should return empty groups")
    }

    // MARK: - AC2: Tool Properties and Annotations

    /// [P1] AnalyzeDuplicatesTool is registered as read-only with correct annotations.
    ///
    /// AC2: Tool should have readOnlyHint: true and destructiveHint: false.
    func testAnalyzeDuplicatesToolAnnotations() async throws {
        let mockPipeline = MockToolAnalysisPipeline(groups: [])
        let mockRepo = MockToolTestRepository(assets: [])

        let tool = createAnalyzeDuplicatesTool(
            pipeline: mockPipeline,
            repository: mockRepo
        )

        XCTAssertEqual(tool.name, "analyze_duplicates",
            "Tool name should be 'analyze_duplicates'")
        XCTAssertTrue(tool.isReadOnly,
            "AnalyzeDuplicatesTool should be marked as read-only")

        if let annotations = tool.annotations {
            XCTAssertTrue(annotations.readOnlyHint,
                "AnalyzeDuplicatesTool should have readOnlyHint = true")
            XCTAssertFalse(annotations.destructiveHint,
                "AnalyzeDuplicatesTool should have destructiveHint = false")
        }
    }

    // MARK: - AC6: Error Handling (NFR20, NFR23)

    /// [P1] AnalyzeDuplicatesTool returns structured JSON error when pipeline fails.
    ///
    /// AC6: Given the ImageAnalysisPipeline throws an error,
    /// When AnalyzeDuplicatesTool executes,
    /// Then tool returns structured JSON error { "error": true, "message": "..." },
    /// And does not crash the Agent loop.
    func testAnalyzeDuplicatesHandlesPipelineError() async throws {
        // Given: Pipeline that throws
        let mockPipeline = MockToolAnalysisPipeline(
            groups: [],
            shouldFail: true
        )
        let mockRepo = MockToolTestRepository(assets: Self.makeTestAssets(count: 2))

        let tool = createAnalyzeDuplicatesTool(
            pipeline: mockPipeline,
            repository: mockRepo
        )

        // When: Calling the tool
        let result = try await tool.call(
            input: [:] as [String: Any],
            context: ToolContext(cwd: "/tmp")
        )

        // Then: Returns structured error
        XCTAssertTrue(result.isError,
            "Tool should indicate error when pipeline fails")
        let contentLower = result.content.lowercased()
        XCTAssertTrue(contentLower.contains("error") || contentLower.contains("failed") || contentLower.contains("analysis"),
            "Error result should contain error information, got: \(result.content)")
    }

    /// [P1] AnalyzeDuplicatesTool passes maxPhotos parameter to repository fetch.
    ///
    /// AC2: Tool should respect pagination parameters from input.
    func testAnalyzeDuplicatesRespectsMaxPhotos() async throws {
        // Given: Tracking repository
        let trackingRepo = TrackingMockToolRepository(
            assets: Self.makeTestAssets(count: 5)
        )
        let mockPipeline = MockToolAnalysisPipeline(groups: [])
        let tool = createAnalyzeDuplicatesTool(
            pipeline: mockPipeline,
            repository: trackingRepo
        )

        // When: Calling with maxPhotos parameter
        _ = try await tool.call(
            input: ["maxPhotos": 3] as [String: Any],
            context: ToolContext(cwd: "/tmp")
        )

        // Then: Repository was called with correct page size
        XCTAssertTrue(trackingRepo.fetchAssetsCalled,
            "Tool should call fetchAssets on repository")
        XCTAssertEqual(trackingRepo.lastPageSize, 3,
            "Tool should pass maxPhotos as pageSize")
    }

    // MARK: - Test Helpers

    private static func makeTestAssets(count: Int) -> [PhotoAsset] {
        (0..<count).map { i in
            PhotoAsset(
                id: AssetID(rawValue: "/photos/test_photo_\(i).jpg"),
                metadata: AssetMetadata(
                    fileName: "test_photo_\(i).jpg",
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
    }
}

// MARK: - Mock: ImageAnalysisPipeline for Tool Tests

/// Mock analysis pipeline that returns pre-configured groups, optionally failing.
private struct MockToolAnalysisPipeline: ImageAnalysisPipelineProtocol {
    private let groups: [DuplicateGroup]
    private let shouldFail: Bool

    init(groups: [DuplicateGroup], shouldFail: Bool = false) {
        self.groups = groups
        self.shouldFail = shouldFail
    }

    func analyze(
        assets: [PhotoAsset],
        repository: PhotoLibraryRepository
    ) async throws -> [DuplicateGroup] {
        if shouldFail {
            throw DomainError.analysisFailed(reason: "Simulated pipeline failure for test")
        }
        return groups
    }

    func analyze(
        assets: [PhotoAsset],
        repository: PhotoLibraryRepository,
        progressHandler: (@Sendable (AnalysisProgress) -> Void)?
    ) async throws -> [DuplicateGroup] {
        if shouldFail {
            throw DomainError.analysisFailed(reason: "Simulated pipeline failure for test")
        }
        return groups
    }
}

// MARK: - Mock: PhotoLibraryRepository for Tool Tests

/// Mock repository that returns pre-configured assets.
private final class MockToolTestRepository: PhotoLibraryRepository, @unchecked Sendable {
    private let assets: [PhotoAsset]

    init(assets: [PhotoAsset] = []) {
        self.assets = assets
    }

    func currentBasePath() async -> String? { nil }
    func requestReadAccess() async throws -> Bool { true }
    func requestWriteAccess() async throws -> Bool { true }

    func fetchAssets(predicate: PhotoPredicate, pageSize: Int, pageOffset: Int) async throws -> AssetPage {
        let end = min(pageOffset + pageSize, assets.count)
        let pageAssets = Array(assets[pageOffset..<end])
        return AssetPage(
            assets: pageAssets,
            hasMore: end < assets.count,
            nextOffset: end < assets.count ? end : nil
        )
    }

    func fetchFullResolutionImage(for assetID: AssetID) async throws -> Data { Data() }
    func fetchThumbnail(for assetID: AssetID, size: CGSize) async throws -> Data { Data() }
    func metadata(for assetID: AssetID) async throws -> AssetMetadata {
        AssetMetadata(fileName: "mock.jpg", fileSize: nil, creationDate: nil,
                       cameraModel: nil, imageWidth: nil, imageHeight: nil,
                       gpsLocation: nil, fileFormat: nil)
    }
    func updateAsset(_ assetID: AssetID, title: String?) async throws {}
    func deleteAssets(_ assetIDs: [AssetID]) async throws {}
    func moveAssets(_ assetIDs: [AssetID], to directory: String) async throws {}
    func observeSourceChanges() -> AsyncStream<SourceChange> { AsyncStream { $0.finish() } }
}

// MARK: - Mock: Tracking Repository for Tool Tests

/// Repository that tracks fetchAssets call parameters.
private final class TrackingMockToolRepository: PhotoLibraryRepository, @unchecked Sendable {
    private let assets: [PhotoAsset]
    private(set) var fetchAssetsCalled = false
    private(set) var lastPageSize: Int?

    init(assets: [PhotoAsset] = []) {
        self.assets = assets
    }

    func currentBasePath() async -> String? { nil }
    func requestReadAccess() async throws -> Bool { true }
    func requestWriteAccess() async throws -> Bool { true }

    func fetchAssets(predicate: PhotoPredicate, pageSize: Int, pageOffset: Int) async throws -> AssetPage {
        fetchAssetsCalled = true
        lastPageSize = pageSize
        let end = min(pageOffset + pageSize, assets.count)
        let pageAssets = Array(assets[pageOffset..<end])
        return AssetPage(assets: pageAssets, hasMore: end < assets.count, nextOffset: nil)
    }

    func fetchFullResolutionImage(for assetID: AssetID) async throws -> Data { Data() }
    func fetchThumbnail(for assetID: AssetID, size: CGSize) async throws -> Data { Data() }
    func metadata(for assetID: AssetID) async throws -> AssetMetadata {
        AssetMetadata(fileName: "mock.jpg", fileSize: nil, creationDate: nil,
                       cameraModel: nil, imageWidth: nil, imageHeight: nil,
                       gpsLocation: nil, fileFormat: nil)
    }
    func updateAsset(_ assetID: AssetID, title: String?) async throws {}
    func deleteAssets(_ assetIDs: [AssetID]) async throws {}
    func moveAssets(_ assetIDs: [AssetID], to directory: String) async throws {}
    func observeSourceChanges() -> AsyncStream<SourceChange> { AsyncStream { $0.finish() } }
}
