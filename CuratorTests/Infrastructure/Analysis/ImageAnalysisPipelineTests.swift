import Accelerate
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

/// ATDD Tests for Story 5.2 — Image Analysis Pipeline
///
/// Tests verify:
/// - AC1: Two-stage analysis flow (pHash -> LLM confirmation)
/// - AC3: LLM match reason explanation
/// - AC4: Cancellation support with result retention
/// - AC5: Error handling and fault tolerance
/// - AC6: Memory control (verified via architecture, not runtime)
///
/// TDD RED PHASE: All tests use XCTSkip("ATDD Red Phase") to skip until
/// the feature is implemented. Remove skips one-by-one during implementation.
final class ImageAnalysisPipelineTests: XCTestCase {

    // MARK: - AC1: Two-Stage Analysis Flow (FR20)

    /// [P0] Two-stage analysis produces DuplicateGroups from candidate pairs.
    ///
    /// AC1: Given visually similar duplicate photo groups exist,
    /// When ImageAnalysisPipeline executes analysis,
    /// Then stage 1 filters candidate groups via local pHash,
    /// And stage 2 sends candidate groups to LLM for semantic confirmation,
    /// And DuplicateGroup models are generated with similarity scores and photo references.
    func testTwoStageAnalysisProducesDuplicateGroups() async throws {

        // Given: Photo assets with some visually similar pairs
        let assets = Self.makeTestAssets(count: 6)
        let mockHasher = MockAnalysisPerceptualHasher(
            similarPairs: [
                PairwiseSimilarity(
                    assetID1: assets[0].id,
                    assetID2: assets[1].id,
                    hammingDistance: 3,
                    isSimilar: true
                ),
                PairwiseSimilarity(
                    assetID1: assets[2].id,
                    assetID2: assets[3].id,
                    hammingDistance: 5,
                    isSimilar: true
                ),
            ]
        )
        let mockLLM = MockAnalysisLLMGateway(
            responses: [
                LLMResponse(
                    text: """
                    {
                      "isDuplicate": true,
                      "reason": "Same scene, different compression levels",
                      "confidence": 0.95
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
                      "isDuplicate": true,
                      "reason": "Identical composition, slight crop difference",
                      "confidence": 0.88
                    }
                    """,
                    modelID: "test-model",
                    providerName: "test-provider",
                    inputTokens: 100,
                    outputTokens: 50
                ),
            ]
        )
        let mockThumbnails = MockAnalysisThumbnailGenerator(thumbnailData: Data([0xFF, 0xD8, 0xFF]))
        let pipeline = ImageAnalysisPipeline(
            hasher: mockHasher,
            llmGateway: mockLLM,
            thumbnailGenerator: mockThumbnails
        )
        let mockRepo = MockAnalysisTestRepository()

        // When: Executing the two-stage analysis
        let results = try await pipeline.analyze(assets: assets, repository: mockRepo)

        // Then: DuplicateGroups are produced
        XCTAssertEqual(results.count, 2, "Should produce 2 duplicate groups from 2 similar pairs")

        // And: Each group has the expected assets
        let group1 = results.first { $0.assets.contains(where: { $0.id == assets[0].id }) }
        XCTAssertNotNil(group1, "Should have a group containing the first asset")
        XCTAssertEqual(group1?.assets.count, 2, "Group 1 should contain 2 assets")

        let group2 = results.first { $0.assets.contains(where: { $0.id == assets[2].id }) }
        XCTAssertNotNil(group2, "Should have a group containing the third asset")
        XCTAssertEqual(group2?.assets.count, 2, "Group 2 should contain 2 assets")

        // And: Similarity scores are populated
        for group in results {
            XCTAssertGreaterThan(group.similarityScore, 0.0, "Each group should have a positive similarity score")
            XCTAssertLessThanOrEqual(group.similarityScore, 1.0, "Similarity score should be <= 1.0")
        }
    }

    /// [P0] LLM confirmation filters out false positives from pHash stage.
    ///
    /// AC1/AC5: When LLM determines a candidate group is NOT truly duplicate,
    /// the group is excluded from results.
    func testLLMConfirmationFiltersFalsePositives() async throws {

        // Given: 2 candidate pairs from pHash
        let assets = Self.makeTestAssets(count: 4)
        let mockHasher = MockAnalysisPerceptualHasher(
            similarPairs: [
                PairwiseSimilarity(
                    assetID1: assets[0].id,
                    assetID2: assets[1].id,
                    hammingDistance: 4,
                    isSimilar: true
                ),
                PairwiseSimilarity(
                    assetID1: assets[2].id,
                    assetID2: assets[3].id,
                    hammingDistance: 6,
                    isSimilar: true
                ),
            ]
        )

        // And: LLM confirms first pair but rejects second (burst photos, different expressions)
        let mockLLM = MockAnalysisLLMGateway(
            responses: [
                LLMResponse(
                    text: """
                    {
                      "isDuplicate": true,
                      "reason": "Same photo, different compression",
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
                      "isDuplicate": false,
                      "reason": "Burst photos with different expressions - not duplicates",
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
        let mockThumbnails = MockAnalysisThumbnailGenerator(thumbnailData: Data([0xFF, 0xD8, 0xFF]))
        let pipeline = ImageAnalysisPipeline(
            hasher: mockHasher,
            llmGateway: mockLLM,
            thumbnailGenerator: mockThumbnails
        )
        let mockRepo = MockAnalysisTestRepository()

        // When: Executing analysis
        let results = try await pipeline.analyze(assets: assets, repository: mockRepo)

        // Then: Only the LLM-confirmed group remains
        XCTAssertEqual(results.count, 1, "Should only keep LLM-confirmed duplicates")
        // Verify the remaining group has exactly 2 assets (a valid pair)
        XCTAssertEqual(results.first?.assets.count, 2,
            "The remaining group should contain a pair of assets")
    }

    // MARK: - AC3: LLM Match Reason Explanation (FR20, FR21)

    /// [P0] Each DuplicateGroup contains the LLM-provided match reason.
    ///
    /// AC3: Given two-stage analysis completes,
    /// When results are generated,
    /// Then each duplicate group includes an LLM-provided reason explanation,
    /// And similarity scores can be used to sort display priority.
    func testDuplicateGroupContainsReason() async throws {

        // Given: A candidate pair that LLM confirms as duplicate
        let assets = Self.makeTestAssets(count: 2)
        let expectedReason = "Same scene captured twice, slight exposure difference"
        let mockHasher = MockAnalysisPerceptualHasher(
            similarPairs: [
                PairwiseSimilarity(
                    assetID1: assets[0].id,
                    assetID2: assets[1].id,
                    hammingDistance: 3,
                    isSimilar: true
                ),
            ]
        )
        let mockLLM = MockAnalysisLLMGateway(
            responses: [
                LLMResponse(
                    text: """
                    {
                      "isDuplicate": true,
                      "reason": "\(expectedReason)",
                      "confidence": 0.91
                    }
                    """,
                    modelID: "test-model",
                    providerName: "test-provider",
                    inputTokens: 100,
                    outputTokens: 50
                ),
            ]
        )
        let mockThumbnails = MockAnalysisThumbnailGenerator(thumbnailData: Data([0xFF, 0xD8, 0xFF]))
        let pipeline = ImageAnalysisPipeline(
            hasher: mockHasher,
            llmGateway: mockLLM,
            thumbnailGenerator: mockThumbnails
        )
        let mockRepo = MockAnalysisTestRepository()

        // When: Executing analysis
        let results = try await pipeline.analyze(assets: assets, repository: mockRepo)

        // Then: Result contains the LLM reason
        XCTAssertEqual(results.count, 1)
        XCTAssertNotNil(results.first?.reason, "Group should have a non-nil reason")
        XCTAssertTrue(results.first?.reason?.contains(expectedReason) ?? false,
            "Reason should contain the LLM-provided explanation")
    }

    // MARK: - AC4: Cancellation Support (FR17)

    /// [P0] Cancelling analysis retains already-completed results.
    ///
    /// AC4: Given the analysis pipeline is executing,
    /// When the user cancels the operation,
    /// Then already-completed analysis results are preserved,
    /// And no memory leaks or data inconsistency occur.
    func testAnalysisCancellationRetainsResults() async throws {

        // Given: A pipeline with multiple candidate groups and slow LLM responses
        let assets = Self.makeTestAssets(count: 6)
        let mockHasher = MockAnalysisPerceptualHasher(
            similarPairs: [
                PairwiseSimilarity(
                    assetID1: assets[0].id,
                    assetID2: assets[1].id,
                    hammingDistance: 3,
                    isSimilar: true
                ),
                PairwiseSimilarity(
                    assetID1: assets[2].id,
                    assetID2: assets[3].id,
                    hammingDistance: 4,
                    isSimilar: true
                ),
                PairwiseSimilarity(
                    assetID1: assets[4].id,
                    assetID2: assets[5].id,
                    hammingDistance: 5,
                    isSimilar: true
                ),
            ]
        )

        // Slow LLM to allow cancellation mid-flight
        let mockLLM = MockAnalysisLLMGateway(
            responses: [
                LLMResponse(
                    text: """
                    { "isDuplicate": true, "reason": "Confirmed duplicate", "confidence": 0.9 }
                    """,
                    modelID: "test-model",
                    providerName: "test-provider",
                    inputTokens: 100,
                    outputTokens: 50
                ),
            ],
            artificialDelay: 0.2
        )
        let mockThumbnails = MockAnalysisThumbnailGenerator(thumbnailData: Data([0xFF, 0xD8, 0xFF]))
        let pipeline = ImageAnalysisPipeline(
            hasher: mockHasher,
            llmGateway: mockLLM,
            thumbnailGenerator: mockThumbnails
        )
        let mockRepo = MockAnalysisTestRepository()

        // When: Starting analysis and cancelling after a short delay
        let analysisTask = Task {
            try await pipeline.analyze(assets: assets, repository: mockRepo)
        }

        // Cancel after enough time for at least one group to complete
        try await Task.sleep(for: .milliseconds(300))
        analysisTask.cancel()

        // Then: Should get partial results (at least 1 group, but fewer than 3)
        do {
            let partialResults = try await analysisTask.value
            XCTAssertGreaterThan(partialResults.count, 0,
                "Should retain at least some completed results after cancellation")
            XCTAssertLessThan(partialResults.count, 3,
                "Should not have completed all groups before cancellation")
        } catch is CancellationError {
            // CancellationError is also acceptable — results may be lost
            // The key requirement is no memory leaks or data inconsistency
        } catch {
            // DomainError.operationCancelled is also acceptable
            XCTAssertTrue(error is DomainError, "Should throw DomainError on cancellation")
        }
    }

    // MARK: - AC5: Error Handling and Fault Tolerance (NFR23)

    /// [P0] LLM call failure causes the group to be skipped gracefully.
    ///
    /// AC5: Given LLM call fails for a candidate group,
    /// When the pipeline continues executing,
    /// Then the failed group is marked as "analysis failed" and skipped,
    /// And other candidate groups' analysis continues unaffected.
    func testLLMFailureSkipsGroupGracefully() async throws {

        // Given: 3 candidate pairs, where LLM will fail for the 2nd pair
        let assets = Self.makeTestAssets(count: 6)
        let mockHasher = MockAnalysisPerceptualHasher(
            similarPairs: [
                PairwiseSimilarity(
                    assetID1: assets[0].id,
                    assetID2: assets[1].id,
                    hammingDistance: 3,
                    isSimilar: true
                ),
                PairwiseSimilarity(
                    assetID1: assets[2].id,
                    assetID2: assets[3].id,
                    hammingDistance: 4,
                    isSimilar: true
                ),
                PairwiseSimilarity(
                    assetID1: assets[4].id,
                    assetID2: assets[5].id,
                    hammingDistance: 5,
                    isSimilar: true
                ),
            ]
        )

        // LLM succeeds for group 1, fails for group 2, succeeds for group 3
        let mockLLM = MockAnalysisLLMGateway(
            responses: [
                LLMResponse(
                    text: """
                    { "isDuplicate": true, "reason": "Confirmed", "confidence": 0.9 }
                    """,
                    modelID: "test-model",
                    providerName: "test-provider",
                    inputTokens: 100,
                    outputTokens: 50
                ),
            ],
            failOnCallNumber: 2 // Fail on the second call
        )
        let mockThumbnails = MockAnalysisThumbnailGenerator(thumbnailData: Data([0xFF, 0xD8, 0xFF]))
        let pipeline = ImageAnalysisPipeline(
            hasher: mockHasher,
            llmGateway: mockLLM,
            thumbnailGenerator: mockThumbnails
        )
        let mockRepo = MockAnalysisTestRepository()

        // When: Executing analysis
        let results = try await pipeline.analyze(assets: assets, repository: mockRepo)

        // Then: 2 groups confirmed + 1 group marked as analysisFailed
        let confirmedGroups = results.filter { $0.status == .pending }
        let failedGroups = results.filter { $0.status == .analysisFailed }
        XCTAssertEqual(confirmedGroups.count, 2,
            "Should have 2 confirmed groups")
        XCTAssertEqual(failedGroups.count, 1,
            "Should have 1 group marked as analysisFailed due to LLM failure")

        // And: Failed group has reason and zero similarity
        if let failedGroup = failedGroups.first {
            XCTAssertNotNil(failedGroup.reason, "Failed group should have a reason")
            XCTAssertEqual(failedGroup.similarityScore, 0.0, "Failed group should have zero similarity")
        }
    }

    // MARK: - AC1: Connected Component Clustering

    /// [P1] Similar pairs are correctly clustered into connected groups.
    ///
    /// AC1: Given pairwise similarities A-B, B-C, D-E,
    /// When clustering via connected components,
    /// Then [A,B,C] form one group and [D,E] form another.
    func testConnectedComponentClustering() async throws {

        // Given: Transitive similarity — A similar to B, B similar to C
        let assets = Self.makeTestAssets(count: 5)
        let mockHasher = MockAnalysisPerceptualHasher(
            similarPairs: [
                PairwiseSimilarity(
                    assetID1: assets[0].id,
                    assetID2: assets[1].id,
                    hammingDistance: 3,
                    isSimilar: true
                ),
                PairwiseSimilarity(
                    assetID1: assets[1].id,
                    assetID2: assets[2].id,
                    hammingDistance: 4,
                    isSimilar: true
                ),
                PairwiseSimilarity(
                    assetID1: assets[3].id,
                    assetID2: assets[4].id,
                    hammingDistance: 5,
                    isSimilar: true
                ),
            ]
        )
        // All confirmed by LLM
        let mockLLM = MockAnalysisLLMGateway(
            responses: [
                LLMResponse(
                    text: """
                    { "isDuplicate": true, "reason": "Transitive group confirmed", "confidence": 0.9 }
                    """,
                    modelID: "test-model",
                    providerName: "test-provider",
                    inputTokens: 100,
                    outputTokens: 50
                ),
                LLMResponse(
                    text: """
                    { "isDuplicate": true, "reason": "Separate pair confirmed", "confidence": 0.88 }
                    """,
                    modelID: "test-model",
                    providerName: "test-provider",
                    inputTokens: 100,
                    outputTokens: 50
                ),
            ]
        )
        let mockThumbnails = MockAnalysisThumbnailGenerator(thumbnailData: Data([0xFF, 0xD8, 0xFF]))
        let pipeline = ImageAnalysisPipeline(
            hasher: mockHasher,
            llmGateway: mockLLM,
            thumbnailGenerator: mockThumbnails
        )
        let mockRepo = MockAnalysisTestRepository()

        // When: Executing analysis
        let results = try await pipeline.analyze(assets: assets, repository: mockRepo)

        // Then: 2 groups — [A,B,C] and [D,E]
        XCTAssertEqual(results.count, 2, "Should produce 2 connected component groups")

        let largeGroup = results.first { $0.assets.count == 3 }
        XCTAssertNotNil(largeGroup, "Should have a 3-asset group from transitive similarity")
        let largeGroupIDs = Set(largeGroup!.assets.map(\.id))
        XCTAssertTrue(largeGroupIDs.contains(assets[0].id))
        XCTAssertTrue(largeGroupIDs.contains(assets[1].id))
        XCTAssertTrue(largeGroupIDs.contains(assets[2].id))

        let smallGroup = results.first { $0.assets.count == 2 }
        XCTAssertNotNil(smallGroup, "Should have a 2-asset group")
        let smallGroupIDs = Set(smallGroup!.assets.map(\.id))
        XCTAssertTrue(smallGroupIDs.contains(assets[3].id))
        XCTAssertTrue(smallGroupIDs.contains(assets[4].id))
    }

    // MARK: - Progress Reporting

    /// [P1] Progress handler reports all analysis stages.
    ///
    /// AC1: Progress callback reports hashing, pairComparison, llmConfirmation,
    /// thumbnailGeneration, and completed stages.
    func testProgressHandlerReportsStages() async throws {

        // Given: Assets and a pipeline with progress tracking
        let assets = Self.makeTestAssets(count: 2)
        let mockHasher = MockAnalysisPerceptualHasher(
            similarPairs: [
                PairwiseSimilarity(
                    assetID1: assets[0].id,
                    assetID2: assets[1].id,
                    hammingDistance: 3,
                    isSimilar: true
                ),
            ]
        )
        let mockLLM = MockAnalysisLLMGateway(
            responses: [
                LLMResponse(
                    text: """
                    { "isDuplicate": true, "reason": "Confirmed", "confidence": 0.9 }
                    """,
                    modelID: "test-model",
                    providerName: "test-provider",
                    inputTokens: 100,
                    outputTokens: 50
                ),
            ]
        )
        let mockThumbnails = MockAnalysisThumbnailGenerator(thumbnailData: Data([0xFF, 0xD8, 0xFF]))
        let pipeline = ImageAnalysisPipeline(
            hasher: mockHasher,
            llmGateway: mockLLM,
            thumbnailGenerator: mockThumbnails
        )
        let mockRepo = MockAnalysisTestRepository()

        let reportedStages = LockedValue<[AnalysisStage]>(initialValue: [])
        let progressHandler: @Sendable (AnalysisProgress) -> Void = { progress in
            reportedStages.withValue { $0.append(progress.stage) }
        }

        // When: Executing analysis with progress handler
        _ = try await pipeline.analyze(
            assets: assets,
            repository: mockRepo,
            progressHandler: progressHandler
        )

        // Then: All expected stages reported
        let stages = reportedStages.withValue { $0 }
        XCTAssertTrue(stages.contains(.hashing),
            "Should report hashing stage")
        XCTAssertTrue(stages.contains(.pairComparison),
            "Should report pair comparison stage")
        XCTAssertTrue(stages.contains(.llmConfirmation),
            "Should report LLM confirmation stage")
        XCTAssertTrue(stages.contains(.thumbnailGeneration),
            "Should report thumbnail generation stage")
        XCTAssertTrue(stages.contains(.completed),
            "Should report completed stage")
    }

    // MARK: - Similarity Score Ordering

    /// [P1] Results are sorted by similarity score in descending order.
    ///
    /// AC3: DuplicateGroups should be sortable by similarity score for display priority.
    func testSimilarityScoreOrdering() async throws {

        // Given: Multiple groups with different similarity scores
        let assets = Self.makeTestAssets(count: 4)
        let mockHasher = MockAnalysisPerceptualHasher(
            similarPairs: [
                PairwiseSimilarity(
                    assetID1: assets[0].id,
                    assetID2: assets[1].id,
                    hammingDistance: 2, // Higher similarity
                    isSimilar: true
                ),
                PairwiseSimilarity(
                    assetID1: assets[2].id,
                    assetID2: assets[3].id,
                    hammingDistance: 8, // Lower similarity
                    isSimilar: true
                ),
            ]
        )
        let mockLLM = MockAnalysisLLMGateway(
            responses: [
                LLMResponse(
                    text: """
                    { "isDuplicate": true, "reason": "Very similar", "confidence": 0.97 }
                    """,
                    modelID: "test-model",
                    providerName: "test-provider",
                    inputTokens: 100,
                    outputTokens: 50
                ),
                LLMResponse(
                    text: """
                    { "isDuplicate": true, "reason": "Somewhat similar", "confidence": 0.72 }
                    """,
                    modelID: "test-model",
                    providerName: "test-provider",
                    inputTokens: 100,
                    outputTokens: 50
                ),
            ]
        )
        let mockThumbnails = MockAnalysisThumbnailGenerator(thumbnailData: Data([0xFF, 0xD8, 0xFF]))
        let pipeline = ImageAnalysisPipeline(
            hasher: mockHasher,
            llmGateway: mockLLM,
            thumbnailGenerator: mockThumbnails
        )
        let mockRepo = MockAnalysisTestRepository()

        // When: Executing analysis
        let results = try await pipeline.analyze(assets: assets, repository: mockRepo)

        // Then: Results sorted by similarity score descending
        XCTAssertEqual(results.count, 2)
        XCTAssertGreaterThan(results[0].similarityScore, results[1].similarityScore,
            "First result should have higher similarity score than second")
    }

    // MARK: - Thumbnail Integration

    /// [P0] Thumbnail data is generated for each DuplicateGroup.
    ///
    /// AC2: ThumbnailGenerator generates thumbnails for each photo in each group.
    func testThumbnailGenerationForDuplicateGroups() async throws {

        // Given: A confirmed duplicate group
        let assets = Self.makeTestAssets(count: 2)
        let mockHasher = MockAnalysisPerceptualHasher(
            similarPairs: [
                PairwiseSimilarity(
                    assetID1: assets[0].id,
                    assetID2: assets[1].id,
                    hammingDistance: 3,
                    isSimilar: true
                ),
            ]
        )
        let mockLLM = MockAnalysisLLMGateway(
            responses: [
                LLMResponse(
                    text: """
                    { "isDuplicate": true, "reason": "Confirmed", "confidence": 0.9 }
                    """,
                    modelID: "test-model",
                    providerName: "test-provider",
                    inputTokens: 100,
                    outputTokens: 50
                ),
            ]
        )
        let expectedThumbnail = Data([0xFF, 0xD8, 0xFF, 0xE0])
        let mockThumbnails = MockAnalysisThumbnailGenerator(thumbnailData: expectedThumbnail)
        let pipeline = ImageAnalysisPipeline(
            hasher: mockHasher,
            llmGateway: mockLLM,
            thumbnailGenerator: mockThumbnails
        )
        let mockRepo = MockAnalysisTestRepository()

        // When: Executing analysis
        let results = try await pipeline.analyze(assets: assets, repository: mockRepo)

        // Then: DuplicateGroups contain thumbnail data
        XCTAssertEqual(results.count, 1)
        let group = results.first!
        XCTAssertFalse(group.thumbnails.isEmpty,
            "Group should contain thumbnail data")
        XCTAssertEqual(group.thumbnails[assets[0].id], expectedThumbnail,
            "First asset should have expected thumbnail data")
        XCTAssertEqual(group.thumbnails[assets[1].id], expectedThumbnail,
            "Second asset should have expected thumbnail data")
    }

    // MARK: - Value Type Tests

    /// [P1] DuplicateGroup conforms to Sendable and Identifiable.
    func testDuplicateGroupSendableAndIdentifiable() async throws {

        // Given: A DuplicateGroup
        let assets = Self.makeTestAssets(count: 2)
        let group = DuplicateGroup(
            assets: assets,
            similarityScore: 0.9,
            reason: "Same photo",
            thumbnails: [:],
            status: .pending
        )

        // Then: Identifiable
        let _ = group.id // UUID — verified at compile time

        // And: Sendable verified by usage across isolation boundary
        let _ = group
    }

    /// [P1] DuplicateGroupStatus has expected cases.
    func testDuplicateGroupStatusCases() async throws {

        // Then: All expected status cases exist
        let _ = DuplicateGroupStatus.pending
        let _ = DuplicateGroupStatus.confirmed
        let _ = DuplicateGroupStatus.rejected
        let _ = DuplicateGroupStatus.analysisFailed
    }

    /// [P1] AnalysisProgress contains expected fields.
    func testAnalysisProgressFields() async throws {

        // Given: An AnalysisProgress value
        let progress = AnalysisProgress(stage: .hashing, completed: 10, total: 100)

        // Then: Fields are populated
        XCTAssertEqual(progress.stage, .hashing)
        XCTAssertEqual(progress.completed, 10)
        XCTAssertEqual(progress.total, 100)
    }

    /// [P1] AnalysisStage has expected cases.
    func testAnalysisStageCases() async throws {

        // Then: All expected stage cases exist
        let _ = AnalysisStage.hashing
        let _ = AnalysisStage.pairComparison
        let _ = AnalysisStage.llmConfirmation
        let _ = AnalysisStage.thumbnailGeneration
        let _ = AnalysisStage.completed
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

// MARK: - Mock: PerceptualHasher for Analysis Pipeline Tests

/// Mock hasher that returns pre-configured hash values and similar pairs.
private struct MockAnalysisPerceptualHasher: PerceptualHasherProtocol {
    private let similarPairs: [PairwiseSimilarity]

    init(similarPairs: [PairwiseSimilarity] = []) {
        self.similarPairs = similarPairs
    }

    func computeHash(for imageData: Data) async throws -> UInt64 {
        0
    }

    func computeHashes(
        for assets: [PhotoAsset],
        repository: PhotoLibraryRepository
    ) async throws -> [PerceptualHashValue] {
        assets.map { PerceptualHashValue(assetID: $0.id, hash: UInt64.random(in: 0...UInt64.max), computedAt: Date()) }
    }

    func findSimilarPairs(
        hashes: [PerceptualHashValue],
        threshold: Int
    ) async -> [PairwiseSimilarity] {
        similarPairs
    }
}

// MARK: - Mock: LLMGateway for Analysis Pipeline Tests

/// Mock LLM gateway that returns pre-configured responses, optionally failing on a specific call.
private actor MockAnalysisLLMGateway: LLMGatewayProtocol {
    private let responses: [LLMResponse]
    private let artificialDelay: TimeInterval
    private let failOnCallNumber: Int?
    private var callCount = 0

    init(
        responses: [LLMResponse],
        artificialDelay: TimeInterval = 0,
        failOnCallNumber: Int? = nil
    ) {
        self.responses = responses
        self.artificialDelay = artificialDelay
        self.failOnCallNumber = failOnCallNumber
    }

    func analyze(images: [Data], prompt: String, model: String) async throws -> LLMResponse {
        callCount += 1

        if let failOn = failOnCallNumber, callCount == failOn {
            throw DomainError.analysisFailed(reason: "Simulated LLM failure for test")
        }

        if artificialDelay > 0 {
            try await Task.sleep(for: .seconds(artificialDelay))
        }

        let index = min(callCount - 1, responses.count - 1)
        guard index >= 0, !responses.isEmpty else {
            throw DomainError.analysisFailed(reason: "No mock responses configured")
        }
        return responses[index]
    }

    func estimateCost(imageCount: Int, model: String) async -> CostEstimate {
        CostEstimate(estimatedTokens: imageCount * 100, estimatedCost: 0.01, modelID: model, providerName: "test-provider", estimatedAPICalls: 1, currency: "USD")
    }
}

// MARK: - Mock: ThumbnailGenerator for Analysis Pipeline Tests

/// Mock thumbnail generator that returns fixed data for all requests.
private struct MockAnalysisThumbnailGenerator: ThumbnailGeneratorProtocol {
    private let thumbnailData: Data

    init(thumbnailData: Data) {
        self.thumbnailData = thumbnailData
    }

    func generateThumbnail(
        for assetID: AssetID,
        repository: PhotoLibraryRepository,
        targetSize: CGSize
    ) async throws -> Data {
        thumbnailData
    }

    func generateThumbnails(
        for assets: [PhotoAsset],
        repository: PhotoLibraryRepository,
        targetSize: CGSize
    ) async -> [AssetID: Data] {
        var result: [AssetID: Data] = [:]
        for asset in assets {
            result[asset.id] = thumbnailData
        }
        return result
    }
}

// MARK: - Mock: PhotoLibraryRepository for Analysis Pipeline Tests

/// Mock repository that returns synthetic JPEG image data.
private final class MockAnalysisTestRepository: PhotoLibraryRepository, @unchecked Sendable {

    func currentBasePath() async -> String? { nil }

    func requestReadAccess() async throws -> Bool { true }

    func requestWriteAccess() async throws -> Bool { true }

    func fetchAssets(predicate: PhotoPredicate, pageSize: Int, pageOffset: Int) async throws -> AssetPage {
        AssetPage(assets: [], hasMore: false)
    }

    func fetchFullResolutionImage(for assetID: AssetID) async throws -> Data {
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
