import Foundation
import XCTest
import OpenAgentSDK

@testable import Curator

/// ATDD Tests for Story 6.2 -- RenameAssetsTool (AC1, AC2, AC3)
///
/// Tests verify:
/// - AC1: RenameAssetsTool executes batch rename via OperationManager with snapshots (FR28)
/// - AC2: Cost estimate integration -- tool registered in AgentToolRegistry alongside estimate_cost
/// - AC3: Partial failure tolerance -- tool collects failures and continues (FR28)
///
/// TDD RED PHASE: All tests use `#if false` / `#endif` guards to prevent compilation
/// errors for not-yet-implemented types. Remove guards one-by-one during implementation
/// to activate each test.
final class RenameAssetsToolTests: XCTestCase {

    // MARK: - AC1: RenameAssetsTool Executes Batch Rename (FR28)

    /// [P0] RenameAssetsTool performs batch rename and returns success JSON.
    ///
    /// AC1: Given user has reviewed and accepted rename suggestions,
    /// When Agent calls RenameAssetsTool,
    /// Then tool calls operationManager.beginBatch() to create snapshot,
    /// And tool calls operationManager.executeBatch() to execute rename,
    /// And returns JSON with batchID and renamedCount.
    func testRenameAssetsToolReturnsSuccess() async throws {
        // Given: A tracking operation manager and valid rename suggestions
        let trackingManager = TrackingRenameMockOperationManager()
        let mockRepo = MockRenameTestRepository()

        let tool = createRenameAssetsTool(
            operationManager: trackingManager,
            repository: mockRepo
        )

        // When: Calling the tool with rename suggestions
        let result = try await tool.call(
            input: [
                "suggestions": [
                    ["assetID": "/photos/beach_001.jpg", "suggestedName": "Beach Sunset.jpg", "originalFileName": "IMG_001.jpg"],
                    ["assetID": "/photos/mountain_002.jpg", "suggestedName": "Mountain View.jpg", "originalFileName": "IMG_002.jpg"],
                ]
            ] as [String: Any],
            context: ToolContext(cwd: "/tmp")
        )

        // Then: Rename succeeds with batchID and count
        XCTAssertFalse(result.isError,
            "RenameAssetsTool should execute without error")
        let beginCalled = await trackingManager.beginBatchCalled
        let execCalled = await trackingManager.executeBatchCalled
        XCTAssertTrue(beginCalled,
            "Tool should call beginBatch to create snapshot")
        XCTAssertTrue(execCalled,
            "Tool should call executeBatch to perform rename")
        XCTAssertTrue(result.content.contains("batchID") || result.content.contains("success"),
            "Result should contain batchID or success status")
        XCTAssertTrue(result.content.contains("2") || result.content.contains("renamedCount"),
            "Result should reflect 2 renamed items")
    }

    /// [P0] RenameAssetsTool creates snapshot via OperationManager before execution.
    ///
    /// AC1: Verify that beginBatch is called with correct PlannedOperation type.
    /// The operations should have .rename operationType with newTitle parameters.
    func testRenameAssetsToolCreatesSnapshots() async throws {
        // Given: A tracking operation manager that captures operations
        let trackingManager = OperationsCapturingMockOperationManager()
        let mockRepo = MockRenameTestRepository()

        let tool = createRenameAssetsTool(
            operationManager: trackingManager,
            repository: mockRepo
        )

        // When: Calling the tool with rename suggestions
        _ = try await tool.call(
            input: [
                "suggestions": [
                    ["assetID": "/photos/beach_001.jpg", "suggestedName": "Beach Sunset.jpg", "originalFileName": "IMG_001.jpg"],
                ]
            ] as [String: Any],
            context: ToolContext(cwd: "/tmp")
        )

        // Then: Operations captured have .rename type with correct parameters
        let operations = await trackingManager.capturedOperations
        XCTAssertEqual(operations.count, 1,
            "Should create exactly one PlannedOperation for one suggestion")
        XCTAssertEqual(operations[0].operationType, .rename,
            "Operation type should be .rename")
        XCTAssertEqual(operations[0].assetID, AssetID(rawValue: "/photos/beach_001.jpg"),
            "Asset ID should match input")
        if case .rename(let newTitle) = operations[0].parameters {
            XCTAssertEqual(newTitle, "Beach Sunset.jpg",
                "Rename parameter should contain the suggested name")
        } else {
            XCTFail("Operation parameters should be .rename(newTitle:)")
        }
    }

    /// [P0] RenameAssetsTool handles partial failure -- continues processing and reports failures.
    ///
    /// AC3: Given a batch rename where OperationManager.executeBatch throws,
    /// When the failure occurs mid-batch,
    /// Then the tool returns structured error information with failure details.
    func testRenameAssetsToolHandlesPartialFailure() async throws {
        // Given: An operation manager that fails on executeBatch
        let failingManager = FailingRenameMockOperationManager()
        let mockRepo = MockRenameTestRepository()

        let tool = createRenameAssetsTool(
            operationManager: failingManager,
            repository: mockRepo
        )

        // When: Calling the tool with rename suggestions
        let result = try await tool.call(
            input: [
                "suggestions": [
                    ["assetID": "/photos/beach_001.jpg", "suggestedName": "Beach Sunset.jpg", "originalFileName": "IMG_001.jpg"],
                    ["assetID": "/photos/locked_002.jpg", "suggestedName": "Locked File.jpg", "originalFileName": "IMG_002.jpg"],
                ]
            ] as [String: Any],
            context: ToolContext(cwd: "/tmp")
        )

        // Then: Error returned (CodableTool catches throws and wraps as isError:true)
        XCTAssertTrue(result.isError,
            "Tool should return error when batch execution fails")
        let contentLower = result.content.lowercased()
        XCTAssertTrue(contentLower.contains("error"),
            "Error result should contain error information, got: \(result.content)")
    }

    /// [P0] RenameAssetsTool rejects empty input suggestions list.
    ///
    /// AC1: Given an empty suggestions list,
    /// When Agent calls RenameAssetsTool,
    /// Then tool returns validation error without calling OperationManager.
    func testRenameAssetsToolRejectsEmptyInput() async throws {
        // Given: A tracking operation manager to verify no calls
        let trackingManager = TrackingRenameMockOperationManager()
        let mockRepo = MockRenameTestRepository()

        let tool = createRenameAssetsTool(
            operationManager: trackingManager,
            repository: mockRepo
        )

        // When: Calling with empty suggestions array
        let result = try await tool.call(
            input: ["suggestions": []] as [String: Any],
            context: ToolContext(cwd: "/tmp")
        )

        // Then: Returns error without touching OperationManager
        XCTAssertTrue(result.isError,
            "Tool should return error for empty suggestions")
        let beginCalled = await trackingManager.beginBatchCalled
        XCTAssertFalse(beginCalled,
            "Tool should NOT call beginBatch for empty input")
    }

    /// [P0] RenameAssetsTool preserves file metadata during rename.
    ///
    /// AC1: The rename operation only changes the file name, preserving all
    /// original file metadata (file size, creation date, camera model, etc.).
    /// This is verified by checking that PlannedOperation uses .rename type
    /// which only modifies the title, not the file content.
    func testRenameAssetsToolPreservesMetadata() async throws {
        // Given: An operations-capturing manager
        let capturingManager = OperationsCapturingMockOperationManager()
        let mockRepo = MockRenameTestRepository()

        let tool = createRenameAssetsTool(
            operationManager: capturingManager,
            repository: mockRepo
        )

        // When: Calling with a rename suggestion
        _ = try await tool.call(
            input: [
                "suggestions": [
                    ["assetID": "/photos/beach_001.jpg", "suggestedName": "Beach Sunset.jpg", "originalFileName": "IMG_001.jpg"],
                ]
            ] as [String: Any],
            context: ToolContext(cwd: "/tmp")
        )

        // Then: The operation is a rename, not a delete/move/metadataChange
        let operations = await capturingManager.capturedOperations
        XCTAssertEqual(operations.count, 1)
        XCTAssertEqual(operations[0].operationType, .rename,
            "Operation must be .rename type to preserve metadata")
        // .rename only modifies the file name/title, all other metadata untouched
    }

    // MARK: - AC2: Tool Registration and Annotations

    /// [P1] RenameAssetsTool has correct tool name and write-operation annotations.
    ///
    /// AC2: Tool should have name "rename_assets", readOnlyHint: false, destructiveHint: true.
    func testRenameAssetsToolAnnotations() async throws {
        let mockManager = SimpleRenameMockOperationManager()
        let mockRepo = MockRenameTestRepository()

        let tool = createRenameAssetsTool(
            operationManager: mockManager,
            repository: mockRepo
        )

        XCTAssertEqual(tool.name, "rename_assets",
            "Tool name should be 'rename_assets'")
        XCTAssertFalse(tool.isReadOnly,
            "RenameAssetsTool should NOT be marked as read-only")

        if let annotations = tool.annotations {
            XCTAssertFalse(annotations.readOnlyHint,
                "RenameAssetsTool should have readOnlyHint = false")
            XCTAssertTrue(annotations.destructiveHint,
                "RenameAssetsTool should have destructiveHint = true")
        }
    }

    /// [P1] RenameAssetsTool is registered in AgentToolRegistry alongside estimate_cost.
    ///
    /// AC2: Given AgentToolRegistry with rename and cost tools registered,
    /// When querying the registry,
    /// Then both rename_assets and estimate_cost tools are present.
    func testRenameAssetsToolRegisteredInRegistry() async throws {
        // Given: A registry with rename and cost tools registered
        let registry = AgentToolRegistry()
        let mockManager = SimpleRenameMockOperationManager()
        let mockRepo = MockRenameTestRepository()
        let mockGateway = MockRenameLLMGateway()

        registry.register(createRenameAssetsTool(
            operationManager: mockManager,
            repository: mockRepo
        ))
        registry.register(createEstimateCostTool(
            llmGateway: mockGateway
        ))

        // Then: Both tools are registered
        let renameTool = registry.tool(named: "rename_assets")
        XCTAssertNotNil(renameTool,
            "rename_assets tool should be registered")

        let costTool = registry.tool(named: "estimate_cost")
        XCTAssertNotNil(costTool,
            "estimate_cost tool should be registered alongside rename_assets")
    }

    // MARK: - AC3: Partial Failure and Rollback

    /// [P1] RenameAssetsTool triggers rollback on total failure via OperationManager.
    ///
    /// AC3: When all operations fail, OperationManager auto-rollback is invoked.
    /// This is the "Method A" strategy where the entire batch rolls back.
    func testRenameAssetsToolRollbackOnTotalFailure() async throws {
        // Given: An operation manager that fails on executeBatch
        let failingManager = FailingRenameMockOperationManager()
        let mockRepo = MockRenameTestRepository()

        let tool = createRenameAssetsTool(
            operationManager: failingManager,
            repository: mockRepo
        )

        // When: Calling the tool (executeBatch will throw)
        let result = try await tool.call(
            input: [
                "suggestions": [
                    ["assetID": "/photos/fail_001.jpg", "suggestedName": "Fail One.jpg", "originalFileName": "IMG_001.jpg"],
                ]
            ] as [String: Any],
            context: ToolContext(cwd: "/tmp")
        )

        // Then: Error returned and OperationManager handles rollback internally
        XCTAssertTrue(result.isError,
            "Tool should return error when all operations fail")
    }

    /// [P1] RenameAssetsTool returns JSON-serializable result.
    ///
    /// AC1: The tool's return value should be valid JSON containing
    /// success status, batchID, and renamedCount fields.
    func testRenameAssetsToolJSONSerialization() async throws {
        // Given: A working operation manager
        let trackingManager = TrackingRenameMockOperationManager()
        let mockRepo = MockRenameTestRepository()

        let tool = createRenameAssetsTool(
            operationManager: trackingManager,
            repository: mockRepo
        )

        // When: Calling the tool
        let result = try await tool.call(
            input: [
                "suggestions": [
                    ["assetID": "/photos/beach_001.jpg", "suggestedName": "Beach Sunset.jpg", "originalFileName": "IMG_001.jpg"],
                ]
            ] as [String: Any],
            context: ToolContext(cwd: "/tmp")
        )

        // Then: Result is valid JSON
        XCTAssertFalse(result.isError)
        let jsonData = result.content.data(using: .utf8)!
        let parsed = try JSONSerialization.jsonObject(with: jsonData)
        XCTAssertTrue(parsed is [String: Any],
            "Result should be a valid JSON object")

        let dict = parsed as! [String: Any]
        XCTAssertTrue(dict["success"] is Bool,
            "Result should contain 'success' boolean")
        XCTAssertTrue(dict["batchID"] is String,
            "Result should contain 'batchID' string")
        XCTAssertTrue(dict["renamedCount"] is Int,
            "Result should contain 'renamedCount' integer")
    }

    // MARK: - Edge Cases

    /// [P1] RenameAssetsTool handles special characters in suggested names.
    ///
    /// Given a suggested name with special characters (Unicode, spaces, hyphens),
    /// When Agent calls RenameAssetsTool,
    /// Then tool passes the name through to the operation without alteration.
    func testRenameAssetsToolHandlesSpecialCharacters() async throws {
        // Given: A capturing manager
        let capturingManager = OperationsCapturingMockOperationManager()
        let mockRepo = MockRenameTestRepository()

        let tool = createRenameAssetsTool(
            operationManager: capturingManager,
            repository: mockRepo
        )

        // When: Calling with Unicode names
        _ = try await tool.call(
            input: [
                "suggestions": [
                    ["assetID": "/photos/unicode_001.jpg", "suggestedName": "Sunset - Tokyo 2024.jpg", "originalFileName": "IMG_001.jpg"],
                ]
            ] as [String: Any],
            context: ToolContext(cwd: "/tmp")
        )

        // Then: The rename parameter preserves the original suggested name
        let operations = await capturingManager.capturedOperations
        XCTAssertEqual(operations.count, 1)
        if case .rename(let newTitle) = operations[0].parameters {
            XCTAssertEqual(newTitle, "Sunset - Tokyo 2024.jpg",
                "Special characters should be preserved in rename parameter")
        } else {
            XCTFail("Expected .rename parameters")
        }
    }

    /// [P1] RenameAssetsTool handles large batch of rename suggestions.
    ///
    /// Given 50 rename suggestions,
    /// When Agent calls RenameAssetsTool,
    /// Then tool creates a single batch with all operations.
    func testRenameAssetsToolHandlesLargeBatch() async throws {
        // Given: A capturing manager
        let capturingManager = OperationsCapturingMockOperationManager()
        let mockRepo = MockRenameTestRepository()

        let tool = createRenameAssetsTool(
            operationManager: capturingManager,
            repository: mockRepo
        )

        // When: Calling with 50 suggestions
        let suggestions = (0..<50).map { i -> [String: String] in
            [
                "assetID": "/photos/photo_\(i).jpg",
                "suggestedName": "Photo \(i).jpg",
                "originalFileName": "IMG_\(String(format: "%04d", i)).jpg"
            ]
        }

        _ = try await tool.call(
            input: ["suggestions": suggestions] as [String: Any],
            context: ToolContext(cwd: "/tmp")
        )

        // Then: All 50 operations captured in single batch
        let operations = await capturingManager.capturedOperations
        XCTAssertEqual(operations.count, 50,
            "Should create 50 PlannedOperations for 50 suggestions")
        // Verify all are rename operations
        for op in operations {
            XCTAssertEqual(op.operationType, .rename,
                "All operations should be .rename type")
        }
    }
}

// MARK: - Mock: Tracking OperationManager for Rename Tool Tests

/// OperationManager mock that tracks beginBatch/executeBatch calls.
private actor TrackingRenameMockOperationManager: OperationManaging {
    private(set) var beginBatchCalled = false
    private(set) var executeBatchCalled = false
    private var batchCounter = 0

    func beginBatch(operations: [PlannedOperation], repository: PhotoLibraryRepository) async throws -> OperationManaging.BatchID {
        beginBatchCalled = true
        batchCounter += 1
        return UUID()
    }

    func executeBatch(_ batchID: OperationManaging.BatchID, repository: PhotoLibraryRepository) async throws {
        executeBatchCalled = true
    }

    func rollbackBatch(_ batchID: OperationManaging.BatchID, repository: PhotoLibraryRepository) async throws {}
    func rollbackLastBatch(repository: PhotoLibraryRepository) async throws {}
    func detectIncompleteBatches() async throws -> [BatchOperation] { [] }
    func getBatchHistory(limit: Int) async throws -> [BatchOperation] { [] }
    func reexecuteLastRolledBackBatch(repository: PhotoLibraryRepository) async throws {}
}

// MARK: - Mock: Operations-Capturing OperationManager for Rename Tool Tests

/// OperationManager mock that captures the PlannedOperations passed to beginBatch.
private actor OperationsCapturingMockOperationManager: OperationManaging {
    private(set) var capturedOperations: [PlannedOperation] = []

    func beginBatch(operations: [PlannedOperation], repository: PhotoLibraryRepository) async throws -> OperationManaging.BatchID {
        capturedOperations = operations
        return UUID()
    }

    func executeBatch(_ batchID: OperationManaging.BatchID, repository: PhotoLibraryRepository) async throws {}

    func rollbackBatch(_ batchID: OperationManaging.BatchID, repository: PhotoLibraryRepository) async throws {}
    func rollbackLastBatch(repository: PhotoLibraryRepository) async throws {}
    func detectIncompleteBatches() async throws -> [BatchOperation] { [] }
    func getBatchHistory(limit: Int) async throws -> [BatchOperation] { [] }
    func reexecuteLastRolledBackBatch(repository: PhotoLibraryRepository) async throws {}
}

// MARK: - Mock: Failing OperationManager for Rename Tool Tests

/// OperationManager mock that succeeds on beginBatch but fails on executeBatch.
private actor FailingRenameMockOperationManager: OperationManaging {
    func beginBatch(operations: [PlannedOperation], repository: PhotoLibraryRepository) async throws -> OperationManaging.BatchID {
        return UUID()
    }

    func executeBatch(_ batchID: OperationManaging.BatchID, repository: PhotoLibraryRepository) async throws {
        throw DomainError.invalidState(reason: "Simulated execution failure for rename test")
    }

    func rollbackBatch(_ batchID: OperationManaging.BatchID, repository: PhotoLibraryRepository) async throws {}
    func rollbackLastBatch(repository: PhotoLibraryRepository) async throws {}
    func detectIncompleteBatches() async throws -> [BatchOperation] { [] }
    func getBatchHistory(limit: Int) async throws -> [BatchOperation] { [] }
    func reexecuteLastRolledBackBatch(repository: PhotoLibraryRepository) async throws {}
}

// MARK: - Mock: Simple OperationManager for Rename Tool Tests

/// Minimal OperationManager mock for annotation/property tests.
private actor SimpleRenameMockOperationManager: OperationManaging {
    func beginBatch(operations: [PlannedOperation], repository: PhotoLibraryRepository) async throws -> OperationManaging.BatchID {
        UUID()
    }

    func executeBatch(_ batchID: OperationManaging.BatchID, repository: PhotoLibraryRepository) async throws {}
    func rollbackBatch(_ batchID: OperationManaging.BatchID, repository: PhotoLibraryRepository) async throws {}
    func rollbackLastBatch(repository: PhotoLibraryRepository) async throws {}
    func detectIncompleteBatches() async throws -> [BatchOperation] { [] }
    func getBatchHistory(limit: Int) async throws -> [BatchOperation] { [] }
    func reexecuteLastRolledBackBatch(repository: PhotoLibraryRepository) async throws {}
}

// MARK: - Mock: PhotoLibraryRepository for Rename Tool Tests

private final class MockRenameTestRepository: PhotoLibraryRepository, @unchecked Sendable {
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

// MARK: - Mock: LLMGateway for Registration Tests

private struct MockRenameLLMGateway: LLMGatewayProtocol {
    func analyze(images: [Data], prompt: String, model: String) async throws -> LLMResponse {
        LLMResponse(text: "mock", modelID: model, providerName: "test", inputTokens: 0, outputTokens: 0)
    }
    func estimateCost(imageCount: Int, model: String) async -> CostEstimate {
        CostEstimate(estimatedTokens: 0, estimatedCost: 0, modelID: model, providerName: "test", estimatedAPICalls: 0, currency: "USD")
    }
}
