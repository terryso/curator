import Foundation
import XCTest

@testable import Curator

/// Thread-safe mutable value wrapper for test progress tracking.
private final class LockedValue<T>: @unchecked Sendable {
    private var value: T
    private let lock = NSLock()
    init(initialValue: T) { self.value = initialValue }
    func withValue<R>(_ body: (inout T) throws -> R) rethrows -> R {
        lock.lock()
        defer { lock.unlock() }
        return try body(&value)
    }
}

/// ATDD Tests for Story 6.1 -- ContentAnalyzerService (AC1, AC2, AC3, AC4)
///
/// Tests verify:
/// - AC1: Content analysis via LLM identifies scenes, people, places (FR24, FR25)
/// - AC2: RenameSuggestion model generation with correct fields
/// - AC3: Error tolerance -- partial failure does not block other photos
/// - AC4: Progress reporting via callback
final class ContentAnalyzerServiceTests: XCTestCase {

    // MARK: - AC1: Content Analysis Returns Suggestions (FR24, FR25)

    /// [P0] ContentAnalyzerService returns RenameSuggestions from LLM analysis.
    ///
    /// AC1: Given a set of photos needing renaming,
    /// When ContentAnalyzerService analyzes them,
    /// Then LLM identifies scenes, people, places and generates descriptive titles,
    /// And RenameSuggestions are returned with correct fields.
    func testAnalyzeContentReturnsSuggestions() async throws {
        // Given: Photos and a mock LLM returning valid analysis
        let assets = Self.makeTestAssets(count: 3)
        let mockLLM = MockAnalyzerLLMGateway(
            responses: [
                LLMResponse(
                    text: """
                    {
                      "title": "Beach Sunset",
                      "description": "A sunset scene at the beach with waves",
                      "confidence": 0.92
                    }
                    """,
                    modelID: "test-model",
                    providerName: "test-provider",
                    inputTokens: 100,
                    outputTokens: 50
                ),
                LLMResponse(
                    text: """
                    {
                      "title": "Mountain View",
                      "description": "Snow-capped mountains with clear sky",
                      "confidence": 0.88
                    }
                    """,
                    modelID: "test-model",
                    providerName: "test-provider",
                    inputTokens: 100,
                    outputTokens: 50
                ),
                LLMResponse(
                    text: """
                    {
                      "title": "City Skyline at Night",
                      "description": "Urban skyline with illuminated buildings",
                      "confidence": 0.85
                    }
                    """,
                    modelID: "test-model",
                    providerName: "test-provider",
                    inputTokens: 100,
                    outputTokens: 50
                ),
            ]
        )
        let service = ContentAnalyzerService(llmGateway: mockLLM)
        let mockRepo = MockAnalyzerTestRepository()

        // When: Analyzing content
        let suggestions = try await service.analyzeContent(
            assets: assets,
            repository: mockRepo,
            language: "en"
        )

        // Then: Suggestions are generated for each asset
        XCTAssertEqual(suggestions.count, 3, "Should generate one suggestion per asset")
        for suggestion in suggestions {
            XCTAssertEqual(suggestion.status, .pending)
            XCTAssertFalse(suggestion.suggestedName.isEmpty)
            XCTAssertGreaterThan(suggestion.confidence, 0.0)
            XCTAssertLessThanOrEqual(suggestion.confidence, 1.0)
        }
    }

    /// [P1] ContentAnalyzerService respects language parameter.
    ///
    /// AC1/FR25: LLM prompt includes the user's preferred language for title generation.
    func testAnalyzeContentRespectsLanguageParameter() async throws {
        // Given: Assets and a tracking LLM gateway
        let assets = Self.makeTestAssets(count: 1)
        let trackingLLM = TrackingMockAnalyzerLLMGateway(
            response: LLMResponse(
                text: """
                {
                  "title": "Sunset",
                  "description": "Beach sunset",
                  "confidence": 0.9
                }
                """,
                modelID: "test-model",
                providerName: "test-provider",
                inputTokens: 50,
                outputTokens: 20
            )
        )
        let service = ContentAnalyzerService(llmGateway: trackingLLM)
        let mockRepo = MockAnalyzerTestRepository()

        // When: Analyzing with Chinese language preference
        _ = try await service.analyzeContent(
            assets: assets,
            repository: mockRepo,
            language: "zh"
        )

        // Then: LLM was called with a prompt containing the language instruction
        let lastPrompt = await trackingLLM.lastPrompt
        XCTAssertTrue(lastPrompt.contains("zh") || lastPrompt.lowercased().contains("chinese"),
            "Prompt should include language parameter, got: \(lastPrompt)")
    }

    // MARK: - AC3: Error Tolerance (Partial Failure)

    /// [P0] Partial LLM failure marks affected photos as failed without blocking others.
    ///
    /// AC3: Given LLM fails for one of three photos,
    /// When the analysis continues,
    /// Then the failed photo is marked .failed and others complete successfully.
    func testAnalyzeContentHandlesPartialFailure() async throws {
        // Given: 3 assets, LLM fails on the 2nd call
        let assets = Self.makeTestAssets(count: 3)
        let mockLLM = MockAnalyzerLLMGateway(
            responses: [
                LLMResponse(
                    text: """
                    {
                      "title": "First Photo",
                      "description": "Description of first photo",
                      "confidence": 0.9
                    }
                    """,
                    modelID: "test-model",
                    providerName: "test-provider",
                    inputTokens: 100,
                    outputTokens: 50
                ),
            ],
            failOnCallNumber: 2
        )
        let service = ContentAnalyzerService(llmGateway: mockLLM)
        let mockRepo = MockAnalyzerTestRepository()

        // When: Analyzing content
        let suggestions = try await service.analyzeContent(
            assets: assets,
            repository: mockRepo,
            language: "en"
        )

        // Then: All 3 suggestions returned, one marked as failed
        XCTAssertEqual(suggestions.count, 3, "Should return suggestions for all assets")

        let failedSuggestions = suggestions.filter {
            if case .failed = $0.status { return true }
            return false
        }
        let successSuggestions = suggestions.filter { $0.status == .pending }

        XCTAssertEqual(failedSuggestions.count, 1, "Exactly one suggestion should be marked as failed")
        XCTAssertEqual(successSuggestions.count, 2, "Two suggestions should succeed")
    }

    /// [P0] All photos fail gracefully when LLM is completely unavailable.
    ///
    /// AC3: Given LLM fails for all photos,
    /// When analysis completes,
    /// Then all photos are marked as failed and no crash occurs.
    func testAnalyzeContentHandlesCompleteLLMFailure() async throws {
        // Given: Assets and an LLM that always fails
        let assets = Self.makeTestAssets(count: 3)
        let mockLLM = MockAnalyzerLLMGateway(
            responses: [],
            failAlways: true
        )
        let service = ContentAnalyzerService(llmGateway: mockLLM)
        let mockRepo = MockAnalyzerTestRepository()

        // When: Analyzing content
        let suggestions = try await service.analyzeContent(
            assets: assets,
            repository: mockRepo,
            language: "en"
        )

        // Then: All suggestions are marked as failed
        XCTAssertEqual(suggestions.count, 3, "Should return suggestions for all assets even on total failure")
        for suggestion in suggestions {
            if case .failed = suggestion.status {
                // Expected
            } else {
                XCTFail("All suggestions should be marked as failed when LLM is unavailable, got: \(suggestion.status)")
            }
        }
    }

    // MARK: - AC2: Name Sanitization

    /// [P0] Illegal characters in LLM-generated names are sanitized.
    ///
    /// AC2: When LLM returns a title with illegal file system characters,
    /// Then the suggested name is sanitized to remove/replace them.
    func testAnalyzeContentSanitizesNames() async throws {
        // Given: LLM returns a title with illegal characters
        let assets = Self.makeTestAssets(count: 1)
        let mockLLM = MockAnalyzerLLMGateway(
            responses: [
                LLMResponse(
                    text: """
                    {
                      "title": "Beach: Sunset *Special* Edition <2024>",
                      "description": "A sunset at the beach",
                      "confidence": 0.9
                    }
                    """,
                    modelID: "test-model",
                    providerName: "test-provider",
                    inputTokens: 100,
                    outputTokens: 50
                ),
            ]
        )
        let service = ContentAnalyzerService(llmGateway: mockLLM)
        let mockRepo = MockAnalyzerTestRepository()

        // When: Analyzing content
        let suggestions = try await service.analyzeContent(
            assets: assets,
            repository: mockRepo,
            language: "en"
        )

        // Then: Suggested name does not contain illegal characters
        XCTAssertEqual(suggestions.count, 1)
        let suggestedName = suggestions[0].suggestedName
        let illegalChars = CharacterSet(charactersIn: "\\/:*?\"<>|")
        XCTAssertTrue(
            suggestedName.unicodeScalars.allSatisfy { !illegalChars.contains($0) },
            "Suggested name '\(suggestedName)' should not contain illegal file system characters"
        )
    }

    /// [P0] Overly long names are truncated.
    ///
    /// AC2: When LLM returns a very long title, it is truncated to a safe length.
    func testAnalyzeContentTruncatesLongNames() async throws {
        // Given: LLM returns a very long title
        let assets = Self.makeTestAssets(count: 1)
        let longTitle = String(repeating: "Very Long Title ", count: 30)
        let mockLLM = MockAnalyzerLLMGateway(
            responses: [
                LLMResponse(
                    text: """
                    {
                      "title": "\(longTitle)",
                      "description": "Description",
                      "confidence": 0.8
                    }
                    """,
                    modelID: "test-model",
                    providerName: "test-provider",
                    inputTokens: 100,
                    outputTokens: 50
                ),
            ]
        )
        let service = ContentAnalyzerService(llmGateway: mockLLM)
        let mockRepo = MockAnalyzerTestRepository()

        // When: Analyzing content
        let suggestions = try await service.analyzeContent(
            assets: assets,
            repository: mockRepo,
            language: "en"
        )

        // Then: Suggested name is truncated
        XCTAssertEqual(suggestions.count, 1)
        XCTAssertLessThanOrEqual(suggestions[0].suggestedName.count, 200,
            "Suggested name should be truncated to 200 characters max")
    }

    // MARK: - AC4: Progress Reporting

    /// [P1] Progress handler reports analyzed/total progress.
    ///
    /// AC4: Given batch analysis is executing,
    /// When progress updates occur,
    /// Then the handler receives (analyzed, total) counts via callback.
    func testAnalyzeContentReportsProgress() async throws {
        // Given: 3 assets and a progress tracker
        let assets = Self.makeTestAssets(count: 3)
        let mockLLM = MockAnalyzerLLMGateway(
            responses: [
                LLMResponse(
                    text: """
                    { "title": "Photo", "description": "Desc", "confidence": 0.8 }
                    """,
                    modelID: "test-model",
                    providerName: "test-provider",
                    inputTokens: 50,
                    outputTokens: 20
                ),
            ]
        )
        let service = ContentAnalyzerService(llmGateway: mockLLM)
        let mockRepo = MockAnalyzerTestRepository()

        let reportedProgress = LockedValue<[(analyzed: Int, total: Int)]>(initialValue: [])
        let progressHandler: @Sendable (Int, Int) -> Void = { analyzed, total in
            reportedProgress.withValue { $0.append((analyzed, total)) }
        }

        // When: Analyzing with progress handler
        _ = try await service.analyzeContent(
            assets: assets,
            repository: mockRepo,
            language: "en",
            progressHandler: progressHandler
        )

        // Then: Progress was reported for each analyzed photo
        let progress = reportedProgress.withValue { $0 }
        XCTAssertFalse(progress.isEmpty, "Progress should be reported")
        XCTAssertEqual(progress.last?.total, 3, "Final total should be 3")
        XCTAssertEqual(progress.last?.analyzed, 3, "Final analyzed count should be 3")
    }

    // MARK: - AC1: Empty Input

    /// [P1] Empty asset list returns empty suggestions.
    ///
    /// AC1: Given no photos to analyze,
    /// When analyzeContent is called,
    /// Then it returns an empty array without errors.
    func testAnalyzeContentEmptyAssets() async throws {
        // Given: No assets
        let mockLLM = MockAnalyzerLLMGateway(responses: [])
        let service = ContentAnalyzerService(llmGateway: mockLLM)
        let mockRepo = MockAnalyzerTestRepository()

        // When: Analyzing empty list
        let suggestions = try await service.analyzeContent(
            assets: [],
            repository: mockRepo,
            language: "en"
        )

        // Then: Empty result
        XCTAssertTrue(suggestions.isEmpty, "Empty input should return empty suggestions")
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

// MARK: - Mock: LLMGateway for ContentAnalyzer Tests

/// Mock LLM gateway that returns pre-configured responses, optionally failing on a specific call.
private actor MockAnalyzerLLMGateway: LLMGatewayProtocol {
    private let responses: [LLMResponse]
    private let failOnCallNumber: Int?
    private let failAlways: Bool
    private var callCount = 0

    init(
        responses: [LLMResponse],
        failOnCallNumber: Int? = nil,
        failAlways: Bool = false
    ) {
        self.responses = responses
        self.failOnCallNumber = failOnCallNumber
        self.failAlways = failAlways
    }

    func analyze(images: [Data], prompt: String, model: String) async throws -> LLMResponse {
        callCount += 1

        if failAlways {
            throw DomainError.analysisFailed(reason: "Simulated LLM failure for test")
        }

        if let failOn = failOnCallNumber, callCount == failOn {
            throw DomainError.analysisFailed(reason: "Simulated LLM failure on call \(callCount)")
        }

        let index = min(callCount - 1, responses.count - 1)
        guard index >= 0, !responses.isEmpty else {
            throw DomainError.analysisFailed(reason: "No mock responses configured")
        }
        return responses[index]
    }

    func estimateCost(imageCount: Int, model: String) async -> CostEstimate {
        CostEstimate(
            estimatedTokens: imageCount * 100,
            estimatedCost: 0.01,
            modelID: model,
            providerName: "test-provider",
            estimatedAPICalls: 1,
            currency: "USD"
        )
    }
}

/// LLM gateway that tracks the prompt content for verification.
private actor TrackingMockAnalyzerLLMGateway: LLMGatewayProtocol {
    private let response: LLMResponse
    private(set) var lastPrompt: String = ""

    init(response: LLMResponse) {
        self.response = response
    }

    func analyze(images: [Data], prompt: String, model: String) async throws -> LLMResponse {
        lastPrompt = prompt
        return response
    }

    func estimateCost(imageCount: Int, model: String) async -> CostEstimate {
        CostEstimate(
            estimatedTokens: imageCount * 100,
            estimatedCost: 0.01,
            modelID: model,
            providerName: "test-provider",
            estimatedAPICalls: 1,
            currency: "USD"
        )
    }
}

// MARK: - Mock: PhotoLibraryRepository for ContentAnalyzer Tests

/// Mock repository that returns synthetic JPEG image data.
private final class MockAnalyzerTestRepository: PhotoLibraryRepository, @unchecked Sendable {

    func currentBasePath() async -> String? { nil }
    func requestReadAccess() async throws -> Bool { true }
    func requestWriteAccess() async throws -> Bool { true }

    func fetchAssets(predicate: PhotoPredicate, pageSize: Int, pageOffset: Int) async throws -> AssetPage {
        AssetPage(assets: [], hasMore: false, nextOffset: nil)
    }

    func fetchFullResolutionImage(for assetID: AssetID) async throws -> Data {
        Data([0xFF, 0xD8, 0xFF, 0xE0])
    }

    func fetchThumbnail(for assetID: AssetID, size: CGSize) async throws -> Data { Data() }

    func metadata(for assetID: AssetID) async throws -> AssetMetadata {
        AssetMetadata(
            fileName: "mock.jpg",
            fileSize: nil,
            creationDate: nil,
            cameraModel: nil,
            imageWidth: nil,
            imageHeight: nil,
            gpsLocation: nil,
            fileFormat: nil
        )
    }

    func updateAsset(_ assetID: AssetID, title: String?) async throws {}
    func deleteAssets(_ assetIDs: [AssetID]) async throws {}
    func moveAssets(_ assetIDs: [AssetID], to directory: String) async throws {}
    func observeSourceChanges() -> AsyncStream<SourceChange> {
        AsyncStream { $0.finish() }
    }
}
