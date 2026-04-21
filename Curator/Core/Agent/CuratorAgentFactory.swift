import Foundation
import OpenAgentSDK

/// Factory for creating configured CuratorAgent instances.
///
/// Encapsulates the agent creation logic, using configuration from AppDependencies
/// (API key, model, provider). The factory is registered during app startup via
/// `AppDependencies.registerAgentInfrastructure()`.
///
/// Story 3.3 (AgentInputBar) will use this factory to create agents on demand.
struct CuratorAgentFactory: Sendable {

    // MARK: - Properties

    /// API key for the LLM provider.
    let apiKey: String

    /// Model identifier (e.g., "claude-sonnet-4-6").
    let model: String

    /// LLM provider (`.anthropic` or `.openai`).
    let provider: OpenAgentSDK.LLMProvider

    /// Optional base URL override.
    let baseURL: String?

    // MARK: - Initialization

    /// Creates a factory with the specified LLM configuration.
    ///
    /// - Parameters:
    ///   - apiKey: API key for authentication.
    ///   - model: Model identifier to use.
    ///   - provider: LLM provider selection.
    ///   - baseURL: Optional base URL override.
    init(apiKey: String, model: String, provider: OpenAgentSDK.LLMProvider, baseURL: String?) {
        self.apiKey = apiKey
        self.model = model
        self.provider = provider
        self.baseURL = baseURL
    }

    // MARK: - Agent Creation

    /// Creates a new CuratorAgent with the factory's stored configuration.
    ///
    /// - Parameters:
    ///   - tools: Array of ToolProtocol tools to register with the agent.
    ///   - systemPrompt: Custom system prompt. Uses CuratorAgent.photoManagerSystemPrompt if nil.
    /// - Returns: A configured CuratorAgent ready for execution.
    func createAgent(tools: [ToolProtocol], systemPrompt: String?) -> CuratorAgent {
        CuratorAgent(
            apiKey: apiKey,
            model: model,
            provider: provider,
            baseURL: baseURL,
            tools: tools,
            systemPrompt: systemPrompt
        )
    }
}
