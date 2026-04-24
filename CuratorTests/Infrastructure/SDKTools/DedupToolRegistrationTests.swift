import XCTest
import OpenAgentSDK

@testable import Curator

/// ATDD Tests for Story 5.3 -- Tool Registration & DI Integration (AC5)
///
/// Tests verify:
/// - AC5: All deduplication SDK tools are registered in AgentToolRegistry (FR13)
/// - AC5: CuratorAgent system prompt includes dedup tool descriptions
///
/// TDD RED PHASE: All tests use XCTSkip("ATDD Red Phase") to skip until
/// the feature is implemented. Remove skips one-by-one during implementation.
final class DedupToolRegistrationTests: XCTestCase {

    // MARK: - AC5: Tool Registration (FR13)

    /// [P1] All deduplication tools are registered in AgentToolRegistry.
    ///
    /// AC5: Given all dedup SDK tools are implemented,
    /// When registerDeduplicationTools() is called,
    /// Then analyze_duplicates, delete_assets, and estimate_cost
    /// are all registered in the toolRegistry.
    func testAllDedupToolsRegisteredInRegistry() async throws {
        // Given: A registry with deduplication tools registered
        let registry = AgentToolRegistry()
        let mockPipeline = MockRegistrationAnalysisPipeline()
        let mockRepo = MockRegistrationTestRepository()
        let mockManager = MockRegistrationOperationManager()
        let mockGateway = MockRegistrationLLMGateway()

        // Register dedup tools (mirrors AppDependencies.registerDeduplicationTools)
        registry.register(createAnalyzeDuplicatesTool(
            pipeline: mockPipeline,
            repository: mockRepo
        ))
        registry.register(createDeleteAssetsTool(
            operationManager: mockManager,
            repository: mockRepo
        ))
        registry.register(createEstimateCostTool(
            llmGateway: mockGateway
        ))

        // Then: All tools are registered
        let toolNames = Set(registry.allTools.map { $0.name })
        XCTAssertTrue(toolNames.contains("analyze_duplicates"),
            "Registry should contain analyze_duplicates tool")
        XCTAssertTrue(toolNames.contains("delete_assets"),
            "Registry should contain delete_assets tool")
        XCTAssertTrue(toolNames.contains("estimate_cost"),
            "Registry should contain estimate_cost tool")
    }

    /// [P1] ScanLibraryTool is already registered (verify existing registration).
    ///
    /// AC5: ScanLibraryTool was registered in Story 3.2; verify it remains registered.
    func testScanLibraryToolRegistered() async throws {
        // Given: A registry with scan_library tool
        let registry = AgentToolRegistry()
        let mockRepo = MockRegistrationTestRepository()

        registry.register(createScanLibraryTool(repository: mockRepo))

        // Then: scan_library is registered
        let scanTool = registry.tool(named: "scan_library")
        XCTAssertNotNil(scanTool,
            "scan_library tool should be registered")
    }

    // MARK: - AC5: Tool Annotations Correctness

    /// [P1] All deduplication tools have correct annotations.
    ///
    /// AC5: readOnlyHint and destructiveHint must be correctly set per tool.
    func testToolAnnotationsCorrect() async throws {
        let mockPipeline = MockRegistrationAnalysisPipeline()
        let mockRepo = MockRegistrationTestRepository()
        let mockManager = MockRegistrationOperationManager()
        let mockGateway = MockRegistrationLLMGateway()

        // analyze_duplicates: read-only, not destructive
        let analyzeTool = createAnalyzeDuplicatesTool(
            pipeline: mockPipeline,
            repository: mockRepo
        )
        XCTAssertTrue(analyzeTool.isReadOnly)
        XCTAssertEqual(analyzeTool.annotations?.readOnlyHint, true)
        XCTAssertEqual(analyzeTool.annotations?.destructiveHint, false)

        // delete_assets: NOT read-only, IS destructive
        let deleteTool = createDeleteAssetsTool(
            operationManager: mockManager,
            repository: mockRepo
        )
        XCTAssertFalse(deleteTool.isReadOnly)
        XCTAssertEqual(deleteTool.annotations?.readOnlyHint, false)
        XCTAssertEqual(deleteTool.annotations?.destructiveHint, true)

        // estimate_cost: read-only, not destructive
        let costTool = createEstimateCostTool(llmGateway: mockGateway)
        XCTAssertTrue(costTool.isReadOnly)
        XCTAssertEqual(costTool.annotations?.readOnlyHint, true)
        XCTAssertEqual(costTool.annotations?.destructiveHint, false)
    }

    // MARK: - AC5: System Prompt Update

    /// [P1] CuratorAgent system prompt includes deduplication tool descriptions.
    ///
    /// AC5: CuratorAgent.photoManagerSystemPrompt should mention
    /// analyze_duplicates, delete_assets, and estimate_cost.
    func testSystemPromptIncludesDedupTools() throws {
        let prompt = CuratorAgent.photoManagerSystemPrompt

        XCTAssertTrue(prompt.contains("analyze_duplicates"),
            "System prompt should mention analyze_duplicates tool")
        XCTAssertTrue(prompt.contains("delete_assets"),
            "System prompt should mention delete_assets tool")
        XCTAssertTrue(prompt.contains("estimate_cost"),
            "System prompt should mention estimate_cost tool")
    }

    /// [P1] CuratorAgent system prompt includes deduplication workflow guidance.
    ///
    /// AC5: System prompt should guide the agent to use the dedup workflow:
    /// scan_library -> estimate_cost -> analyze_duplicates -> review -> delete_assets.
    func testSystemPromptIncludesDedupWorkflowGuidance() throws {
        let prompt = CuratorAgent.photoManagerSystemPrompt

        // Should mention the workflow order or guidance
        let hasDedupGuidance = prompt.contains("deduplication") || prompt.contains("dedup")
        XCTAssertTrue(hasDedupGuidance,
            "System prompt should include deduplication workflow guidance")
    }
}

// MARK: - Mocks for Registration Tests

private struct MockRegistrationAnalysisPipeline: ImageAnalysisPipelineProtocol {
    func analyze(assets: [PhotoAsset], repository: PhotoLibraryRepository) async throws -> [DuplicateGroup] { [] }
    func analyze(assets: [PhotoAsset], repository: PhotoLibraryRepository, progressHandler: (@Sendable (AnalysisProgress) -> Void)?) async throws -> [DuplicateGroup] { [] }
}

private actor MockRegistrationOperationManager: OperationManaging {
    func beginBatch(operations: [PlannedOperation], repository: PhotoLibraryRepository) async throws -> OperationManaging.BatchID { UUID() }
    func executeBatch(_ batchID: OperationManaging.BatchID, repository: PhotoLibraryRepository) async throws {}
    func rollbackBatch(_ batchID: OperationManaging.BatchID, repository: PhotoLibraryRepository) async throws {}
    func rollbackLastBatch(repository: PhotoLibraryRepository) async throws {}
    func detectIncompleteBatches() async throws -> [BatchOperation] { [] }
    func getBatchHistory(limit: Int) async throws -> [BatchOperation] { [] }
    func reexecuteLastRolledBackBatch(repository: PhotoLibraryRepository) async throws {}
}

private struct MockRegistrationLLMGateway: LLMGatewayProtocol {
    func analyze(images: [Data], prompt: String, model: String) async throws -> LLMResponse {
        LLMResponse(text: "mock", modelID: model, providerName: "test", inputTokens: 0, outputTokens: 0)
    }
    func estimateCost(imageCount: Int, model: String) async -> CostEstimate {
        CostEstimate(estimatedTokens: 0, estimatedCost: 0, modelID: model, providerName: "test", estimatedAPICalls: 0, currency: "USD")
    }
}

private final class MockRegistrationTestRepository: PhotoLibraryRepository, @unchecked Sendable {
    func currentBasePath() async -> String? { nil }
    func requestReadAccess() async throws -> Bool { true }
    func requestWriteAccess() async throws -> Bool { true }
    func fetchAssets(predicate: PhotoPredicate, pageSize: Int, pageOffset: Int) async throws -> AssetPage {
        AssetPage(assets: [], hasMore: false)
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
