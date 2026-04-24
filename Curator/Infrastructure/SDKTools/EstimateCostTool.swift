import Foundation
import OpenAgentSDK

/// Input structure for the estimate_cost tool.
///
/// Codable to work with the `defineTool()` factory function's
/// JSON serialization/deserialization pipeline.
struct EstimateCostInput: Codable, Sendable {
    /// Number of photos to estimate cost for.
    /// Optional to allow manual validation with structured error messages.
    let photoCount: Int?

    /// Operation type: "deduplication" or "rename".
    /// Optional to allow manual validation with structured error messages.
    let operation: String?

    /// Optional model identifier to estimate for.
    let model: String?
}

/// Creates an estimate_cost tool that estimates LLM API costs for analysis operations.
///
/// The tool calculates estimated API call counts based on the operation type and photo
/// count, then delegates to `LLMGatewayProtocol.estimateCost()` for token and monetary
/// cost estimates.
///
/// - Parameter llmGateway: An LLMGatewayProtocol implementation for cost estimation.
/// - Returns: A ToolProtocol instance registered as "estimate_cost".
func createEstimateCostTool(
    llmGateway: any LLMGatewayProtocol
) -> ToolProtocol {
    return defineTool(
        name: "estimate_cost",
        description: "Estimate the cost of an AI analysis operation based on photo count and operation type. Returns estimated API calls, token count, and monetary cost.",
        inputSchema: [
            "type": "object",
            "properties": [
                "photoCount": [
                    "type": "integer",
                    "description": "Number of photos to estimate cost for"
                ],
                "operation": [
                    "type": "string",
                    "description": "Operation type: 'deduplication' or 'rename'",
                    "enum": ["deduplication", "rename"]
                ],
                "model": [
                    "type": "string",
                    "description": "Optional model identifier (e.g., 'claude-sonnet-4-6')"
                ]
            ] as [String: Any],
            "required": ["photoCount", "operation"]
        ],
        isReadOnly: true,
        annotations: ToolAnnotations(readOnlyHint: true, destructiveHint: false)
    ) { (input: EstimateCostInput, _: ToolContext) async throws -> String in
        // Validate required parameters
        guard let photoCount = input.photoCount, photoCount > 0 else {
            throw EstimateCostToolError(message: "photoCount is required and must be greater than 0")
        }

        guard let operation = input.operation, !operation.isEmpty else {
            throw EstimateCostToolError(message: "operation is required")
        }

        // Step 1: Calculate estimated API calls based on operation type
        let estimatedAPICalls: Int
        switch operation.lowercased() {
        case "deduplication":
            // LLM only called in stage 2: ~1 call per group of 5 photos
            estimatedAPICalls = max(1, photoCount / 5)
        case "rename":
            // One LLM call per photo (content analysis + name generation)
            estimatedAPICalls = photoCount
        default:
            throw EstimateCostToolError(message: "Unknown operation type: \(operation). Supported: deduplication, rename")
        }

        // Step 2: Get cost estimate from LLM gateway
        let model = input.model ?? "default"
        let estimate = await llmGateway.estimateCost(
            imageCount: estimatedAPICalls,
            model: model
        )

        // Step 3: Build and return result JSON
        let result: [String: Any] = [
            "estimatedCost": estimate.estimatedCost,
            "estimatedAPICalls": estimate.estimatedAPICalls,
            "estimatedTokens": estimate.estimatedTokens,
            "model": estimate.modelID,
            "provider": estimate.providerName,
            "currency": estimate.currency,
            "operation": operation,
            "photoCount": photoCount
        ]

        let data = try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
        return String(data: data, encoding: .utf8) ?? "{}"
    }
}

/// Error type for EstimateCostTool validation failures.
private struct EstimateCostToolError: Error, Sendable {
    let message: String
}
