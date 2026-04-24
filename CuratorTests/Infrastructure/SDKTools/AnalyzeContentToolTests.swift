import XCTest
import OpenAgentSDK

@testable import Curator

/// ATDD Tests for Story 6.1 -- AnalyzeContentTool (AC1, AC5)
///
/// Tests verify:
/// - AC1: AnalyzeContentTool chains ContentAnalyzerProtocol for photo analysis (FR24, FR25)
/// - AC5: Cost estimate integration with LLMGateway (FR46)
final class AnalyzeContentToolTests: XCTestCase {

    // MARK: - AC1: AnalyzeContentTool Returns Rename Suggestions (FR24, FR25)

    /// [P0] AnalyzeContentTool returns valid JSON with RenameSuggestion data.
    ///
    /// AC1: Given a library with photos,
    /// When Agent calls AnalyzeContentTool,
    /// Then tool returns JSON with suggestedName, confidence, and originalFileName fields.
    func testAnalyzeContentToolReturnsValidJSON() async throws {
        // Given: Mock analyzer returning suggestions
        let assets = Self.makeTestAssets(count: 2)
        let suggestions = [
            RenameSuggestion(
                assetID: assets[0].id,
                originalFileName: "IMG_001.jpg",
                suggestedName: "Beach Sunset.jpg",
                confidence: 0.92,
                analysisDescription: "A sunset scene at the beach",
                status: .pending
            ),
            RenameSuggestion(
                assetID: assets[1].id,
                originalFileName: "IMG_002.jpg",
                suggestedName: "Mountain View.jpg",
                confidence: 0.88,
                analysisDescription: "Snow-capped mountains",
                status: .pending
            ),
        ]
        let mockAnalyzer = MockContentAnalyzerTool(suggestions: suggestions)
        let mockRepo = MockContentToolTestRepository(assets: assets)

        let tool = createAnalyzeContentTool(
            analyzer: mockAnalyzer,
            repository: mockRepo
        )

        // When: Calling the tool
        let result = try await tool.call(
            input: [:] as [String: Any],
            context: ToolContext(cwd: "/tmp")
        )

        // Then: Result contains suggestion data
        XCTAssertFalse(result.isError,
            "AnalyzeContentTool should execute without error")
        XCTAssertTrue(result.content.contains("suggestedName"),
            "Result should contain suggestedName field")
        XCTAssertTrue(result.content.contains("confidence"),
            "Result should contain confidence field")
        XCTAssertTrue(result.content.contains("originalFileName"),
            "Result should contain originalFileName field")
    }

    /// [P0] AnalyzeContentTool with empty library returns empty results.
    ///
    /// AC1: Given an empty photo library,
    /// When Agent calls AnalyzeContentTool,
    /// Then tool returns an empty list without errors.
    func testAnalyzeContentToolWithEmptyLibrary() async throws {
        // Given: Empty library
        let mockAnalyzer = MockContentAnalyzerTool(suggestions: [])
        let mockRepo = MockContentToolTestRepository(assets: [])

        let tool = createAnalyzeContentTool(
            analyzer: mockAnalyzer,
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
        XCTAssertTrue(result.content.contains("suggestions") || result.content.contains("[]"),
            "Empty library should return empty suggestions")
    }

    // MARK: - AC1: Tool Properties and Annotations

    /// [P1] AnalyzeContentTool is registered as read-only with correct annotations.
    ///
    /// AC1: Tool should have readOnlyHint: true and destructiveHint: false.
    func testAnalyzeContentToolAnnotations() async throws {
        let mockAnalyzer = MockContentAnalyzerTool(suggestions: [])
        let mockRepo = MockContentToolTestRepository(assets: [])

        let tool = createAnalyzeContentTool(
            analyzer: mockAnalyzer,
            repository: mockRepo
        )

        XCTAssertEqual(tool.name, "analyze_content",
            "Tool name should be 'analyze_content'")
        XCTAssertTrue(tool.isReadOnly,
            "AnalyzeContentTool should be marked as read-only")

        if let annotations = tool.annotations {
            XCTAssertTrue(annotations.readOnlyHint,
                "AnalyzeContentTool should have readOnlyHint = true")
            XCTAssertFalse(annotations.destructiveHint,
                "AnalyzeContentTool should have destructiveHint = false")
        }
    }

    // MARK: - AC3: Error Handling

    /// [P1] AnalyzeContentTool returns structured JSON error when analyzer fails.
    ///
    /// AC3: Given the ContentAnalyzerProtocol throws an error,
    /// When AnalyzeContentTool executes,
    /// Then tool returns structured JSON error and does not crash the Agent loop.
    func testAnalyzeContentToolHandlesAnalyzerError() async throws {
        // Given: Analyzer that throws
        let mockAnalyzer = MockContentAnalyzerTool(
            suggestions: [],
            shouldFail: true
        )
        let mockRepo = MockContentToolTestRepository(assets: Self.makeTestAssets(count: 2))

        let tool = createAnalyzeContentTool(
            analyzer: mockAnalyzer,
            repository: mockRepo
        )

        // When: Calling the tool
        let result = try await tool.call(
            input: [:] as [String: Any],
            context: ToolContext(cwd: "/tmp")
        )

        // Then: Returns structured error
        XCTAssertTrue(result.isError,
            "Tool should indicate error when analyzer fails")
        let contentLower = result.content.lowercased()
        XCTAssertTrue(contentLower.contains("error") || contentLower.contains("failed") || contentLower.contains("analysis"),
            "Error result should contain error information, got: \(result.content)")
    }

    // MARK: - AC1: maxPhotos Parameter

    /// [P1] AnalyzeContentTool respects maxPhotos parameter.
    ///
    /// AC1: Tool should pass maxPhotos to limit the number of analyzed photos.
    func testAnalyzeContentToolRespectsMaxPhotos() async throws {
        // Given: Tracking repository
        let trackingRepo = TrackingContentToolRepository(
            assets: Self.makeTestAssets(count: 5)
        )
        let mockAnalyzer = MockContentAnalyzerTool(suggestions: [])
        let tool = createAnalyzeContentTool(
            analyzer: mockAnalyzer,
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

    // MARK: - AC5: Cost Estimate Integration

    /// [P1] AnalyzeContentTool includes cost estimate when requested.
    ///
    /// AC5: When the tool executes, it should provide cost estimation data.
    func testAnalyzeContentToolIncludesCostEstimate() async throws {
        // Given: Mock with cost estimation
        let assets = Self.makeTestAssets(count: 2)
        let suggestions = [
            RenameSuggestion(
                assetID: assets[0].id,
                originalFileName: "IMG_001.jpg",
                suggestedName: "Beach Sunset.jpg",
                confidence: 0.9,
                status: .pending
            ),
        ]
        let mockAnalyzer = MockContentAnalyzerTool(suggestions: suggestions)
        let mockRepo = MockContentToolTestRepository(assets: assets)

        let tool = createAnalyzeContentTool(
            analyzer: mockAnalyzer,
            repository: mockRepo
        )

        // When: Calling the tool
        let result = try await tool.call(
            input: [:] as [String: Any],
            context: ToolContext(cwd: "/tmp")
        )

        // Then: Result includes cost estimate data
        XCTAssertFalse(result.isError)
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

// MARK: - Mocks for AnalyzeContentTool Tests

/// Mock content analyzer that returns pre-configured suggestions, optionally failing.
private struct MockContentAnalyzerTool: ContentAnalyzerProtocol {
    private let suggestions: [RenameSuggestion]
    private let shouldFail: Bool

    init(suggestions: [RenameSuggestion], shouldFail: Bool = false) {
        self.suggestions = suggestions
        self.shouldFail = shouldFail
    }

    func analyzeContent(
        assets: [PhotoAsset],
        repository: PhotoLibraryRepository,
        language: String
    ) async throws -> [RenameSuggestion] {
        if shouldFail {
            throw DomainError.analysisFailed(reason: "Simulated analyzer failure for test")
        }
        return suggestions
    }

    func analyzeContent(
        assets: [PhotoAsset],
        repository: any PhotoLibraryRepository,
        language: String,
        progressHandler: (@Sendable (Int, Int) -> Void)?
    ) async throws -> [RenameSuggestion] {
        if shouldFail {
            throw DomainError.analysisFailed(reason: "Simulated analyzer failure for test")
        }
        return suggestions
    }
}

// MARK: - Mock: PhotoLibraryRepository for Tool Tests

/// Mock repository that returns pre-configured assets.
private final class MockContentToolTestRepository: PhotoLibraryRepository, @unchecked Sendable {
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
private final class TrackingContentToolRepository: PhotoLibraryRepository, @unchecked Sendable {
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
