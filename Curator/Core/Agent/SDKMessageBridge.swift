import Foundation
import OpenAgentSDK

/// Bridges OpenAgentSDK `SDKMessage` events to Curator's `AgentEvent` stream.
///
/// The bridge maintains a `toolUseId -> UUID` mapping so that correlated events
/// (e.g., `.toolUse` followed by `.toolResult`) reference the same `AgentStep` ID.
/// This enables the `AgentJob` state machine to update the correct step when
/// results arrive asynchronously.
///
/// Usage:
/// ```swift
/// let bridge = SDKMessageBridge()
/// for await message in agent.stream(userMessage) {
///     let events = bridge.mapSDKMessage(message)
///     for event in events { agentJob.emit(event) }
/// }
/// ```
struct SDKMessageBridge: Sendable {

    // MARK: - Step ID Tracking

    /// Maps SDK toolUseId to Curator's AgentStep UUID.
    /// Used to correlate .toolUse, .toolResult, and .toolProgress events.
    private let stepIDMap: NSLockingDictionary<String, UUID>

    // MARK: - Initialization

    init() {
        self.stepIDMap = NSLockingDictionary()
    }

    // MARK: - Mapping

    /// Converts a single SDKMessage into zero or more AgentEvents.
    ///
    /// Mapping rules follow the architecture decision in the story spec:
    /// - `.toolUse` → `.stepStarted`
    /// - `.toolResult(isError: false)` → `.stepCompleted`
    /// - `.toolResult(isError: true)` → `.stepFailed`
    /// - `.assistant` with reasoning text → `.stepReasoning`
    /// - `.result(.success)` → `.executionCompleted`
    /// - `.result(.errorDuringExecution)` → `.stepFailed`
    /// - `.result(.cancelled)` → empty (AgentJob handles cancellation)
    /// - `.partialMessage` → empty (Story 3.6 optimization)
    /// - `.system` → empty (initialization metadata)
    /// - `.toolProgress` → `.stepProgress`
    /// - `.toolUseSummary` → empty (aggregate info)
    /// - `.userMessage` → empty (handled outside bridge)
    ///
    /// - Parameter message: An SDKMessage from the Agent stream.
    /// - Returns: An array of AgentEvents (may be empty for ignored message types).
    func mapSDKMessage(_ message: SDKMessage) -> [AgentEvent] {
        switch message {
        case .toolUse(let data):
            return mapToolUse(data)

        case .toolResult(let data):
            return mapToolResult(data)

        case .assistant(let data):
            return mapAssistant(data)

        case .result(let data):
            return mapResult(data)

        case .toolProgress(let data):
            return mapToolProgress(data)

        // Ignored message types (Story 3.6 optimization or non-applicable)
        case .partialMessage, .system, .userMessage, .toolUseSummary,
             .hookStarted, .hookProgress, .hookResponse,
             .taskStarted, .taskProgress,
             .authStatus, .filesPersisted, .localCommandOutput,
             .promptSuggestion:
            return []
        }
    }

    // MARK: - Private Mapping Methods

    /// Maps a toolUse message to stepStarted, creating a new step ID.
    private func mapToolUse(_ data: SDKMessage.ToolUseData) -> [AgentEvent] {
        let stepID = UUID()
        stepIDMap[data.toolUseId] = stepID
        return [.stepStarted(stepID: stepID, title: data.toolName)]
    }

    /// Maps a toolResult message to stepCompleted or stepFailed.
    private func mapToolResult(_ data: SDKMessage.ToolResultData) -> [AgentEvent] {
        guard let stepID = stepIDMap[data.toolUseId] else {
            // If no prior toolUse was tracked, generate a new stepID
            let stepID = UUID()
            if data.isError {
                return [.stepFailed(stepID: stepID, error: .analysisFailed(reason: data.content))]
            }
            return [.stepCompleted(stepID: stepID, result: StepResult(stepID: stepID, message: data.content, data: [:]))]
        }

        if data.isError {
            return [.stepFailed(stepID: stepID, error: .analysisFailed(reason: data.content))]
        } else {
            return [.stepCompleted(stepID: stepID, result: StepResult(stepID: stepID, message: data.content, data: [:]))]
        }
    }

    /// Maps an assistant message to stepReasoning (if it has text content).
    private func mapAssistant(_ data: SDKMessage.AssistantData) -> [AgentEvent] {
        guard !data.text.isEmpty else { return [] }

        // Use the most recent stepID from the map, or generate a new one
        let stepID = stepIDMap.latestValue ?? UUID()
        return [.stepReasoning(stepID: stepID, message: data.text)]
    }

    /// Maps a result message to executionCompleted or stepFailed.
    private func mapResult(_ data: SDKMessage.ResultData) -> [AgentEvent] {
        switch data.subtype {
        case .success:
            let summary = ExecutionSummary(
                totalSteps: data.numTurns,
                completedSteps: data.numTurns,
                failedSteps: 0,
                duration: Double(data.durationMs) / 1000.0,
                message: data.text
            )
            return [.executionCompleted(summary: summary)]

        case .cancelled:
            // Cancellation is handled by AgentJob directly; no event needed
            return []

        case .errorDuringExecution, .errorMaxTurns, .errorMaxBudgetUsd, .errorMaxStructuredOutputRetries:
            // Generate a synthetic stepID for the error
            let stepID = UUID()
            return [.stepFailed(stepID: stepID, error: .analysisFailed(reason: data.text))]
        }
    }

    /// Maps a toolProgress message to stepProgress.
    private func mapToolProgress(_ data: SDKMessage.ToolProgressData) -> [AgentEvent] {
        guard let stepID = stepIDMap[data.toolUseId] else { return [] }
        // toolProgress doesn't have completed/total info; use 0/0 as placeholder
        return [.stepProgress(stepID: stepID, completed: 0, total: 0)]
    }
}

// MARK: - NSLockingDictionary

/// A thread-safe dictionary wrapper using NSLock.
///
/// Used internally by SDKMessageBridge to maintain the toolUseId -> stepID mapping
/// across concurrent SDK message processing.
private final class NSLockingDictionary<Key: Hashable & Sendable, Value: Sendable>: @unchecked Sendable {
    private var storage: [Key: Value] = [:]
    private let lock = NSLock()

    subscript(key: Key) -> Value? {
        get {
            lock.withLock { storage[key] }
        }
        set {
            lock.withLock {
                storage[key] = newValue
                if newValue != nil {
                    lastInsertedKey = key
                }
            }
        }
    }

    /// Returns the most recently inserted value, or nil if empty.
    var latestValue: Value? {
        lock.withLock {
            guard let lastKey = lastInsertedKey else { return nil }
            return storage[lastKey]
        }
    }

    /// Tracks the most recently inserted key for latestValue lookup.
    private var lastInsertedKey: Key?
}
