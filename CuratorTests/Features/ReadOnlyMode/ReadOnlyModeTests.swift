import Foundation
import XCTest

@testable import Curator

/// ATDD Tests for Story 4.5 — 只读模式保障 (Read-Only Mode Safety)
///
/// Tests verify:
/// - AC1: 只读模式下分析功能正常运行（FR37）
/// - AC2: 只读模式下写操作触发权限升级（FR6, UX-DR9）
/// - AC3: Repository 层写入守卫（FR38）
/// - AC4: 只读模式全局视觉指示（UX-DR9, UX-DR15）
/// - AC5: 只读模式下保存结果供稍后执行
@MainActor
final class ReadOnlyModeTests: XCTestCase {

    // MARK: - AC1: 只读模式下分析功能正常运行（FR37）

    /// [P0] 只读模式下分析操作正常执行和返回结果。
    ///
    /// AC1: Given 应用处于只读模式（PermissionState.isReadOnly == true），
    /// When 用户执行任何分析操作（去重检测、重命名建议生成、照片扫描），
    /// Then 分析正常执行，结果正常展示。
    func testAnalysisWorksInReadOnlyMode() async throws {
        // Given: 只读模式下（PermissionState.isReadOnly == true）
        // Use a temp directory so fetchAssets has a valid folder to scan
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReadOnlyAnalysisTest_\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        let bookmarkManager = MockReadOnlyBookmarkManager(hasValidBookmark: true)
        let repository = LocalFolderRepository(
            bookmarkManager: bookmarkManager,
            initialFolderURL: tempDir
        )
        let permissionState = PermissionState(repository: repository)

        XCTAssertTrue(permissionState.isReadOnly, "应用应处于只读模式")

        // When: 执行分析操作（照片扫描）
        // fetchAssets 是只读操作，不应受权限限制
        let result = try await repository.fetchAssets(
            predicate: .all,
            pageSize: 20,
            pageOffset: 0
        )

        // Then: 分析正常执行，结果正常返回
        XCTAssertNotNil(result, "只读操作应正常返回结果")
    }

    /// [P1] 只读模式下元数据读取正常执行。
    ///
    /// AC1: 只读操作（metadata, fetchThumbnail）在只读模式下不受影响。
    func testMetadataReadWorksInReadOnlyMode() async throws {
        // Given: 只读模式
        let bookmarkManager = MockReadOnlyBookmarkManager()
        let repository = LocalFolderRepository(bookmarkManager: bookmarkManager)
        let permissionState = PermissionState(repository: repository)

        XCTAssertTrue(permissionState.isReadOnly, "应处于只读模式")

        // When: 读取元数据（只读操作）
        // Then: 不应抛出 insufficientPermission 错误
        // metadata() 方法不检查写入权限，应正常工作（will throw fileNotFound for nonexistent)
        do {
            _ = try await repository.metadata(
                for: AssetID(rawValue: "/nonexistent/photo.jpg")
            )
            // If no throw, the file happened to exist — still valid
        } catch let error as DomainError {
            // Should NOT be insufficientPermission
            if case .insufficientPermission = error {
                XCTFail("只读操作不应抛出 insufficientPermission 错误")
            }
            // fileNotFound or other errors are expected
        }
    }

    // MARK: - AC2: 只读模式下写操作触发权限升级（FR6, UX-DR9）

    /// [P0] 只读模式下写操作触发权限升级请求。
    ///
    /// AC2: Given 只读模式下 Agent 生成了修改建议，
    /// When 用户尝试执行写操作（通过 ConfirmationViewModel 或直接调用），
    /// Then 系统请求写入权限升级。
    func testWritePermissionRequestedOnWriteAttempt() async throws {
        // Given: 只读模式下的 ConfirmationViewModel
        let permissionState = PermissionState() // 默认只读
        let viewModel = ConfirmationViewModel(
            operationManager: MockReadOnlyOperationManager(),
            permissionState: permissionState
        )

        XCTAssertTrue(permissionState.isReadOnly, "应处于只读模式")

        let operations = [
            PlannedOperation(
                operationType: .rename,
                assetID: AssetID(rawValue: "/photos/sunset.jpg"),
                parameters: .rename(newTitle: "golden_hour")
            ),
        ]

        let request = ConfirmationRequest(
            operations: operations,
            confirmationLevel: .standard,
            summary: "重命名 1 张照片"
        )

        // When: 尝试执行写操作
        viewModel.presentConfirmation(request: request)

        // Then: 系统请求写入权限升级
        XCTAssertTrue(viewModel.needsPermissionUpgrade,
            "只读模式下写操作应触发权限升级请求")
        XCTAssertFalse(viewModel.isExecuting,
            "不应在未授权时执行写操作")
    }

    /// [P0] 用户拒绝权限时操作建议被保存。
    ///
    /// AC2/AC5: Given 用户拒绝写入权限，
    /// When 权限被拒绝，
    /// Then 建议保存结果供稍后执行。
    func testOperationsSavedForLaterWhenPermissionDenied() async throws {
        // Given: 只读模式下的 ConfirmationViewModel with ReadOnlyModeViewModel
        let permissionState = PermissionState()
        let readOnlyVM = ReadOnlyModeViewModel()
        let viewModel = ConfirmationViewModel(
            operationManager: MockReadOnlyOperationManager(),
            permissionState: permissionState,
            readOnlyModeViewModel: readOnlyVM
        )

        let operations = [
            PlannedOperation(
                operationType: .rename,
                assetID: AssetID(rawValue: "/photos/sunset.jpg"),
                parameters: .rename(newTitle: "golden_hour")
            ),
        ]

        let request = ConfirmationRequest(
            operations: operations,
            confirmationLevel: .standard,
            summary: "重命名 1 张照片"
        )

        viewModel.presentConfirmation(request: request)
        XCTAssertTrue(viewModel.needsPermissionUpgrade, "应触发权限升级")

        // When: 用户拒绝权限
        viewModel.permissionDenied()

        // Then: 操作建议被保存
        XCTAssertTrue(viewModel.showPermissionDenied,
            "应显示权限拒绝提示")
        XCTAssertTrue(readOnlyVM.hasSavedOperations,
            "操作建议应被保存供稍后执行")

        // Cleanup
        readOnlyVM.clearAllSavedOperations()
    }

    /// [P0] 用户授权后操作正常继续执行。
    ///
    /// AC2: Given 用户授权写入权限，
    /// When 权限被授予，
    /// Then 操作正常继续执行。
    func testOperationsContinueAfterPermissionGranted() async throws {
        // Given: 只读模式下触发权限升级
        let mockRepo = MockWriteGrantedRepository()
        let permissionState = PermissionState(repository: mockRepo)
        let viewModel = ConfirmationViewModel(
            operationManager: MockReadOnlyOperationManager(),
            permissionState: permissionState
        )

        let operations = [
            PlannedOperation(
                operationType: .rename,
                assetID: AssetID(rawValue: "/photos/sunset.jpg"),
                parameters: .rename(newTitle: "golden_hour")
            ),
        ]

        let request = ConfirmationRequest(
            operations: operations,
            confirmationLevel: .standard,
            summary: "重命名 1 张照片"
        )

        viewModel.presentConfirmation(request: request)
        XCTAssertTrue(viewModel.needsPermissionUpgrade, "应触发权限升级")

        // When: 用户授权写入权限
        viewModel.permissionGranted()

        try await Task.sleep(for: .milliseconds(300))

        // Then: 权限升级标志被清除
        XCTAssertFalse(viewModel.needsPermissionUpgrade,
            "授权后权限升级标志应被清除")
    }

    // MARK: - AC3: Repository 层写入守卫（FR38）

    /// [P0] 只读模式下 LocalFolderRepository 拒绝写操作并抛出 DomainError.insufficientPermission。
    ///
    /// AC3: Given LocalFolderRepository 收到写操作请求（updateAsset），
    /// When 检查权限（bookmarkManager.hasWriteAccess == false），
    /// Then 拒绝操作并抛出 DomainError.insufficientPermission(required: .write)。
    func testUpdateAssetBlockedInReadOnlyMode() async throws {
        // Given: 只读模式下的 repository
        let bookmarkManager = MockReadOnlyBookmarkManager()
        let repository = LocalFolderRepository(bookmarkManager: bookmarkManager)

        // When: 尝试更新资产（写操作）
        do {
            try await repository.updateAsset(
                AssetID(rawValue: "/photos/test.jpg"),
                title: "new_name"
            )
            XCTFail("只读模式下 updateAsset 应抛出 insufficientPermission 错误")
        } catch let error as DomainError {
            // Then: 抛出 insufficientPermission 错误
            if case .insufficientPermission(let required) = error {
                XCTAssertEqual(required, .write,
                    "应要求 write 权限")
            } else {
                XCTFail("应为 insufficientPermission 错误，实际: \(error)")
            }
        }
    }

    /// [P0] 只读模式下 deleteAssets 被拒绝。
    ///
    /// AC3: deleteAssets 在无写入权限时抛出 DomainError.insufficientPermission。
    func testDeleteAssetsBlockedInReadOnlyMode() async throws {
        // Given: 只读模式下的 repository
        let bookmarkManager = MockReadOnlyBookmarkManager()
        let repository = LocalFolderRepository(bookmarkManager: bookmarkManager)

        // When: 尝试删除资产（写操作）
        do {
            try await repository.deleteAssets([AssetID(rawValue: "/photos/test.jpg")])
            XCTFail("只读模式下 deleteAssets 应抛出 insufficientPermission 错误")
        } catch let error as DomainError {
            // Then: 抛出 insufficientPermission 错误
            if case .insufficientPermission(let required) = error {
                XCTAssertEqual(required, .write,
                    "应要求 write 权限")
            } else {
                XCTFail("应为 insufficientPermission 错误，实际: \(error)")
            }
        }
    }

    /// [P0] 只读模式下 moveAssets 被拒绝。
    ///
    /// AC3: moveAssets 在无写入权限时抛出 DomainError.insufficientPermission。
    func testMoveAssetsBlockedInReadOnlyMode() async throws {
        // Given: 只读模式下的 repository
        let bookmarkManager = MockReadOnlyBookmarkManager()
        let repository = LocalFolderRepository(bookmarkManager: bookmarkManager)

        // When: 尝试移动资产（写操作）
        do {
            try await repository.moveAssets(
                [AssetID(rawValue: "/photos/test.jpg")],
                to: "vacation"
            )
            XCTFail("只读模式下 moveAssets 应抛出 insufficientPermission 错误")
        } catch let error as DomainError {
            // Then: 抛出 insufficientPermission 错误
            if case .insufficientPermission(let required) = error {
                XCTAssertEqual(required, .write,
                    "应要求 write 权限")
            } else {
                XCTFail("应为 insufficientPermission 错误，实际: \(error)")
            }
        }
    }

    /// [P0] 写操作守卫确保原始图像文件不被修改。
    ///
    /// AC3: 绝不直接修改原始图像文件 — 守卫阻止文件系统变更。
    func testOriginalImageFilesNeverModified() async throws {
        // Given: 一个临时目录中的测试图片文件
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReadOnlyTest_\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        let testFileURL = tempDir.appendingPathComponent("original_photo.jpg")
        let originalData = Data("original image data".utf8)
        try originalData.write(to: testFileURL)

        let bookmarkManager = MockReadOnlyBookmarkManager(hasValidBookmark: true)
        let repository = LocalFolderRepository(
            bookmarkManager: bookmarkManager,
            initialFolderURL: tempDir
        )

        // When: 尝试在只读模式下执行写操作
        do {
            try await repository.updateAsset(
                AssetID(rawValue: testFileURL.path),
                title: "modified_name"
            )
        } catch {
            // 预期抛出 insufficientPermission
        }

        // Then: 原始文件内容未被修改
        let fileData = try Data(contentsOf: testFileURL)
        XCTAssertEqual(fileData, originalData,
            "只读模式下原始图像文件绝不应被修改")
    }

    // MARK: - AC4: 只读模式全局视觉指示（UX-DR9, UX-DR15）

    /// [P1] 只读模式下视觉指示正确显示。
    ///
    /// AC4: Given 应用处于只读模式，
    /// When 渲染主界面，
    /// Then 工具栏显示锁图标按钮，提示"当前为只读模式"。
    func testReadOnlyBannerShowsWhenReadOnly() async throws {
        // Given: 只读模式的 ReadOnlyModeViewModel
        let permissionState = PermissionState()
        let readOnlyVM = ReadOnlyModeViewModel(permissionState: permissionState)

        // Then: isReadOnly 为 true
        XCTAssertTrue(readOnlyVM.isReadOnly,
            "ReadOnlyModeViewModel 应反映只读状态")
    }

    /// [P1] 授权后只读指示自动消失。
    ///
    /// AC4: 用户授权写入后，只读指示自动更新。
    func testReadOnlyBannerHidesAfterPermissionGranted() async throws {
        // Given: 只读模式
        let mockRepo = MockWriteGrantedRepository()
        let permissionState = PermissionState(repository: mockRepo)
        let readOnlyVM = ReadOnlyModeViewModel(permissionState: permissionState)

        XCTAssertTrue(readOnlyVM.isReadOnly, "初始应为只读模式")

        // When: 用户授权写入
        _ = try await permissionState.requestWritePermission()

        // Then: 只读指示消失
        XCTAssertFalse(readOnlyVM.isReadOnly,
            "授权后 ReadOnlyModeViewModel 应反映非只读状态")
    }

    // MARK: - AC5: 只读模式下保存结果供稍后执行

    /// [P0] 授权后保存的操作可重新执行。
    ///
    /// AC5: Given 用户下次授权写入后，
    /// When 选择重新执行保存的操作，
    /// Then 操作正常执行。
    func testSavedOperationsCanBeReexecutedAfterPermissionGranted() async throws {
        // Given: ReadOnlyModeViewModel
        let readOnlyVM = ReadOnlyModeViewModel()

        let operations = [
            PlannedOperation(
                operationType: .rename,
                assetID: AssetID(rawValue: "/photos/sunset.jpg"),
                parameters: .rename(newTitle: "golden_hour")
            ),
            PlannedOperation(
                operationType: .move,
                assetID: AssetID(rawValue: "/photos/beach.jpg"),
                parameters: .move(targetDirectory: "/photos/vacation")
            ),
        ]

        // When: 保存操作供稍后执行
        readOnlyVM.saveOperationsForLater(operations, summary: "重命名 1 张照片，移动 1 张照片")

        // Then: 操作被保存
        XCTAssertTrue(readOnlyVM.hasSavedOperations, "应有保存的操作")

        let savedOps = readOnlyVM.savedOperations
        XCTAssertEqual(savedOps.count, 1, "应保存 1 组操作")
        XCTAssertEqual(savedOps.first?.operations.count, 2, "该组应包含 2 个操作")
        XCTAssertEqual(savedOps.first?.summary, "重命名 1 张照片，移动 1 张照片")

        // And: 授权后可重新执行
        let mockManager = MockReadOnlyOperationManager()
        let savedSet = savedOps.first!
        try await readOnlyVM.executeSavedOperations(savedSet, operationManager: mockManager)

        XCTAssertTrue(mockManager.beginBatchCalled, "应调用 beginBatch 执行保存的操作")
        XCTAssertTrue(mockManager.executeBatchCalled, "应调用 executeBatch 执行保存的操作")
    }

    /// [P1] 保存的操作在应用重启后仍可加载。
    ///
    /// AC5: 操作通过 UserDefaults 持久化，跨应用会话保持。
    func testSavedOperationsPersistAcrossAppRestarts() async throws {
        // Use a unique key prefix to avoid interfering with other tests
        let readOnlyVM = ReadOnlyModeViewModel()

        let operations = [
            PlannedOperation(
                operationType: .rename,
                assetID: AssetID(rawValue: "/photos/sunset.jpg"),
                parameters: .rename(newTitle: "golden_hour")
            ),
        ]

        readOnlyVM.saveOperationsForLater(operations, summary: "重命名 1 张照片")

        // When: 创建新的 ReadOnlyModeViewModel 实例（模拟应用重启）
        let newReadOnlyVM = ReadOnlyModeViewModel()

        // Then: 保存的操作仍可加载
        XCTAssertTrue(newReadOnlyVM.hasSavedOperations, "重启后应仍有保存的操作")
        let loadedOps = newReadOnlyVM.savedOperations
        XCTAssertEqual(loadedOps.count, 1, "应加载 1 组操作")
        XCTAssertEqual(loadedOps.first?.operations.count, 1)
        XCTAssertEqual(loadedOps.first?.summary, "重命名 1 张照片")

        // Cleanup
        newReadOnlyVM.clearAllSavedOperations()
    }

    /// [P1] 删除保存的操作正确清除。
    ///
    /// AC5: 用户可删除保存的操作。
    func testDeleteSavedOperations() async throws {
        // Given: 保存了多组操作
        let readOnlyVM = ReadOnlyModeViewModel()

        let ops1 = [
            PlannedOperation(
                operationType: .rename,
                assetID: AssetID(rawValue: "/photos/a.jpg"),
                parameters: .rename(newTitle: "renamed_a")
            ),
        ]
        let ops2 = [
            PlannedOperation(
                operationType: .delete,
                assetID: AssetID(rawValue: "/photos/b.jpg"),
                parameters: .delete
            ),
        ]

        readOnlyVM.saveOperationsForLater(ops1, summary: "操作组 1")
        readOnlyVM.saveOperationsForLater(ops2, summary: "操作组 2")

        XCTAssertEqual(readOnlyVM.savedOperations.count, 2, "应有 2 组保存的操作")

        // When: 删除第一组操作
        let savedOps = readOnlyVM.savedOperations
        let firstSet = savedOps.first { $0.summary == "操作组 1" }!
        readOnlyVM.deleteSavedOperations(firstSet)

        // Then: 只剩一组操作
        let remaining = readOnlyVM.savedOperations
        XCTAssertEqual(remaining.count, 1, "应只剩 1 组操作")
        XCTAssertEqual(remaining.first?.summary, "操作组 2")

        // Cleanup
        readOnlyVM.clearAllSavedOperations()
    }

    /// [P1] 清除所有保存的操作。
    func testClearAllSavedOperations() async throws {
        // Given: 保存了多组操作
        let readOnlyVM = ReadOnlyModeViewModel()

        let ops = [
            PlannedOperation(
                operationType: .rename,
                assetID: AssetID(rawValue: "/photos/a.jpg"),
                parameters: .rename(newTitle: "renamed_a")
            ),
        ]

        readOnlyVM.saveOperationsForLater(ops, summary: "操作组 1")
        readOnlyVM.saveOperationsForLater(ops, summary: "操作组 2")
        XCTAssertTrue(readOnlyVM.hasSavedOperations)

        // When: 清除所有操作
        readOnlyVM.clearAllSavedOperations()

        // Then: 所有操作被清除
        XCTAssertFalse(readOnlyVM.hasSavedOperations, "应没有保存的操作")
        XCTAssertEqual(readOnlyVM.savedOperations.count, 0, "操作列表应为空")
    }

    // MARK: - PermissionState 只读模式单元测试

    /// [P0] PermissionState 初始为只读模式。
    func testPermissionStateStartsReadOnly() async throws {
        let permissionState = PermissionState()

        XCTAssertTrue(permissionState.isReadOnly, "初始状态应为只读模式")
        XCTAssertFalse(permissionState.hasWriteAccess, "初始状态不应有写权限")
    }

    /// [P0] PermissionState 授权后离开只读模式。
    func testPermissionStateExitsReadOnlyAfterGrant() async throws {
        let mockRepo = MockWriteGrantedRepository()
        let permissionState = PermissionState(repository: mockRepo)

        XCTAssertTrue(permissionState.isReadOnly, "初始应为只读")

        _ = try await permissionState.requestWritePermission()

        XCTAssertFalse(permissionState.isReadOnly, "授权后应为非只读")
        XCTAssertTrue(permissionState.hasWriteAccess, "授权后应有写权限")
    }

    /// [P0] PermissionState 撤销权限后回到只读模式。
    func testPermissionStateReturnsToReadOnlyAfterRevoke() async throws {
        let mockRepo = MockWriteGrantedRepository()
        let permissionState = PermissionState(repository: mockRepo)

        _ = try await permissionState.requestWritePermission()
        XCTAssertFalse(permissionState.isReadOnly, "授权后应为非只读")

        permissionState.revokeWriteAccess()

        XCTAssertTrue(permissionState.isReadOnly, "撤销后应为只读模式")
        XCTAssertFalse(permissionState.hasWriteAccess, "撤销后不应有写权限")
    }

    // MARK: - SavedOperationSet 序列化测试

    /// [P1] SavedOperationSet 正确编码和解码。
    func testSavedOperationSetCodable() async throws {
        // Given: 一个 SavedOperationSet
        let operations = [
            PlannedOperation(
                operationType: .rename,
                assetID: AssetID(rawValue: "/photos/sunset.jpg"),
                parameters: .rename(newTitle: "golden_hour")
            ),
            PlannedOperation(
                operationType: .move,
                assetID: AssetID(rawValue: "/photos/beach.jpg"),
                parameters: .move(targetDirectory: "/photos/vacation")
            ),
        ]

        let savedSet = SavedOperationSet(
            operations: operations,
            summary: "重命名和移动操作"
        )

        // When: 编码和解码
        let encoder = JSONEncoder()
        let data = try encoder.encode(savedSet)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(SavedOperationSet.self, from: data)

        // Then: 数据保持一致
        XCTAssertEqual(decoded.summary, savedSet.summary)
        XCTAssertEqual(decoded.operations.count, savedSet.operations.count)
        XCTAssertEqual(decoded.operations, savedSet.operations)
    }

    /// [P1] PlannedOperation 正确支持 Codable（前置条件验证）。
    func testPlannedOperationCodable() async throws {
        // Given: 各种类型的 PlannedOperation
        let operations = [
            PlannedOperation(
                operationType: .rename,
                assetID: AssetID(rawValue: "/photos/a.jpg"),
                parameters: .rename(newTitle: "new_name")
            ),
            PlannedOperation(
                operationType: .delete,
                assetID: AssetID(rawValue: "/photos/b.jpg"),
                parameters: .delete
            ),
            PlannedOperation(
                operationType: .move,
                assetID: AssetID(rawValue: "/photos/c.jpg"),
                parameters: .move(targetDirectory: "/photos/target")
            ),
            PlannedOperation(
                operationType: .metadataChange,
                assetID: AssetID(rawValue: "/photos/d.jpg"),
                parameters: .metadataChange
            ),
        ]

        // When: 编码和解码
        let encoder = JSONEncoder()
        let data = try encoder.encode(operations)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode([PlannedOperation].self, from: data)

        // Then: 所有操作正确往返
        XCTAssertEqual(decoded.count, operations.count)
        for (index, decodedOp) in decoded.enumerated() {
            XCTAssertEqual(decodedOp, operations[index],
                "操作 \(index) 应在编码/解码后保持一致")
        }
    }

    // MARK: - AgentStep isWriteOperation Tests

    /// [P1] AgentStep correctly identifies write operations by title.
    func testAgentStepWriteOperationDetection() async throws {
        // Write operation steps
        let renameStep = AgentStep(id: UUID(), title: "Rename Files", status: .pending,
                                   completedCount: 0, totalCount: 0, reasoningMessages: [])
        XCTAssertTrue(renameStep.isWriteOperation, "重命名步骤应为写操作")

        let deleteStep = AgentStep(id: UUID(), title: "Delete Duplicates", status: .pending,
                                   completedCount: 0, totalCount: 0, reasoningMessages: [])
        XCTAssertTrue(deleteStep.isWriteOperation, "删除步骤应为写操作")

        let moveStep = AgentStep(id: UUID(), title: "Move to Album", status: .pending,
                                 completedCount: 0, totalCount: 0, reasoningMessages: [])
        XCTAssertTrue(moveStep.isWriteOperation, "移动步骤应为写操作")

        // Read-only steps
        let scanStep = AgentStep(id: UUID(), title: "Scan Library", status: .pending,
                                 completedCount: 0, totalCount: 0, reasoningMessages: [])
        XCTAssertFalse(scanStep.isWriteOperation, "扫描步骤不应为写操作")

        let analyzeStep = AgentStep(id: UUID(), title: "Analyze Photos", status: .pending,
                                    completedCount: 0, totalCount: 0, reasoningMessages: [])
        XCTAssertFalse(analyzeStep.isWriteOperation, "分析步骤不应为写操作")
    }

    /// [P1] Chinese keywords in step titles are detected as write operations.
    func testAgentStepChineseWriteOperationDetection() async throws {
        let renameStep = AgentStep(id: UUID(), title: "重命名照片", status: .pending,
                                   completedCount: 0, totalCount: 0, reasoningMessages: [])
        XCTAssertTrue(renameStep.isWriteOperation, "中文重命名步骤应为写操作")

        let deleteStep = AgentStep(id: UUID(), title: "删除重复照片", status: .pending,
                                   completedCount: 0, totalCount: 0, reasoningMessages: [])
        XCTAssertTrue(deleteStep.isWriteOperation, "中文删除步骤应为写操作")

        let moveStep = AgentStep(id: UUID(), title: "移动到文件夹", status: .pending,
                                 completedCount: 0, totalCount: 0, reasoningMessages: [])
        XCTAssertTrue(moveStep.isWriteOperation, "中文移动步骤应为写操作")
    }
}

// MARK: - Mock: Read-Only Bookmark Manager

/// Mock FolderBookmarkManaging that always reports no write access.
/// Used to simulate read-only mode without real file system operations.
private struct MockReadOnlyBookmarkManager: FolderBookmarkManaging, Sendable {
    let hasValidBookmarkValue: Bool

    init(hasValidBookmark: Bool = true) {
        self.hasValidBookmarkValue = hasValidBookmark
    }

    var hasValidBookmark: Bool { hasValidBookmarkValue }

    var currentFolderURL: URL? { nil }

    var hasWriteAccess: Bool { false }

    func selectAndBookmarkFolder() async throws -> URL {
        URL(fileURLWithPath: "/tmp/CuratorTestFolder")
    }

    func loadBookmark() async throws -> URL? { nil }

    func accessBookmark(_ url: URL) -> Bool { true }

    func releaseBookmark(_ url: URL) {}

    func grantWriteAccess() async {}

    func revokeWriteAccess() async {}

    func requestWriteConsent() async -> Bool { false }
}

// MARK: - Mock: OperationManager for Read-Only Tests

/// Mock OperationManaging that tracks calls for read-only mode tests.
private final class MockReadOnlyOperationManager: OperationManaging, @unchecked Sendable {

    private let queue = DispatchQueue(label: "MockReadOnlyOpManager")

    private var _beginBatchCalled = false
    private var _executeBatchCalled = false
    private var _lastOperations: [PlannedOperation]?

    var beginBatchCalled: Bool { queue.sync { _beginBatchCalled } }
    var executeBatchCalled: Bool { queue.sync { _executeBatchCalled } }
    var lastOperations: [PlannedOperation]? { queue.sync { _lastOperations } }

    func beginBatch(operations: [PlannedOperation], repository: PhotoLibraryRepository) async throws -> OperationManaging.BatchID {
        queue.sync {
            _beginBatchCalled = true
            _lastOperations = operations
        }
        return UUID()
    }

    func executeBatch(_ batchID: OperationManaging.BatchID, repository: PhotoLibraryRepository) async throws {
        queue.sync {
            _executeBatchCalled = true
        }
    }

    func rollbackBatch(_ batchID: OperationManaging.BatchID, repository: PhotoLibraryRepository) async throws {}

    func rollbackLastBatch(repository: PhotoLibraryRepository) async throws {}

    func detectIncompleteBatches() async throws -> [BatchOperation] { [] }

    func getBatchHistory(limit: Int) async throws -> [BatchOperation] { [] }

    func reexecuteLastRolledBackBatch(repository: PhotoLibraryRepository) async throws {}
}

// MARK: - Mock: Write-Granted Repository

/// Mock repository that always grants write access, used for tests
/// that need permissionState.hasWriteAccess == true.
private struct MockWriteGrantedRepository: PhotoLibraryRepository, Sendable {
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
