# Story 4.3: 批量回滚与撤销系统

Status: done

## Story

As a 用户，
I want 随时撤销任何批量操作，
So that 我知道即使犯错也能恢复。

## Acceptance Criteria

1. **AC1: 用户触发的批量操作撤销（FR34, NFR16）**
   **Given** 批量操作已完成
   **When** 用户按 ⌘Z 或点击撤销按钮
   **Then** `OperationManager.rollbackLastBatch()` 执行，5 秒内完成
   **And** 所有受影响资产恢复到操作前的元数据状态

2. **AC2: 批量操作中途失败自动回滚（FR36）**
   **Given** 批量操作执行中途某个操作项失败
   **When** OperationManager 检测到失败
   **Then** 自动回滚已完成的操作项
   **And** 向用户报告失败原因

3. **AC3: 回滚操作可撤销（双向撤销）**
   **Given** 用户执行了回滚操作
   **When** 再次按 ⌘Z
   **Then** 回滚操作本身也可撤销（恢复到回滚前状态）
   **And** 操作日志记录所有变更

4. **AC4: 崩溃恢复提示（NFR17）**
   **Given** 应用意外崩溃
   **When** 重新启动
   **Then** 未完成的批量操作通过持久化快照被检测到
   **And** 提示用户是否回滚未完成的操作

## Tasks / Subtasks

- [x] Task 1: 实现 ⌘Z 键盘快捷键绑定 (AC: #1)
  - [x] 1.1 在 `MainWorkspaceView` 中注册 `⌘Z` 键盘快捷键，绑定到撤销操作
  - [x] 1.2 创建 `UndoManagerViewModel`（@MainActor）管理撤销队列和 UI 状态
  - [x] 1.3 通过 `AppDependencies.operationManager` 调用 `rollbackLastBatch(repository:)`
  - [x] 1.4 确保无已完成批次时 ⌘Z 不触发任何操作（静默忽略）

- [x] Task 2: 实现撤销按钮 UI (AC: #1)
  - [x] 2.1 在 `MainWorkspaceView` 工具栏或执行面板底部添加撤销按钮（仅在存在可撤销操作时可见）
  - [x] 2.2 按钮点击触发与 ⌘Z 相同的 `rollbackLastBatch` 调用
  - [x] 2.3 撤销操作进行中展示进度指示器（ProgressView）

- [x] Task 3: 实现回滚进度 UI 与结果反馈 (AC: #1, #2)
  - [x] 3.1 创建 `RollbackProgressView` — 展示回滚进度（当前/总数）
  - [x] 3.2 回滚完成后展示成功/失败结果摘要（内联消息或 Sheet）
  - [x] 3.3 回滚失败时展示错误信息和重试选项

- [x] Task 4: 实现双向撤销 — 回滚本身可撤销 (AC: #3)
  - [x] 4.1 在 `OperationManager` 中实现 `reexecuteLastRolledBackBatch(repository:)` 方法
  - [x] 4.2 当批次被回滚后，记录反向操作（"重做"快照）
  - [x] 4.3 ⌘Z 在回滚后再次按下时执行重做（恢复到回滚前状态）
  - [x] 4.4 在 `OperationManaging` 协议中添加 `reexecuteLastRolledBackBatch` 方法签名

- [x] Task 5: 实现崩溃恢复检测与提示 (AC: #4)
  - [x] 5.1 在应用启动时调用 `detectIncompleteBatches()` 检测未完成批次
  - [x] 5.2 检测到未完成批次时弹出恢复提示 Sheet（说明发现未完成操作）
  - [x] 5.3 用户选择回滚时调用 `rollbackBatch(_:repository:)`
  - [x] 5.4 用户选择忽略时标记批次为 `.failed` 状态

- [x] Task 6: ATDD 测试 (AC: #1, #2, #3, #4)
  - [x] 6.1 创建 `CuratorTests/Core/Operations/BatchRollbackUndoTests.swift`
  - [x] 6.2 [P0] testRollbackLastBatchViaCommandZ — 验证 ⌘Z 触发 rollbackLastBatch 成功恢复
  - [x] 6.3 [P0] testRollbackCompletesWithin5Seconds — 验证回滚在 5 秒内完成（NFR16）
  - [x] 6.4 [P0] testPartialFailureAutoRollback — 批量执行中途失败时自动回滚已完成项
  - [x] 6.5 [P0] testRedoAfterUndo — 回滚后再次 ⌘Z 可重做（恢复回滚前状态）
  - [x] 6.6 [P0] testDetectIncompleteBatchesOnStartup — 启动时检测到未完成批次
  - [x] 6.7 [P1] testNoCompletedBatchSilentlyIgnored — 无可撤销批次时 ⌘Z 静默忽略
  - [x] 6.8 [P1] testOperationLogRecordsRollback — 操作日志记录回滚事件
  - [x] 6.9 [P1] testCrashRecoveryPromptShown — 崩溃恢复提示在检测到未完成批次时显示
  - [x] 6.10 构建通过 + 全部现有测试通过

## Dev Notes

### 架构约束

1. **分层边界严格**：`OperationManaging` 协议在 `Core/Operations/`，UI 在 `Features/`。ViewModel 用 `@MainActor`，不直接调用 Infrastructure。[Source: architecture.md#分层架构]
2. **Actor 隔离**：OperationManager 是 actor，所有状态变更串行化。UI 层通过 async/await 调用，不直接接触 actor 内部状态。[Source: architecture.md#决策7]
3. **Swift 6 strict concurrency**：所有新增类型标注 `Sendable`。值类型用 struct。ViewModel 标注 `@MainActor`。[Source: project-context.md#Critical Implementation Rules]
4. **三层错误链路**：InfrastructureError → DomainError → UserFacingError，不可跳层。[Source: project-context.md#三层错误体系]
5. **禁止使用 `Task` 作为类型名**。[Source: CLAUDE.md]
6. **SwiftUI 视图不超过 200 行**。复杂视图拆分子视图。[Source: project-context.md#SwiftUI 视图模式]
7. **协议在 Domain 层定义**：新增的 `reexecuteLastRolledBackBatch` 方法加在 `OperationManaging` 协议中。[Source: project-context.md#Architecture Boundaries]

### 前置 Story 上下文

**Story 4.2 已完成的核心实现（本 Story 在此基础上构建）：**

- `OperationManager` (actor) — 已实现 `beginBatch`、`executeBatch`、`rollbackBatch`、`rollbackLastBatch`、`detectIncompleteBatches`、`getBatchHistory`
- `OperationManaging` 协议 — 已定义完整 API，本 Story 需扩展 `reexecuteLastRolledBackBatch`
- `OperationSnapshot` / `BatchOperation` / `BatchStatus` / `PlannedOperation` / `OperationType` — 值类型模型已完整定义
- SwiftData 持久化实体 `OperationSnapshotEntity` / `BatchOperationEntity` — 已实现，包含 `isExecuted`、`isRolledBack`、`afterStateFilePath` 字段
- `AppDependencies.operationManager` — 已注册，通过 `OperationManager(modelContext:)` 初始化
- `PhotoLibraryRepository` 协议 — 包含 `updateAsset`、`deleteAssets`、`moveAssets`、`metadata(for:)`、`currentBasePath()` 方法

**Story 4.2 的关键设计决策和已知问题：**

- **delete 回滚**：使用 `FileManager.default.moveItem` 从 `~/.Trash/` 移回原路径。垃圾桶中文件可能不存在（用户已清空垃圾桶），此时抛出 `DomainError.invalidState`
- **ModelContext 并发**：使用 `nonisolated(unsafe)` 标注，因为 `ModelContext` 不是 `Sendable`。仅在 actor 隔离上下文中访问
- **rollbackBatch 当前限制**：只回滚 `isExecuted && !isRolledBack` 的 snapshot。回滚后状态设为 `.rolledBack`
- **回滚机制已完整实现**：`rollbackBatch` 和 `rollbackLastBatch` 的回滚逻辑已完整（rename 回原名、delete 从垃圾桶恢复、move 回原目录）。本 Story 重点是在 UI 层暴露这些功能并增加双向撤销

**Story 4.1 已完成：**

- `PermissionState` (@Observable @MainActor) — 管理读写权限状态
- `WritePermissionPromptView` — 写入权限请求 UI
- `LocalFolderRepository` — 已实现所有写操作方法

### 关键设计细节

#### 双向撤销（重做）实现方案

回滚本身可撤销（重做）需要将已回滚的批次重新执行。方案：

1. **回滚时不删除批次数据**，仅更新状态为 `.rolledBack`
2. **新增 `reexecuteLastRolledBackBatch(repository:)` 方法**：
   - 查询最近一个 `.rolledBack` 状态的批次
   - 对该批次中 `isRolledBack == true` 的 snapshots 重新执行原始操作
   - 标记 `isRolledBack = false`，`isExecuted = true`
   - 状态更新为 `.completed`
3. **撤销/重做栈**：用 `UndoManagerViewModel` 维护当前可执行的操作类型（undo 或 redo）
   - 最后操作是 `.completed` → ⌘Z 执行 undo（rollback）
   - 最后操作是 `.rolledBack` → ⌘Z 执行 redo（reexecute）

#### ⌘Z 快捷键绑定

macOS SwiftUI 中通过 `.keyboardShortcut("z", modifiers: .command)` 绑定。但需要在合适层级注册，确保不与系统撤销冲突：

```swift
// 在 MainWorkspaceView 的 toolbar 或 .commands 修饰符中注册
.toolbar {
    ToolbarItemGroup(placement: .primaryAction) {
        // 现有按钮...
    }
}
.keyboardShortcut("z", modifiers: .command) {
    // undoAction()
}
```

注意：SwiftUI 的 `.keyboardShortcut` 需要附加到可聚焦的 Button 上。考虑使用 `.commands` modifier 或在 `UndoManagerViewModel` 中通过 NotificationCenter 监听。

#### 崩溃恢复提示

在应用启动时（如 `CuratorApp.init` 或 `MainWorkspaceView.onAppear`），检测未完成批次：

```swift
// UndoManagerViewModel 或 AppDependencies 扩展
func checkForIncompleteBatches() async {
    guard let opManager = dependencies.operationManager else { return }
    let incomplete = (try? await opManager.detectIncompleteBatches()) ?? []
    if !incomplete.isEmpty {
        showCrashRecoveryAlert = true
        incompleteBatches = incomplete
    }
}
```

#### NFR16（5 秒回滚）保障

`rollbackBatch` 的回滚逻辑已在 Story 4.2 中实现。对于 100+ 项的大批量操作：
- 文件系统操作（rename/move）通常 <10ms 每项
- 100 项 = ~1 秒，远低于 5 秒限制
- delete 回滚（从垃圾桶恢复）可能较慢，需要监控

### 与现有代码的集成点

**修改的文件：**

1. `Curator/Core/Operations/OperationManaging.swift` — 添加 `reexecuteLastRolledBackBatch(repository:)` 方法签名
2. `Curator/Core/Operations/OperationManager.swift` — 实现 `reexecuteLastRolledBackBatch`
3. `Curator/Features/MainWorkspace/MainWorkspaceView.swift` — 添加 ⌘Z 绑定和撤销按钮
4. `Curator/App/AppDependencies.swift` — 可能需要添加 `UndoManagerViewModel` 注册

**新建的文件：**

1. `Curator/Features/Undo/UndoManagerViewModel.swift` — 撤销/重做状态管理（@MainActor @Observable）
2. `Curator/Features/Undo/RollbackProgressView.swift` — 回滚进度 UI
3. `Curator/Features/Undo/CrashRecoverySheet.swift` — 崩溃恢复提示 Sheet
4. `CuratorTests/Core/Operations/BatchRollbackUndoTests.swift` — ATDD 测试

### 不做什么（范围边界）

以下内容在本 Story 中 **不实现**：

- **操作确认工作流 UI（Story 4.4）** — 破坏性操作的二次确认界面
- **只读模式保障（Story 4.5）** — 更深层的只读模式验证
- **SDK Tools 集成** — 去重/重命名工具通过 OperationManager 执行（Epic 5/6 时集成）
- **撤销历史面板** — 展示完整撤销历史的 UI（当前仅支持最近一次撤销/重做）
- **批量操作进度 UI** — executeBatch 的进度展示（Story 4.4 实现）

### 技术要求

- **Swift 6 strict concurrency**：所有新增类型标注 `Sendable`。ViewModel 标注 `@MainActor`
- **不引入新第三方依赖** — 仅使用 SwiftUI + Foundation + SwiftData
- **构建通过**：`xcodebuild build` 必须成功
- **无回归**：全部现有测试必须仍然通过
- **xcodegen 自动发现**：新增文件通过 project.yml 的 `sources: - Curator` 配置自动发现

### NFR 关注点

- **NFR15（零文件损坏）**：回滚操作通过 OperationManager 已有的 rollback 机制执行，不写入图像像素数据
- **NFR16（5 秒回滚）**：rollbackBatch 已在 Story 4.2 中实现，本 Story 仅在 UI 层暴露。需验证大批量回滚性能
- **NFR17（崩溃恢复）**：detectIncompleteBatches 已实现，本 Story 添加启动时检测和用户提示
- **NFR6（500MB 内存）**：撤销/重做仅操作元数据，不加载图像数据

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 4.3] — 原始需求定义（批量回滚与撤销系统）
- [Source: _bmad-output/planning-artifacts/architecture.md#决策7] — 操作回滚系统设计（快照 + 操作日志模式）
- [Source: _bmad-output/planning-artifacts/architecture.md#Core/Operations/] — OperationManager 目录规划
- [Source: _bmad-output/planning-artifacts/prd.md#FR34] — 可配置时间窗口内撤销批量操作
- [Source: _bmad-output/planning-artifacts/prd.md#FR36] — 批量操作中途失败自动回滚
- [Source: _bmad-output/planning-artifacts/prd.md#NFR16] — 5 秒内完成回滚
- [Source: _bmad-output/planning-artifacts/prd.md#NFR17] — 崩溃恢复
- [Source: _bmad-output/implementation-artifacts/4-2-operation-manager-core.md] — 前一 Story 的实现记录
- [Source: _bmad-output/project-context.md#Critical Implementation Rules] — Swift 6 严格并发、actor 隔离、三层错误体系
- [Source: _bmad-output/project-context.md#Architecture Boundaries] — Core/Operations/ 目录映射
- [Source: _bmad-output/project-context.md#Testing Rules] — ATDD 风格、Mock 模式
- [Source: Curator/Core/Operations/OperationManaging.swift] — OperationManaging 协议（需扩展）
- [Source: Curator/Core/Operations/OperationManager.swift] — OperationManager actor（需扩展 reexecute）
- [Source: Curator/Core/Operations/BatchStatus.swift] — BatchStatus 枚举（含 .rolledBack 状态）
- [Source: Curator/Core/Operations/OperationSnapshot.swift] — OperationSnapshot 值类型
- [Source: Curator/Infrastructure/Storage/SwiftDataModels.swift] — SwiftData 实体（OperationSnapshotEntity、BatchOperationEntity）
- [Source: Curator/Features/MainWorkspace/MainWorkspaceView.swift] — 主界面视图（需添加 ⌘Z 绑定）
- [Source: Curator/App/AppDependencies.swift] — 依赖注入容器

### 与后续 Story 的关系

**本 Story（4.3）完成后，Epic 4 剩余工作：**

- **Story 4.4（操作确认工作流 UI）** — 将使用 OperationManager 的 beginBatch + executeBatch 包装完整的确认流程，集成 ⌘Z 撤销功能
- **Story 4.5（只读模式保障）** — 将在写操作路径上添加 OperationManager 集成检查
- **Epic 5（去重）** — DeleteAssetsTool 将通过 OperationManager 执行删除操作，完成后用户可通过 ⌘Z 撤销
- **Epic 6（重命名）** — RenameAssetsTool 将通过 OperationManager 执行重命名操作

### ATDD Artifacts

- Checklist: `_bmad-output/test-artifacts/atdd-checklist-4-3-batch-rollback-and-undo.md`
- Unit tests: `CuratorTests/Core/Operations/BatchRollbackUndoTests.swift`

## Dev Agent Record

### Agent Model Used

Claude Opus 4.7 (GLM-5.1)

### Debug Log References

- Build succeeded on first attempt after fixing `private(set)` access issue in UndoManagerViewModel previews
- `testRollbackLastBatchViaCommandZ` initially failed because `MockRollbackRepo.rollbackUpdateCalled` was never set — fixed by tracking repeated `updateAsset` calls as rollback indicator

### Completion Notes List

- Implemented `UndoManagerViewModel` (@MainActor @Observable) managing undo/redo state via `OperationManaging` protocol
- Added `reexecuteLastRolledBackBatch(repository:)` to `OperationManaging` protocol and `OperationManager` actor — re-executes rolled-back snapshots to support bidirectional undo (AC3)
- Extended `rollbackBatch` to accept `.executing` status batches for crash recovery (AC4) — only performs file rollback if executed snapshots exist
- Created `RollbackProgressView` for inline progress/error display during rollback operations
- Created `CrashRecoverySheet` for crash recovery prompt with rollback/ignore options
- Integrated Cmd+Z keyboard shortcut via hidden button with `.keyboardShortcut("z", modifiers: .command)` in MainWorkspaceView toolbar
- Added undo/redo toolbar button with dynamic label based on `UndoManagerViewModel.availableAction`
- `AppDependencies` now conforms to `UndoManagerRepositoryProvider` protocol, providing repository access to `UndoManagerViewModel`
- Startup crash recovery check via `checkForIncompleteBatches()` in `MainWorkspaceView.onAppear`
- All 8 ATDD tests activated and passing; full suite 607 tests, 0 failures, 0 regressions

### File List

**New Files:**
- Curator/Features/Undo/UndoManagerViewModel.swift
- Curator/Features/Undo/RollbackProgressView.swift
- Curator/Features/Undo/CrashRecoverySheet.swift

**Modified Files:**
- Curator/Core/Operations/OperationManaging.swift — added `reexecuteLastRolledBackBatch(repository:)` method
- Curator/Core/Operations/OperationManager.swift — implemented `reexecuteLastRolledBackBatch`, extended `rollbackBatch` to accept `.executing` status
- Curator/App/AppDependencies.swift — added `UndoManagerRepositoryProvider` conformance, `undoManagerViewModel` property, `getRepository()` method
- Curator/Features/MainWorkspace/MainWorkspaceView.swift — added Cmd+Z shortcut, undo/redo toolbar button, rollback progress view, crash recovery sheet
- CuratorTests/Core/Operations/BatchRollbackUndoTests.swift — activated all 8 tests (removed skip guards, changed `#if false` to `#if true`), fixed `rollbackUpdateCalled` tracking in MockRollbackRepo
- CuratorTests/Core/Operations/OperationManagerTests.swift — added `reexecuteLastRolledBackBatch` to MockOperationManager

## Change Log

- 2026-04-23: Story 4.3 implementation complete — batch rollback & undo system with bidirectional undo, crash recovery, Cmd+Z shortcut, and UI components. All 8 ATDD tests pass, 607 total tests pass with 0 regressions.
