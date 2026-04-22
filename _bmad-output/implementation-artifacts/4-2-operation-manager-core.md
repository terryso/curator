# Story 4.2: 操作管理器核心

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a 系统，
I want 在每次批量操作前创建元数据快照，
So that 所有修改都可以安全回滚。

## Acceptance Criteria

1. **AC1: OperationManager actor 实现（FR35）**
   **Given** OperationManager actor 已实现
   **When** 调用 `beginBatch(operations:)`
   **Then** 为每个受影响的资产创建 OperationSnapshot（操作前元数据）
   **And** 快照持久化到 SwiftData

2. **AC2: OperationSnapshot 模型定义**
   **Given** OperationSnapshot 模型已定义
   **When** 检查字段
   **Then** 包含 id、timestamp、operationType（.rename/.delete/.move/.metadataChange）、assetID、beforeState
   **And** BatchOperation 模型关联多个 OperationSnapshot

3. **AC3: 批量操作执行与记录（FR38, NFR15）**
   **Given** 批量操作执行完成
   **When** 检查操作记录
   **Then** 原始图像文件未被修改，仅操作文件名、目录结构和元数据
   **And** NFR15（零文件损坏）得到保证

4. **AC4: 批量操作中途失败自动回滚（FR36）**
   **Given** 批量操作执行中途某项失败
   **When** OperationManager 检测到失败
   **Then** 自动回滚已完成的操作项
   **And** 向上层报告失败原因

5. **AC5: 操作日志持久化（NFR17）**
   **Given** 应用意外崩溃
   **When** 重新启动
   **Then** 未完成的批量操作通过持久化快照被检测到
   **And** 可查询所有历史操作记录

## Tasks / Subtasks

- [x] Task 1: 定义操作相关领域模型 (AC: #2)
  - [x] 1.1 创建 `Curator/Core/Operations/OperationType.swift` — 枚举：`.rename`、`.delete`、`.move`、`.metadataChange`，标记 `Sendable`、`Codable`
  - [x] 1.2 创建 `Curator/Core/Operations/OperationSnapshot.swift` — 值类型 struct：`id: UUID`、`timestamp: Date`、`operationType: OperationType`、`assetID: AssetID`、`beforeState: AssetMetadata`，标记 `Sendable`、`Codable`
  - [x] 1.3 创建 `Curator/Core/Operations/BatchOperation.swift` — 值类型 struct：`id: UUID`、`createdAt: Date`、`snapshots: [OperationSnapshot]`、`status: BatchStatus`（.pending/.executing/.completed/.failed/.rolledBack），标记 `Sendable`、`Codable`
  - [x] 1.4 创建 `Curator/Core/Operations/BatchStatus.swift` — 枚举：`.pending`、`.executing`、`.completed`、`.failed`、`.rolledBack`，标记 `Sendable`、`Codable`
  - [x] 1.5 创建 `Curator/Core/Operations/PlannedOperation.swift` — 值类型 struct：描述一个待执行操作（类型 + 目标资产 + 参数），用于 `beginBatch` 输入

- [x] Task 2: 创建 SwiftData 持久化实体 (AC: #1, #5)
  - [x] 2.1 在 `Curator/Infrastructure/Storage/SwiftDataModels.swift` 添加 `OperationSnapshotEntity` — `@Model` 类，字段对应 OperationSnapshot 值类型
  - [x] 2.2 在 `Curator/Infrastructure/Storage/SwiftDataModels.swift` 添加 `BatchOperationEntity` — `@Model` 类，关联 `[OperationSnapshotEntity]`，记录状态和时间戳
  - [x] 2.3 更新 `SwiftDataManager` — Schema 中添加 `OperationSnapshotEntity.self` 和 `BatchOperationEntity.self`

- [x] Task 3: 实现 OperationManager actor (AC: #1, #3, #4)
  - [x] 3.1 创建 `Curator/Core/Operations/OperationManaging.swift` — 协议定义：`beginBatch`、`executeBatch`、`rollbackBatch`、`rollbackLastBatch`、`getBatchHistory`
  - [x] 3.2 创建 `Curator/Core/Operations/OperationManager.swift` — actor 实现 `OperationManaging` 协议
  - [x] 3.3 实现 `beginBatch(operations:)` — 为每个操作创建快照（读取当前 AssetMetadata），持久化到 SwiftData，返回 `BatchID`
  - [x] 3.4 实现 `executeBatch(_:repository:)` — 逐步执行操作，成功后更新快照状态，失败时触发自动回滚
  - [x] 3.5 实现 `rollbackBatch(_:)` — 遍历快照还原每个资产的操作前状态（反向操作：rename 回原名、从垃圾桶恢复、move 回原目录）
  - [x] 3.6 实现 `rollbackLastBatch()` — 查询最近一个 completed 状态的批次并执行回滚（为 Story 4.3 ⌘Z 撤销准备）
  - [x] 3.7 实现 `detectIncompleteBatches()` — 查询 SwiftData 中 status 为 .executing 的批次（NFR17 崩溃恢复检测）
  - [x] 3.8 注入 `PhotoLibraryRepository` 协议 — executeBatch 和 rollbackBatch 通过协议调用实际文件操作，不直接依赖 LocalFolderRepository

- [x] Task 4: 注册 OperationManager 到依赖注入 (AC: #1)
  - [x] 4.1 在 `AppDependencies` 添加 `operationManager: (any OperationManaging)?` 属性
  - [x] 4.2 在 `registerLLMGateway()` 中创建并注册 OperationManager（注入 SwiftData ModelContext）

- [x] Task 5: ATDD 测试 (AC: #1, #2, #3, #4, #5)
  - [x] 5.1 创建 `CuratorTests/Core/Operations/OperationManagerTests.swift`
  - [x] 5.2 [P0] testBeginBatchCreatesSnapshots — 验证 beginBatch 为每个操作创建 OperationSnapshot
  - [x] 5.3 [P0] testSnapshotContainsBeforeState — 验证快照包含操作前元数据（文件名、路径等）
  - [x] 5.4 [P0] testExecuteBatchUpdatesAssetNames — 验证批量重命名执行成功
  - [x] 5.5 [P0] testExecuteBatchOriginalImagesNotModified — 验证原始图像文件像素数据未被修改（NFR15）
  - [x] 5.6 [P0] testPartialFailureAutoRollback — 批量执行中途失败时自动回滚已完成项
  - [x] 5.7 [P1] testSnapshotsPersistToSwiftData — 验证快照持久化到 SwiftData，可重新查询
  - [x] 5.8 [P1] testDetectIncompleteBatches — 检测未完成批次（NFR17 崩溃恢复场景）
  - [x] 5.9 [P1] testRollbackBatchRestoresOriginalState — 验证回滚恢复到操作前状态
  - [x] 5.10 [P1] testRollbackLastBatch — 验证撤销最近一个完成的批次
  - [x] 5.11 构建通过 + 全部现有测试通过

## Dev Notes

### 架构约束

1. **分层边界严格**：`OperationManaging` 协议在 `Core/Operations/`（Domain 层），`OperationManager` actor 实现也在 `Core/Operations/`（Application 层）。SwiftData 实体在 `Infrastructure/Storage/`。[Source: architecture.md#分层架构]
2. **Actor 隔离**：OperationManager 必须为 actor，所有状态变更串行化。executeBatch 和 rollbackBatch 内的文件操作通过注入的 `PhotoLibraryRepository` 协议调用。[Source: architecture.md#决策7]
3. **Swift 6 strict concurrency**：所有新增类型标注 `Sendable`。值类型用 struct。[Source: project-context.md#Critical Implementation Rules]
4. **三层错误链路**：InfrastructureError → DomainError → UserFacingError，不可跳层。[Source: project-context.md#三层错误体系]
5. **禁止使用 `Task` 作为类型名**。[Source: CLAUDE.md]
6. **SwiftUI 视图不超过 200 行**（本 Story 不涉及 UI）。[Source: project-context.md#SwiftUI 视图模式]
7. **协议在 Domain 层定义**：`OperationManaging` 协议在 Core/Operations/，实现在同一模块的 OperationManager actor。[Source: project-context.md#Architecture Boundaries]

### 前置 Story 上下文

**Story 4.1 已完成的核心类型（本 Story 需复用）：**

- `LocalFolderRepository` (actor) — 已实现 `updateAsset(_:title:)`（重命名）、`deleteAssets(_:)`（移到垃圾桶）、`moveAssets(_:to:)`（移动到子目录）。本 Story 的 OperationManager 将在这些操作外层包装快照和回滚逻辑
- `PhotoLibraryRepository` 协议 — 已定义 `updateAsset`、`deleteAssets`、`moveAssets`。OperationManager 通过此协议调用文件操作
- `PermissionState` (@Observable @MainActor) — 管理读写权限状态。本 Story 不需修改
- `FolderBookmarkManager` — 已实现 `hasWriteAccess`、`grantWriteAccess()`。本 Story 不需修改
- `DomainError.insufficientPermission(required: PermissionLevel)` — 写操作无权限时抛出
- `DomainError.invalidState(reason:)` — 文件名冲突等状态错误
- `InfrastructureError.fileWriteFailed(path:reason:)` — 文件写操作失败
- `InfrastructureError.fileNotFound(path:)` — 文件未找到
- `AppDependencies` — 依赖注入容器，需注册 OperationManager
- `SwiftDataManager` — 管理 ModelContainer，当前 Schema 包含 `CostRecordEntity` 和 `SessionEntity`
- `SwiftDataModels.swift` — SwiftData `@Model` 实体，当前含 `CostRecordEntity`。本 Story 需添加 `OperationSnapshotEntity` 和 `BatchOperationEntity`

**Epic 1-3 已建立的模式：**

- 值类型 struct + Sendable 模式（PhotoAsset、AssetMetadata、AssetID 等）
- SwiftData @Model 实体模式（参考 CostRecordEntity）
- Actor 隔离模式（LocalFolderRepository、LLMGateway）
- 三层错误映射模式
- Mock 模式（测试文件内 private struct 实现协议）

### OperationManager 设计细节

**核心 API：**

```swift
/// 协议定义 — Core/Operations/OperationManaging.swift
protocol OperationManaging: Sendable {
    typealias BatchID = UUID

    /// 创建批量操作批次（创建快照，不执行）
    func beginBatch(operations: [PlannedOperation]) async throws -> BatchID

    /// 执行指定批次（通过 repository 执行实际文件操作）
    func executeBatch(_ batchID: BatchID, repository: PhotoLibraryRepository) async throws

    /// 回滚指定批次（恢复到操作前状态）
    func rollbackBatch(_ batchID: BatchID) async throws

    /// 回滚最近一个已完成的批次（⌘Z 撤销，Story 4.3 使用）
    func rollbackLastBatch() async throws

    /// 检测未完成的批次（NFR17 崩溃恢复）
    func detectIncompleteBatches() async throws -> [BatchOperation]

    /// 查询操作历史
    func getBatchHistory(limit: Int) async throws -> [BatchOperation]
}
```

**PlannedOperation 设计：**

```swift
struct PlannedOperation: Sendable, Codable {
    let operationType: OperationType
    let assetID: AssetID
    let parameters: OperationParameters
}

// 操作参数根据类型不同
enum OperationParameters: Sendable, Codable {
    case rename(newTitle: String)
    case delete
    case move(targetDirectory: String)
    case metadataChange
}
```

**快照创建流程（beginBatch）：**

1. 接收 `[PlannedOperation]`
2. 对每个 PlannedOperation，从 repository 获取当前 `AssetMetadata` 作为 `beforeState`
3. 创建 `OperationSnapshot`（id、timestamp、operationType、assetID、beforeState）
4. 创建 `BatchOperation`（关联所有 snapshots，status = .pending）
5. 持久化到 SwiftData
6. 返回 `BatchID`

**批量执行流程（executeBatch）：**

1. 从 SwiftData 加载 BatchOperation 及其 Snapshots
2. 更新 status = .executing
3. 逐个执行操作：
   - `.rename` → `repository.updateAsset(assetID, title: newTitle)`
   - `.delete` → `repository.deleteAssets([assetID])`
   - `.move` → `repository.moveAssets([assetID], to: directory)`
4. 每个操作成功后标记对应 snapshot 为已完成
5. 全部成功 → status = .completed
6. 任一失败 → 自动回滚已完成的操作 → status = .failed

**回滚逻辑（rollbackBatch）：**

反向执行每个已完成的 snapshot：
- `.rename` → 用 beforeState.fileName 重命名回去
- `.delete` → 注意：trashItem 后的恢复需要 `FileManager.default.moveItem` 从垃圾桶 URL 移回。trashItem 返回的 `resultingItemURL` 需要在 snapshot 中记录（或在 beforeState 中记录原始路径，从垃圾桶按名称匹配恢复）
- `.move` → 移回原始目录

**关键设计决策：delete 回滚限制**

`FileManager.default.trashItem` 返回的 resultingItemURL 是垃圾桶中的路径，不保证稳定。两种策略：

- **方案 A（推荐）**：在 snapshot 的 beforeState 中记录文件的完整路径。回滚时，从垃圾桶目录中按文件名查找匹配项并移回。macOS 垃圾桶路径为 `~/.Trash/`
- **方案 B**：在 snapshot 中额外记录 trashResultURL。但这需要 trashItem 的 resultingItemURL 持久化，且用户可能在 Finder 中清空垃圾桶

建议采用方案 A，并在回滚失败时抛出 `DomainError.invalidState(reason: "无法从垃圾桶恢复文件")`。

### SwiftData 实体设计

**OperationSnapshotEntity：**

```swift
@Model
final class OperationSnapshotEntity {
    @Attribute(.unique) var id: UUID
    var timestamp: Date
    var operationType: String  // OperationType raw value
    var assetID: String        // AssetID rawValue
    var beforeStateFileName: String
    var beforeStateFilePath: String  // 完整路径，用于回滚定位
    var beforeStateFileSize: Int64?
    var beforeStateCreationDate: Date?
    var isExecuted: Bool       // 是否已执行
    var isRolledBack: Bool     // 是否已回滚

    var batch: BatchOperationEntity?  // 关联所属批次
}
```

**BatchOperationEntity：**

```swift
@Model
final class BatchOperationEntity {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var completedAt: Date?
    var status: String         // BatchStatus raw value

    @Relationship(deleteRule: .cascade)
    var snapshots: [OperationSnapshotEntity] = []
}
```

### 与 Story 4.1 的集成

OperationManager 在写操作外层包装，不修改 LocalFolderRepository 本身：

```
用户请求批量操作
    → OperationManager.beginBatch(operations:)     // 创建快照
    → OperationManager.executeBatch(id, repo)       // 执行
        → repo.updateAsset / deleteAssets / moveAssets  // Story 4.1 的实现
    → 成功：status = .completed
    → 失败：自动回滚 → status = .failed
```

OperationManager 通过注入的 `PhotoLibraryRepository` 协议调用写操作，不直接依赖 LocalFolderRepository。

### 不做什么（范围边界）

以下内容在本 Story 中 **不实现**：

- **⌘Z 键盘快捷键绑定** — Story 4.3 实现
- **操作确认工作流 UI（Story 4.4）** — 破坏性操作的二次确认界面
- **只读模式保障（Story 4.5）** — 更深层的只读模式验证
- **SDK Tools 集成** — 去重/重命名工具通过 OperationManager 执行（Epic 5/6 时集成）
- **FileSystemWatcher 集成（Story 7.1）** — 文件变更监控
- **回滚进度 UI** — 回滚操作的 UI 展示（Story 4.3）

### 技术要求

- **Swift 6 strict concurrency**：所有新增类型标注 `Sendable`。OperationManager 为 actor
- **不引入新第三方依赖** — 仅使用 SwiftUI + Foundation + SwiftData
- **构建通过**：`xcodebuild build` 必须成功
- **无回归**：全部现有测试必须仍然通过
- **xcodegen 自动发现**：新增文件通过 project.yml 的 `sources: - Curator` 配置自动发现

### 项目结构说明

本 Story 新增的文件：

```
Curator/
├── Core/Operations/
│   ├── OperationType.swift                 # 新建：操作类型枚举
│   ├── OperationSnapshot.swift             # 新建：操作快照值类型
│   ├── BatchOperation.swift                # 新建：批量操作值类型
│   ├── BatchStatus.swift                   # 新建：批次状态枚举
│   ├── PlannedOperation.swift              # 新建：待执行操作描述
│   ├── OperationManaging.swift             # 新建：操作管理协议
│   └── OperationManager.swift              # 新建：操作管理器 actor 实现
```

修改的文件：

```
Curator/
├── Infrastructure/Storage/SwiftDataModels.swift   # 修改：添加 OperationSnapshotEntity、BatchOperationEntity
├── Infrastructure/Storage/SwiftDataManager.swift   # 修改：Schema 添加新实体
├── App/AppDependencies.swift                       # 修改：注册 OperationManager
```

测试文件：

```
CuratorTests/
├── Core/Operations/OperationManagerTests.swift    # 新建：操作管理器测试
```

### NFR 关注点

- **NFR15（零文件损坏）**：OperationManager 仅通过 PhotoLibraryRepository 协议调用 updateAsset/deleteAssets/moveAssets。这些方法在 Story 4.1 中已实现为 rename/trashItem/moveItem，绝不写入图像像素数据
- **NFR16（5 秒回滚）**：rollbackBatch 应在 5 秒内完成。快照数据从 SwiftData 加载后直接执行反向操作，无需重新计算。对于大批量（100+ 项），需要关注文件系统操作耗时
- **NFR17（崩溃恢复）**：批次状态为 .executing 时表示应用在执行中途崩溃。`detectIncompleteBatches()` 返回这些批次供上层（Story 4.3/4.5）提示用户是否回滚
- **NFR6（500MB 内存）**：快照数据仅含元数据（文件名、路径、日期），不包含图像数据，内存占用极小

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 4.2] — 原始需求定义（操作管理器核心）
- [Source: _bmad-output/planning-artifacts/architecture.md#决策7] — 操作回滚系统设计（快照 + 操作日志模式）
- [Source: _bmad-output/planning-artifacts/architecture.md#Core/Operations/] — OperationManager、OperationSnapshot、BatchOperation 目录规划
- [Source: _bmad-output/planning-artifacts/architecture.md#决策5] — 数据持久化（SwiftData）
- [Source: _bmad-output/planning-artifacts/architecture.md#决策9] — 错误处理模式
- [Source: _bmad-output/planning-artifacts/architecture.md#跨切关注点] — 操作可逆性贯穿所有写操作
- [Source: _bmad-output/planning-artifacts/prd.md#FR35] — 批量修改前创建元数据快照
- [Source: _bmad-output/planning-artifacts/prd.md#FR36] — 批量操作中途失败自动回滚
- [Source: _bmad-output/planning-artifacts/prd.md#FR38] — 绝不修改原始图像文件
- [Source: _bmad-output/planning-artifacts/prd.md#NFR15] — 零文件损坏容忍
- [Source: _bmad-output/planning-artifacts/prd.md#NFR16] — 5 秒内完成回滚
- [Source: _bmad-output/planning-artifacts/prd.md#NFR17] — 崩溃恢复
- [Source: _bmad-output/implementation-artifacts/4-1-write-permission-progressive.md] — 前一 Story 的实现记录
- [Source: _bmad-output/project-context.md#Critical Implementation Rules] — Swift 6 严格并发、actor 隔离、三层错误体系
- [Source: _bmad-output/project-context.md#Architecture Boundaries] — Core/Operations/ 目录映射
- [Source: _bmad-output/project-context.md#Testing Rules] — ATDD 风格、Mock 模式
- [Source: Curator/Core/Models/AssetMetadata.swift] — AssetMetadata 值类型（快照 beforeState）
- [Source: Curator/Core/Models/AssetID.swift] — AssetID 值类型
- [Source: Curator/Core/Models/PhotoLibraryRepository.swift] — Repository 协议（含写操作方法签名）
- [Source: Curator/Core/Errors/DomainError.swift] — DomainError 定义
- [Source: Curator/Core/Errors/InfrastructureError.swift] — InfrastructureError 定义
- [Source: Curator/Infrastructure/PhotoSource/LocalFolderRepository.swift] — 写操作实现（updateAsset/deleteAssets/moveAssets）
- [Source: Curator/Infrastructure/Storage/SwiftDataModels.swift] — SwiftData @Model 实体模式参考
- [Source: Curator/Infrastructure/Storage/SwiftDataManager.swift] — ModelContainer 和 Schema 管理
- [Source: Curator/App/AppDependencies.swift] — 依赖注入容器

### 与后续 Story 的关系

**本 Story（4.2）是 Epic 4 的中间层基础：**

- **Story 4.3（批量回滚与撤销）** — 将在本 Story 的 rollbackBatch/rollbackLastBatch 基础上添加 ⌘Z 快捷键绑定、回滚进度 UI、崩溃恢复提示
- **Story 4.4（操作确认工作流 UI）** — 将使用本 Story 的 beginBatch + executeBatch 包装完整的确认流程
- **Story 4.5（只读模式保障）** — 将在写操作路径上添加 OperationManager 集成检查
- **Epic 5（去重）** — DeleteAssetsTool 将通过 OperationManager.beginBatch + executeBatch 包装删除操作
- **Epic 6（重命名）** — RenameAssetsTool 将通过 OperationManager 包装重命名操作

## Dev Agent Record

### Agent Model Used

GLM-5.1

### Debug Log References

- Swift 6 strict concurrency: ModelContext is not Sendable. Used `nonisolated(unsafe)` on OperationManager.modelContext property and `@unchecked Sendable` TestModelContext wrapper in tests.
- `#Predicate` with enum raw values: Cannot reference enum cases directly in #Predicate macros. Used local String constants instead.
- OperationSnapshot Codable: AssetMetadata is not Codable, so implemented manual Codable conformance with flat key encoding.

### Completion Notes List

- All 5 tasks completed with all subtasks checked
- 26 ATDD tests implemented, all passing (0 failures)
- Full regression suite: 597 tests, 0 failures
- Task 4.2: Registered OperationManager in registerLLMGateway() instead of registerLocalFolderRepository() because SwiftDataManager is initialized there (the registerLocalFolderRepository method does not create a SwiftDataManager)
- OperationManager uses `nonisolated(unsafe)` for ModelContext to satisfy Swift 6 strict concurrency while maintaining actor isolation
- Auto-rollback in executeBatch uses direct FileManager operations (not repository) for file-level rollback consistency

### File List

New files:
- Curator/Core/Operations/OperationType.swift
- Curator/Core/Operations/OperationSnapshot.swift
- Curator/Core/Operations/BatchOperation.swift
- Curator/Core/Operations/BatchStatus.swift
- Curator/Core/Operations/PlannedOperation.swift
- Curator/Core/Operations/OperationManaging.swift
- Curator/Core/Operations/OperationManager.swift
- CuratorTests/Core/Operations/OperationManagerTests.swift

Modified files:
- Curator/Infrastructure/Storage/SwiftDataModels.swift (added OperationSnapshotEntity, BatchOperationEntity)
- Curator/Infrastructure/Storage/SwiftDataManager.swift (added entities to Schema)
- Curator/App/AppDependencies.swift (added operationManager property and registration)
