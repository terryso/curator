import SwiftData
import Combine

/// SwiftData model container manager for persistent storage.
///
/// Initializes and provides access to the shared ModelContainer.
/// Called once during app startup; injected into services that need persistence.
@MainActor
final class SwiftDataManager: ObservableObject {
    let container: ModelContainer

    init(inMemory: Bool = false) {
        let schema = Schema([CostRecordEntity.self, SessionEntity.self])
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory
        )
        do {
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }
}
