import Foundation
import OpenAgentSDK

/// Bridges the OpenAgentSDK Agent loop with Curator's AgentJob state machine.
///
/// CuratorAgent wraps an SDK `Agent` instance and translates its `AsyncStream<SDKMessage>`
/// output into Curator's `AsyncStream<AgentEvent>` via `SDKMessageBridge`. This is the
/// primary integration point between the SDK and Curator's execution engine.
///
/// Created by `CuratorAgentFactory` using user-configured API key, model, and provider.
/// Consumed by `ChatInputViewModel` (Story 3.3) to start agent execution.
actor CuratorAgent {

    // MARK: - Properties

    /// The underlying SDK Agent instance.
    private let agent: Agent

    // MARK: - System Prompt

    /// Default system prompt defining Curator's photo management agent role.
    ///
    /// This prompt is used when no custom system prompt is provided. It describes
    /// the agent's capabilities, available tools, and behavioral guidelines.
    static let photoManagerSystemPrompt = """
    You are Curator, an AI photo management assistant for macOS.
    You help users organize, analyze, and manage their photo library using natural language commands.

    ## Available Tools

    - **scan_library**: Scan the user's photo folder and return a summary of photos found, including count, formats, and date range.
    - **analyze_duplicates**: Analyze photos for duplicates using two-stage analysis (local hashing + AI confirmation). Returns groups of similar photos with similarity scores and explanations.
    - **delete_assets**: Delete specified photo assets. Destructive — always confirm with the user first. Creates snapshots for rollback.
    - **estimate_cost**: Estimate the API cost for an analysis operation based on photo count and operation type.

    ## Guidelines

    - Always explain what you're doing before taking action.
    - For operations that modify files (rename, move, delete), clearly state what will happen and wait for confirmation.
    - Report photo counts and progress updates during long operations.
    - If the user's intent is unclear, ask for clarification rather than guessing.
    - Never modify original image files — only operate on metadata (filenames, directory structure).
    - For deduplication requests: scan_library -> estimate_cost -> analyze_duplicates -> review with user -> delete_assets (only after explicit user approval).
    - Always show cost estimate before starting large analysis operations (>100 photos).
    - Never delete photos without explicit user confirmation.
    """

    // MARK: - Initialization

    /// Creates a CuratorAgent with the specified configuration.
    ///
    /// - Parameters:
    ///   - apiKey: API key for the LLM provider.
    ///   - model: Model identifier (e.g., "claude-sonnet-4-6").
    ///   - provider: LLM provider (`.anthropic` or `.openai`).
    ///   - baseURL: Optional base URL override for the provider API.
    ///   - tools: Array of ToolProtocol tools to register with the agent.
    ///   - systemPrompt: System prompt for the agent. Uses `photoManagerSystemPrompt` if nil.
    init(
        apiKey: String,
        model: String,
        provider: OpenAgentSDK.LLMProvider,
        baseURL: String?,
        tools: [ToolProtocol],
        systemPrompt: String?
    ) {
        let prompt = systemPrompt ?? Self.photoManagerSystemPrompt

        let options = AgentOptions(
            apiKey: apiKey,
            model: model,
            baseURL: baseURL,
            provider: provider,
            systemPrompt: prompt,
            maxTurns: 10,
            tools: tools.isEmpty ? nil : tools
        )

        self.agent = createAgent(options: options)
    }

    // MARK: - Execution

    /// Executes a user instruction and returns a stream of AgentEvents.
    ///
    /// The method:
    /// 1. Calls `agent.stream(userMessage)` to get `AsyncStream<SDKMessage>`
    /// 2. Translates each SDKMessage through `SDKMessageBridge`
    /// 3. Applies `mergeProgressEvents()` to coalesce rapid progress updates
    /// 4. Flattens the resulting `[AgentEvent]` arrays into a single `AsyncStream<AgentEvent>`
    ///
    /// Pipeline: SDKMessage -> SDKMessageBridge -> mergeProgressEvents() -> AgentJob
    ///
    /// - Parameter userMessage: The natural language instruction from the user.
    /// - Returns: An async stream of AgentEvents for AgentJob consumption.
    func execute(_ userMessage: String) -> AsyncStream<AgentEvent> {
        let sdkStream = agent.stream(userMessage)
        let bridge = SDKMessageBridge()

        // Build raw event stream from SDK messages
        let rawEventStream = AsyncStream<AgentEvent> { continuation in
            let task = _Concurrency.Task {
                for await message in sdkStream {
                    let events = bridge.mapSDKMessage(message)
                    for event in events {
                        continuation.yield(event)
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }

        // Apply merge to coalesce rapid stepProgress events
        return rawEventStream.mergeProgressEvents()
    }

    // MARK: - Cancellation

    /// Cancels the currently executing agent loop.
    ///
    /// Delegates to the SDK Agent's `interrupt()` method, which triggers
    /// cooperative cancellation in the agent loop.
    func cancel() {
        agent.interrupt()
    }
}
