import XCTest
import OpenAgentSDK
@testable import Curator

/// ATDD Tests for Story 3.2 - OpenAgentSDK Integration (AC1, AC4)
///
/// Tests verify:
/// - AC1: AgentToolRegistry tool registration with defineTool() factory (FR9, FR13)
/// - AC4: Tool execution accesses infrastructure via DI (FR13)
///
/// TDD RED PHASE: These tests will fail until the implementation types are created:
/// - AgentToolRegistry (Core/Agent/)
/// - ScanLibraryTool (Infrastructure/SDKTools/)
final class AgentToolRegistryTests: XCTestCase {

    // MARK: - AC1: Tool Registration (FR9, FR13)

    /// [P0] After registering a tool, allTools contains that tool
    func testToolRegistration() async throws {
        let registry = AgentToolRegistry()
        let tool = Self.makeStubTool(name: "test_tool")

        registry.register(tool)

        XCTAssertEqual(registry.allTools.count, 1,
            "allTools should contain exactly 1 tool after registration")
        XCTAssertEqual(registry.allTools.first?.name, "test_tool",
            "Registered tool name should match")
    }

    /// [P0] Tool lookup by name returns the correct tool
    func testToolLookupByName() async throws {
        let registry = AgentToolRegistry()
        let tool = Self.makeStubTool(name: "scan_library")
        registry.register(tool)

        let found = registry.tool(named: "scan_library")

        XCTAssertNotNil(found,
            "tool(named:) should return a tool when name matches")
        XCTAssertEqual(found?.name, "scan_library")
    }

    /// [P0] Tool lookup by name returns nil for unregistered name
    func testToolLookupByNameReturnsNilForMissing() async throws {
        let registry = AgentToolRegistry()

        let found = registry.tool(named: "nonexistent")

        XCTAssertNil(found,
            "tool(named:) should return nil for an unregistered tool name")
    }

    /// [P1] Multiple tools can be registered and allTools returns all of them
    func testMultipleToolRegistration() async throws {
        let registry = AgentToolRegistry()
        let tool1 = Self.makeStubTool(name: "scan_library")
        let tool2 = Self.makeStubTool(name: "analyze_duplicates")
        let tool3 = Self.makeStubTool(name: "rename_assets")

        registry.register(tool1)
        registry.register(tool2)
        registry.register(tool3)

        XCTAssertEqual(registry.allTools.count, 3,
            "allTools should contain all 3 registered tools")

        let names = Set(registry.allTools.map { $0.name })
        XCTAssertTrue(names.contains("scan_library"))
        XCTAssertTrue(names.contains("analyze_duplicates"))
        XCTAssertTrue(names.contains("rename_assets"))
    }

    // MARK: - AC1: defineTool() Factory Function (FR9)

    /// [P0] defineTool() creates a tool conforming to ToolProtocol with all required properties
    func testDefineToolCreatesValidToolProtocol() async throws {
        let tool = defineTool(
            name: "verify_tool",
            description: "A tool for verifying protocol conformance",
            inputSchema: [
                "type": "object",
                "properties": [:] as [String: Any]
            ]
        ) { (_: EmptyCodable, _: ToolContext) async throws -> String in
            return "verified"
        }

        XCTAssertEqual(tool.name, "verify_tool",
            "Tool name should match the provided name")
        XCTAssertEqual(tool.description, "A tool for verifying protocol conformance",
            "Tool description should match the provided description")
        XCTAssertNotNil(tool.inputSchema,
            "Tool should have an inputSchema")
    }

    /// [P0] Custom tool created with defineTool() implements all ToolProtocol required properties
    func testToolProtocolConformance() async throws {
        let tool = Self.makeStubTool(name: "conformance_test")

        // Verify all ToolProtocol required properties exist
        XCTAssertEqual(tool.name, "conformance_test")
        XCTAssertFalse(tool.description.isEmpty,
            "Tool description should not be empty")
        XCTAssertNotNil(tool.inputSchema,
            "Tool should have an inputSchema")

        // Verify call() executes successfully
        let result = try await tool.call(input: [:] as [String: Any], context: ToolContext(cwd: "/tmp"))
        XCTAssertEqual(result.isError, false,
            "Tool call should not produce an error")
        XCTAssertFalse(result.content.isEmpty,
            "Tool result should have content")
    }

    // MARK: - AC4: ScanLibraryTool Execution (FR13)

    /// [P0] ScanLibraryTool calls PhotoLibraryRepository and returns valid JSON result
    func testScanLibraryToolExecution() async throws {
        let mockRepository = MockPhotoLibraryRepository(
            photos: MockPhotoData.samplePhotos
        )
        let tool = createScanLibraryTool(repository: mockRepository)

        let result = try await tool.call(
            input: ["maxResults": 10] as [String: Any],
            context: ToolContext(cwd: "/tmp")
        )

        XCTAssertFalse(result.isError,
            "ScanLibraryTool should execute without error")
        XCTAssertTrue(result.content.contains("count") || result.content.contains("photoCount"),
            "ScanLibraryTool result should contain photo count information")
    }

    /// [P1] ScanLibraryTool is registered as read-only with correct annotations
    func testScanLibraryToolAnnotations() async throws {
        let mockRepository = MockPhotoLibraryRepository()
        let tool = createScanLibraryTool(repository: mockRepository)

        XCTAssertTrue(tool.isReadOnly,
            "ScanLibraryTool should be marked as read-only")

        if let annotations = tool.annotations {
            XCTAssertTrue(annotations.readOnlyHint,
                "ScanLibraryTool should have readOnlyHint = true")
            XCTAssertFalse(annotations.destructiveHint,
                "ScanLibraryTool should have destructiveHint = false")
        }
    }

    // MARK: - AC4: Dependency Injection (FR13)

    /// [P0] Tool accesses infrastructure via injected dependency, not direct instantiation
    func testToolUsesInjectedRepository() async throws {
        // Create a mock that tracks whether fetchAssets was called
        let trackingRepo = TrackingMockRepository()
        let tool = createScanLibraryTool(repository: trackingRepo)

        _ = try await tool.call(
            input: [:] as [String: Any],
            context: ToolContext(cwd: "/tmp")
        )

        XCTAssertTrue(trackingRepo.fetchAssetsCalled,
            "ScanLibraryTool should call fetchAssets on the injected repository")
    }

    // MARK: - Helper: Empty Codable struct for defineTool

    /// Empty Codable struct used as input for simple tools.
    private struct EmptyCodable: Codable {}

    // MARK: - Helper: Stub Tool

    /// Creates a minimal stub tool for testing registry behavior.
    private static func makeStubTool(name: String) -> ToolProtocol {
        defineTool(
            name: name,
            description: "Stub tool for testing: \(name)",
            inputSchema: [
                "type": "object",
                "properties": [:] as [String: Any]
            ]
        ) { (_: EmptyCodable, _: ToolContext) async throws -> String in
            return "stub result for \(name)"
        }
    }
}

// MARK: - Tracking Mock Repository

/// Mock repository that tracks whether fetchAssets was called,
/// for verifying DI-based tool execution.
private final class TrackingMockRepository: PhotoLibraryRepository, @unchecked Sendable {
    private(set) var fetchAssetsCalled = false

    func currentBasePath() async -> String? { nil }
    func requestReadAccess() async throws -> Bool { true }
    func requestWriteAccess() async throws -> Bool { true }

    func fetchAssets(predicate: PhotoPredicate, pageSize: Int, pageOffset: Int) async throws -> AssetPage {
        fetchAssetsCalled = true
        return AssetPage(assets: [], hasMore: false, nextOffset: nil)
    }

    func fetchFullResolutionImage(for assetID: AssetID) async throws -> Data { Data() }
    func fetchThumbnail(for assetID: AssetID, size: CGSize) async throws -> Data { Data() }
    func metadata(for assetID: AssetID) async throws -> AssetMetadata {
        AssetMetadata(fileName: "mock.jpg", fileSize: nil, creationDate: nil, cameraModel: nil, imageWidth: nil, imageHeight: nil, gpsLocation: nil, fileFormat: nil)
    }
    func updateAsset(_ assetID: AssetID, title: String?) async throws {}
    func deleteAssets(_ assetIDs: [AssetID]) async throws {}
    func moveAssets(_ assetIDs: [AssetID], to directory: String) async throws {}
    func observeSourceChanges() -> AsyncStream<SourceChange> { AsyncStream { _ in } }
}
