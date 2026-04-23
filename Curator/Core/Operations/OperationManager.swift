import Foundation
import SwiftData

/// Actor-based operation manager providing snapshot/rollback for batch operations.
///
/// All state mutations are serialized through actor isolation. File operations
/// are performed via the injected `PhotoLibraryRepository` protocol, keeping
/// this class decoupled from infrastructure details.
actor OperationManager: OperationManaging {
    typealias BatchID = UUID

    // ModelContext is not Sendable, but we only access it within this actor's
    // isolated context, so it is safe to use nonisolated(unsafe).
    nonisolated(unsafe) private let modelContext: ModelContext

    /// Creates an OperationManager with the given SwiftData ModelContext.
    ///
    /// - Parameter modelContext: The SwiftData context for persisting operation snapshots.
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - OperationManaging Conformance

    func beginBatch(operations: [PlannedOperation], repository: PhotoLibraryRepository) async throws -> BatchID {
        guard !operations.isEmpty else {
            throw DomainError.invalidState(reason: "Cannot begin batch with empty operations")
        }

        let batchID = UUID()
        let now = Date()

        let batchEntity = BatchOperationEntity(
            id: batchID,
            createdAt: now,
            status: BatchStatus.pending.rawValue
        )

        for operation in operations {
            let snapshotID = UUID()
            let metadata = try await repository.metadata(for: operation.assetID)

            let snapshotEntity = OperationSnapshotEntity(
                id: snapshotID,
                timestamp: now,
                operationType: operation.operationType.rawValue,
                assetID: operation.assetID.rawValue,
                beforeStateFileName: metadata.fileName,
                beforeStateFilePath: operation.assetID.rawValue,
                beforeStateFileSize: metadata.fileSize ?? 0,
                beforeStateCreationDate: metadata.creationDate,
                isExecuted: false,
                isRolledBack: false,
                plannedOperationData: try? JSONEncoder().encode(operation)
            )
            snapshotEntity.batch = batchEntity
            batchEntity.snapshots.append(snapshotEntity)
        }

        modelContext.insert(batchEntity)
        try modelContext.save()

        return batchID
    }

    func executeBatch(_ batchID: BatchID, repository: PhotoLibraryRepository) async throws {
        let batchEntity = try fetchBatchEntity(batchID)

        guard BatchStatus(rawValue: batchEntity.status) == .pending else {
            throw DomainError.invalidState(reason: "Batch \(batchID) is not in pending state (current: \(batchEntity.status))")
        }

        batchEntity.status = BatchStatus.executing.rawValue
        try modelContext.save()

        var executedSnapshots: [OperationSnapshotEntity] = []

        do {
            for snapshotEntity in batchEntity.snapshots {
                let operation = try decodePlannedOperation(from: snapshotEntity)
                try await executeSingleOperation(operation, repository: repository)
                snapshotEntity.isExecuted = true
                snapshotEntity.afterStateFilePath = computeAfterStatePath(
                    originalPath: snapshotEntity.beforeStateFilePath,
                    operation: operation,
                    basePath: await repository.currentBasePath()
                )
                executedSnapshots.append(snapshotEntity)
            }

            batchEntity.status = BatchStatus.completed.rawValue
            batchEntity.completedAt = Date()
            try modelContext.save()
        } catch {
            // Partial failure: attempt rollback, but always set status to failed
            batchEntity.status = BatchStatus.failed.rawValue
            batchEntity.completedAt = Date()
            try? await rollbackSnapshots(executedSnapshots, repository: repository)
            try modelContext.save()
            throw error
        }
    }

    func rollbackBatch(_ batchID: BatchID, repository: PhotoLibraryRepository) async throws {
        let batchEntity = try fetchBatchEntity(batchID)
        let currentStatus = BatchStatus(rawValue: batchEntity.status)

        guard currentStatus == .completed || currentStatus == .failed || currentStatus == .executing else {
            throw DomainError.invalidState(
                reason: "Batch \(batchID) cannot be rolled back (current status: \(batchEntity.status))"
            )
        }

        let executedSnapshots = batchEntity.snapshots.filter { $0.isExecuted && !$0.isRolledBack }

        // For crash recovery (.executing state), there may be no executed snapshots yet
        // In that case, just update the status without performing file rollback
        if executedSnapshots.isEmpty && currentStatus != .executing {
            throw DomainError.invalidState(reason: "Batch \(batchID) has no executed operations to roll back")
        }

        if !executedSnapshots.isEmpty {
            try await rollbackSnapshots(executedSnapshots, repository: repository)
        }

        batchEntity.status = BatchStatus.rolledBack.rawValue
        try modelContext.save()
    }

    func rollbackLastBatch(repository: PhotoLibraryRepository) async throws {
        let completedStatus = BatchStatus.completed.rawValue
        let descriptor = FetchDescriptor<BatchOperationEntity>(
            predicate: #Predicate { $0.status == completedStatus },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )

        let completedBatches = try modelContext.fetch(descriptor)
        guard let lastBatch = completedBatches.first else {
            throw DomainError.invalidState(reason: "No completed batch available to roll back")
        }

        try await rollbackBatch(lastBatch.id, repository: repository)
    }

    func detectIncompleteBatches() async throws -> [BatchOperation] {
        let executingStatus = BatchStatus.executing.rawValue
        let descriptor = FetchDescriptor<BatchOperationEntity>(
            predicate: #Predicate { $0.status == executingStatus },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )

        let entities = try modelContext.fetch(descriptor)
        return entities.map { $0.toBatchOperation() }
    }

    func getBatchHistory(limit: Int) async throws -> [BatchOperation] {
        var descriptor = FetchDescriptor<BatchOperationEntity>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit

        let entities = try modelContext.fetch(descriptor)
        return entities.map { $0.toBatchOperation() }
    }

    func reexecuteLastRolledBackBatch(repository: PhotoLibraryRepository) async throws {
        let rolledBackStatus = BatchStatus.rolledBack.rawValue
        let descriptor = FetchDescriptor<BatchOperationEntity>(
            predicate: #Predicate { $0.status == rolledBackStatus },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )

        let rolledBackBatches = try modelContext.fetch(descriptor)
        guard let lastBatch = rolledBackBatches.first else {
            throw DomainError.invalidState(reason: "No rolled-back batch available to re-execute")
        }

        let rolledBackSnapshots = lastBatch.snapshots.filter { $0.isRolledBack }
        guard !rolledBackSnapshots.isEmpty else {
            throw DomainError.invalidState(reason: "Batch \(lastBatch.id) has no rolled-back operations to re-execute")
        }

        // Re-execute each rolled-back operation in original order
        for snapshotEntity in rolledBackSnapshots {
            let operation = try decodePlannedOperation(from: snapshotEntity)
            try await executeSingleOperation(operation, repository: repository)
            snapshotEntity.isRolledBack = false
            snapshotEntity.isExecuted = true
        }

        lastBatch.status = BatchStatus.completed.rawValue
        lastBatch.completedAt = Date()
        try modelContext.save()
    }

    // MARK: - Private Helpers

    private func fetchBatchEntity(_ batchID: BatchID) throws -> BatchOperationEntity {
        let id = batchID
        let descriptor = FetchDescriptor<BatchOperationEntity>(
            predicate: #Predicate { $0.id == id }
        )

        let results = try modelContext.fetch(descriptor)
        guard let entity = results.first else {
            throw DomainError.invalidState(reason: "Batch \(batchID) not found")
        }
        return entity
    }

    private func executeSingleOperation(
        _ operation: PlannedOperation,
        repository: PhotoLibraryRepository
    ) async throws {
        switch operation.parameters {
        case .rename(let newTitle):
            try await repository.updateAsset(operation.assetID, title: newTitle)
        case .delete:
            try await repository.deleteAssets([operation.assetID])
        case .move(let targetDirectory):
            try await repository.moveAssets([operation.assetID], to: targetDirectory)
        case .metadataChange:
            break
        }
    }

    /// Rolls back executed snapshots in reverse order using the repository protocol.
    ///
    /// Throws on the first rollback failure so the caller can record the error state.
    private func rollbackSnapshots(
        _ snapshots: [OperationSnapshotEntity],
        repository: PhotoLibraryRepository
    ) async throws {
        for snapshotEntity in snapshots.reversed() {
            let operation = try decodePlannedOperation(from: snapshotEntity)
            let originalFileName = snapshotEntity.beforeStateFileName
            let originalPath = snapshotEntity.beforeStateFilePath

            switch operation.parameters {
            case .rename:
                try await performRollbackRename(
                    snapshotEntity: snapshotEntity,
                    operation: operation,
                    repository: repository
                )

            case .delete:
                try await performRollbackDelete(
                    originalPath: originalPath,
                    originalFileName: originalFileName,
                    repository: repository
                )

            case .move:
                try await performRollbackMove(
                    snapshotEntity: snapshotEntity,
                    operation: operation,
                    repository: repository
                )

            case .metadataChange:
                break
            }

            snapshotEntity.isRolledBack = true
        }
    }

    /// Rename rollback: the file was renamed from originalName to newTitle.
    /// The current path is the after-state path (or computed from the original directory + new title).
    /// We call updateAsset with the current path and the original filename to rename back.
    private func performRollbackRename(
        snapshotEntity: OperationSnapshotEntity,
        operation: PlannedOperation,
        repository: PhotoLibraryRepository
    ) async throws {
        guard case .rename(let newTitle) = operation.parameters else { return }

        let currentPath: String
        if let after = snapshotEntity.afterStateFilePath {
            currentPath = after
        } else {
            // Fallback: compute from before-state directory + new title + extension
            let originalPath = snapshotEntity.beforeStateFilePath
            let directory = (originalPath as NSString).deletingLastPathComponent
            let ext = (originalPath as NSString).pathExtension
            currentPath = (directory as NSString).appendingPathComponent(
                ext.isEmpty ? newTitle : "\(newTitle).\(ext)"
            )
        }

        let originalNameWithoutExt = (snapshotEntity.beforeStateFileName as NSString).deletingPathExtension
        try await repository.updateAsset(AssetID(rawValue: currentPath), title: originalNameWithoutExt)
    }

    /// Delete rollback: best-effort restore from macOS Trash.
    /// Since `deleteAssets` uses `FileManager.trashItem`, the file may be in ~/.Trash/.
    /// We attempt to move it back; if not found in Trash, we throw.
    private func performRollbackDelete(
        originalPath: String,
        originalFileName: String,
        repository: PhotoLibraryRepository
    ) async throws {
        let trashPath = NSHomeDirectory() + "/.Trash/" + originalFileName
        let directory = (originalPath as NSString).deletingLastPathComponent

        guard FileManager.default.fileExists(atPath: trashPath) else {
            throw DomainError.invalidState(
                reason: "Cannot rollback delete: file '\(originalFileName)' not found in Trash"
            )
        }
        guard !FileManager.default.fileExists(atPath: originalPath) else { return }

        // Delete rollback must use FileManager since the repository has no "restore from trash" method.
        // This is the one exception where direct FileManager is architecturally necessary.
        try FileManager.default.moveItem(atPath: trashPath, toPath: originalPath)
    }

    /// Move rollback: the file was moved from originalDir to targetDirectory.
    /// The current path is the after-state path (or computed from basePath + targetDir + fileName).
    /// We call moveAssets with the current AssetID and the original relative directory.
    private func performRollbackMove(
        snapshotEntity: OperationSnapshotEntity,
        operation: PlannedOperation,
        repository: PhotoLibraryRepository
    ) async throws {
        guard case .move(let targetDirectory) = operation.parameters else { return }
        let basePath = await repository.currentBasePath()
        guard let basePath else {
            throw DomainError.invalidState(reason: "Cannot rollback move: repository has no base path")
        }

        let currentPath: String
        if let after = snapshotEntity.afterStateFilePath {
            currentPath = after
        } else {
            // Fallback: compute from base path + target directory + original filename
            let destDir = URL(fileURLWithPath: basePath).appendingPathComponent(targetDirectory, isDirectory: true)
            currentPath = destDir.appendingPathComponent(snapshotEntity.beforeStateFileName).path
        }

        // Compute the original relative directory (relative to basePath)
        let originalPath = snapshotEntity.beforeStateFilePath
        var originalRelativeDir: String
        if originalPath.hasPrefix(basePath) {
            let relative = String(originalPath.dropFirst(basePath.count))
            // relative is like "/subfolder/file.jpg" — take directory part
            let dirPart = (relative as NSString).deletingLastPathComponent
            // Remove leading slash
            originalRelativeDir = dirPart.hasPrefix("/") ? String(dirPart.dropFirst()) : dirPart
            // If empty, it was in the root of the base folder
            if originalRelativeDir.isEmpty { originalRelativeDir = "." }
        } else {
            // Original was not under base path — shouldn't happen but fallback
            originalRelativeDir = (originalPath as NSString).deletingLastPathComponent
        }

        try await repository.moveAssets([AssetID(rawValue: currentPath)], to: originalRelativeDir)
    }

    /// Computes the expected file path after an operation is applied.
    private func computeAfterStatePath(
        originalPath: String,
        operation: PlannedOperation,
        basePath: String?
    ) -> String? {
        switch operation.parameters {
        case .rename(let newTitle):
            let directory = (originalPath as NSString).deletingLastPathComponent
            let ext = (originalPath as NSString).pathExtension
            return (directory as NSString).appendingPathComponent(
                ext.isEmpty ? newTitle : "\(newTitle).\(ext)"
            )

        case .move(let targetDirectory):
            guard let basePath else { return nil }
            let baseURL = URL(fileURLWithPath: basePath)
            let destDir = baseURL.appendingPathComponent(targetDirectory, isDirectory: true)
            let fileName = (originalPath as NSString).lastPathComponent
            return destDir.appendingPathComponent(fileName).path

        case .delete, .metadataChange:
            return nil
        }
    }

    private func decodePlannedOperation(from snapshotEntity: OperationSnapshotEntity) throws -> PlannedOperation {
        guard let data = snapshotEntity.plannedOperationData else {
            throw DomainError.invalidState(
                reason: "Snapshot \(snapshotEntity.id) missing planned operation data"
            )
        }
        return try JSONDecoder().decode(PlannedOperation.self, from: data)
    }
}
