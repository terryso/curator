# Story 5.5: 批量审批与执行

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a 用户，
I want 能够批量审批所有重复项，
so that 在处理大量重复照片时节省时间。

## Acceptance Criteria

1. **AC1: 批量操作按钮（FR23, UX-DR17）**
   **Given** 审核界面中存在多个待处理的重复组
   **When** 用户点击"全部移除"或"全部保留"按钮
   **Then** BatchApprovalView 展示批量确认摘要，列出将要执行的操作数量
   **And** 用户确认后通过 OperationManager 批量执行操作

2. **AC2: 执行结果摘要（FR23）**
   **Given** 用户执行了批量操作
   **When** 操作完成后
   **Then** 系统展示执行结果摘要（成功数、失败数、跳过数）
   **And** 提供撤销选项以回滚批量操作

3. **AC3: 部分失败容错（NFR16, FR36）**
   **Given** 批量操作正在进行
   **When** 某个操作失败
   **Then** 系统跳过失败项继续处理后续项
   **And** 操作完成后汇总所有失败项供用户处理

4. **AC4: 审核数据到确认工作流的桥接**
   **Given** 用户在去重审核界面完成审核
   **When** 点击"全部移除"触发批量执行
   **Then** DeduplicationViewModel.assetsToRemove() 的结果转换为 [PlannedOperation]（.delete 类型）
   **And** 通过 ConfirmationViewModel.presentConfirmation() 路由到正确的确认级别（.destructive）

5. **AC5: DuplicateGroup 数据流打通**
   **Given** AnalyzeDuplicatesTool 产出去重分析结果
   **When** AgentEvent 通过 AsyncStream 传递结果
   **Then** MainWorkspaceView.extractDuplicateGroups 能正确解析 AgentJob 中的 DuplicateGroup 数据
   **And** 数据传递给 DeduplicationViewModel.loadGroups() 显示审核界面

6. **AC6: 与现有确认工作流的集成**
   **Given** 批量删除操作触发确认流程
   **When** ConfirmationLevel.forOperations() 检测到 .delete 操作
   **Then** 自动路由为 .destructive 级别，触发 BatchConfirmationSummaryView + DestructiveConfirmationSheet 二次确认
   **And** 确认后通过 OperationManager 安全执行，支持 5 秒内回滚（NFR16）

## Tasks / Subtasks

- [x] Task 1: 实现 BatchApprovalView 组件 (AC: #1)
  - [x] 1.1 创建 `Curator/Features/Deduplication/BatchApprovalView.swift`
  - [x] 1.2 添加"全部保留"按钮（次要样式，描边），将所有 pending 组标记为 `.keep`
  - [x] 1.3 添加"全部移除"按钮（危险样式，红色），将所有 pending 组标记为 `.remove`
  - [x] 1.4 点击"全部移除"后先在 DeduplicationViewModel 批量更新状态，再触发 ConfirmationViewModel 确认流程
  - [x] 1.5 按钮仅在 `allReviewed` 为 false 时显示"全部保留/移除"；`allReviewed` 为 true 时显示"执行删除"按钮
  - [x] 1.6 遵循 UX-DR17 按钮层级：每界面最多一个主要按钮，危险操作需二次确认

- [x] Task 2: 扩展 DeduplicationViewModel 支持批量操作 (AC: #1, #2)
  - [x] 2.1 添加 `markAllAsKeep()` 方法 — 将所有 pending 组标记为 `.keep`
  - [x] 2.2 添加 `markAllAsRemove()` 方法 — 将所有 pending 组标记为 `.remove`
  - [x] 2.3 添加 `toDeleteOperations() -> [PlannedOperation]` — 将 `.remove` 状态组转换为 `.delete` 类型 PlannedOperation 列表
  - [x] 2.4 添加 `executionResult: ExecutionResult?` 可选属性，存储批量执行结果（由 ConfirmationViewModel 管理，BatchApprovalView 直接观察）
  - [x] 2.5 添加 `isExecuting: Bool` 属性追踪执行状态（由 ConfirmationViewModel.isExecuting 管理）
  - [x] 2.6 添加 `executeBatchConfirmation(summary:)` 方法：调用 ConfirmationViewModel.presentConfirmation（在 BatchApprovalView 中直接调用）

- [x] Task 3: 打通 DuplicateGroup 数据流 (AC: #5)
  - [x] 3.1 在 SDKMessageBridge 中检测 analyze_duplicates 工具输出并将 JSON 写入 StepResult.data["duplicateGroups"]
  - [x] 3.2 在 AgentJob 中存储 stepResults 列表以支持数据提取
  - [x] 3.3 在 MainWorkspaceView 中实现 `extractDuplicateGroups(from:)` 和 `extractDuplicateGroupsFromStepResult(_:)` — 从 AgentJob 的 stepResults 中解析 DuplicateGroup 列表
  - [x] 3.4 验证 AgentJob.review 状态时的数据传递完整性

- [x] Task 4: 集成 DuplicateReviewView 与 BatchApprovalView (AC: #1, #4, #6)
  - [x] 4.1 在 DuplicateReviewView 底部添加 BatchApprovalView 组件
  - [x] 4.2 BatchApprovalView 接收 DeduplicationViewModel 和 ConfirmationViewModel 引用
  - [x] 4.3 "全部移除"按钮生成 PlannedOperation 列表并调用 ConfirmationViewModel.presentConfirmation
  - [x] 4.4 ConfirmationLevel 自动判定为 .destructive（因为包含 .delete 操作），触发 DestructiveConfirmationSheet
  - [x] 4.5 确认后 OperationManager 执行批量删除，完成后更新 ConfirmationViewModel.executionResult

- [x] Task 5: 执行结果展示与撤销 (AC: #2, #3)
  - [x] 5.1 在 BatchApprovalView 中展示 ExecutionResult（成功数/失败数/总数）
  - [x] 5.2 失败项列表展示（如有），包含失败原因摘要
  - [x] 5.3 添加"撤销操作"按钮，调用 UndoManagerViewModel.performUndoAction()
  - [x] 5.4 通过 UndoManagerViewModel 提供撤销路径信息

- [x] Task 6: ATDD 测试 (AC: #1, #2, #3, #4, #5, #6)
  - [x] 6.1 创建 `CuratorTests/Features/Deduplication/BatchApprovalViewModelTests.swift`（17 个测试）
  - [x] 6.2 [P0] testMarkAllAsKeepUpdatesAllStates — 全部标记保留后所有状态为 .keep
  - [x] 6.3 [P0] testMarkAllAsRemoveUpdatesAllStates — 全部标记移除后所有状态为 .remove
  - [x] 6.4 [P0] testToDeleteOperationsReturnsCorrectOperations — toDeleteOperations 返回正确 PlannedOperation 列表（类型 .delete，ID 匹配）
  - [x] 6.5 [P0] testToDeleteOperationsExcludesKeepGroups — 标记为 .keep 的组不出现在删除操作列表中
  - [x] 6.6 [P0] testExtractDuplicateGroupsParsesStepResult — extractDuplicateGroups 正确解析包含 JSON 数据的 StepResult
  - [x] 6.7 [P0] testExtractDuplicateGroupsReturnsEmptyForNoData — 无 StepResult 数据时返回空数组
  - [x] 6.8 [P1] testBatchApprovalTriggersDestructiveConfirmation — 批量移除操作触发 .destructive 确认级别
  - [x] 6.9 [P1] testExecutionResultUpdatesOnCompletion — 执行完成后 executionResult 被正确设置
  - [x] 6.10 [P1] testMarkAllPreservesAlreadyReviewedStates — markAll 不覆盖已审核的组（仅更新 pending）
  - [x] 6.11 构建通过 + 全部现有测试通过（733 tests, 0 failures）

## Dev Notes

### 架构约束

1. **ViewModel 必须 `@MainActor @Observable`**：所有 UI 状态更新在主线程。[Source: project-context.md#Critical Implementation Rules]
2. **禁止使用 `Task` 作为类型名**：使用 `AgentJob`、`AgentWork` 等前缀。[Source: CLAUDE.md]
3. **跨层数据传递只用值类型**：PlannedOperation、ConfirmationRequest 都是 Sendable struct。[Source: project-context.md#Critical Implementation Rules]
4. **SwiftUI 视图不超过 200 行**：BatchApprovalView 独立，DuplicateReviewView 添加底部按钮。[Source: project-context.md#Code Patterns]
5. **Preview 覆盖亮色/暗色模式**：自定义组件必须提供 Preview。[Source: project-context.md#Code Patterns]
6. **三层错误体系**：Infrastructure → Domain → UserFacing 错误映射。[Source: project-context.md#三层错误体系]
7. **破坏性操作需二次确认**：删除操作自动路由为 `.destructive` 级别。[Source: ux-design-specification.md#操作确认模式]

### 前置 Story 的已有实现（必须复用）

**数据模型（不修改）：**
- `DuplicateGroup` — `id: UUID`、`assets: [PhotoAsset]`、`similarityScore: Double`、`reason: String?`、`thumbnails: [AssetID: Data]`、`status: DuplicateGroupStatus`。[Source: Curator/Core/Models/DuplicateGroup.swift]
- `PhotoAsset` — `id: AssetID`、`metadata: AssetMetadata`、`thumbnailData: Data?`。[Source: Curator/Core/Models/PhotoAsset.swift]
- `AssetID` — `rawValue: String`，Sendable, Hashable, Codable。[Source: Curator/Core/Models/AssetID.swift]
- `PlannedOperation` — `operationType: OperationType`、`assetID: AssetID`、`parameters: OperationParameters`。`.delete` case 已定义。[Source: Curator/Core/Operations/PlannedOperation.swift]
- `OperationType` — `.rename`、`.delete`、`.move`、`.metadataChange`。[Source: Curator/Core/Operations/OperationType.swift]
- `ConfirmationRequest` — `operations: [PlannedOperation]`、`confirmationLevel: ConfirmationLevel`、`summary: String`、`undoPathDescription: String`。[Source: Curator/Features/Confirmation/ConfirmationRequest.swift]
- `ConfirmationLevel` — `.none`、`.standard`、`.destructive`。`forOperations(_:)` 自动判定。[Source: Curator/Features/Confirmation/ConfirmationLevel.swift]
- `ExecutionResult` — `successCount`、`failureCount`、`total`、`isFullSuccess`。[Source: Curator/Features/Confirmation/ConfirmationViewModel.swift]
- `ExecutionProgress` — `completed`、`total`。[Source: Curator/Features/Confirmation/ConfirmationViewModel.swift]
- `StepResult` — `stepID: UUID`、`message: String`、`data: [String: String]`。[Source: Curator/Core/Agent/StepResult.swift]

**ViewModel（复用 + 扩展）：**
- `DeduplicationViewModel` — 已有 `assetsToRemove()`、`markAsKeep(groupID:)`、`markAsRemove(groupID:)`、`allReviewed`。**需扩展** `markAllAsKeep()`、`markAllAsRemove()`、`toDeleteOperations()`。[Source: Curator/Features/Deduplication/DeduplicationViewModel.swift]
- `ConfirmationViewModel` — 已有完整的确认流程：权限检查、确认路由、批量执行、进度追踪。`presentConfirmation(request:)` 是唯一入口。[Source: Curator/Features/Confirmation/ConfirmationViewModel.swift]
- `UndoManagerViewModel` — 提供 `canUndo`、`undoLastBatch()` 撤销操作。[Source: Curator/Features/Undo/UndoManagerViewModel.swift]

**UI 组件（复用）：**
- `BatchConfirmationSummaryView` — 已实现批量确认摘要 UI（操作数量、缩略图预览、执行/取消按钮）。[Source: Curator/Features/Confirmation/BatchConfirmationSummaryView.swift]
- `DestructiveConfirmationSheet` — 已实现二次确认 Sheet（警告图标、摘要、确认/取消按钮）。[Source: Curator/Features/Confirmation/DestructiveConfirmationSheet.swift]
- `DuplicateReviewView` — 已实现审核列表，**需修改**底部添加 BatchApprovalView。[Source: Curator/Features/Deduplication/DuplicateReviewView.swift]
- `PhotoComparisonCard` — 已实现照片对比卡片，不修改。[Source: Curator/Features/Deduplication/PhotoComparisonCard.swift]

**Agent 基础设施（复用 + 小修改）：**
- `AgentJob` — `@Observable` 状态机。`stepResults` 属性存储已完成步骤的结果。[Source: Curator/Core/Agent/AgentJob.swift]
- `AgentEvent` — `.stepCompleted(stepID:result:)` 携带 StepResult。[Source: Curator/Core/Agent/AgentEvent.swift]
- `StepResult` — `data: [String: String]` 字典可携带额外数据。**需约定 key**（如 `"duplicateGroups"`）存放 JSON 编码的 DuplicateGroup 数组。[Source: Curator/Core/Agent/StepResult.swift]
- `SDKMessageBridge` — 将 SDK 工具结果映射为 AgentEvent。[Source: Curator/Core/Agent/SDKMessageBridge.swift]

**OperationManager（复用，不修改）：**
- `OperationManager` — `beginBatch`/`executeBatch`/`rollbackBatch`/`rollbackLastBatch` 完整实现。[Source: Curator/Core/Operations/OperationManager.swift]
- `OperationManager.executeSingleOperation` 已处理 `.delete` case：调用 `repository.deleteAssets`。[Source: Curator/Core/Operations/OperationManager.swift:219]
- 删除回滚通过 `FileManager.trashItem` 实现（从 macOS Trash 恢复）。[Source: Curator/Core/Operations/OperationManager.swift:299-317]

**AppDependencies（不修改）：**
- `deduplicationViewModel` — 已注册。[Source: Curator/App/AppDependencies.swift:66]
- `confirmationViewModel` — 已注册。[Source: Curator/App/AppDependencies.swift:47]
- `undoManagerViewModel` — 已注册。[Source: Curator/App/AppDependencies.swift:44]
- `operationManager` — 已注册。[Source: Curator/App/AppDependencies.swift:38]

**MainWorkspaceView（需修改）：**
- `extractDuplicateGroups(from:)` — 当前返回空数组 stub，**需实现真实解析逻辑**。[Source: Curator/Features/MainWorkspace/MainWorkspaceView.swift:381-386]

**SDK 工具（需小修改）：**
- `AnalyzeDuplicatesTool` — 分析结果需写入 StepResult.data 字典。当前返回纯文本 message。[Source: Curator/Infrastructure/SDKTools/AnalyzeDuplicatesTool.swift]

### 关键设计决策

#### BatchApprovalView 设计

BatchApprovalView 作为 DuplicateReviewView 底部的操作栏：

```
┌─────────────────────────────────────────────────┐
│ Duplicate Review (progress header)              │
│ [All] [Pending] [Marked for Removal]            │
├─────────────────────────────────────────────────┤
│ PhotoComparisonCard 1                           │
│ PhotoComparisonCard 2                           │
│ ...                                             │
├─────────────────────────────────────────────────┤
│ [全部保留 (N)]    [全部移除 (N)]    ← BatchApprovalView │
│ *仅在 allReviewed=true 时显示 [执行删除] 按钮*     │
└─────────────────────────────────────────────────┘
```

**操作流程：**
1. 用户审核组（逐个 keep/remove）
2. 点击"全部保留"或"全部移除"批量处理未审核组
3. "全部移除"后 → ConfirmationViewModel.presentConfirmation → .destructive 路由 → BatchConfirmationSummaryView → DestructiveConfirmationSheet → OperationManager 执行
4. 执行完成后 → BatchApprovalView 显示 ExecutionResult + "撤销"按钮

#### DuplicateGroup 数据流打通方案

**问题：** `MainWorkspaceView.extractDuplicateGroups` 当前返回 `[]`，因为 AgentEvent 管道不直接携带 DuplicateGroup 数据。

**解决方案：通过 StepResult.data 字典传递 JSON**

1. `AnalyzeDuplicatesTool` 在工具结果中将 DuplicateGroup 列表编码为 JSON，写入 `StepResult.data["duplicateGroups"]`
2. `SDKMessageBridge` 将工具结果映射为 `AgentEvent.stepCompleted(stepID:result:)`，StepResult.data 携带 JSON 字符串
3. `MainWorkspaceView.extractDuplicateGroups(from:)` 遍历 AgentJob 的 stepResults，查找包含 `"duplicateGroups"` key 的 StepResult，解码为 `[DuplicateGroup]`

```swift
// AnalyzeDuplicatesTool 中：
let groupsJSON = try JSONEncoder().encode(groups)
let stepResult = StepResult(
    stepID: stepID,
    message: "Found \(groups.count) duplicate groups",
    data: ["duplicateGroups": String(data: groupsJSON, encoding: .utf8) ?? ""]
)

// MainWorkspaceView.extractDuplicateGroups 中：
private static func extractDuplicateGroups(from job: AgentJob) -> [DuplicateGroup] {
    // 遍历 AgentJob 已记录的 stepResults
    // 查找 data["duplicateGroups"] 不为空的 StepResult
    // 解码 JSON 为 [DuplicateGroup]
}
```

**注意：** 需要确认 AgentJob 是否暴露了 stepResults 列表。如果不暴露，需要添加一个属性来存储。检查 `AgentJob.swift` 的公开 API。

#### DeduplicationViewModel 批量操作扩展

在 ViewModel 中添加方法而非修改已有方法：

```swift
// 批量标记所有未审核组
func markAllAsKeep() {
    for group in groups where reviewStates[group.id] == .pending {
        reviewStates[group.id] = .keep
    }
}

func markAllAsRemove() {
    for group in groups where reviewStates[group.id] == .pending {
        reviewStates[group.id] = .remove
    }
}

// 转换为 PlannedOperation 列表
func toDeleteOperations() -> [PlannedOperation] {
    assetsToRemove().map { assetID in
        PlannedOperation(
            operationType: .delete,
            assetID: assetID,
            parameters: .delete
        )
    }
}
```

#### 执行结果展示

执行完成后，ConfirmationViewModel 的 `executionResult` 被设置。BatchApprovalView 观察该结果并展示：

```swift
// BatchApprovalView 中
if let result = confirmationViewModel.executionResult {
    resultSummary(result)
}

@ViewBuilder
private func resultSummary(_ result: ExecutionResult) -> some View {
    VStack {
        Text("操作完成：\(result.successCount) 成功，\(result.failureCount) 失败")
        if !result.isFullSuccess {
            // 展示失败详情
        }
        Button("撤销操作") { undoManager?.undoLastBatch() }
    }
}
```

### 与现有代码的集成点

**新建的文件：**

1. `Curator/Features/Deduplication/BatchApprovalView.swift` — 批量审批操作栏组件
2. `CuratorTests/Features/Deduplication/BatchApprovalViewModelTests.swift` — ATDD 测试

**修改的文件：**

1. `Curator/Features/Deduplication/DeduplicationViewModel.swift` — 添加 markAllAsKeep/markAllAsRemove/toDeleteOperations/isExecuting/executionResult
2. `Curator/Features/Deduplication/DuplicateReviewView.swift` — 底部添加 BatchApprovalView
3. `Curator/Features/MainWorkspace/MainWorkspaceView.swift` — 实现 extractDuplicateGroups 真实逻辑
4. `Curator/Infrastructure/SDKTools/AnalyzeDuplicatesTool.swift` — 在工具结果中写入 DuplicateGroup JSON
5. `Curator/Core/Agent/AgentJob.swift` — 可能需要暴露 stepResults 列表供 extractDuplicateGroups 访问

**不修改的文件：**

- 不修改 `OperationManager.swift` — 批量执行/回滚 API 已完整
- 不修改 `ConfirmationViewModel.swift` — 确认流程已完整，通过 presentConfirmation 传入即可
- 不修改 `ConfirmationLevel.swift` — forOperations 自动判定 .destructive
- 不修改 `BatchConfirmationSummaryView.swift` — 复用现有确认摘要 UI
- 不修改 `DestructiveConfirmationSheet.swift` — 复用现有二次确认 UI
- 不修改 `PhotoComparisonCard.swift` — 单组审核组件不涉及批量操作
- 不修改 `AppDependencies.swift` — 所有依赖已注册
- 不修改 `PlannedOperation.swift` — .delete case 已定义

### 不做什么（范围边界）

以下内容在本 Story 中 **不实现**：

- **去重结果摘要（AgentResultSummary）** — Story 5.6 职责（庆祝动画、节省空间统计）
- **费用预估展示** — Story 2.6 已实现 CostEstimateCard
- **键盘导航增强** — 已从 Story 5.4 deferred，全局处理
- **QuickLook 放大** — 已从 Story 5.4 deferred，全局处理
- **PhotoComparisonCard 修改** — 单组审核组件完成，不涉及批量操作
- **其他 SDK 工具修改** — 仅修改 AnalyzeDuplicatesTool 以输出结构化数据

### NFR 关注点

- **NFR2（60fps 滚动）**：BatchApprovalView 是固定底部栏，不影响列表滚动性能。
- **NFR3（500ms 进度更新）**：ConfirmationViewModel 的 executionProgress 通过 @Observable 驱动 SwiftUI，远快于 500ms。
- **NFR6（500MB 内存）**：批量操作通过 OperationManager 逐个执行，不一次性加载所有文件数据。
- **NFR7（UI 保持响应）**：批量执行在后台 Task 中进行，ConfirmationViewModel 是 @MainActor 但执行操作在 actor 内。
- **NFR15（零文件损坏）**：删除操作通过 FileManager.trashItem（移至废纸篓），不直接删除文件。
- **NFR16（5 秒回滚）**：OperationManager.rollbackBatch 已实现 5 秒内回滚保证。
- **UX-DR17（按钮层级）**：BatchApprovalView 遵循——"全部保留"为次要样式（描边），"全部移除"为危险样式（红色），每界面最多一个主要按钮。

### 项目结构说明

本 Story 新增的文件：

```
Curator/
└── Features/
    └── Deduplication/
        └── BatchApprovalView.swift          # 新建：批量审批操作栏组件
```

修改的文件：

```
Curator/
├── Core/
│   └── Agent/
│       └── AgentJob.swift                   # 修改：可能需暴露 stepResults 属性
├── Features/
│   ├── Deduplication/
│   │   ├── DeduplicationViewModel.swift     # 修改：添加批量操作方法
│   │   └── DuplicateReviewView.swift        # 修改：底部添加 BatchApprovalView
│   └── MainWorkspace/
│       └── MainWorkspaceView.swift          # 修改：实现 extractDuplicateGroups
└── Infrastructure/
    └── SDKTools/
        └── AnalyzeDuplicatesTool.swift       # 修改：输出结构化 JSON 数据
```

测试文件：

```
CuratorTests/
└── Features/
    └── Deduplication/
        └── BatchApprovalViewModelTests.swift  # 新建：ATDD 测试
```

### 与后续 Story 的关系

**本 Story（5.5）完成后：**

- **Story 5.6（去重结果摘要）** — 批量执行完成后展示 AgentResultSummary，显示移除数量、节省空间、庆祝动画。本 Story 的 ExecutionResult 为 5.6 提供数据基础。
- **Epic 6（智能重命名）** — BatchApprovalView 的批量操作模式可复用于批量重命名确认流程。

### Mock 策略

测试中需要 Mock 以下依赖：

```swift
// Mock ConfirmationViewModel（用于测试批量确认触发）
// Mock OperationManager（用于测试批量执行流程）
// Mock AgentJob（用于测试 extractDuplicateGroups 解析）

// DuplicateGroup 测试数据工厂（复用 Story 5.4 的 makeDuplicateGroup）
```

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 5.5] — 原始需求定义（批量审批与执行）
- [Source: _bmad-output/planning-artifacts/architecture.md#Features/Deduplication] — Deduplication 目录结构，含 BatchApprovalView
- [Source: _bmad-output/planning-artifacts/architecture.md#决策1] — 分层架构
- [Source: _bmad-output/planning-artifacts/architecture.md#决策2] — Agent 执行引擎（状态机、review 状态）
- [Source: _bmad-output/planning-artifacts/architecture.md#决策7] — 操作回滚系统（快照+回滚）
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#操作确认模式] — UX-DR11 确认分级
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#Button Hierarchy] — UX-DR17 按钮层级
- [Source: _bmad-output/planning-artifacts/prd.md#FR23] — 批量批准或批量拒绝
- [Source: _bmad-output/planning-artifacts/prd.md#FR33] — 破坏性操作前需用户批准
- [Source: _bmad-output/planning-artifacts/prd.md#FR34] — 可配置时间窗口内撤销
- [Source: _bmad-output/planning-artifacts/prd.md#FR35] — 批量修改前创建元数据快照
- [Source: _bmad-output/planning-artifacts/prd.md#FR36] — 批量操作中途失败自动回滚
- [Source: _bmad-output/planning-artifacts/prd.md#NFR15] — 零文件损坏
- [Source: _bmad-output/planning-artifacts/prd.md#NFR16] — 5 秒内回滚
- [Source: _bmad-output/project-context.md#Critical Implementation Rules] — Swift 6 严格并发、@MainActor、Sendable
- [Source: _bmad-output/project-context.md#Code Patterns] — SwiftUI 视图模式、命名规范
- [Source: _bmad-output/project-context.md#Testing Rules] — ATDD 风格、Mock 模式
- [Source: _bmad-output/implementation-artifacts/5-4-dedup-review-ui.md] — Story 5.4 实现（去重审核界面），含 deferred work：extractDuplicateGroups
- [Source: _bmad-output/implementation-artifacts/deferred-work.md#Story 5.4] — Deferred: extractDuplicateGroups、keyboard navigation
- [Source: Curator/Core/Models/DuplicateGroup.swift] — DuplicateGroup 模型（复用）
- [Source: Curator/Core/Operations/PlannedOperation.swift] — PlannedOperation（.delete case 复用）
- [Source: Curator/Core/Operations/OperationManager.swift] — 批量执行/回滚（复用）
- [Source: Curator/Core/Operations/OperationType.swift] — OperationType（复用）
- [Source: Curator/Core/Agent/AgentEvent.swift] — AgentEvent.stepCompleted（复用）
- [Source: Curator/Core/Agent/StepResult.swift] — StepResult.data 字典（复用）
- [Source: Curator/Features/Confirmation/ConfirmationViewModel.swift] — 确认工作流（复用）
- [Source: Curator/Features/Confirmation/ConfirmationRequest.swift] — ConfirmationRequest（复用）
- [Source: Curator/Features/Confirmation/ConfirmationLevel.swift] — ConfirmationLevel.forOperations（复用）
- [Source: Curator/Features/Confirmation/BatchConfirmationSummaryView.swift] — 批量确认摘要 UI（复用）
- [Source: Curator/Features/Confirmation/DestructiveConfirmationSheet.swift] — 二次确认 UI（复用）
- [Source: Curator/Features/Deduplication/DeduplicationViewModel.swift] — ViewModel（扩展）
- [Source: Curator/Features/Deduplication/DuplicateReviewView.swift] — 审核界面（修改）
- [Source: Curator/Features/MainWorkspace/MainWorkspaceView.swift] — extractDuplicateGroups（实现）
- [Source: Curator/Infrastructure/SDKTools/AnalyzeDuplicatesTool.swift] — SDK 工具（修改）
- [Source: Curator/App/AppDependencies.swift] — 依赖注入容器（不修改，已完整）

## Dev Agent Record

### Agent Model Used

Claude GLM-5.1

### Debug Log References

No debug issues encountered. Build succeeded on first attempt after all implementations. All 733 tests pass with 0 failures.

### Completion Notes List

- Task 1: Created BatchApprovalView.swift with "Keep All" (bordered secondary) and "Remove All" (red destructive) buttons. When allReviewed=true, shows "Execute Deletion" button. Displays ExecutionResult with undo option after completion. Follows UX-DR17 button hierarchy.
- Task 2: Extended DeduplicationViewModel with markAllAsKeep(), markAllAsRemove() (both only update pending groups, preserving already-reviewed states), and toDeleteOperations() (reuses assetsToRemove() to generate .delete PlannedOperations). executionResult and isExecuting are managed by ConfirmationViewModel directly, observed by BatchApprovalView.
- Task 3: Implemented full DuplicateGroup data flow: (1) AgentJob now stores stepResults list, (2) SDKMessageBridge detects analyze_duplicates output and writes JSON into StepResult.data["duplicateGroups"], (3) MainWorkspaceView.extractDuplicateGroups(from:) iterates stepResults, (4) extractDuplicateGroupsFromStepResult() parses JSON into [DuplicateGroup]. Also added DuplicateGroupStatus.init(stringValue:) for JSON deserialization.
- Task 4: Integrated BatchApprovalView into DuplicateReviewView bottom bar. Updated DuplicateReviewView to accept confirmationViewModel and undoManager parameters. Updated AgentExecutionPanel to pass these through from MainWorkspaceView.
- Task 5: BatchApprovalView resultSummary section shows success/failure counts and undo button using UndoManagerViewModel.
- Task 6: All 17 ATDD tests pass (6 P0 + 11 P1). Full suite: 733 tests, 0 failures.

### File List

New files:
- Curator/Features/Deduplication/BatchApprovalView.swift

Modified files:
- Curator/Features/Deduplication/DeduplicationViewModel.swift
- Curator/Features/Deduplication/DuplicateReviewView.swift
- Curator/Features/MainWorkspace/MainWorkspaceView.swift
- Curator/Features/AgentExecution/AgentExecutionPanel.swift
- Curator/Core/Agent/AgentJob.swift
- Curator/Core/Agent/SDKMessageBridge.swift
- Curator/Core/Models/DuplicateGroup.swift

### Change Log

- 2026-04-24: Implemented Story 5.5 Batch Approval and Execution — all 6 tasks complete, 17 ATDD tests passing, 733 total tests passing with 0 failures.

### Review Findings

- [x] [Review][Patch] isAnalyzeDuplicatesOutput uses fragile string-contains heuristic instead of tool-name tracking [SDKMessageBridge.swift:134-136] -- **Fixed**: Replaced content sniffing with tool-name tracking via `toolNameMap` dictionary. `mapToolUse` records tool name, `mapToolResult` checks it.
- [x] [Review][Patch] markAllForRemoval() immediately triggers confirmation without preserving rollback state [BatchApprovalView.swift:174-177] -- **Fixed**: Separated into two-step flow. "Remove All" now only marks groups, user must then click "Execute Deletion" in executeSection.
- [x] [Review][Patch] extractDuplicateGroupsFromStepResult silently skips malformed entries with no logging [MainWorkspaceView.swift:414-422] -- **Fixed**: Added `Logger` warning for skipped entries and length-mismatched arrays.
- [x] [Review][Patch] DuplicateGroupStatus.init(stringValue:) silently defaults to .pending for unrecognized values [DuplicateGroup.swift:33] -- **Fixed**: Added `Logger` warning for unrecognized values before defaulting to .pending.
- [x] [Review][Patch] zip(assetIDs, fileNames) silently truncates on array length mismatch [MainWorkspaceView.swift:424] -- **Fixed**: Added length mismatch warning log before zip.
- [x] [Review][Patch] stepResults array grows unbounded with no clearing mechanism [AgentJob.swift:25,153] -- **Fixed**: Added `stepResults.removeAll()` in `cancel()`.
- [x] [Review][Defer] AnalyzeDuplicatesTool not modified -- detection done in SDKMessageBridge via content sniffing [SDKMessageBridge.swift:122-127] -- deferred, pre-existing architecture choice from Story 5-3
- [x] [Review][Defer] UI text hardcoded in English despite Chinese user story [BatchApprovalView.swift: multiple] -- deferred, pre-existing pattern across all views
