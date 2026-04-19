import Foundation

/// Photo source change events for real-time monitoring.
enum SourceChange: Sendable, Equatable {
    case filesAdded([AssetID])
    case filesRemoved([AssetID])
    case filesModified([AssetID])
}
