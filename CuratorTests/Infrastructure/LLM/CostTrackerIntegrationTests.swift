import XCTest
import SwiftData
@testable import Curator

/// ATDD Integration Tests for Story 2.4 - LLMGateway + CostTracker 集成
///
/// Tests verify:
/// - AC1: LLMGateway 成功调用后自动记录成本
/// - AC2: 费用预估计算增强
final class CostTrackerIntegrationTests: XCTestCase {

    nonisolated(unsafe) private var modelContext: ModelContext!

    override func setUp() {
        super.setUp()
        let schema = Schema([CostRecordEntity.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [config])
        modelContext = ModelContext(container)
    }

    override func tearDown() {
        modelContext = nil
        super.tearDown()
    }

    /// Mock provider that returns a successful response with token counts.
    private struct MockProvider: LLMProvider {
        let name: String
        let response: LLMResponse

        func analyze(images: [Data], prompt: String, model: String) async throws -> LLMResponse {
            response
        }

        func estimateCost(imageCount: Int, model: String) -> CostEstimate {
            CostEstimate(
                estimatedTokens: imageCount * 1000,
                estimatedCost: Double(imageCount) * 0.01,
                modelID: model,
                providerName: name,
                estimatedAPICalls: 1,
                currency: "USD"
            )
        }
    }

    /// Mock provider that always fails.
    private struct FailingProvider: LLMProvider {
        let name: String

        func analyze(images: [Data], prompt: String, model: String) async throws -> LLMResponse {
            throw InfrastructureError.llmProviderError(provider: name, statusCode: 500, message: "Server error")
        }

        func estimateCost(imageCount: Int, model: String) -> CostEstimate {
            CostEstimate(
                estimatedTokens: 0, estimatedCost: 0,
                modelID: model, providerName: name,
                estimatedAPICalls: 0, currency: "USD"
            )
        }
    }

    // MARK: - AC1: LLMGateway 集成

    /// [P0] LLMGateway 成功调用后自动通过 CostTracker 记录成本 (AC1-T3)
    func testLLMGatewayRecordsCostAfterSuccessfulCall() async throws {
        let tracker = CostTracker(modelContext: modelContext)
        let response = LLMResponse(
            text: "分析结果",
            modelID: "claude-sonnet-4-20250514",
            providerName: "Anthropic",
            inputTokens: 1000,
            outputTokens: 500
        )
        let provider = MockProvider(name: "Anthropic", response: response)
        let gateway = LLMGateway(providers: [provider], costTracker: tracker, maxRetries: 1)

        _ = try await gateway.analyze(images: [Data()], prompt: "test", model: "claude-sonnet-4-20250514")

        let descriptor = FetchDescriptor<CostRecordEntity>()
        let records = try modelContext.fetch(descriptor)
        XCTAssertEqual(records.count, 1, "应在成功调用后记录一条成本")
        XCTAssertEqual(records[0].providerName, "Anthropic")
        XCTAssertEqual(records[0].inputTokens, 1000)
        XCTAssertEqual(records[0].outputTokens, 500)
    }

    /// [P1] LLMGateway 调用失败时不记录成本
    func testLLMGatewayDoesNotRecordCostOnFailure() async throws {
        let tracker = CostTracker(modelContext: modelContext)
        let provider = FailingProvider(name: "BrokenProvider")
        let gateway = LLMGateway(providers: [provider], costTracker: tracker, maxRetries: 1)

        _ = try? await gateway.analyze(images: [Data()], prompt: "test", model: "model")

        let descriptor = FetchDescriptor<CostRecordEntity>()
        let records = try modelContext.fetch(descriptor)
        XCTAssertEqual(records.count, 0, "失败调用不应记录成本")
    }

    /// [P1] LLMGateway 故障转移后记录成功供应商的成本
    func testLLMGatewayRecordsCostAfterFailover() async throws {
        let tracker = CostTracker(modelContext: modelContext)
        let failProvider = FailingProvider(name: "Failing")
        let successResponse = LLMResponse(
            text: "结果", modelID: "gpt-4o",
            providerName: "OpenAI", inputTokens: 800, outputTokens: 400
        )
        let successProvider = MockProvider(name: "OpenAI", response: successResponse)
        let gateway = LLMGateway(
            providers: [failProvider, successProvider],
            costTracker: tracker,
            maxRetries: 1
        )

        _ = try await gateway.analyze(images: [Data()], prompt: "test", model: "gpt-4o")

        let descriptor = FetchDescriptor<CostRecordEntity>()
        let records = try modelContext.fetch(descriptor)
        XCTAssertEqual(records.count, 1, "故障转移后应记录成功供应商的成本")
        XCTAssertEqual(records[0].providerName, "OpenAI")
    }

    // MARK: - AC2: 费用预估增强

    /// [P0] estimateCost 基于照片数量和模型返回正确预估 (AC2-T2)
    func testEstimateCostReturnsCorrectEstimate() async {
        let provider = MockProvider(name: "Anthropic", response: LLMResponse(
            text: "", modelID: "claude-sonnet-4-20250514",
            providerName: "Anthropic", inputTokens: 0, outputTokens: 0
        ))
        let gateway = LLMGateway(providers: [provider], maxRetries: 1)

        let estimate = await gateway.estimateCost(imageCount: 10, model: "claude-sonnet-4-20250514")
        XCTAssertEqual(estimate.estimatedTokens, 10_000)
        XCTAssertEqual(estimate.estimatedAPICalls, 1)
        XCTAssertEqual(estimate.currency, "USD")
    }

    /// [P2] 未知模型使用默认保守估算 (AC2-T3)
    func testEstimateCostUsesDefaultForUnknownModel() {
        let cost = CostTracker.calculateCost(model: "unknown-model", inputTokens: 1000, outputTokens: 500)
        let expected = Double(1000 + 500) * 0.003 / 1000.0
        XCTAssertEqual(cost, expected, accuracy: 0.000001, "未知模型应使用默认保守估算")
    }
}
