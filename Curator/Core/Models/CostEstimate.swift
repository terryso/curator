import Foundation

/// Estimated cost for an LLM operation.
///
/// Placeholder type for Story 1.2 — will be expanded in
/// Story 2.4 (Cost Tracking Engine) with currency and token details.
struct CostEstimate: Sendable {
    let estimatedTokens: Int
    let estimatedCost: Double
}
