import Foundation

/// Provider protocol for Large Language Model services.
///
/// Defined in the Domain layer; concrete implementations reside in
/// the Infrastructure layer. Supports test-time replacement with mocks.
protocol LLMProvider: Sendable {
    var name: String { get }
    func analyze(images: [Data], prompt: String, model: String) async throws -> LLMResponse
    func estimateCost(imageCount: Int, model: String) -> CostEstimate
}
