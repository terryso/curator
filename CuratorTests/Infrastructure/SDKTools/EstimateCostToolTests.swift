import XCTest
import OpenAgentSDK

@testable import Curator

/// ATDD Tests for Story 5.3 -- EstimateCostTool (AC4, AC6)
///
/// Tests verify:
/// - AC4: EstimateCostTool returns cost estimate via LLMGateway (FR46)
/// - AC6: Error handling returns structured JSON errors (NFR20, NFR23)
///
/// TDD RED PHASE: All tests use XCTSkip("ATDD Red Phase") to skip until
/// the feature is implemented. Remove skips one-by-one during implementation.
final class EstimateCostToolTests: XCTestCase {

    // MARK: - AC4: EstimateCostTool Returns Cost Estimate (FR46)

    /// [P0] EstimateCostTool returns cost estimate for deduplication operation.
    ///
    /// AC4: Given Agent needs to estimate cost,
    /// When Agent calls EstimateCostTool with photoCount and operation,
    /// Then tool calls llmGateway.estimateCost() and returns
    /// JSON with estimatedCost, estimatedAPICalls, model, and provider.
    func testEstimateCostReturnsCostEstimate() async throws {
        // Given: Mock LLM gateway returning a cost estimate
        let expectedEstimate = CostEstimate(
            estimatedTokens: 5000,
            estimatedCost: 0.05,
            modelID: "claude-sonnet-4-6",
            providerName: "test-provider",
            estimatedAPICalls: 20,
            currency: "USD"
        )
        let mockGateway = MockToolLLMGateway(estimate: expectedEstimate)

        let tool = createEstimateCostTool(llmGateway: mockGateway)

        // When: Calling the tool for deduplication
        let result = try await tool.call(
            input: [
                "photoCount": 100,
                "operation": "deduplication",
            ] as [String: Any],
            context: ToolContext(cwd: "/tmp")
        )

        // Then: Result contains cost estimate fields
        XCTAssertFalse(result.isError,
            "EstimateCostTool should execute without error")
        XCTAssertTrue(result.content.contains("estimatedCost"),
            "Result should contain estimatedCost field")
        XCTAssertTrue(result.content.contains("estimatedAPICalls"),
            "Result should contain estimatedAPICalls field")
    }

    /// [P1] EstimateCostTool calculates correct API call counts for different operations.
    ///
    /// AC4: Given different operation types,
    /// When Agent calls EstimateCostTool,
    /// Then deduplication estimates photoCount/5 API calls,
    /// And rename estimates photoCount API calls.
    func testEstimateCostDifferentOperations() async throws {
        // Given: Tracking gateway
        let trackingGateway = TrackingMockLLMGateway()
        let tool = createEstimateCostTool(llmGateway: trackingGateway)

        // When: Calling for deduplication with 100 photos
        _ = try await tool.call(
            input: [
                "photoCount": 100,
                "operation": "deduplication",
            ] as [String: Any],
            context: ToolContext(cwd: "/tmp")
        )

        // Then: Should estimate ~20 API calls (100/5)
        XCTAssertEqual(trackingGateway.lastImageCount, 20,
            "Deduplication should estimate photoCount/5 API calls")

        // When: Calling for rename with 50 photos
        trackingGateway.reset()
        _ = try await tool.call(
            input: [
                "photoCount": 50,
                "operation": "rename",
            ] as [String: Any],
            context: ToolContext(cwd: "/tmp")
        )

        // Then: Should estimate 50 API calls
        XCTAssertEqual(trackingGateway.lastImageCount, 50,
            "Rename should estimate 1 API call per photo")
    }

    // MARK: - AC4: Tool Properties and Annotations

    /// [P1] EstimateCostTool is registered as read-only with correct annotations.
    ///
    /// AC4: Tool should have readOnlyHint: true and destructiveHint: false.
    func testEstimateCostToolAnnotations() async throws {
        let mockGateway = MockToolLLMGateway()

        let tool = createEstimateCostTool(llmGateway: mockGateway)

        XCTAssertEqual(tool.name, "estimate_cost",
            "Tool name should be 'estimate_cost'")
        XCTAssertTrue(tool.isReadOnly,
            "EstimateCostTool should be marked as read-only")

        if let annotations = tool.annotations {
            XCTAssertTrue(annotations.readOnlyHint,
                "EstimateCostTool should have readOnlyHint = true")
            XCTAssertFalse(annotations.destructiveHint,
                "EstimateCostTool should have destructiveHint = false")
        }
    }

    // MARK: - AC6: Error Handling (NFR20, NFR23)

    /// [P1] EstimateCostTool handles missing required parameters gracefully.
    ///
    /// AC6: Given missing required parameters (photoCount, operation),
    /// When Agent calls EstimateCostTool,
    /// Then tool returns structured JSON error.
    func testEstimateCostHandlesMissingParameters() async throws {
        let mockGateway = MockToolLLMGateway()
        let tool = createEstimateCostTool(llmGateway: mockGateway)

        // When: Calling without required parameters
        let result = try await tool.call(
            input: [:] as [String: Any],
            context: ToolContext(cwd: "/tmp")
        )

        // Then: Returns error (CodableTool wraps decode failure as isError:true)
        XCTAssertTrue(result.isError,
            "Tool should return error for missing required parameters")
        // CodableTool returns "Failed to decode input: ..." or "Error: ..." depending on failure stage
        let contentLower = result.content.lowercased()
        XCTAssertTrue(contentLower.contains("error") || contentLower.contains("failed") || contentLower.contains("missing"),
            "Error result should contain error information, got: \(result.content)")
    }
}

// MARK: - Mock: LLMGateway for Tool Tests

/// Mock LLM gateway returning pre-configured cost estimates.
private struct MockToolLLMGateway: LLMGatewayProtocol {
    private let estimate: CostEstimate

    init(estimate: CostEstimate? = nil) {
        self.estimate = estimate ?? CostEstimate(
            estimatedTokens: 1000,
            estimatedCost: 0.01,
            modelID: "test-model",
            providerName: "test-provider",
            estimatedAPICalls: 1,
            currency: "USD"
        )
    }

    func analyze(images: [Data], prompt: String, model: String) async throws -> LLMResponse {
        LLMResponse(text: "mock", modelID: model, providerName: "test-provider",
                     inputTokens: 100, outputTokens: 50)
    }

    func estimateCost(imageCount: Int, model: String) async -> CostEstimate {
        estimate
    }
}

// MARK: - Mock: Tracking LLMGateway for Tool Tests

/// Mock LLM gateway that tracks estimateCost call parameters.
private final class TrackingMockLLMGateway: LLMGatewayProtocol, @unchecked Sendable {
    private(set) var lastImageCount: Int?
    private(set) var lastModel: String?

    func reset() {
        lastImageCount = nil
        lastModel = nil
    }

    func analyze(images: [Data], prompt: String, model: String) async throws -> LLMResponse {
        LLMResponse(text: "mock", modelID: model, providerName: "test-provider",
                     inputTokens: 100, outputTokens: 50)
    }

    func estimateCost(imageCount: Int, model: String) async -> CostEstimate {
        lastImageCount = imageCount
        lastModel = model
        return CostEstimate(
            estimatedTokens: imageCount * 100,
            estimatedCost: Double(imageCount) * 0.01,
            modelID: model,
            providerName: "test-provider",
            estimatedAPICalls: imageCount,
            currency: "USD"
        )
    }
}
