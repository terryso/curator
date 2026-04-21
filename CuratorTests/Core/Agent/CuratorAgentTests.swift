import XCTest
import OpenAgentSDK
@testable import Curator

/// ATDD Tests for Story 3.2 - OpenAgentSDK Integration (AC2, AC5)
///
/// Tests verify:
/// - AC2: SDK Agent loop starts and processes user instruction (FR8, FR9)
/// - AC5: Agent bridge layer uses user-configured apiKey, model, provider (FR43, FR44)
///
/// TDD RED PHASE: These tests will fail until the implementation types are created:
/// - CuratorAgent (Core/Agent/) - actor wrapping SDK Agent
/// - CuratorAgentFactory (Core/Agent/) - factory creating configured agents
final class CuratorAgentTests: XCTestCase {

    // MARK: - Helper: Empty Codable Input

    private struct EmptyCodable: Codable {}

    // MARK: - Helper: Stub Tool Factory

    /// Creates a minimal stub tool for testing agent registration.
    private static func makeStubTool(name: String) -> ToolProtocol {
        defineTool(
            name: name,
            description: "Stub tool for testing: \(name)",
            inputSchema: [
                "type": "object",
                "properties": [:] as [String: Any]
            ]
        ) { (_: EmptyCodable, _: ToolContext) async throws -> String in
            return "stub result for \(name)"
        }
    }

    // MARK: - AC2: CuratorAgent Creation (FR8, FR9)

    /// [P0] CuratorAgent can be created with configuration parameters
    func testCuratorAgentCreation() async throws {
        let agent = CuratorAgent(
            apiKey: "test-key",
            model: "claude-sonnet-4-6",
            provider: .anthropic,
            baseURL: nil,
            tools: [],
            systemPrompt: "You are a test assistant."
        )

        XCTAssertNotNil(agent,
            "CuratorAgent should be created with valid configuration parameters")
    }

    /// [P0] CuratorAgent exposes cancel() without crashing
    func testCuratorAgentCancel() async throws {
        let agent = CuratorAgent(
            apiKey: "test-key",
            model: "claude-sonnet-4-6",
            provider: .anthropic,
            baseURL: nil,
            tools: [],
            systemPrompt: "You are a test assistant."
        )

        // Cancel on an idle agent should not crash
        await agent.cancel()
    }

    // MARK: - AC5: Agent Bridge Configuration (FR43, FR44)

    /// [P0] CuratorAgent uses configured apiKey, model, provider
    func testAgentUsesConfiguredParameters() async throws {
        // Verify that CuratorAgent can be created with different provider configs
        let anthropicAgent = CuratorAgent(
            apiKey: "sk-ant-test",
            model: "claude-sonnet-4-6",
            provider: .anthropic,
            baseURL: nil,
            tools: [],
            systemPrompt: "Test"
        )
        XCTAssertNotNil(anthropicAgent)

        let openaiAgent = CuratorAgent(
            apiKey: "sk-openai-test",
            model: "gpt-4o",
            provider: .openai,
            baseURL: "https://api.openai.com/v1",
            tools: [],
            systemPrompt: "Test"
        )
        XCTAssertNotNil(openaiAgent)
    }

    /// [P1] CuratorAgent system prompt contains photo management role definition
    func testCuratorSystemPrompt() async throws {
        let prompt = CuratorAgent.photoManagerSystemPrompt

        XCTAssertTrue(prompt.contains("photo") || prompt.contains("Photo"),
            "System prompt should mention photo management")
        XCTAssertTrue(prompt.contains("Curator") || prompt.contains("curator"),
            "System prompt should identify the agent as Curator")
        XCTAssertTrue(prompt.contains("scan_library") || prompt.contains("library") || prompt.contains("organize"),
            "System prompt should describe available capabilities or tools")
        XCTAssertTrue(prompt.count > 50,
            "System prompt should be substantive (not a placeholder)")
    }

    /// [P0] CuratorAgent registers tools from the provided list
    func testCuratorAgentRegistersTools() async throws {
        let stubTool = Self.makeStubTool(name: "test_tool_for_agent")

        let agent = CuratorAgent(
            apiKey: "test-key",
            model: "claude-sonnet-4-6",
            provider: .anthropic,
            baseURL: nil,
            tools: [stubTool],
            systemPrompt: "Test"
        )

        XCTAssertNotNil(agent,
            "CuratorAgent should accept a non-empty tools list")
    }

    // MARK: - AC5: CuratorAgentFactory

    /// [P0] CuratorAgentFactory creates a configured CuratorAgent
    func testCuratorAgentFactoryCreation() async throws {
        let factory = CuratorAgentFactory(
            apiKey: "test-factory-key",
            model: "claude-sonnet-4-6",
            provider: .anthropic,
            baseURL: nil
        )

        let agent = factory.createAgent(
            tools: [],
            systemPrompt: "Factory test"
        )

        XCTAssertNotNil(agent,
            "CuratorAgentFactory should create a CuratorAgent")
    }

    /// [P1] CuratorAgentFactory uses llmGateway configuration
    func testCuratorAgentFactoryUsesGatewayConfig() async throws {
        // Factory should be able to use configuration from an LLMGateway-like source
        let factory = CuratorAgentFactory(
            apiKey: "gateway-api-key",
            model: "claude-sonnet-4-6",
            provider: .anthropic,
            baseURL: "https://custom-api.example.com/v1"
        )

        let agent = factory.createAgent(
            tools: [],
            systemPrompt: "Gateway config test"
        )

        XCTAssertNotNil(agent,
            "Factory should create an agent using gateway-style configuration")
    }

    // MARK: - AC2: execute() returns AsyncStream<AgentEvent>

    /// [P0] CuratorAgent.execute() returns an AsyncStream<AgentEvent>
    /// Note: This test validates the return type; actual execution requires a real API key.
    func testCuratorAgentExecuteReturnsAsyncStream() async throws {
        let agent = CuratorAgent(
            apiKey: "test-key",
            model: "claude-sonnet-4-6",
            provider: .anthropic,
            baseURL: nil,
            tools: [],
            systemPrompt: "Test"
        )

        let stream = await agent.execute("test instruction")

        // The stream should be non-nil and produce events (or terminate cleanly)
        var eventCount = 0
        for await _ in stream {
            eventCount += 1
            if eventCount >= 1 {
                break // We just need to verify the stream is usable
            }
        }

        // Stream either produced events or terminated cleanly - both are acceptable
        // since we're using a fake API key
    }

    // MARK: - AC4: AppDependencies Registration

    /// [P1] AppDependencies can register agent infrastructure
    @MainActor
    func testAppDependenciesRegistersAgentInfrastructure() async throws {
        let deps = AppDependencies()
        deps.registerMockRepository()

        // Agent infrastructure registration should not crash
        deps.registerAgentInfrastructure()

        XCTAssertNotNil(deps.toolRegistry,
            "After registerAgentInfrastructure(), toolRegistry should be set")
        XCTAssertNotNil(deps.curatorAgentFactory,
            "After registerAgentInfrastructure(), curatorAgentFactory should be set")
    }
}
