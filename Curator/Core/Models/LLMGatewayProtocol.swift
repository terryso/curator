import Foundation

/// Protocol defining the unified LLM gateway interface.
///
/// The gateway manages provider selection, retry logic, and failover.
/// Upper layers call through this protocol rather than directly invoking
/// LLMProvider, ensuring provider-agnostic access to AI capabilities.
protocol LLMGatewayProtocol: Sendable {
    /// Analyzes images using the current active provider, with automatic retry and failover.
    ///
    /// - Parameters:
    ///   - images: Raw image data array (JPEG/PNG/GIF/WebP).
    ///   - prompt: The text prompt describing the analysis task.
    ///   - model: The model identifier to use (e.g. "claude-sonnet-4-20250514").
    /// - Returns: The LLM analysis response.
    func analyze(images: [Data], prompt: String, model: String) async throws -> LLMResponse

    /// Estimates the cost of an analysis operation using the current active provider.
    ///
    /// - Parameters:
    ///   - imageCount: Number of images to be analyzed.
    ///   - model: The model identifier to estimate for.
    /// - Returns: A cost estimate for the planned operation.
    func estimateCost(imageCount: Int, model: String) async -> CostEstimate
}
