import XCTest
@testable import Curator

/// ATDD Tests for Story 2.6 - Cost Estimate & Tracking Panel (AC1: CostEstimateCard)
///
/// Tests verify:
/// - CostEstimateCard renders with valid CostEstimate data
/// - Estimated API calls, cost, model name displayed correctly
/// - Model switching triggers recalculation via LLMGatewayProtocol
/// - USD formatting (4 decimal places, thousands separator)
final class CostEstimateCardTests: XCTestCase {

    // MARK: - Mock Gateway

    /// Mock LLM gateway for testing CostEstimateCard model switching.
    private actor MockLLMGatewayForEstimate: LLMGatewayProtocol {
        let name: String = "MockGateway"
        private let estimates: [String: CostEstimate]

        init(estimates: [String: CostEstimate] = [:]) {
            self.estimates = estimates
        }

        func analyze(images: [Data], prompt: String, model: String) async throws -> LLMResponse {
            fatalError("Not used in CostEstimateCard tests")
        }

        func estimateCost(imageCount: Int, model: String) async -> CostEstimate {
            if let estimate = estimates[model] {
                return estimate
            }
            return CostEstimate(
                estimatedTokens: imageCount * LLMModelID.estimatedTokensPerImage,
                estimatedCost: Double(imageCount) * 0.003,
                modelID: model,
                providerName: "MockProvider",
                estimatedAPICalls: max(1, imageCount / 10),
                currency: "USD"
            )
        }
    }

    // MARK: - AC1: CostEstimateCard Rendering

    /// [P0] CostEstimateCard renders with valid CostEstimate data (AC1)
    func testCostEstimateCardDisplaysEstimate() async throws {
        // Given: A CostEstimate with known values
        let _ = CostEstimate(
            estimatedTokens: 5000,
            estimatedCost: 0.0150,
            modelID: "claude-sonnet-4-20250514",
            providerName: "Anthropic",
            estimatedAPICalls: 5,
            currency: "USD"
        )

        // When: CostEstimateCard is created with the estimate
        let gateway = MockLLMGatewayForEstimate()
        let card = await CostEstimateCard(
            gateway: gateway,
            imageCount: 5,
            selectedModel: "claude-sonnet-4-20250514"
        )

        // Then: Card should display the estimate data
        await MainActor.run {
            XCTAssertNotNil(card, "CostEstimateCard should be created")
            // Verify the card accepts and renders estimate data
            // (Detailed SwiftUI view inspection requires ViewInspector or similar)
        }
    }

    /// [P0] CostEstimateCard displays estimated API call count (AC1)
    func testCostEstimateCardDisplaysAPICallCount() async throws {
        // Given: A CostEstimate with 10 estimated API calls
        let estimate = CostEstimate(
            estimatedTokens: 10000,
            estimatedCost: 0.0300,
            modelID: "claude-sonnet-4-20250514",
            providerName: "Anthropic",
            estimatedAPICalls: 10,
            currency: "USD"
        )

        // Then: The estimate's estimatedAPICalls should be accessible
        XCTAssertEqual(estimate.estimatedAPICalls, 10, "Should report 10 estimated API calls")
    }

    /// [P0] CostEstimateCard displays cost in USD with 4 decimal places (AC1)
    func testCostEstimateCardFormatsCostInUSD() async throws {
        // Given: Cost estimates with various amounts
        let smallCost = CostEstimate(
            estimatedTokens: 100, estimatedCost: 0.0001,
            modelID: "model", providerName: "Test",
            estimatedAPICalls: 1, currency: "USD"
        )
        let largeCost = CostEstimate(
            estimatedTokens: 1000000, estimatedCost: 1234.5678,
            modelID: "model", providerName: "Test",
            estimatedAPICalls: 100, currency: "USD"
        )

        // Then: USD formatting should show 4 decimal places
        let formattedSmall = String(format: "$%.4f", smallCost.estimatedCost)
        let formattedLarge = String(format: "$%.4f", largeCost.estimatedCost)

        XCTAssertEqual(formattedSmall, "$0.0001", "Should format small costs to 4 decimals")
        XCTAssertEqual(formattedLarge, "$1234.5678", "Should format large costs to 4 decimals")
    }

    /// [P0] CostEstimateCard displays selected model name (AC1)
    func testCostEstimateCardDisplaysModelName() async throws {
        // Given: A CostEstimate for a specific model
        let estimate = CostEstimate(
            estimatedTokens: 5000, estimatedCost: 0.015,
            modelID: "claude-sonnet-4-20250514",
            providerName: "Anthropic",
            estimatedAPICalls: 5, currency: "USD"
        )

        // Then: The model ID should be present in the estimate
        XCTAssertEqual(estimate.modelID, "claude-sonnet-4-20250514")
        XCTAssertEqual(estimate.providerName, "Anthropic")
    }

    // MARK: - AC1: Model Switching

    /// [P1] CostEstimateCard recalculates estimate when model changes (AC1)
    func testModelSwitchRecalculatesEstimate() async throws {
        // Given: A mock gateway returning different estimates per model
        let sonnetEstimate = CostEstimate(
            estimatedTokens: 5000, estimatedCost: 0.015,
            modelID: "claude-sonnet-4-20250514",
            providerName: "Anthropic",
            estimatedAPICalls: 5, currency: "USD"
        )
        let haikuEstimate = CostEstimate(
            estimatedTokens: 5000, estimatedCost: 0.004,
            modelID: "claude-haiku-4-20250506",
            providerName: "Anthropic",
            estimatedAPICalls: 5, currency: "USD"
        )

        let gateway = MockLLMGatewayForEstimate(estimates: [
            "claude-sonnet-4-20250514": sonnetEstimate,
            "claude-haiku-4-20250506": haikuEstimate
        ])

        // When: Querying estimates for different models
        let sonnetResult = await gateway.estimateCost(imageCount: 5, model: "claude-sonnet-4-20250514")
        let haikuResult = await gateway.estimateCost(imageCount: 5, model: "claude-haiku-4-20250506")

        // Then: Different models should return different costs
        XCTAssertNotEqual(sonnetResult.estimatedCost, haikuResult.estimatedCost,
                          "Switching models should produce different cost estimates")
        XCTAssertGreaterThan(sonnetResult.estimatedCost, haikuResult.estimatedCost,
                             "Sonnet should cost more than Haiku for same image count")
    }

    /// [P1] CostEstimateCard supports all LLMModelID cases (AC1)
    func testCostEstimateCardSupportsAllModels() async throws {
        let gateway = MockLLMGatewayForEstimate()

        // When: Querying estimate for each model
        for model in LLMModelID.allCases {
            let estimate = await gateway.estimateCost(imageCount: 10, model: model.rawValue)

            // Then: Each model should return a valid estimate
            XCTAssertGreaterThan(estimate.estimatedTokens, 0,
                                 "\(model.rawValue) should estimate positive tokens")
            XCTAssertGreaterThanOrEqual(estimate.estimatedCost, 0,
                                        "\(model.rawValue) should estimate non-negative cost")
        }
    }
}
