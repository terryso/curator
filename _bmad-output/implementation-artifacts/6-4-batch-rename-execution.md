# Story 6.4: 批量重命名执行

Status: done

## Story

As a 用户，
I want 在审核完所有建议后一次性批量执行重命名，
so that 高效完成整个重命名流程。

## Acceptance Criteria

1. **AC1: 批量操作按钮（FR28, UX-DR17）**
   **Given** 审核界面中存在多个待处理的重命名建议
   **When** 用户点击"全部接受"或"全部拒绝"按钮
   **Then** BatchRenameView 展示批量确认摘要，列出将要重命名的照片数量
   **And** 已审核的建议状态不受影响

2. **AC2: 批量确认与执行（FR28, FR33, UX-DR11）**
   **Given** 用户已审核完所有重命名建议
   **When** 点击"执行重命名"按钮
   **Then** 系统生成 `[PlannedOperation]`（.rename 类型），通过 ConfirmationViewModel 路由到正确的确认级别（.standard，重命名非破坏性操作）
   **And** 用户确认后通过 OperationManager 批量执行重命名操作

3. **AC3: 执行结果摘要（UX-DR6）**
   **Given** 批量重命名操作已完成
   **When** 展示结果界面
   **Then** AgentResultSummary 显示已重命名的照片数量、跳过数量、失败数量
   **And** 提供撤销按钮支持回滚本次批量重命名

4. **AC4: 撤销/回滚（FR34, NFR16）**
   **Given** 用户触发了撤销操作
   **When** 系统通过 OperationManager 回滚
   **Then** 所有照片恢复至原始文件名
   **And** 操作日志记录本次回滚事件

5. **AC5: 部分失败容错（FR36, NFR15）**
   **Given** 批量重命名过程中某张照片操作失败
   **When** 文件被占用或权限不足
   **Then** 系统跳过失败项继续处理后续项
   **And** 操作完成后汇总所有失败项及失败原因

6. **AC6: 审核数据到确认工作流的桥接**
   **Given** 用户在重命名审核界面完成审核
   **When** 点击"执行重命名"触发批量执行
   **Then** RenameViewModel.toRenameOperations() 的结果转换为 [PlannedOperation]（.rename 类型）
   **And** 通过 ConfirmationViewModel.presentConfirmation() 路由到正确的确认级别（.standard）

7. **AC7: 与 AgentExecutionPanel 的集成**
   **Given** RenameReviewView 底部需要添加 BatchRenameView
   **When** AgentExecutionPanel 的 .review 状态分支渲染
   **Then** RenameReviewView 包含底部 BatchRenameView 操作栏，接收 confirmationViewModel 和 undoManager 参数
   **And** AgentResultSummaryView 在执行完成后展示重命名结果摘要

## Tasks / Subtasks

- [x] Task 1: 创建 BatchRenameView 组件 (AC: #1, #2)
  - [x] 1.1 创建 `Curator/Features/Rename/BatchRenameView.swift`
  - [x] 1.2 添加"全部接受"按钮（次要样式，描边），将所有 pending 建议标记为 `.accepted`
  - [x] 1.3 添加"全部拒绝"按钮（次要样式，描边），将所有 pending 建议标记为 `.rejected`
  - [x] 1.4 点击"全部接受"后先在 RenameViewModel 批量更新状态，用户需再点击"执行重命名"
  - [x] 1.5 按钮仅在 `allReviewed` 为 false 时显示"全部接受/拒绝"；`allReviewed` 为 true 且有接受项时显示"执行重命名"按钮
  - [x] 1.6 遵循 UX-DR17 按钮层级：每界面最多一个主要按钮

- [x] Task 2: 实现批量确认与执行流程 (AC: #2, #6)
  - [x] 2.1 BatchRenameView 接收 `confirmationViewModel: ConfirmationViewModel?` 参数
  - [x] 2.2 实现 `executeBatchRename()` 方法：调用 `viewModel.toRenameOperations()` 生成 [PlannedOperation]
  - [x] 2.3 构建 `ConfirmationRequest`：operations 为 rename 列表、confirmationLevel 为 `.forOperations(operations)`（应为 `.standard`）、summary 为重命名数量描述
  - [x] 2.4 调用 `confirmationViewModel.presentConfirmation(request:)` 触发确认流程
  - [x] 2.5 验证 ConfirmationLevel.forOperations 对 .rename 操作返回 `.standard`（非 destructive）

- [x] Task 3: 执行结果展示与撤销 (AC: #3, #4)
  - [x] 3.1 在 BatchRenameView 中观察 `confirmationViewModel.executionResult` 展示结果摘要
  - [x] 3.2 结果展示：成功数/失败数/总数（复用 BatchApprovalView 的 resultSummary 布局模式）
  - [x] 3.3 添加"撤销操作"按钮，调用 `UndoManagerViewModel.performUndoAction()`
  - [x] 3.4 添加"查看详情"按钮，触发 `showResultSummary = true` 展示完整 AgentResultSummaryView
  - [x] 3.5 "Dismiss"按钮重置 confirmationViewModel 状态

- [x] Task 4: 集成 BatchRenameView 到 RenameReviewView 与 AgentExecutionPanel (AC: #7)
  - [x] 4.1 修改 `RenameReviewView`：底部添加 BatchRenameView，传入 renameViewModel、confirmationViewModel、undoManager
  - [x] 4.2 修改 `AgentExecutionPanel`：在 `.review` 分支中传递 confirmationViewModel 和 undoManager 给 RenameReviewView
  - [x] 4.3 修改 `AgentExecutionPanel`：添加 `onResultSummaryDone` 和 `onResultSummaryUndo` 回调处理重命名结果
  - [x] 4.4 修改 `MainWorkspaceView`：传递 confirmationViewModel 和 undoManager 到 AgentExecutionPanel 的重命名路径

- [x] Task 5: ATDD 测试 (AC: #1, #2, #3, #4, #5, #6)
  - [x] 5.1 创建 `CuratorTests/Features/Rename/BatchRenameViewModelTests.swift`
  - [x] 5.2 [P0] testMarkAllAsAcceptUpdatesAllStates -- 全部标记接受后所有 pending 状态变为 accepted
  - [x] 5.3 [P0] testMarkAllAsRejectUpdatesAllStates -- 全部标记拒绝后所有 pending 状态变为 rejected
  - [x] 5.4 [P0] testToRenameOperationsReturnsCorrectOperations -- toRenameOperations 返回正确 PlannedOperation 列表（类型 .rename，名称匹配）
  - [x] 5.5 [P0] testToRenameOperationsExcludesRejected -- 标记为 rejected 的不出现在重命名操作列表中
  - [x] 5.6 [P0] testToRenameOperationsIncludesEdited -- edited 状态的建议使用用户编辑后的名称
  - [x] 5.7 [P0] testBatchRenameTriggersStandardConfirmation -- 批量重命名操作触发 .standard 确认级别
  - [x] 5.8 [P0] testExecutionResultUpdatesOnCompletion -- 执行完成后 executionResult 被正确设置
  - [x] 5.9 [P1] testMarkAllPreservesAlreadyReviewedStates -- markAll 不覆盖已审核的建议
  - [x] 5.10 [P1] testBatchRenameWithEmptyOperations -- 无操作时不触发确认流程
  - [x] 5.11 [P1] testRenameConfirmationLevelIsStandard -- rename 操作的 ConfirmationLevel 为 .standard（非 destructive）
  - [x] 5.12 构建通过 + 全部现有测试通过

## Dev Notes

### 架构约束

1. **RenameViewModel 是 @MainActor @Observable**：所有 UI 状态更新在主线程。[Source: project-context.md#Critical Implementation Rules]
2. **禁止使用 `Task` 作为类型名**：使用 `AgentJob`、`AgentWork` 等前缀。[Source: CLAUDE.md]
3. **跨层数据传递只用值类型**：PlannedOperation、ConfirmationRequest 都是 Sendable struct。[Source: project-context.md#Critical Implementation Rules]
4. **SwiftUI 视图不超过 200 行**：BatchRenameView 独立，RenameReviewView 添加底部按钮。[Source: project-context.md#Code Patterns]
5. **三层错误体系**：Infrastructure → Domain → UserFacing 错误映射。[Source: project-context.md#三层错误体系]
6. **重命名是写操作但非破坏性操作**：ConfirmationLevel 应为 `.standard`（非 `.destructive`），因为文件名可完全回滚。

### 前置 Story 的已有实现（必须复用）

**RenameViewModel（复用，不修改核心方法）：**
- `loadSuggestions(_:)` — 加载建议列表。[Source: Curator/Features/Rename/RenameViewModel.swift:100-106]
- `accept(suggestionID:)` / `reject(suggestionID:)` / `edit(suggestionID:newName:)` — 审核操作。[Source: Curator/Features/Rename/RenameViewModel.swift:108-129]
- `markAllAsAccept()` / `markAllAsReject()` — 批量标记（Story 6.3 已为 6.4 预留实现）。[Source: Curator/Features/Rename/RenameViewModel.swift:133-149]
- `toRenameOperations() -> [PlannedOperation]` — 转换为 PlannedOperation 列表（Story 6.3 已为 6.4 预留实现）。[Source: Curator/Features/Rename/RenameViewModel.swift:153-177]
- `allReviewed`、`acceptedCount`、`pendingSuggestions`、`progressText` — 计算属性。[Source: Curator/Features/Rename/RenameViewModel.swift:49-93]

**数据模型（复用，不修改）：**
- `RenameSuggestion` — 重命名建议模型。[Source: Curator/Core/Models/RenameSuggestion.swift]
- `RenameSuggestionStatus` — `.pending`、`.accepted`、`.rejected`、`.edited(String)`、`.failed(String)`。[Source: Curator/Core/Models/RenameSuggestion.swift]
- `RenameReviewDecision` — `.pending`、`.accepted`、`.rejected`、`.edited(String)`。[Source: Curator/Features/Rename/RenameViewModel.swift:8-17]
- `PlannedOperation` — 重命名使用 `.rename(newTitle: String)`。[Source: Curator/Core/Operations/PlannedOperation.swift]
- `ConfirmationRequest` — `operations: [PlannedOperation]`、`confirmationLevel: ConfirmationLevel`、`summary: String`。[Source: Curator/Features/Confirmation/ConfirmationRequest.swift]
- `ConfirmationLevel` — `.none`、`.standard`、`.destructive`。`forOperations(_:)` 自动判定。[Source: Curator/Features/Confirmation/ConfirmationLevel.swift]
- `ExecutionResult` — `successCount`、`failureCount`、`total`、`isFullSuccess`。[Source: Curator/Features/Confirmation/ConfirmationViewModel.swift:10-16]

**确认工作流（复用，不修改）：**
- `ConfirmationViewModel` — `presentConfirmation(request:)` 是唯一入口。已有权限检查、确认路由、批量执行、进度追踪完整实现。[Source: Curator/Features/Confirmation/ConfirmationViewModel.swift]
- `BatchConfirmationSummaryView` — 已实现批量确认摘要 UI。[Source: Curator/Features/Confirmation/BatchConfirmationSummaryView.swift]
- `UndoManagerViewModel` — 提供 `canPerformAction`、`performUndoAction()`。[Source: Curator/Features/Undo/UndoManagerViewModel.swift]

**执行引擎（复用，不修改）：**
- `OperationManager` — `beginBatch`/`executeBatch`/`rollbackBatch`/`rollbackLastBatch` 完整实现。[Source: Curator/Core/Operations/OperationManager.swift]
- `RenameAssetsTool` — Story 6.2 已实现的 SDK 侧重命名执行工具。[Source: Curator/Infrastructure/SDKTools/RenameAssetsTool.swift]
- `LocalFolderRepository` — `updateAsset(_:title:)` 执行实际文件重命名。[Source: Curator/Infrastructure/PhotoSource/LocalFolderRepository.swift]

**结果摘要（复用）：**
- `ResultSummaryViewModel` — Story 5.6 创建的结果摘要 ViewModel。`populateFrom(result:duration:)` 方法。[Source: Curator/Features/ResultSummary/ResultSummaryViewModel.swift]
- `AgentResultSummaryView` — 结果摘要主视图。[Source: Curator/Features/ResultSummary/AgentResultSummaryView.swift]
- **注意**：ResultSummaryViewModel 当前的 `populateFrom` 方法签名为 `(result:ExecutionResult, groups:[DuplicateGroup], reviewStates:[UUID:DuplicateGroupReviewState], removedAssetSizes:[AssetID:Int64], duration:TimeInterval)`，去重专用。重命名结果摘要可能需要新增 populateFrom 变体或在 BatchRenameView 中直接展示 ExecutionResult（复用 BatchApprovalView 的 resultSummary 布局模式）。

**Epic 5 批量审核参考模式（直接对齐）：**
- `BatchApprovalView` — **主要参考模板**。本 Story 的 BatchRenameView 与其架构完全对齐：批量操作按钮 → 确认流程 → 执行结果 → 撤销。[Source: Curator/Features/Deduplication/BatchApprovalView.swift]
- `DuplicateReviewView` — 参考 BatchApprovalView 在底部栏的集成方式。[Source: Curator/Features/Deduplication/DuplicateReviewView.swift]
- `DeduplicationViewModel` — 参考 markAllAsKeep/markAllAsRemove/toDeleteOperations 的实现模式。[Source: Curator/Features/Deduplication/DeduplicationViewModel.swift]

**Agent 集成（复用/小修改）：**
- `AgentExecutionPanel` — `.review` 分支已有重命名审核路径，需传递 confirmationViewModel 和 undoManager。[Source: Curator/Features/AgentExecution/AgentExecutionPanel.swift:87-98]
- `MainWorkspaceView` — 需传递 confirmationViewModel 和 undoManager 到重命名审核路径。[Source: Curator/Features/MainWorkspace/MainWorkspaceView.swift]

### 关键设计决策

#### BatchRenameView 设计

BatchRenameView 作为 RenameReviewView 底部的操作栏，直接参考 BatchApprovalView 模式：

```
┌─────────────────────────────────────────────────┐
│ Rename Review (progress header)                  │
│ [All] [Pending] [Accepted] [Rejected]            │
├─────────────────────────────────────────────────┤
│ RenameSuggestionCard 1                           │
│ RenameSuggestionCard 2                           │
│ ...                                              │
├─────────────────────────────────────────────────┤
│ [全部接受 (N)]    [全部拒绝 (N)]   ← BatchRenameView │
│ *仅在 allReviewed=true 时显示 [执行重命名] 按钮*    │
└─────────────────────────────────────────────────┘
```

**操作流程：**
1. 用户审核建议（逐个 accept/reject/edit）
2. 点击"全部接受"或"全部拒绝"批量处理未审核建议
3. "全部接受"后 → 进入 executeSection → "执行重命名"按钮 → ConfirmationViewModel.presentConfirmation → `.standard` 路由 → BatchConfirmationSummaryView → 用户确认 → OperationManager 执行
4. 执行完成后 → BatchRenameView 显示 ExecutionResult + "撤销"按钮

#### 与 BatchApprovalView 的对比

| 方面 | BatchApprovalView (Epic 5) | BatchRenameView (Epic 6) |
|------|---------------------------|--------------------------|
| 批量标记 | markAllAsKeep / markAllAsRemove | markAllAsAccept / markAllAsReject |
| 操作转换 | toDeleteOperations() → [.delete] | toRenameOperations() → [.rename(newTitle:)] |
| 确认级别 | .destructive（删除是破坏性操作） | .standard（重命名可完全回滚） |
| 结果展示 | 移除数量 + 撤销 | 重命名数量 + 撤销 |
| 危险按钮 | "Remove All" 红色危险样式 | "全部拒绝" 次要样式（非危险） |
| 主要按钮 | "Execute Deletion" 红色填充 | "执行重命名" 系统强调色填充 |

#### ConfirmationLevel 判定

重命名操作的确认级别：
- `.rename` 不是破坏性操作（文件名可完全回滚，不涉及数据丢失）
- `ConfirmationLevel.forOperations(_:)` 应返回 `.standard`
- 这意味着：BatchConfirmationSummaryView 展示摘要 + 执行/取消按钮（无 DestructiveConfirmationSheet 二次确认）
- **必须验证** `ConfirmationLevel.forOperations()` 对 `.rename` 操作确实返回 `.standard`

#### 结果摘要策略

由于 ResultSummaryViewModel 的 `populateFrom` 方法是去重专用的（需要 DuplicateGroup 和 removedAssetSizes），重命名结果摘要采用两种策略之一：

**策略 A（推荐）：直接在 BatchRenameView 中展示 ExecutionResult**
- 复用 BatchApprovalView 的 resultSummary 布局模式
- 展示成功数/失败数 + 撤销按钮
- 简单、直接、无需修改 ResultSummaryViewModel

**策略 B：新增 ResultSummaryViewModel.populateFrom(result:duration:) 重载**
- 通用版本不依赖去重专用数据
- 可复用于后续 Epic 的结果展示
- 需修改 ResultSummaryViewModel

本 Story 优先采用策略 A，与 BatchApprovalView 保持一致。

### 与现有代码的集成点

**新建的文件：**

1. `Curator/Features/Rename/BatchRenameView.swift` — 批量重命名操作栏组件
2. `CuratorTests/Features/Rename/BatchRenameViewModelTests.swift` — ATDD 测试

**修改的文件：**

1. `Curator/Features/Rename/RenameReviewView.swift` — 底部添加 BatchRenameView，接收 confirmationViewModel 和 undoManager 参数
2. `Curator/Features/AgentExecution/AgentExecutionPanel.swift` — 传递 confirmationViewModel 和 undoManager 给 RenameReviewView 的 BatchRenameView
3. `Curator/Features/MainWorkspace/MainWorkspaceView.swift` — 传递 confirmationViewModel 和 undoManager 到重命名审核路径

**不修改的文件：**

- 不修改 `RenameViewModel.swift` — markAllAsAccept/markAllAsReject/toRenameOperations 已由 Story 6.3 实现
- 不修改 `RenameSuggestionCard.swift` — 单建议审核组件不涉及批量操作
- 不修改 `OperationManager.swift` — 批量执行/回滚 API 已完整
- 不修改 `ConfirmationViewModel.swift` — 确认流程已完整
- 不修改 `ConfirmationLevel.swift` — forOperations 自动判定
- 不修改 `BatchConfirmationSummaryView.swift` — 复用现有确认摘要 UI
- 不修改 `RenameAssetsTool.swift` — SDK 侧重命名工具已完成
- 不修改 `ResultSummaryViewModel.swift` — 直接使用 ExecutionResult
- 不修改 `AppDependencies.swift` — 所有依赖已注册

### 不做什么（范围边界）

以下内容在本 Story 中 **不实现**：

- **重命名结果摘要持久化到 SwiftData** — MVP 阶段结果仅在会话中展示
- **重命名结果庆祝动画** — 复用 BatchApprovalView 的结果展示模式，不引入 ResultSummaryViewModel 的庆祝动画
- **重命名历史记录** — 后续 Epic 可能添加
- **费用预估展示** — 已在 EstimateCostTool 中实现
- **RenameSuggestionCard 修改** — 单建议审核组件完成，不涉及批量操作
- **用户偏好语言存储** — 复用 UserDefaults

### NFR 关注点

- **NFR2（60fps 滚动）**：BatchRenameView 是固定底部栏，不影响 LazyVStack 列表滚动性能。
- **NFR3（500ms 进度更新）**：ConfirmationViewModel 的 executionProgress 通过 @Observable 驱动 SwiftUI。
- **NFR6（500MB 内存）**：批量操作通过 OperationManager 逐个执行，不一次性加载所有文件数据。
- **NFR7（UI 保持响应）**：批量执行在后台 Task 中进行。
- **NFR15（零文件损坏）**：重命名只修改文件名，不修改文件内容。通过 OperationManager 快照确保可回滚。
- **NFR16（5 秒内回滚）**：OperationManager.rollbackBatch 已实现 5 秒内回滚保证。
- **UX-DR17（按钮层级）**：BatchRenameView 遵循——"全部接受"次要样式、"全部拒绝"次要样式、"执行重命名"主要样式，每界面最多一个主要按钮。

### Mock 策略

测试中 RenameViewModel 是纯内存操作，不需要 Mock 外部依赖。测试直接构造 RenameSuggestion 数组并调用 ViewModel 方法：

```swift
private func makeSuggestion(
    id: UUID = UUID(),
    originalFileName: String = "IMG_001.jpg",
    suggestedName: String = "sunset-beach.jpg",
    confidence: Double = 0.9
) -> RenameSuggestion {
    RenameSuggestion(
        id: id,
        assetID: AssetID(rawValue: "test-asset-\(id.uuidString)"),
        originalFileName: originalFileName,
        suggestedName: suggestedName,
        confidence: confidence,
        status: .pending
    )
}
```

ConfirmationLevel 测试直接调用 `ConfirmationLevel.forOperations(operations)` 验证返回值。

### 项目结构说明

本 Story 新增的文件：

```
Curator/
├── Features/
│   └── Rename/
│       └── BatchRenameView.swift             # 新建：批量重命名操作栏组件
```

修改的文件：

```
Curator/
├── Features/
│   ├── Rename/
│   │   └── RenameReviewView.swift            # 修改：底部添加 BatchRenameView
│   ├── AgentExecution/
│   │   └── AgentExecutionPanel.swift         # 修改：传递 confirmationViewModel/undoManager
│   └── MainWorkspace/
│       └── MainWorkspaceView.swift           # 修改：传递依赖到重命名审核路径
```

测试文件：

```
CuratorTests/
├── Features/
│   └── Rename/
│       └── BatchRenameViewModelTests.swift   # 新建：ATDD 测试
```

### 与 Epic 5 批量审核的对比

| 方面 | BatchApprovalView (Epic 5) | BatchRenameView (Epic 6) |
|------|---------------------------|--------------------------|
| 数据单元 | DuplicateGroup（每组多个 PhotoAsset） | RenameSuggestion（每条一个 PhotoAsset） |
| 批量操作 | markAllAsKeep / markAllAsRemove | markAllAsAccept / markAllAsReject |
| 转换输出 | toDeleteOperations() → [.delete] | toRenameOperations() → [.rename(newTitle:)] |
| 确认级别 | .destructive | .standard |
| 危险按钮 | "Remove All"（红色） | 无（"全部拒绝"是次要样式） |
| 结果摘要 | 移除数 + 节省空间 | 重命名数 + 撤销 |
| 卡片组件 | PhotoComparisonCard | RenameSuggestionCard |
| 进度展示 | "Reviewed X / Y groups" | "Reviewed X / Y suggestions" |

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 6.4] -- 原始需求定义（批量重命名执行）
- [Source: _bmad-output/planning-artifacts/architecture.md#Features/Rename] -- Rename 功能目录结构
- [Source: _bmad-output/planning-artifacts/architecture.md#决策1] -- 分层架构
- [Source: _bmad-output/planning-artifacts/architecture.md#决策7] -- 操作回滚系统（快照+回滚）
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#AgentResultSummary] -- UX-DR6 成果摘要组件
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#Button Hierarchy] -- UX-DR17 按钮层级
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#操作确认模式] -- UX-DR11 确认分级
- [Source: _bmad-output/planning-artifacts/prd.md#FR28] -- 批量重命名执行
- [Source: _bmad-output/planning-artifacts/prd.md#FR33] -- 破坏性操作前需用户批准
- [Source: _bmad-output/planning-artifacts/prd.md#FR34] -- 可配置时间窗口内撤销
- [Source: _bmad-output/planning-artifacts/prd.md#FR35] -- 批量修改前创建元数据快照
- [Source: _bmad-output/planning-artifacts/prd.md#FR36] -- 批量操作中途失败自动回滚
- [Source: _bmad-output/planning-artifacts/prd.md#NFR15] -- 零文件损坏
- [Source: _bmad-output/planning-artifacts/prd.md#NFR16] -- 5 秒内回滚
- [Source: _bmad-output/implementation-artifacts/6-1-content-analysis-and-naming.md] -- 前置 Story 6.1
- [Source: _bmad-output/implementation-artifacts/6-2-rename-sdk-tools.md] -- 前置 Story 6.2（RenameAssetsTool）
- [Source: _bmad-output/implementation-artifacts/6-3-rename-review-ui.md] -- 前置 Story 6.3（RenameViewModel + RenameReviewView）
- [Source: _bmad-output/implementation-artifacts/5-5-batch-approval-and-execution.md] -- **主要参考**：Epic 5 批量审核模式
- [Source: _bmad-output/implementation-artifacts/5-6-dedup-result-summary.md] -- 参考：结果摘要模式
- [Source: _bmad-output/project-context.md#Critical Implementation Rules] -- Swift 6 严格并发、actor 隔离、Sendable
- [Source: _bmad-output/project-context.md#Code Patterns] -- SwiftUI 视图模式、命名规范
- [Source: _bmad-output/project-context.md#Testing Rules] -- ATDD 风格、Mock 模式
- [Source: Curator/Features/Rename/RenameViewModel.swift] -- **直接复用**：markAllAsAccept/markAllAsReject/toRenameOperations 已实现
- [Source: Curator/Features/Rename/RenameReviewView.swift] -- **需修改**：底部添加 BatchRenameView
- [Source: Curator/Features/Deduplication/BatchApprovalView.swift] -- **主要参考**：批量操作栏模式
- [Source: Curator/Features/Confirmation/ConfirmationViewModel.swift] -- **复用**：确认工作流
- [Source: Curator/Features/Confirmation/ConfirmationLevel.swift] -- **复用**：确认级别判定
- [Source: Curator/Features/Confirmation/BatchConfirmationSummaryView.swift] -- **复用**：确认摘要 UI
- [Source: Curator/Core/Operations/OperationManager.swift] -- **复用**：批量执行/回滚
- [Source: Curator/Core/Operations/PlannedOperation.swift] -- **复用**：.rename(newTitle:) case
- [Source: Curator/Features/AgentExecution/AgentExecutionPanel.swift] -- **需修改**：传递 confirmationViewModel/undoManager
- [Source: Curator/Features/MainWorkspace/MainWorkspaceView.swift] -- **需修改**：传递依赖
- [Source: Curator/Infrastructure/SDKTools/RenameAssetsTool.swift] -- SDK 侧工具（不修改，已完整）
- [Source: Curator/Features/ResultSummary/ResultSummaryViewModel.swift] -- 参考（不修改，采用策略 A）

## Dev Agent Record

### Agent Model Used

GLM-5.1

### Debug Log References

No blocking issues encountered during implementation.

### Completion Notes List

- Created BatchRenameView.swift mirroring BatchApprovalView pattern, adapted for rename (accept/reject instead of keep/remove)
- BatchRenameView uses `.standard` confirmation level (non-destructive) since renames are reversible
- Result summary uses Strategy A (direct ExecutionResult display in BatchRenameView) as recommended in Dev Notes
- RenameReviewView updated to accept confirmationViewModel and undoManager parameters, with BatchRenameView at bottom
- AgentExecutionPanel updated to pass confirmationViewModel and undoManager through to RenameReviewView
- MainWorkspaceView already passed these parameters to AgentExecutionPanel -- no changes needed there
- Task 4.3 (onResultSummaryDone/onResultSummaryUndo) already handled by existing MainWorkspaceView code path through the confirmation overlay
- All 15 ATDD tests activated and passing (7 P0 + 8 P1)
- Full regression suite: 822 tests, 0 failures

### File List

**New Files:**
- Curator/Features/Rename/BatchRenameView.swift

**Modified Files:**
- Curator/Features/Rename/RenameReviewView.swift
- Curator/Features/AgentExecution/AgentExecutionPanel.swift

**Activated Test Files (existing, XCTSkip removed):**
- CuratorTests/Features/Rename/BatchRenameViewModelTests.swift

### Review Findings
