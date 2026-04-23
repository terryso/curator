import Foundation

/// ViewModel managing read-only mode state and saved operations.
///
/// Provides a presentation-layer facade over `PermissionState` and handles
/// persistence of operation sets via UserDefaults. Marked `@Observable @MainActor`
/// so SwiftUI views can bind to it directly.
@Observable
@MainActor
final class ReadOnlyModeViewModel {

    // MARK: - Dependencies

    /// Permission state providing read/write mode information.
    private let permissionState: PermissionState?

    /// UserDefaults key for persisted saved operations.
    private static let savedOperationsKey = "curator.savedOperations"

    // MARK: - Initialization

    init(permissionState: PermissionState? = nil) {
        self.permissionState = permissionState
        loadSavedOperations()
    }

    // MARK: - Read-Only State

    /// Whether the app is currently in read-only mode.
    var isReadOnly: Bool {
        permissionState?.isReadOnly ?? true
    }

    /// Whether write access has been granted.
    var hasWriteAccess: Bool {
        permissionState?.hasWriteAccess ?? false
    }

    // MARK: - Saved Operations

    /// Cached saved operation sets, loaded once and kept in sync with UserDefaults.
    /// Marked as an observable property so SwiftUI views react to changes.
    var savedOperations: [SavedOperationSet] = []

    /// Whether there are saved operations awaiting execution.
    var hasSavedOperations: Bool {
        !savedOperations.isEmpty
    }

    /// Saves planned operations for later execution.
    ///
    /// Serializes the operations into a `SavedOperationSet` and appends it
    /// to the persisted list in UserDefaults as JSON.
    ///
    /// - Parameters:
    ///   - operations: The planned operations to save.
    ///   - summary: Human-readable summary of the operations.
    func saveOperationsForLater(_ operations: [PlannedOperation], summary: String) {
        let newSet = SavedOperationSet(operations: operations, summary: summary)
        savedOperations.append(newSet)
        persistSavedOperations(savedOperations)
    }

    /// Loads all saved operation sets from UserDefaults into the cached property.
    /// Called once during initialization. Subsequent reads use the cached value.
    func loadSavedOperations() {
        guard let data = UserDefaults.standard.data(forKey: Self.savedOperationsKey) else {
            savedOperations = []
            return
        }
        do {
            savedOperations = try JSONDecoder().decode([SavedOperationSet].self, from: data)
        } catch {
            // Corrupted data — clear and return empty
            clearAllSavedOperations()
        }
    }

    /// Executes a saved operation set through the operation manager.
    ///
    /// Requires write access. Creates a batch and executes it via the
    /// provided repository from the repository provider.
    ///
    /// - Parameters:
    ///   - savedSet: The saved operation set to execute.
    ///   - operationManager: The operation manager for batch execution.
    ///   - repositoryProvider: Provider for the photo library repository.
    func executeSavedOperations(
        _ savedSet: SavedOperationSet,
        operationManager: any OperationManaging,
        repositoryProvider: (any UndoManagerRepositoryProvider)? = nil
    ) async throws {
        let repository: any PhotoLibraryRepository = repositoryProvider?.getRepository()
            ?? ReadOnlyNoOpRepository()

        let batchID = try await operationManager.beginBatch(
            operations: savedSet.operations,
            repository: repository
        )
        try await operationManager.executeBatch(batchID, repository: repository)

        // Remove the executed set from cached operations and persist
        deleteSavedOperations(savedSet)
    }

    /// Deletes a specific saved operation set.
    ///
    /// - Parameter savedSet: The set to remove.
    func deleteSavedOperations(_ savedSet: SavedOperationSet) {
        savedOperations.removeAll { $0.id == savedSet.id }
        persistSavedOperations(savedOperations)
    }

    /// Clears all saved operation sets.
    func clearAllSavedOperations() {
        savedOperations = []
        UserDefaults.standard.removeObject(forKey: Self.savedOperationsKey)
    }

    // MARK: - Private Helpers

    /// Persists the given array of saved operation sets to UserDefaults.
    private func persistSavedOperations(_ operations: [SavedOperationSet]) {
        do {
            let data = try JSONEncoder().encode(operations)
            UserDefaults.standard.set(data, forKey: Self.savedOperationsKey)
        } catch {
            // Encoding failure — best effort, data is not critical
        }
    }
}

// MARK: - No-Op Repository

/// Minimal no-op repository for ReadOnlyModeViewModel when no provider is configured.
private struct ReadOnlyNoOpRepository: PhotoLibraryRepository, Sendable {
    func currentBasePath() async -> String? { nil }
    func requestReadAccess() async throws -> Bool { true }
    func requestWriteAccess() async throws -> Bool { true }
    func fetchAssets(predicate: PhotoPredicate, pageSize: Int, pageOffset: Int) async throws -> AssetPage {
        AssetPage(assets: [], hasMore: false)
    }
    func fetchFullResolutionImage(for assetID: AssetID) async throws -> Data { Data() }
    func fetchThumbnail(for assetID: AssetID, size: CGSize) async throws -> Data { Data() }
    func metadata(for assetID: AssetID) async throws -> AssetMetadata {
        AssetMetadata(fileName: "", fileSize: nil, creationDate: nil, cameraModel: nil, imageWidth: nil, imageHeight: nil, gpsLocation: nil, fileFormat: nil)
    }
    func updateAsset(_ assetID: AssetID, title: String?) async throws {}
    func deleteAssets(_ assetIDs: [AssetID]) async throws {}
    func moveAssets(_ assetIDs: [AssetID], to directory: String) async throws {}
    func observeSourceChanges() -> AsyncStream<SourceChange> {
        AsyncStream { $0.finish() }
    }
}
