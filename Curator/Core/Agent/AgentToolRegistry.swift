import Foundation
import OpenAgentSDK

/// Registry for managing custom tools that integrate with the OpenAgentSDK Agent loop.
///
/// Tools registered here are passed to `AgentOptions.tools` when creating a CuratorAgent.
/// The registry supports dynamic registration via `register()` and lookup via `tool(named:)`.
/// Tools obtain infrastructure dependencies (e.g., PhotoLibraryRepository) through
/// closure capture at creation time, following the project's dependency injection pattern.
final class AgentToolRegistry: @unchecked Sendable {

    // MARK: - Internal State

    /// Thread-safe storage for registered tools.
    /// ToolProtocol inherits Sendable, so the array contents are safe to share across concurrency domains.
    private var _tools: [ToolProtocol] = []

    /// Lock protecting concurrent access to _tools.
    private let lock = NSLock()

    // MARK: - Initialization

    init() {}

    // MARK: - Registration

    /// Registers a tool conforming to ToolProtocol.
    ///
    /// The tool is appended to the internal collection and will be included
    /// in `allTools` and discoverable via `tool(named:)`.
    ///
    /// - Parameter tool: A ToolProtocol-conforming tool instance.
    func register(_ tool: ToolProtocol) {
        lock.withLock {
            _tools.append(tool)
        }
    }

    // MARK: - Access

    /// Returns a copy of all registered tools.
    ///
    /// The returned array is a snapshot; mutations to the registry after calling
    /// this property are not reflected in previously returned arrays.
    var allTools: [ToolProtocol] {
        lock.withLock {
            return _tools
        }
    }

    /// Finds a registered tool by its name.
    ///
    /// - Parameter name: The tool name to search for (matches `ToolProtocol.name`).
    /// - Returns: The matching tool, or `nil` if no tool with that name is registered.
    func tool(named name: String) -> ToolProtocol? {
        lock.withLock {
            return _tools.first { $0.name == name }
        }
    }
}
