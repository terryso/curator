# Story 6.3: 重命名审核界面

Status: done

## Story

As a 用户，
I want 以直观的方式查看重命名建议并支持内联编辑，
so that 我可以在接受之前确认或修改建议的名称。

## Acceptance Criteria

1. **AC1: 重命名审核界面展示（FR26, UX-DR5）**
   **Given** AI 已为多张照片生成重命名建议
   **When** 进入重命名审核界面（RenameReviewView）
   **Then** 每张照片以 RenameSuggestionCard 形式展示：缩略图、当前文件名、建议文件名
   **And** 当前名称到建议名称之间有平滑的过渡动画效果

2. **AC2: 内联编辑建议名称（FR27）**
   **Given** 用户正在查看某张照片的重命名建议
   **When** 点击建议名称进行编辑
   **Then** 支持内联编辑，用户可直接修改建议的文件名
   **And** 编辑后的名称实时验证文件系统命名合规性

3. **AC3: 逐个审核与状态追踪**
   **Given** 用户对单张照片做出决策
   **When** 点击接受或拒绝按钮
   **Then** 该照片的重命名建议被标记为已接受或已拒绝
   **And** RenameViewModel 更新审核进度，界面自动聚焦到下一张未审核的照片

## Tasks / Subtasks

- [x] Task 1: 创建 RenameViewModel (AC: #1, #2, #3)
  - [x] 1.1 创建 `Curator/Features/Rename/RenameViewModel.swift`
  - [x] 1.2 定义 `@MainActor @Observable final class RenameViewModel`
  - [x] 1.3 实现 `loadSuggestions(_ suggestions: [RenameSuggestion])` 加载建议列表
  - [x] 1.4 实现 `accept(suggestionID:)`、`reject(suggestionID:)` 审核操作
  - [x] 1.5 实现 `edit(suggestionID:, newName:)` 内联编辑，含文件名合规验证
  - [x] 1.6 实现计算属性：`pendingSuggestions`、`acceptedCount`、`allReviewed`、`progressText`
  - [x] 1.7 实现 `markAllAsAccept()`、`markAllAsReject()` 批量操作（为 Story 6.4 预留）
  - [x] 1.8 实现 `toRenameOperations() -> [PlannedOperation]` 转换（为 Story 6.4 预留）

- [x] Task 2: 创建 RenameSuggestionCard 组件 (AC: #1, #2, #3)
  - [x] 2.1 创建 `Curator/Features/Rename/RenameSuggestionCard.swift`
  - [x] 2.2 实现 UX-DR5 布局：缩略图 + 当前文件名 + 箭头动画 + 建议文件名
  - [x] 2.3 实现内联编辑模式：TextField 替换建议名称显示，实时校验
  - [x] 2.4 实现 Accept（次要样式）/ Reject（次要样式）/ Edit 操作按钮
  - [x] 2.5 实现状态视觉区分：pending（默认边框）、accepted（绿色）、rejected（红色）、editing（蓝色）
  - [x] 2.6 实现减少动态效果适配：`@Environment(\.accessibilityReduceMotion)`
  - [x] 2.7 实现 VoiceOver 无障碍标签

- [x] Task 3: 创建 RenameReviewView 主界面 (AC: #1, #3)
  - [x] 3.1 创建 `Curator/Features/Rename/RenameReviewView.swift`
  - [x] 3.2 实现进度头部：显示审核进度 "Reviewed X / Y suggestions"
  - [x] 3.3 实现筛选栏：All / Pending / Accepted / Rejected
  - [x] 3.4 实现 LazyVStack 滚动列表：展示 RenameSuggestionCard
  - [x] 3.5 实现空状态：无建议 / 筛选无匹配
  - [x] 3.6 实现自动聚焦：接受/拒绝后 ScrollViewReader 跳转到下一张未审核建议

- [x] Task 4: 集成到 AgentExecutionPanel (AC: #1)
  - [x] 4.1 在 `AgentExecutionPanel` 中添加 `renameViewModel` 参数
  - [x] 4.2 在 `.review` 状态分支中添加重命名审核路径：当 `renameViewModel` 有建议时展示 `RenameReviewView`
  - [x] 4.3 在 `MainWorkspaceView` 中从 AgentJob 提取 RenameSuggestion 数据并加载到 RenameViewModel
  - [x] 4.4 在 `AgentExecutionPanel.reviewSummary` 中添加重命名审核进度文案

- [x] Task 5: ATDD 测试 (AC: #1, #2, #3)
  - [x] 5.1 创建 `CuratorTests/Features/Rename/RenameViewModelTests.swift`
  - [x] 5.2 [P0] testLoadSuggestions -- 加载建议列表后状态正确
  - [x] 5.3 [P0] testAcceptSuggestion -- 接受建议后状态变为 accepted
  - [x] 5.4 [P0] testRejectSuggestion -- 拒绝建议后状态变为 rejected
  - [x] 5.5 [P0] testEditSuggestionValid -- 编辑为合规名称后状态变为 edited
  - [x] 5.6 [P0] testEditSuggestionInvalid -- 编辑为非法名称后验证失败
  - [x] 5.7 [P0] testProgressTracking -- 审核进度统计准确
  - [x] 5.8 [P0] testAllReviewed -- 所有建议审核后 allReviewed 为 true
  - [x] 5.9 [P1] testToRenameOperations -- 转换为 PlannedOperation 列表正确
  - [x] 5.10 [P1] testFileNameValidation -- 各种非法文件名被正确拒绝
  - [x] 5.11 构建通过 + 全部现有测试通过

## Dev Notes

### 架构约束

1. **RenameViewModel 是 @MainActor @Observable**：所有 UI 状态更新在主线程，遵循项目标准 ViewModel 模式。[Source: project-context.md#Critical Implementation Rules]
2. **禁止使用 `Task` 作为类型名**：使用 `AgentJob`、`AgentWork` 等前缀。[Source: CLAUDE.md]
3. **三层错误体系**：文件名验证错误通过 `RenameSuggestion.isValidFileName()` 处理，不引入新错误类型。[Source: project-context.md#三层错误体系]
4. **SwiftUI 视图不超过 200 行**：复杂视图拆分子视图。[Source: project-context.md#SwiftUI 视图模式]

### 前置 Story 的已有实现（必须复用）

**数据模型（复用，不修改）：**
- `RenameSuggestion` — Story 6.1 创建的重命名建议模型。`id: UUID`、`assetID: AssetID`、`originalFileName: String`、`suggestedName: String`、`confidence: Double`、`analysisDescription: String?`、`status: RenameSuggestionStatus`。[Source: Curator/Core/Models/RenameSuggestion.swift]
- `RenameSuggestionStatus` — `.pending`、`.accepted`、`.rejected`、`.edited(String)`、`.failed(String)`。[Source: Curator/Core/Models/RenameSuggestion.swift]
- `PlannedOperation` — `operationType: OperationType`、`assetID: AssetID`、`parameters: OperationParameters`。重命名使用 `.rename(newTitle: String)`。[Source: Curator/Core/Operations/PlannedOperation.swift]
- `PhotoAsset` — 照片资产值类型，含 `id: AssetID`、`metadata: AssetMetadata`、`thumbnailData: Data?`。[Source: Curator/Core/Models/PhotoAsset.swift]
- `AssetID` — `rawValue: String`，Sendable, Hashable, Codable。[Source: Curator/Core/Models/AssetID.swift]

**文件名验证方法（复用）：**
- `RenameSuggestion.isValidFileName(_ name: String) -> Bool` — 验证文件名合规性（非空、无非法字符、不超过 200 字符、不以句号开头/结尾）。[Source: Curator/Core/Models/RenameSuggestion.swift:104-110]
- `RenameSuggestion.sanitizeFileName(_ name: String, extension ext: String) -> String` — 清理文件名。[Source: Curator/Core/Models/RenameSuggestion.swift:118-132]

**审核 UI 模式（必须对齐 Epic 5 去重审核）：**
- `DeduplicationViewModel` — 直接参考模板。RenameViewModel 与其架构完全对齐：加载建议列表 → 跟踪审核状态 → 提供批量操作 → 转换为 PlannedOperation。[Source: Curator/Features/Deduplication/DeduplicationViewModel.swift]
- `DuplicateReviewView` — 参考进度头部、筛选栏、LazyVStack 滚动列表、空状态处理。[Source: Curator/Features/Deduplication/DuplicateReviewView.swift]
- `PhotoComparisonCard` — 参考卡片边框状态颜色、操作按钮布局、无障碍标签。[Source: Curator/Features/Deduplication/PhotoComparisonCard.swift]
- `BatchApprovalView` — Story 6.4 会参考此模式实现批量重命名审核。[Source: Curator/Features/Deduplication/BatchApprovalView.swift]

**执行集成点（复用）：**
- `AgentExecutionPanel` — `.review` 状态分支需要添加重命名审核路径。[Source: Curator/Features/AgentExecution/AgentExecutionPanel.swift:85-93]
- `MainWorkspaceView` — `extractDuplicateGroups` 模式用于从 AgentJob 提取 RenameSuggestion 数据。[Source: Curator/Features/MainWorkspace/MainWorkspaceView.swift:448-527]
- `ConfirmationViewModel` — Story 6.4 会复用此确认工作流。[Source: Curator/Features/Confirmation/ConfirmationViewModel.swift]

### 关键设计决策

#### RenameViewModel 审核状态管理

与 `DeduplicationViewModel` 对齐，使用独立的审核状态字典而非直接修改 `RenameSuggestion`（不可变值类型）：

```swift
/// 用户审核决策，独立于 RenameSuggestion.status
enum RenameReviewDecision: Sendable, Equatable {
    case pending
    case accepted
    case rejected
    case edited(String)  // 用户自定义的编辑名称
}

@MainActor
@Observable
final class RenameViewModel {
    private(set) var suggestions: [RenameSuggestion] = []
    private(set) var reviewDecisions: [UUID: RenameReviewDecision] = [:]

    // 计算属性：pendingSuggestions, acceptedCount, allReviewed 等
    // 操作方法：accept/reject/edit/loadSuggestions
    // 批量操作：markAllAsAccept/markAllAsReject（Story 6.4 用）
    // 转换：toRenameOperations() -> [PlannedOperation]（Story 6.4 用）
}
```

**关键区别 vs DeduplicationViewModel：**
- DeduplicationViewModel 操作 `DuplicateGroup`（每组含多个 PhotoAsset）
- RenameViewModel 操作 `RenameSuggestion`（每条对应一个 PhotoAsset）
- RenameViewModel 额外支持内联编辑（将 `.edited(name)` 写入决策字典）
- RenameViewModel 的 `toRenameOperations()` 使用 `.rename(newTitle:)` 而非 `.delete`

#### RenameSuggestionCard 布局（UX-DR5）

```
┌──────────────────────────────────────────────┐
│  [缩略图]   IMG_0019.jpg                      │
│              ↓ (动画箭头)                      │
│             sunset-over-ocean.jpg             │
│                                              │
│  🤖 AI: "金色夕阳下的海浪与沙滩"                │
│  置信度: 92%                                  │
│                                              │
│  [Accept]  [Reject]  [Edit]                  │
└──────────────────────────────────────────────┘
```

编辑模式：
```
┌──────────────────────────────────────────────┐
│  [缩略图]   IMG_0019.jpg                      │
│              ↓                                │
│             [sunset-over-ocean.jpg  ✏️]       │
│             ✓ 文件名合规                       │
│                                              │
│  [Confirm Edit]  [Cancel]                    │
└──────────────────────────────────────────────┘
```

- 缩略图使用与 `PhotoComparisonCard` 相同的 NSImage 加载模式
- 箭头使用 SF Symbols `arrow.right` + 动画过渡
- AI 分析描述使用靛蓝色背景标签（与 PhotoComparisonCard 的 reasonLabel 一致）
- 置信度以百分比展示，颜色根据分值变化：>= 0.8 绿色、0.5-0.8 橙色、< 0.5 灰色

#### 与 AgentExecutionPanel 的集成

当前 `AgentExecutionPanel` 的 `.review` 分支只处理去重审核：

```swift
// 当前代码 [Source: AgentExecutionPanel.swift:85-93]
case .review:
    if let dedupVM = deduplicationViewModel, !dedupVM.groups.isEmpty {
        DuplicateReviewView(...)
    } else {
        stepList
    }
```

需要扩展为同时支持去重和重命名审核：

```swift
case .review:
    if let dedupVM = deduplicationViewModel, !dedupVM.groups.isEmpty {
        DuplicateReviewView(...)
    } else if let renameVM = renameViewModel, !renameVM.suggestions.isEmpty {
        RenameReviewView(viewModel: renameVM)
    } else {
        stepList
    }
```

#### 从 AgentJob 提取 RenameSuggestion 数据

参考 `MainWorkspaceView.extractDuplicateGroups(from:)` 模式，新增提取重命名建议的方法：

```swift
// 在 MainWorkspaceView 中添加
private static func extractRenameSuggestions(from job: AgentJob) -> [RenameSuggestion] {
    // 遍历 job.stepResults，查找 "renameSuggestions" key
    // 解析 JSON 为 [RenameSuggestion]
}
```

**SDK 工具侧的数据格式：** `AnalyzeContentTool` 在 Story 6.1 中已实现，其返回结果的 `data["renameSuggestions"]` 字段包含 JSON 序列化的建议列表。

### 与现有代码的集成点

**新建的文件：**

1. `Curator/Features/Rename/RenameViewModel.swift` — 重命名审核 ViewModel
2. `Curator/Features/Rename/RenameSuggestionCard.swift` — 重命名建议卡片组件
3. `Curator/Features/Rename/RenameReviewView.swift` — 重命名审核主界面

**需要修改的文件：**

4. `Curator/Features/AgentExecution/AgentExecutionPanel.swift` — 添加 `renameViewModel` 参数和 `.review` 分支
5. `Curator/Features/MainWorkspace/MainWorkspaceView.swift` — 添加 RenameViewModel 到 AppDependencies，提取建议数据

**不修改的文件：**

- 不修改 `RenameSuggestion.swift` — 复用现有模型和验证方法
- 不修改 `DeduplicationViewModel.swift` — 独立的重命名审核流程
- 不修改 `DuplicateReviewView.swift` — 独立的视图
- 不修改 `AnalyzeContentTool.swift` — 只消费其输出的数据
- 不修改 `RenameAssetsTool.swift` — Story 6.4 的执行工具

**后续 Story 修改的文件（本 Story 不动）：**

- `Curator/Features/Rename/BatchRenameView.swift` — Story 6.4 创建（批量接受/拒绝 UI）
- Story 6.4 可能需要在 RenameReviewView 底部添加批量操作栏

### 不做什么（范围边界）

以下内容在本 Story 中 **不实现**：

- **批量重命名确认与执行 UI** — Story 6.4 实现（全部接受/全部拒绝 + 执行按钮 + 结果摘要）
- **文件系统重命名操作** — 已在 Story 6.2 (RenameAssetsTool) 实现
- **LLM 分析调用** — 已在 Story 6.1 (AnalyzeContentTool) 实现
- **费用预估展示** — 已在 EstimateCostTool 中实现
- **回滚 UI** — Story 6.4 复用 AgentResultSummaryView
- **用户偏好语言存储** — 复用 UserDefaults

### NFR 关注点

- **NFR2（60fps 滚动）**：使用 `LazyVStack` 懒加载卡片，避免一次性渲染大量建议。
- **NFR6（500MB 内存）**：缩略图通过 `NSCache` 缓存管理，不在 RenameViewModel 中持有全分辨率图像。
- **NFR7（UI 不阻塞）**：所有审核操作是本地内存操作，无 I/O。
- **UX-DR14（WCAG AA 无障碍）**：所有自定义控件提供 accessibilityLabel/Value/Hint，颜色不是唯一信息传达方式。
- **UX-DR5（RenameSuggestionCard）**：缩略图 + 当前名称 → 建议名称（含动画过渡），支持内联编辑。

### Mock 策略

测试中 RenameViewModel 是纯内存操作，不需要 Mock 外部依赖。测试直接构造 `RenameSuggestion` 数组：

```swift
private func makeSuggestion(
    id: UUID = UUID(),
    originalFileName: String = "IMG_001.jpg",
    suggestedName: String = "sunset-beach.jpg",
    confidence: Double = 0.9,
    status: RenameSuggestionStatus = .pending
) -> RenameSuggestion {
    RenameSuggestion(
        id: id,
        assetID: AssetID(rawValue: "test-asset-\(id.uuidString)"),
        originalFileName: originalFileName,
        suggestedName: suggestedName,
        confidence: confidence,
        status: status
    )
}
```

### 项目结构说明

本 Story 新增的文件：

```
Curator/
├── Features/
│   └── Rename/
│       ├── RenameViewModel.swift           # 新建：重命名审核 ViewModel
│       ├── RenameSuggestionCard.swift      # 新建：重命名建议卡片组件
│       └── RenameReviewView.swift          # 新建：重命名审核主界面
```

测试文件：

```
CuratorTests/
├── Features/
│   └── Rename/
│       └── RenameViewModelTests.swift      # 新建：ViewModel 测试
```

### 与 Epic 5 去重审核的对比

| 方面 | DeduplicationViewModel (Epic 5) | RenameViewModel (Epic 6) |
|------|--------------------------------|--------------------------|
| 数据单元 | `DuplicateGroup`（每组多个 PhotoAsset） | `RenameSuggestion`（每条一个 PhotoAsset） |
| 审核操作 | keep / remove | accept / reject / edit(name) |
| 内联编辑 | 不支持 | 支持（FR27 核心需求） |
| 批量操作 | markAllAsKeep / markAllAsRemove | markAllAsAccept / markAllAsReject |
| 转换输出 | `toDeleteOperations()` → `[PlannedOperation]` (.delete) | `toRenameOperations()` → `[PlannedOperation]` (.rename) |
| 卡片组件 | PhotoComparisonCard（并排对比） | RenameSuggestionCard（名称过渡） |
| 进度展示 | "Reviewed X / Y groups" | "Reviewed X / Y suggestions" |
| 筛选选项 | All / Pending / Marked for Removal | All / Pending / Accepted / Rejected |

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 6.3] -- 原始需求定义（重命名审核界面）
- [Source: _bmad-output/planning-artifacts/architecture.md#Features/Rename] -- Rename 功能目录结构
- [Source: _bmad-output/planning-artifacts/architecture.md#决策1] -- 分层架构
- [Source: _bmad-output/planning-artifacts/architecture.md#决策6] -- @Observable 状态管理
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#RenameSuggestionCard] -- UX-DR5 组件规格
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#Button Hierarchy] -- UX-DR17 按钮层级
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#Accessibility Strategy] -- UX-DR14 WCAG AA
- [Source: _bmad-output/planning-artifacts/prd.md#FR26] -- 审核建议名称
- [Source: _bmad-output/planning-artifacts/prd.md#FR27] -- 修改单个建议名称
- [Source: _bmad-output/implementation-artifacts/6-1-content-analysis-and-naming.md] -- 前置 Story 6.1 实现记录
- [Source: _bmad-output/implementation-artifacts/6-2-rename-sdk-tools.md] -- 前置 Story 6.2 实现记录
- [Source: _bmad-output/project-context.md#Critical Implementation Rules] -- Swift 6 严格并发、actor 隔离、Sendable
- [Source: _bmad-output/project-context.md#Code Patterns] -- SwiftUI 视图模式、命名规范
- [Source: _bmad-output/project-context.md#Testing Rules] -- ATDD 风格、Mock 模式
- [Source: Curator/Core/Models/RenameSuggestion.swift] -- 重命名建议模型（复用，含 isValidFileName）
- [Source: Curator/Features/Deduplication/DeduplicationViewModel.swift] -- **主要参考**：审核 ViewModel 模式
- [Source: Curator/Features/Deduplication/DuplicateReviewView.swift] -- **主要参考**：审核主界面布局
- [Source: Curator/Features/Deduplication/PhotoComparisonCard.swift] -- **参考**：卡片组件模式（边框状态、按钮布局、无障碍）
- [Source: Curator/Features/AgentExecution/AgentExecutionPanel.swift] -- **需修改**：添加重命名审核分支
- [Source: Curator/Features/MainWorkspace/MainWorkspaceView.swift] -- **需修改**：提取建议数据 + 注入 RenameViewModel
- [Source: Curator/Core/Operations/PlannedOperation.swift] -- 计划操作模型（复用 .rename case）

## Dev Agent Record

### Agent Model Used

{{agent_model_name_version}}

### Debug Log References

### Completion Notes List

### File List

### Review Findings

- [x] [Review][Patch] scrollToNextPending ignores `after` parameter, always jumps to first pending [RenameReviewView.swift:170-176] -- FIXED
- [x] [Review][Patch] Edit button resets to AI suggestion instead of preserving user's edited name [RenameSuggestionCard.swift:279-282] -- FIXED
- [x] [Review][Patch] Perpetual bounce animation on every card arrow (NFR2 risk) [RenameSuggestionCard.swift:107] -- FIXED
- [x] [Review][Defer] parseRenameSuggestionStatus discards associated values for edited/failed [MainWorkspaceView.swift:611-619] -- deferred, pre-existing design consistent with dedup pattern
- [x] [Review][Defer] Validation does not indicate which naming rule was violated [RenameSuggestionCard.swift:266-274] -- deferred, UX polish
- [x] [Review][Defer] No smooth name transition animation (spec UX-DR5 interpretation gap) [RenameSuggestionCard.swift:103-115] -- deferred, UX polish
- [x] [Review][Defer] Thumbnail is placeholder, not using NSImage loading pattern [RenameSuggestionCard.swift:128-136] -- deferred, no image data in RenameSuggestion
