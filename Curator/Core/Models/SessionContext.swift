import Foundation

/// Lightweight session context for cost tracking correlation.
///
/// Uses Task-local values to pass the current session ID through the
/// call stack without modifying LLMGatewayProtocol's signature.
enum SessionContext: Sendable {
    @TaskLocal static var current: String?
}
