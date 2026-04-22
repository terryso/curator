import Foundation

extension AsyncStream where Element == AgentEvent {

    /// Merges consecutive `.stepProgress` events to prevent over-rendering in the UI.
    ///
    /// Only `.stepProgress` events are eligible for merging; all other event types pass
    /// through unchanged and in their original order. When a non-progress event arrives,
    /// any buffered progress events are flushed first in arrival order, preserving correct
    /// ordering.
    ///
    /// The merge strategy keeps only the latest `.stepProgress` for each stepID,
    /// discarding earlier ones that would cause redundant UI updates. This satisfies
    /// NFR7 by preventing the UI thread from being overwhelmed with rapid progress updates.
    ///
    /// - Returns: A new `AsyncStream<AgentEvent>` with coalesced progress events.
    func mergeProgressEvents() -> AsyncStream<AgentEvent> {
        AsyncStream<AgentEvent> { continuation in
            let task = _Concurrency.Task {
                // Buffer preserves arrival order: each entry is (stepID, event)
                // When a new progress for an existing stepID arrives, the old entry is
                // replaced in-place to maintain its original position in the arrival sequence.
                var progressBuffer: [(stepID: UUID, event: AgentEvent)] = []

                for await event in self {
                    switch event {
                    case .stepProgress(let stepID, _, _):
                        // Replace existing entry for this stepID to keep arrival order
                        if let index = progressBuffer.firstIndex(where: { $0.stepID == stepID }) {
                            progressBuffer[index] = (stepID, event)
                        } else {
                            progressBuffer.append((stepID, event))
                        }

                    default:
                        // Non-progress event: flush all buffered progress in arrival order
                        for (_, bufferedEvent) in progressBuffer {
                            continuation.yield(bufferedEvent)
                        }
                        progressBuffer.removeAll()

                        // Then emit the non-progress event
                        continuation.yield(event)
                    }
                }

                // Flush any remaining buffered progress events
                for (_, bufferedEvent) in progressBuffer {
                    continuation.yield(bufferedEvent)
                }

                continuation.finish()
            }

            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }
}
