import Foundation

/// Estimated cost for an LLM operation.
///
/// Provides token and monetary cost estimates for a planned LLM call,
/// including the target model and provider for traceability.
struct CostEstimate: Sendable {
    /// Estimated total token count for the operation.
    let estimatedTokens: Int
    /// Estimated monetary cost in USD.
    let estimatedCost: Double
    /// The model identifier this estimate is based on.
    let modelID: String
    /// The provider name this estimate is based on.
    let providerName: String
    /// Estimated number of API calls required.
    let estimatedAPICalls: Int
    /// Currency code for the cost estimate.
    let currency: String
}
