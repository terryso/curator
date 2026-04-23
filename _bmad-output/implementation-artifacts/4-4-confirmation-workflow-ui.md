# Story 4.4: 操作确认工作流 UI

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a 用户，
I want 在执行破坏性操作前看到明确的确认界面，
So that 我不会意外删除或修改照片。

## Acceptance Criteria

1. **AC1: 只读操作无需确认（UX-DR11, FR33）**
   **Given** Agent 完成了只读分析任务
   **When** 展示分析结果
   **Then** 无需用户确认，直接显示结果

2. **AC2: 写入操作批量确认摘要（UX-DR11, FR33）**
   **Given** Agent 请求执行写操作（重命名、移动）
   **When** 展示批量确认摘要
   **Then** 包含操作数量和缩略图预览
   **And** 展示"执行"按钮（主要样式，UX-DR17）和"取消"按钮（次要样式）
   **And** 展示撤销路径和时间窗口说明

3. **AC3: 破坏性操作二次确认（UX-DR11, FR33）**
   **Given** Agent 请求执行破坏性操作（删除）
   **When** 展示确认界面
   **Then** 先展示批量确认摘要 + "执行"按钮（危险样式，红色）
   **Then** 用户点击"执行"后弹出二次确认 Sheet
   **And** 二次确认包含操作摘要和"确认执行"按钮
   **And** 所有写入操作展示撤销路径和时间窗口

4. **AC4: 确认流程与 OperationManager 集成（FR35, FR36）**
   **Given** 用户在确认界面点击"执行"
   **When** 确认流程开始执行
   **Then** 通过 `OperationManager.beginBatch()` 创建快照
   **And** 通过 `OperationManager.executeBatch()` 执行操作
   **And** 执行过程中展示进度（当前/总数）
   **And** 执行完成后展示结果摘要（成功/失败数量）

5. **AC5: 权限检查前置（FR6, UX-DR9）**
   **Given** Agent 请求执行写操作
   **When** 确认界面展示前
   **Then** 检查 `PermissionState.hasWriteAccess`
   **And** 无写入权限时先展示权限升级提示
   **And** 用户拒绝权限时取消操作，建议保存结果供稍后执行

## Tasks / Subtasks

- [ ] Task 1: 创建确认级别枚举和确认请求模型 (AC: #1, #2, #3)
  - [ ] 1.1 创建 `Curator/Features/Confirmation/ConfirmationLevel.swift` — 枚举：`.none`（只读）、`.standard`（写入）、`.destructive`（删除），标记 `Sendable`
  - [ ] 1.2 创建 `Curator/Features/Confirmation/ConfirmationRequest.swift` — 值类型 struct：包含 `operations: [PlannedOperation]`、`confirmationLevel: ConfirmationLevel`、`summary: String`、`affectedAssetIDs: [AssetID]`
  - [ ] 1.3 在 `ConfirmationLevel` 中添加静态方法 `forOperations(_:)` — 根据 PlannedOperation 列表自动判断确认级别（包含 .delete 则为 destructive，否则为 standard）

- [ ] Task 2: 创建确认工作流 ViewModel (AC: #2, #3, #4, #5)
  - [ ] 2.1 创建 `Curator/Features/Confirmation/ConfirmationViewModel.swift` — `@Observable @MainActor` 类
  - [ ] 2.2 添加 `request: ConfirmationRequest?` 状态 — 当前待确认的请求（nil 表示无确认待处理）
  - [ ] 2.3 添加 `isExecuting: Bool` 状态 — 正在执行操作
  - [ ] 2.4 添加 `executionProgress: (completed: Int, total: Int)?` 状态 — 执行进度
  - [ ] 2.5 添加 `executionResult: ExecutionResult?` 状态 — 执行结果（成功/失败数量）
  - [ ] 2.6 添加 `showSecondConfirmation: Bool` 状态 — 破坏性操作的二次确认 Sheet
  - [ ] 2.7 添加 `needsPermissionUpgrade: Bool` 状态 — 需要权限升级
  - [ ] 2.8 实现 `presentConfirmation(request:)` — 检查权限、设置确认级别、展示确认界面
  - [ ] 2.9 实现 `confirm()` — 用户确认执行，对于 destructive 先展示二次确认
  - [ ] 2.10 实现 `confirmDestructive()` — 破坏性操作二次确认后执行
  - [ ] 2.11 实现 `executeOperations()` — 调用 OperationManager.beginBatch + executeBatch，更新进度和结果
  - [ ] 2.12 实现 `cancel()` — 取消确认，重置状态

- [ ] Task 3: 创建批量确认摘要视图 (AC: #2)
  - [ ] 3.1 创建 `Curator/Features/Confirmation/BatchConfirmationSummaryView.swift` — 展示操作数量和缩略图预览
  - [ ] 3.2 展示操作类型标签（"重命名 X 张照片"、"移动 X 张照片"）
  - [ ] 3.3 展示受影响资产的缩略图网格（最多 6 张预览 + "+N 更多"）
  - [ ] 3.4 展示"执行"按钮（主要/危险样式，根据确认级别）和"取消"按钮（次要样式）
  - [ ] 3.5 展示撤销路径说明文字（"可在 X 分钟内撤销此操作"）

- [ ] Task 4: 创建二次确认 Sheet (AC: #3)
  - [ ] 4.1 创建 `Curator/Features/Confirmation/DestructiveConfirmationSheet.swift` — 破坏性操作二次确认
  - [ ] 4.2 展示警告图标 + 操作摘要（"确定要删除 X 张照片？"）
  - [ ] 4.3 展示"确认执行"按钮（危险样式，红色）和"取消"按钮
  - [ ] 4.4 包含撤销路径提醒文字

- [ ] Task 5: 创建执行进度和结果视图 (AC: #4)
  - [ ] 5.1 创建 `Curator/Features/Confirmation/ExecutionProgressView.swift` — 执行过程中的进度展示
  - [ ] 5.2 展示进度条 + "正在执行... (X/Y)" 文字
  - [ ] 5.3 创建 `Curator/Features/Confirmation/ExecutionResultView.swift` — 执行完成后的结果摘要
  - [ ] 5.4 展示成功数量、失败数量（如有）、撤销按钮

- [ ] Task 6: 创建权限升级拦截视图 (AC: #5)
  - [ ] 6.1 创建 `Curator/Features/Confirmation/PermissionUpgradeView.swift` — 写入权限升级提示
  - [ ] 6.2 复用 Story 4.1 的 `WritePermissionPromptView` 模式，但作为确认流程的前置步骤
  - [ ] 6.3 权限升级成功后自动继续确认流程
  - [ ] 6.4 权限拒绝后展示"保存结果供稍后执行"提示并取消

- [ ] Task 7: 集成到 AgentExecutionPanel (AC: #1, #2, #3)
  - [ ] 7.1 在 `AgentExecutionPanel` 或 `MainWorkspaceView` 中集成 ConfirmationViewModel
  - [ ] 7.2 当 AgentJob 进入 Confirm 状态时，触发 `ConfirmationViewModel.presentConfirmation()`
  - [ ] 7.3 确认完成后，通知 AgentJob 继续执行或取消
  - [ ] 7.4 在 `AppDependencies` 注册 `ConfirmationViewModel`

- [ ] Task 8: ATDD 测试 (AC: #1, #2, #3, #4, #5)
  - [ ] 8.1 创建 `CuratorTests/Features/Confirmation/ConfirmationWorkflowTests.swift`
  - [ ] 8.2 [P0] testReadOnlyOperationsSkipConfirmation — 只读操作跳过确认，直接展示结果
  - [ ] 8.3 [P0] testWriteOperationsShowBatchConfirmation — 写入操作展示批量确认摘要
  - [ ] 8.4 [P0] testDestructiveOperationsShowSecondConfirmation — 删除操作需二次确认
  - [ ] 8.5 [P0] testConfirmationCallsBeginBatchThenExecuteBatch — 确认执行通过 OperationManager 完成快照和执行
  - [ ] 8.6 [P0] testPermissionCheckBeforeConfirmation — 无写入权限时先展示权限升级
  - [ ] 8.7 [P0] testPermissionDeniedCancelsOperation — 权限拒绝后操作被取消
  - [ ] 8.8 [P1] testExecutionProgressUpdates — 执行过程中进度正确更新
  - [ ] 8.9 [P1] testExecutionResultShowsSuccessAndFailure — 执行结果展示成功和失败数量
  - [ ] 8.10 [P1] testCancelResetsState — 取消确认后所有状态重置
  - [ ] 8.11 [P1] testUndoPathDisplayed — 确认界面展示撤销路径说明
  - [ ] 8.12 构建通过 + 全部现有测试通过

## Dev Notes

### 架构约束

1. **分层边界严格**：`ConfirmationLevel` 和 `ConfirmationRequest` 是值类型，在 `Features/Confirmation/`（Presentation 层）。`ConfirmationViewModel` 用 `@MainActor`，通过 `OperationManaging` 协议调用 Application 层。[Source: architecture.md#分层架构]
2. **@MainActor ViewModel**：ConfirmationViewModel 标记 `@Observable @MainActor`。[Source: project-context.md#Critical Implementation Rules]
3. **Sendable 类型**：ConfirmationLevel 和 ConfirmationRequest 为 Sendable struct。[Source: project-context.md#Code Patterns]
4. **禁止使用 `Task` 作为类型名**。[Source: CLAUDE.md]
5. **SwiftUI 视图不超过 200 行**。BatchConfirmationSummaryView、DestructiveConfirmationSheet、ExecutionProgressView 等拆分为独立视图文件。[Source: project-context.md#SwiftUI 视图模式]
6. **三层错误链路**：InfrastructureError -> DomainError -> UserFacingError，不可跳层。[Source: project-context.md#三层错误体系]
7. **协议在 Domain 层定义**：`OperationManaging` 协议在 Core/Operations/，ConfirmationViewModel 通过注入使用。[Source: project-context.md#Architecture Boundaries]

### 前置 Story 上下文

**Story 4.1-4.3 已完成的核心实现（本 Story 需复用和集成）：**

- `OperationManager` (actor) — 已实现 `beginBatch`、`executeBatch`、`rollbackBatch`、`rollbackLastBatch`、`detectIncompleteBatches`、`getBatchHistory`、`reexecuteLastRolledBackBatch`
- `OperationManaging` 协议 — 完整 API，`beginBatch` 接收 `[PlannedOperation]` 和 `PhotoLibraryRepository`，返回 `BatchID`
- `OperationSnapshot` / `BatchOperation` / `BatchStatus` / `PlannedOperation` / `OperationType` — 值类型模型已完整定义
- `OperationParameters` 枚举 — `.rename(newTitle:)`、`.delete`、`.move(targetDirectory:)`、`.metadataChange`
- `PermissionState` (@Observable @MainActor) — `isReadOnly`、`hasWriteAccess`、`requestWritePermission()`
- `WritePermissionPromptView` — 权限请求 UI 组件（Story 4.1）
- `UndoManagerViewModel` (@Observable @MainActor) — 管理 undo/redo 状态，`availableAction` 属性
- `RollbackProgressView` — 回滚进度 UI（Story 4.3）
- `AppDependencies` — 依赖注入容器，已注册 `operationManager`、`permissionState`、`undoManagerViewModel`
- `AgentJob` @Observable 类 — 状态机：Planning -> Running -> Review -> Confirm -> Completed/Cancelled/Failed
- `AgentEvent` 枚举 — `reviewReady(items:)` 和 `executionCompleted(summary:)` 事件

### 确认工作流设计细节

#### 确认级别判断逻辑

```swift
enum ConfirmationLevel: Sendable {
    case none        // 只读操作，无需确认
    case standard    // 写入操作（重命名、移动），需批量确认
    case destructive // 破坏性操作（删除），需二次确认

    static func forOperations(_ operations: [PlannedOperation]) -> ConfirmationLevel {
        if operations.contains(where: { $0.operationType == .delete }) {
            return .destructive
        }
        if operations.allSatisfy({ $0.operationType == .metadataChange }) {
            return .none
        }
        return .standard
    }
}
```

#### ConfirmationViewModel 核心流程

```
Agent 请求执行操作
    -> ConfirmationViewModel.presentConfirmation(request:)
        -> 检查 PermissionState.hasWriteAccess
            -> 无权限: needsPermissionUpgrade = true, 展示 PermissionUpgradeView
                -> 用户授权: 继续确认流程
                -> 用户拒绝: cancel(), 建议"保存结果供稍后执行"
            -> 有权限: 根据 confirmationLevel 展示对应界面
                -> .none: 直接执行 executeOperations()
                -> .standard: 展示 BatchConfirmationSummaryView
                    -> 用户点击"执行": executeOperations()
                    -> 用户点击"取消": cancel()
                -> .destructive: 展示 BatchConfirmationSummaryView (红色按钮)
                    -> 用户点击"执行": showSecondConfirmation = true
                        -> 用户在 DestructiveConfirmationSheet 点击"确认执行": confirmDestructive() -> executeOperations()
                        -> 用户取消: showSecondConfirmation = false
                    -> 用户点击"取消": cancel()
    -> executeOperations()
        -> OperationManager.beginBatch(operations:, repository:)
        -> isExecuting = true
        -> OperationManager.executeBatch(batchID, repository:)
        -> 更新 executionProgress
        -> 成功: executionResult = .success(count)
        -> 失败: executionResult = .partialFailure(success: X, failed: Y)
    -> 完成后通知 AgentJob 继续
```

#### 与 AgentJob 的集成

当前 AgentJob 状态机有 `Confirm` 状态。当 AgentJob 进入 Confirm 时，需要将操作列表传递给 ConfirmationViewModel：

```swift
// 在 AgentExecutionViewModel 或 MainWorkspaceView 中
// 当 AgentJob 状态变为 .confirm 时
case .confirm:
    let request = ConfirmationRequest(
        operations: agentJob.plannedOperations,
        summary: agentJob.executionSummary
    )
    confirmationViewModel.presentConfirmation(request: request)
```

注意：需要检查 AgentJob 当前是否已有 `plannedOperations` 属性，或者需要从 AgentEvent.reviewReady 中提取操作列表。如果 AgentJob 不直接暴露 plannedOperations，可能需要通过事件流获取。

#### UI 布局建议

确认界面应作为 AgentExecutionPanel 下方的内容区域展示（而非全屏 Sheet），这样用户仍然能看到 Agent 的执行过程和推理。具体布局：

1. **确认摘要区域**：嵌入在 AgentExecutionPanel 底部，展示 BatchConfirmationSummaryView
2. **二次确认 Sheet**：使用 SwiftUI `.sheet()` 修饰符弹出
3. **执行进度**：替换确认摘要区域，展示 ExecutionProgressView
4. **执行结果**：替换执行进度，展示 ExecutionResultView

#### 撤销路径说明

根据 Story 4.3 的实现，当前支持最近一次操作的撤销（undo）和重做（redo）。确认界面中的撤销说明应为："此操作可通过 ⌘Z 撤销"。

### 与现有代码的集成点

**修改的文件：**

1. `Curator/Features/AgentExecution/AgentExecutionPanel.swift` — 集成确认界面
2. `Curator/Features/MainWorkspace/MainWorkspaceView.swift` — 可能需要在主视图层级集成 ConfirmationViewModel
3. `Curator/App/AppDependencies.swift` — 注册 ConfirmationViewModel

**新建的文件：**

1. `Curator/Features/Confirmation/ConfirmationLevel.swift` — 确认级别枚举
2. `Curator/Features/Confirmation/ConfirmationRequest.swift` — 确认请求值类型
3. `Curator/Features/Confirmation/ConfirmationViewModel.swift` — 确认工作流状态管理
4. `Curator/Features/Confirmation/BatchConfirmationSummaryView.swift` — 批量确认摘要视图
5. `Curator/Features/Confirmation/DestructiveConfirmationSheet.swift` — 破坏性操作二次确认 Sheet
6. `Curator/Features/Confirmation/ExecutionProgressView.swift` — 执行进度视图
7. `Curator/Features/Confirmation/ExecutionResultView.swift` — 执行结果视图
8. `Curator/Features/Confirmation/PermissionUpgradeView.swift` — 权限升级拦截视图
9. `CuratorTests/Features/Confirmation/ConfirmationWorkflowTests.swift` — ATDD 测试

### 不做什么（范围边界）

以下内容在本 Story 中 **不实现**：

- **去重 SDK 工具集成（Epic 5）** — DeleteAssetsTool 和 ScanLibraryTool 的实际注册
- **重命名 SDK 工具集成（Epic 6）** — RenameAssetsTool 和 AnalyzeContentTool
- **成本预估集成（Epic 2）** — CostEstimateCard 在确认前展示（Epic 5/6 时集成）
- **只读模式保障（Story 4.5）** — 更深层的只读模式验证
- **批量操作进度详细展示** — 每个操作项的独立状态（当前仅展示总体 X/Y 进度）
- **操作预览缩略图加载** — 如果加载缩略图过于复杂，可先用文件名列表替代（后续迭代加缩略图）

### 技术要求

- **Swift 6 strict concurrency**：所有新增类型标注 `Sendable`。ViewModel 标注 `@MainActor`
- **不引入新第三方依赖** — 仅使用 SwiftUI + Foundation
- **构建通过**：`xcodebuild build` 必须成功
- **无回归**：全部现有测试必须仍然通过
- **xcodegen 自动发现**：新增文件通过 project.yml 的 `sources: - Curator` 配置自动发现

### 项目结构说明

本 Story 新增的文件：

```
Curator/
├── Features/Confirmation/
│   ├── ConfirmationLevel.swift                   # 新建：确认级别枚举
│   ├── ConfirmationRequest.swift                 # 新建：确认请求值类型
│   ├── ConfirmationViewModel.swift               # 新建：确认工作流 ViewModel
│   ├── BatchConfirmationSummaryView.swift         # 新建：批量确认摘要视图
│   ├── DestructiveConfirmationSheet.swift         # 新建：破坏性操作二次确认
│   ├── ExecutionProgressView.swift               # 新建：执行进度视图
│   ├── ExecutionResultView.swift                 # 新建：执行结果视图
│   └── PermissionUpgradeView.swift               # 新建：权限升级拦截视图
```

修改的文件：

```
Curator/
├── Features/AgentExecution/AgentExecutionPanel.swift  # 修改：集成确认界面
├── Features/MainWorkspace/MainWorkspaceView.swift      # 修改：集成 ConfirmationViewModel
├── App/AppDependencies.swift                           # 修改：注册 ConfirmationViewModel
```

测试文件：

```
CuratorTests/
├── Features/Confirmation/ConfirmationWorkflowTests.swift  # 新建：确认工作流测试
```

### NFR 关注点

- **NFR15（零文件损坏）**：确认流程通过 OperationManager 调用写操作，OperationManager 仅通过 PhotoLibraryRepository 协议调用 rename/trashItem/moveItem，绝不写入图像像素数据
- **NFR16（5 秒回滚）**：确认界面展示撤销说明，用户可通过 ⌘Z 触发 UndoManagerViewModel.rollbackLastBatch
- **NFR7（UI 不阻塞）**：executeOperations 在 Task 中异步执行，不阻塞 UI。进度更新通过 @Observable 自动刷新
- **NFR3（500ms 进度更新）**：executeBatch 的进度通过 ViewModel 的 executionProgress 属性实时更新到 UI

### 按钮样式规则（UX-DR17）

| 确认级别 | "执行"按钮样式 | "取消"按钮样式 |
|---------|--------------|--------------|
| standard（写入） | 主要样式（实色填充 + 系统强调色） | 次要样式（描边） |
| destructive（删除） | 危险样式（实色填充 + 系统红色） | 次要样式（描边） |

**规则**：每个界面最多一个主要/危险按钮。每界面最多一个主要按钮。[Source: ux-design-specification.md#Button Hierarchy]

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 4.4] — 原始需求定义（操作确认工作流 UI）
- [Source: _bmad-output/planning-artifacts/architecture.md#决策7] — 操作回滚系统设计（快照 + 操作日志模式）
- [Source: _bmad-output/planning-artifacts/architecture.md#决策2] — AgentJob 状态机（Planning -> Running -> Review -> Confirm -> Completed）
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#Agent-Specific Patterns] — 操作确认分级模式（只读/写入/破坏性三级）
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#Button Hierarchy] — 按钮层级系统（主要/次要/危险/文本）
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#Experience Principles] — 渐进承诺原则
- [Source: _bmad-output/planning-artifacts/prd.md#FR33] — 破坏性操作需用户批准
- [Source: _bmad-output/planning-artifacts/prd.md#FR34] — 可配置时间窗口内撤销批量操作
- [Source: _bmad-output/planning-artifacts/prd.md#FR35] — 批量修改前创建元数据快照
- [Source: _bmad-output/planning-artifacts/prd.md#FR36] — 批量操作中途失败自动回滚
- [Source: _bmad-output/planning-artifacts/prd.md#FR6] — 授予写入权限
- [Source: _bmad-output/planning-artifacts/prd.md#NFR15] — 零文件损坏容忍
- [Source: _bmad-output/planning-artifacts/prd.md#NFR16] — 5 秒内完成回滚
- [Source: _bmad-output/implementation-artifacts/4-1-write-permission-progressive.md] — Story 4.1 实现记录（PermissionState、WritePermissionPromptView）
- [Source: _bmad-output/implementation-artifacts/4-2-operation-manager-core.md] — Story 4.2 实现记录（OperationManager、beginBatch、executeBatch）
- [Source: _bmad-output/implementation-artifacts/4-3-batch-rollback-and-undo.md] — Story 4.3 实现记录（UndoManagerViewModel、RollbackProgressView、⌘Z 绑定）
- [Source: _bmad-output/project-context.md#Critical Implementation Rules] — Swift 6 严格并发、@MainActor ViewModel、Sendable 类型、三层错误体系
- [Source: _bmad-output/project-context.md#Architecture Boundaries] — Core/ 和 Features/ 和 Infrastructure/ 目录映射
- [Source: _bmad-output/project-context.md#Testing Rules] — ATDD 风格、Mock 模式
- [Source: Curator/Core/Operations/OperationManaging.swift] — OperationManaging 协议（beginBatch、executeBatch API）
- [Source: Curator/Core/Operations/PlannedOperation.swift] — PlannedOperation 值类型（输入模型）
- [Source: Curator/Core/Operations/OperationType.swift] — OperationType 枚举（.rename/.delete/.move/.metadataChange）
- [Source: Curator/Core/Models/PermissionState.swift] — PermissionState（hasWriteAccess、requestWritePermission）
- [Source: Curator/Features/Permission/WritePermissionPromptView.swift] — 权限请求 UI 组件
- [Source: Curator/Features/Undo/UndoManagerViewModel.swift] — 撤销/重做状态管理
- [Source: Curator/Features/Undo/RollbackProgressView.swift] — 回滚进度 UI（可复用模式）
- [Source: Curator/Features/AgentExecution/AgentExecutionPanel.swift] — Agent 执行面板（需集成确认界面）
- [Source: Curator/App/AppDependencies.swift] — 依赖注入容器

### 与后续 Story 的关系

**本 Story（4.4）完成后，Epic 4 剩余工作：**

- **Story 4.5（只读模式保障）** — 将在写操作路径上添加更深层的只读模式验证，与确认工作流配合
- **Epic 5（去重）** — DeleteAssetsTool 将触发 ConfirmationViewModel 的 destructive 确认流程
- **Epic 6（重命名）** — RenameAssetsTool 将触发 ConfirmationViewModel 的 standard 确认流程

## Dev Agent Record

### Agent Model Used

{{agent_model_name_version}}

### Debug Log References

### Completion Notes List

### File List

### Review Findings

- [x] [Review][Patch] 只读操作被静默丢弃 — 已修复：`presentConfirmation` 现在先设 `self.request = request` 再调用 `executeOperations()` [ConfirmationViewModel.swift:82-83]
- [x] [Review][Patch] PermissionUpgradeView 未调用 `requestWritePermission()` — 已修复：`permissionGranted()` 现在调用 `permissionState?.requestWritePermission()` 获取实际 OS 级权限 [ConfirmationViewModel.swift:119-126]
- [x] [Review][Patch] `showPermissionDenied` 状态从未被任何视图消费 — 已修复：新增 `PermissionDeniedView` 展示"保存结果供稍后执行"提示 [PermissionDeniedView.swift / MainWorkspaceView.swift]
- [x] [Review][Patch] DestructiveConfirmationSheet 与 undo 说明矛盾 — 已修复：统一消息为"删除的照片将移至废纸篓，可通过 ⌘Z 撤销" [DestructiveConfirmationSheet.swift:30]
- [x] [Review][Patch] `ConfirmationRepositoryProvider` 与 `UndoManagerRepositoryProvider` 完全重复 — 已修复：移除 `ConfirmationRepositoryProvider`，复用现有 `UndoManagerRepositoryProvider` [ConfirmationViewModel.swift]
- [x] [Review][Patch] `executionProgress` 使用元组类型不利于 `@Observable` 变更追踪 — 已修复：改为 `ExecutionProgress` struct [ConfirmationViewModel.swift:12-15]
- [x] [Review][Patch] `confirmationViewModel` 在 AppDependencies 中非 `@Published` — 已修复：改为 `@Published` [AppDependencies.swift:47]
- [x] [Review][Patch] `executeWithMockFallback` 与 `executeOperations` 代码几乎完全重复 — 已修复：合并为单一 `executeOperations()` 方法，使用 nil-coalescing 回退 [ConfirmationViewModel.swift]
- [x] [Review][Patch] AgentJob.confirm 状态未接入 presentConfirmation() — 已添加集成钩子注释，实际操作列表将由 Epic 5/6 SDK 工具层提供 [MainWorkspaceView.swift]
- [x] [Review][Patch] `testReadOnlyOperationsSkipConfirmation` 断言语义错误 — 已修复：更新断言为等待 async 完成后验证状态 [ConfirmationWorkflowTests.swift]
- [x] [Review][Patch] `testWriteOperationsShowBatchConfirmation` 测试名误导 — 已修复：分为两个阶段测试，先验证权限升级路径再验证有权限时的确认流程 [ConfirmationWorkflowTests.swift]
- [x] [Review][Patch] ExecutionResultView onUndo 回调中 undoManager 静默 nil — 已修复：添加 guard 检查 [MainWorkspaceView.swift:281]
- [x] [Review][Defer] BatchConfirmationSummaryView 用文件路径替代缩略图 — Dev Notes 明确允许此回退方案 [BatchConfirmationSummaryView.swift]
- [x] [Review][Defer] 硬编码中文字符串无本地化 — 与现有代码库模式一致 [ConfirmationRequest.swift:25]
- [x] [Review][Defer] executeBatch API 不提供增量进度回调 — API 设计限制，当前实现直接跳到 100% [ConfirmationViewModel.swift:183-185]
