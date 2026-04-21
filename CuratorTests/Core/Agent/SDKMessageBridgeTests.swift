import XCTest
import OpenAgentSDK
@testable import Curator

/// ATDD Tests for Story 3.2 - OpenAgentSDK Integration (AC3)
///
/// Tests verify:
/// - AC3: SDK messages correctly mapped to AgentEvent via SDKMessageBridge (FR16, NFR3)
/// - Mapping via AsyncStream<AgentEvent> delivers to AgentJob within 500ms
///
/// TDD RED PHASE: These tests will fail until the implementation types are created:
/// - SDKMessageBridge (Core/Agent/)
final class SDKMessageBridgeTests: XCTestCase {

    // MARK: - AC3: SDKMessage -> AgentEvent Mapping (FR16, NFR3)

    /// [P0] .toolUse maps to AgentEvent.stepStarted
    func testSDKMessageBridgeToolUse() async throws {
        let bridge = SDKMessageBridge()
        let toolUseId = "tool-use-123"

        let message = SDKMessage.toolUse(SDKMessage.ToolUseData(
            toolName: "scan_library",
            toolUseId: toolUseId,
            input: "{}"
        ))

        let events = bridge.mapSDKMessage(message)

        XCTAssertTrue(events.contains { if case .stepStarted = $0 { return true } else { return false } },
            ".toolUse should map to .stepStarted event")

        // Verify step title matches tool name
        for event in events {
            if case .stepStarted(_, let title) = event {
                XCTAssertEqual(title, "scan_library",
                    "stepStarted title should match the tool name")
                return
            }
        }
    }

    /// [P0] .toolResult(isError: false) maps to AgentEvent.stepCompleted
    func testSDKMessageBridgeToolResult() async throws {
        let bridge = SDKMessageBridge()
        let toolUseId = "tool-result-456"

        // First, track a toolUse so the bridge knows the toolUseId -> stepID mapping
        let toolUseMsg = SDKMessage.toolUse(SDKMessage.ToolUseData(
            toolName: "scan_library",
            toolUseId: toolUseId,
            input: "{}"
        ))
        _ = bridge.mapSDKMessage(toolUseMsg)

        // Then send the successful result
        let resultMsg = SDKMessage.toolResult(SDKMessage.ToolResultData(
            toolUseId: toolUseId,
            content: "Found 42 photos",
            isError: false
        ))

        let events = bridge.mapSDKMessage(resultMsg)

        XCTAssertTrue(events.contains { if case .stepCompleted = $0 { return true } else { return false } },
            ".toolResult (success) should map to .stepCompleted event")
    }

    /// [P0] .toolResult(isError: true) maps to AgentEvent.stepFailed
    func testSDKMessageBridgeToolResultError() async throws {
        let bridge = SDKMessageBridge()
        let toolUseId = "tool-error-789"

        // Track the toolUse first
        let toolUseMsg = SDKMessage.toolUse(SDKMessage.ToolUseData(
            toolName: "failing_tool",
            toolUseId: toolUseId,
            input: "{}"
        ))
        _ = bridge.mapSDKMessage(toolUseMsg)

        // Send the error result
        let errorMsg = SDKMessage.toolResult(SDKMessage.ToolResultData(
            toolUseId: toolUseId,
            content: "Tool execution failed",
            isError: true
        ))

        let events = bridge.mapSDKMessage(errorMsg)

        XCTAssertTrue(events.contains { if case .stepFailed = $0 { return true } else { return false } },
            ".toolResult (error) should map to .stepFailed event")
    }

    /// [P0] .result(subtype: .success) maps to AgentEvent.executionCompleted
    func testSDKMessageBridgeResultSuccess() async throws {
        let bridge = SDKMessageBridge()

        let message = SDKMessage.result(SDKMessage.ResultData(
            subtype: .success,
            text: "All done",
            usage: nil,
            numTurns: 3,
            durationMs: 5000
        ))

        let events = bridge.mapSDKMessage(message)

        XCTAssertTrue(events.contains { if case .executionCompleted = $0 { return true } else { return false } },
            ".result(.success) should map to .executionCompleted event")
    }

    /// [P0] .result(subtype: .errorDuringExecution) maps to AgentEvent.stepFailed
    func testSDKMessageBridgeResultError() async throws {
        let bridge = SDKMessageBridge()

        let message = SDKMessage.result(SDKMessage.ResultData(
            subtype: .errorDuringExecution,
            text: "Execution failed",
            usage: nil,
            numTurns: 2,
            durationMs: 3000
        ))

        let events = bridge.mapSDKMessage(message)

        XCTAssertTrue(events.contains { if case .stepFailed = $0 { return true } else { return false } },
            ".result(.errorDuringExecution) should map to .stepFailed event")
    }

    // MARK: - AC3: Additional Mappings

    /// [P1] .assistant with text maps to AgentEvent.stepReasoning
    func testSDKMessageBridgeAssistantReasoning() async throws {
        let bridge = SDKMessageBridge()
        let toolUseId = "assistant-step-1"

        // Track a toolUse to get a stepID
        let toolUseMsg = SDKMessage.toolUse(SDKMessage.ToolUseData(
            toolName: "analyze",
            toolUseId: toolUseId,
            input: "{}"
        ))
        _ = bridge.mapSDKMessage(toolUseMsg)

        // Send assistant reasoning
        let assistantMsg = SDKMessage.assistant(SDKMessage.AssistantData(
            text: "I will analyze the photos by looking at their metadata first.",
            model: "claude-sonnet-4-6",
            stopReason: "tool_use"
        ))

        let events = bridge.mapSDKMessage(assistantMsg)

        XCTAssertTrue(events.contains { if case .stepReasoning = $0 { return true } else { return false } },
            ".assistant with reasoning text should map to .stepReasoning event")
    }

    /// [P1] .result(subtype: .cancelled) is handled (mapping may be no-op for AgentJob)
    func testSDKMessageBridgeCancellation() async throws {
        let bridge = SDKMessageBridge()

        let message = SDKMessage.result(SDKMessage.ResultData(
            subtype: .cancelled,
            text: "User cancelled",
            usage: nil,
            numTurns: 1,
            durationMs: 500
        ))

        // Should not crash; may produce empty events or a specific event
        let events = bridge.mapSDKMessage(message)

        // Cancellation is handled by AgentJob directly, so bridge may produce
        // either an empty array or a specific cancellation-related event.
        // The important thing is it doesn't crash or produce incorrect events.
        for event in events {
            if case .stepFailed = event {
                // Acceptable: cancellation mapped to stepFailed
            } else {
                XCTFail("Cancellation should not produce unexpected events, got: \(event)")
            }
        }
    }

    /// [P1] .partialMessage is ignored (Story 3.6 optimization)
    func testSDKMessageBridgePartialMessageIgnored() async throws {
        let bridge = SDKMessageBridge()

        let message = SDKMessage.partialMessage(SDKMessage.PartialData(
            text: "partial text"
        ))

        let events = bridge.mapSDKMessage(message)

        XCTAssertTrue(events.isEmpty,
            ".partialMessage should be ignored (no events produced)")
    }

    /// [P1] .system messages are ignored
    func testSDKMessageBridgeSystemIgnored() async throws {
        let bridge = SDKMessageBridge()

        let message = SDKMessage.system(SDKMessage.SystemData(
            subtype: .`init`,
            message: "Session initialized"
        ))

        let events = bridge.mapSDKMessage(message)

        XCTAssertTrue(events.isEmpty,
            ".system messages should be ignored (no events produced)")
    }

    // MARK: - AC3: Context Tracking (toolUseId -> stepID mapping)

    /// [P0] Bridge maintains toolUseId -> stepID mapping for correlating events
    func testBridgeMaintainsStepIDMapping() async throws {
        let bridge = SDKMessageBridge()
        let toolUseId = "mapping-test-001"

        // Send toolUse to create mapping
        let toolUseMsg = SDKMessage.toolUse(SDKMessage.ToolUseData(
            toolName: "test_tool",
            toolUseId: toolUseId,
            input: "{}"
        ))
        let toolUseEvents = bridge.mapSDKMessage(toolUseMsg)

        // Extract the generated stepID
        var generatedStepID: UUID?
        for event in toolUseEvents {
            if case .stepStarted(let stepID, _) = event {
                generatedStepID = stepID
            }
        }
        XCTAssertNotNil(generatedStepID,
            "toolUse should produce a stepStarted with a generated stepID")

        // Send toolResult referencing the same toolUseId
        let resultMsg = SDKMessage.toolResult(SDKMessage.ToolResultData(
            toolUseId: toolUseId,
            content: "Done",
            isError: false
        ))
        let resultEvents = bridge.mapSDKMessage(resultMsg)

        // Verify the stepCompleted uses the same stepID
        for event in resultEvents {
            if case .stepCompleted(let stepID, _) = event {
                XCTAssertEqual(stepID, generatedStepID,
                    "stepCompleted should use the same stepID as the corresponding stepStarted")
                return
            }
        }
        XCTFail("Expected stepCompleted event with matching stepID")
    }

    /// [P1] Multiple toolUse/toolResult pairs maintain independent mappings
    func testBridgeMultipleToolMappings() async throws {
        let bridge = SDKMessageBridge()

        // First tool
        let toolUse1 = SDKMessage.toolUse(SDKMessage.ToolUseData(
            toolName: "tool_a", toolUseId: "id-1", input: "{}"
        ))
        let events1 = bridge.mapSDKMessage(toolUse1)
        var stepID1: UUID?
        for e in events1 { if case .stepStarted(let id, _) = e { stepID1 = id } }

        // Second tool
        let toolUse2 = SDKMessage.toolUse(SDKMessage.ToolUseData(
            toolName: "tool_b", toolUseId: "id-2", input: "{}"
        ))
        let events2 = bridge.mapSDKMessage(toolUse2)
        var stepID2: UUID?
        for e in events2 { if case .stepStarted(let id, _) = e { stepID2 = id } }

        XCTAssertNotEqual(stepID1, stepID2,
            "Different tool invocations should generate different stepIDs")

        // Results for first tool
        let result1 = SDKMessage.toolResult(SDKMessage.ToolResultData(
            toolUseId: "id-1", content: "A done", isError: false
        ))
        let resultEvents1 = bridge.mapSDKMessage(result1)
        for e in resultEvents1 {
            if case .stepCompleted(let id, _) = e {
                XCTAssertEqual(id, stepID1,
                    "First tool result should map back to first stepID")
            }
        }

        // Results for second tool
        let result2 = SDKMessage.toolResult(SDKMessage.ToolResultData(
            toolUseId: "id-2", content: "B done", isError: false
        ))
        let resultEvents2 = bridge.mapSDKMessage(result2)
        for e in resultEvents2 {
            if case .stepCompleted(let id, _) = e {
                XCTAssertEqual(id, stepID2,
                    "Second tool result should map back to second stepID")
            }
        }
    }
}
