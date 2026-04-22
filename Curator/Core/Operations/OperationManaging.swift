import Foundation

/// Protocol for managing batch operations with snapshot and rollback support.
///
/// Defined in the Domain layer (Core/Operations/). Concrete implementations
/// (e.g., OperationManager actor) reside in the same module.
/// Supports test-time replacement with mock implementations.
protocol OperationManaging: Sendable {
    typealias BatchID = UUID

    /// Creates a batch with snapshots for each planned operation.
    ///
    /// Captures the before-state metadata of each affected asset via the
    /// repository, without executing any operations.
    /// Returns a unique batch ID for later execution.
    /// - Parameters:
    ///   - operations: The planned operations to include in the batch.
    ///   - repository: The repository to read asset metadata from.
    /// - Returns: A unique identifier for the created batch.
    /// - Throws: `DomainError.invalidState` if operations is empty.
    func beginBatch(operations: [PlannedOperation], repository: PhotoLibraryRepository) async throws -> BatchID

    /// Executes all operations in the specified batch.
    ///
    /// Updates batch status to `.executing`, then applies each operation
    /// sequentially via the provided repository. On partial failure, automatically
    /// rolls back completed operations and sets status to `.failed`.
    /// - Parameters:
    ///   - batchID: The batch to execute.
    ///   - repository: The repository to perform actual file operations.
    /// - Throws: `DomainError.invalidState` if batch not found or not in pending state.
    func executeBatch(_ batchID: BatchID, repository: PhotoLibraryRepository) async throws

    /// Rolls back a completed batch, restoring each asset to its before-state.
    ///
    /// Uses the repository to reverse file operations (rename, move).
    /// Delete rollback is best-effort (file may be in macOS Trash).
    /// - Parameters:
    ///   - batchID: The batch to roll back.
    ///   - repository: The repository to perform rollback file operations.
    /// - Throws: `DomainError.invalidState` if batch not found, cannot be rolled back,
    ///           or rollback of an operation fails.
    func rollbackBatch(_ batchID: BatchID, repository: PhotoLibraryRepository) async throws

    /// Rolls back the most recently completed batch.
    ///
    /// Used for the undo (Cmd+Z) feature in Story 4.3.
    /// - Parameter repository: The repository to perform rollback file operations.
    /// - Throws: `DomainError.invalidState` if no completed batch exists.
    func rollbackLastBatch(repository: PhotoLibraryRepository) async throws

    /// Detects batches left in `.executing` status (crash recovery, NFR17).
    ///
    /// - Returns: Array of incomplete BatchOperations.
    func detectIncompleteBatches() async throws -> [BatchOperation]

    /// Queries batch operation history.
    ///
    /// - Parameter limit: Maximum number of batches to return.
    /// - Returns: Array of BatchOperations ordered by creation date (newest first).
    func getBatchHistory(limit: Int) async throws -> [BatchOperation]
}
