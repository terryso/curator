# Story 3.4: Agent 执行面板

Status: done

## Story

As a 用户，
I want 实时查看 Agent 的执行进度和推理过程，
So that 我了解 Agent 正在做什么以及为什么这样做决策。

## Acceptance Criteria

1. **AC1: AgentExecutionPanel 步骤卡片渲染（FR14, UX-DR3）**
   **Given** AgentJob 进入 Running 状态
   **When** AgentExecutionPanel 渲染
   **Then** 展示步骤卡片列表，每步显示状态图标（等待/执行中/完成/失败）
   **And** 实时更新进度数字（如"已处理 1,200/15,000"）
   **And** 步骤卡片使用 SF Symbols 图标区分状态（clock.fill / progress.indicator / checkmark.circle / xmark.circle）

2. **AC2: ReasoningBubbleView 推理气泡（FR15, UX-DR10）**
   **Given** Agent 发布推理事件（stepReasoning）
   **When** ReasoningBubbleView 渲染
   **Then** 以靛蓝色背景卡片展示推理内容
   **And** 推理内容用斜体或灰色文字，区别于陈述性内容
   **And** 推理气泡可展开/折叠查看完整内容

3. **AC3: 实时 UI 更新（FR16, NFR3）**
   **Given** AgentExecutionViewModel 已绑定 AgentJob
   **When** AsyncStream<AgentEvent> 收到新事件
   **Then** 500ms 内 UI 更新
   **And** 更新过程不阻塞用户交互（NFR7）

4. **AC4: AgentExecutionViewModel 状态管理**
   **Given** AgentExecutionViewModel 作为 @Observable 观察 AgentJob
   **When** AgentJob 状态变化（planning → running → review → completed 等）
   **Then** ViewModel 正确映射为 UI 渲染状态（空态/执行中/审核/完成/失败/取消）
   **And** ViewModel 提供 formattedSummary 计算属性用于完成状态展示

5. **AC5: MainWorkspaceView 集成**
   **Given** MainWorkspaceView 已渲染
   **When** AgentContentAreaPlaceholder 被替换为 AgentExecutionPanel
   **Then** AgentExecutionPanel 占据主内容区，根据 agentJob 状态动态渲染
   **And** AgentExecutionPanel 通过 chatInputViewModel.agentJob 获取 AgentJob 引用
   **And** 无 AgentJob 或 planning 状态时展示 QuickCommandSuggestions（复用已有逻辑）

## Tasks / Subtasks

- [x] Task 1: 创建 AgentExecutionViewModel (AC: #3, #4)
  - [x] 1.1 创建 `Curator/Features/AgentExecution/AgentExecutionViewModel.swift`
  - [x] 1.2 定义 `@MainActor @Observable final class AgentExecutionViewModel`
  - [x] 1.3 属性：`agentJob: AgentJob?`（弱引用或观察用）
  - [x] 1.4 计算属性 `var displayState: ExecutionDisplayState` — 映射 AgentJob.state 到 UI 渲染状态枚举
  - [x] 1.5 定义 `enum ExecutionDisplayState`：empty、executing、review、completed、failed、cancelled
  - [x] 1.6 计算属性 `var steps: [AgentStep]` — 从 agentJob.steps 获取
  - [x] 1.7 计算属性 `var reasoningMessages: [String]` — 从 agentJob.reasoningMessages 获取
  - [x] 1.8 计算属性 `var formattedSummary: String?` — 格式化 ExecutionSummary 为用户友好文本
  - [x] 1.9 计算属性 `var formattedDuration: String?` — 格式化执行耗时
  - [x] 1.10 计算属性 `var isRunning: Bool` — displayState == .executing

- [x] Task 2: 创建 StepCardView (AC: #1)
  - [x] 2.1 创建 `Curator/Features/AgentExecution/StepCardView.swift`
  - [x] 2.2 定义 `struct StepCardView: View`，接收 `AgentStep` 参数
  - [x] 2.3 根据 `step.status` 渲染不同状态图标：
    - `.pending` → clock.fill（灰色）
    - `.running` → progress.indicator（强调色，旋转动画）
    - `.completed` → checkmark.circle.fill（绿色）
    - `.failed` → xmark.circle.fill（红色）
  - [x] 2.4 展示 `step.title` 作为卡片标题
  - [x] 2.5 展示进度数字：`"已处理 {completed}/{total}"`（使用 SF Mono 字体）
  - [x] 2.6 进度条：使用 ProgressView(value:) 显示确定性进度
  - [x] 2.7 推理消息：展示 `step.reasoningMessages`（使用 ReasoningBubbleView）
  - [x] 2.8 状态转换动画：`withAnimation(.easeInOut(duration: 0.3))` 处理状态变化
  - [x] 2.9 添加 accessibilityLabel：`"{title}, {statusText}, {progressText}"`
  - [x] 2.10 支持"减少动态效果"：检测减少动画偏好，使用即时过渡替代旋转动画

- [x] Task 3: 创建 ReasoningBubbleView (AC: #2)
  - [x] 3.1 创建 `Curator/Features/AgentExecution/ReasoningBubbleView.swift`
  - [x] 3.2 定义 `struct ReasoningBubbleView: View`，接收 `message: String` 参数
  - [x] 3.3 使用靛蓝色背景卡片（`Color.indigo.opacity(0.1)` 或类似柔和色调）
  - [x] 3.4 推理文本使用斜体 + 次要文字颜色（`Color.secondary`）
  - [x] 3.5 可展开/折叠：默认显示前 2 行，点击展开完整内容
  - [x] 3.6 展开/折叠使用 `withAnimation` 过渡
  - [x] 3.7 左侧图标：brain.head.profile（SF Symbol）标识为推理内容
  - [x] 3.8 accessibilityLabel："Agent 推理：{message 前缀}"

- [x] Task 4: 创建 AgentExecutionPanel (AC: #1, #2, #3, #4)
  - [x] 4.1 创建 `Curator/Features/AgentExecution/AgentExecutionPanel.swift`
  - [x] 4.2 定义 `struct AgentExecutionPanel: View`，接收 `AgentExecutionViewModel` 参数
  - [x] 4.3 根据 `viewModel.displayState` 条件渲染不同内容：
    - `.empty` → 空状态（不应出现，由 MainWorkspaceView 控制）
    - `.executing` → ScrollView + StepCardView 列表 + 底部进度摘要
    - `.completed` → 结果摘要卡片 + 步骤列表
    - `.failed` → 错误展示 + 步骤列表
    - `.cancelled` → 取消状态展示
    - `.review` → 审核提示（完整审核 UI 在 Epic 5/6）
  - [x] 4.4 ScrollViewReader 自动滚动到最新步骤：当新步骤开始时 scrollTarget
  - [x] 4.5 底部摘要区域：展示总进度（"已完成 {n}/{total} 步骤"）
  - [x] 4.6 完成状态展示 ExecutionSummary：总步骤数、耗时、结果消息
  - [x] 4.7 失败状态展示错误信息（使用 UserFacingError 友好文本）
  - [x] 4.8 视图不超过 200 行，子视图提取到独立文件

- [x] Task 5: 更新 MainWorkspaceView 集成 (AC: #5)
  - [x] 5.1 创建 `@State private var executionViewModel: AgentExecutionViewModel`
  - [x] 5.2 在 agentJob 变化时更新 executionViewModel（通过 .onChange）
  - [x] 5.3 替换 `AgentContentAreaPlaceholder()` 为条件渲染：
    - `quickCommandsVisible` → QuickCommandSuggestions（保留）
    - `agentJob != nil` → AgentExecutionPanel(viewModel: executionViewModel)
  - [x] 5.4 删除 `AgentContentAreaPlaceholder` 私有结构体
  - [x] 5.5 确保 agentJob 引用正确传递给 executionViewModel

- [x] Task 6: ATDD 测试 (AC: #1, #2, #3, #4, #5)
  - [x] 6.1 创建 `CuratorTests/Features/AgentExecution/AgentExecutionViewModelTests.swift`
  - [x] 6.2 [P0] testDisplayStateRunning — AgentJob 进入 running 时 displayState == .executing
  - [x] 6.3 [P0] testDisplayStateCompleted — AgentJob 完成时 displayState == .completed
  - [x] 6.4 [P0] testDisplayStateFailed — AgentJob 失败时 displayState == .failed
  - [x] 6.5 [P0] testDisplayStateCancelled — AgentJob 取消时 displayState == .cancelled
  - [x] 6.6 [P0] testStepsFromAgentJob — steps 正确从 agentJob.steps 映射
  - [x] 6.7 [P0] testReasoningMessages — reasoningMessages 从 agentJob 正确获取
  - [x] 6.8 [P0] testFormattedSummary — ExecutionSummary 格式化为友好文本
  - [x] 6.9 [P1] testEmptyAgentJob — agentJob 为 nil 时 displayState == .empty
  - [x] 6.10 [P1] testFormattedDuration — 耗时格式化（秒/分钟）
  - [x] 6.11 [P1] testRealTimeEventUpdates — emit 事件后 steps 实时更新
  - [x] 6.12 构建通过 + 全部现有测试通过

## Dev Notes

### 架构约束

1. **分层边界严格**：AgentExecutionViewModel、AgentExecutionPanel、StepCardView、ReasoningBubbleView 都在 `Features/AgentExecution/`（Presentation 层）。ViewModel 只观察 AgentJob（@Observable），不调用 Infrastructure 层 [Source: architecture.md#分层架构]。
2. **@MainActor ViewModel**：AgentExecutionViewModel 标记 `@MainActor`，所有 UI 状态更新在主线程。AgentJob 也是 `@MainActor`，两者可直接交互 [Source: project-context.md#Critical Implementation Rules]。
3. **禁止使用 `Task` 作为类型名**：与 Swift Concurrency 冲突 [Source: CLAUDE.md]。
4. **SwiftUI 视图不超过 200 行**：AgentExecutionPanel 拆分子视图（StepCardView 和 ReasoningBubbleView 独立文件）[Source: project-context.md#SwiftUI 视图模式]。
5. **不引入新第三方依赖** — 仅使用 SwiftUI + Foundation + 已有的 Observation 框架。

### 前置 Story 上下文

**Story 3.1 已完成的核心类型（`Curator/Core/Agent/`）：**

- `AgentJob.swift` — @Observable @MainActor 状态机，本 Story 的核心数据源：
  - `state: AgentJobState` — 当前状态
  - `steps: [AgentStep]` — 执行步骤列表
  - `executionSummary: ExecutionSummary?` — 完成后的执行摘要
  - `error: DomainError?` — 失败时的错误
  - `reasoningMessages: [String]` — 通用推理消息（不属于特定步骤的）
  - `start()` / `emit(_:)` / `cancel()` — 核心方法

- `AgentEvent.swift` — 8 个 Sendable case，本 Story 关注的渲染事件：
  - `.planGenerated(steps:)` → 触发步骤列表渲染
  - `.stepStarted(stepID:title:)` → 步骤状态变为 running
  - `.stepProgress(stepID:completed:total:)` → 更新进度数字
  - `.stepReasoning(stepID:message:)` → 渲染推理气泡
  - `.stepCompleted(stepID:result:)` → 步骤状态变为 completed
  - `.stepFailed(stepID:error:)` → 步骤状态变为 failed
  - `.executionCompleted(summary:)` → 完成状态渲染

- `AgentStep.swift` — 步骤模型：
  - `id: UUID`、`title: String`、`status: StepStatus`
  - `completedCount: Int`、`totalCount: Int`
  - `reasoningMessages: [String]`
  - 计算属性 `progress: Double`（0.0-1.0）

- `AgentJobState.swift` — 7 个状态：planning、running、review、confirm、completed、cancelled、failed

- `StepStatus.swift` — 4 个步骤状态：pending、running、completed、failed

- `ExecutionSummary.swift` — `totalSteps`、`completedSteps`、`failedSteps`、`duration`、`message`

**Story 3.3 已完成的输入通道（`Curator/Features/ChatInput/`）：**

- `ChatInputViewModel.swift` — @MainActor @Observable：
  - `agentJob: AgentJob?` — 当前活跃的 AgentJob（**本 Story 通过此属性获取 AgentJob**）
  - `isAgentRunning: Bool` — 计算属性
  - `quickCommandsVisible: Bool` — 控制快捷指令显示

- `MainWorkspaceView.swift` — 当前集成点：
  - `@State private var chatInputViewModel: ChatInputViewModel`
  - 已有条件渲染：`quickCommandsVisible` → QuickCommandSuggestions / else → `AgentContentAreaPlaceholder()`
  - **需要将 `AgentContentAreaPlaceholder` 替换为 `AgentExecutionPanel`**

### AgentExecutionViewModel 设计

AgentExecutionViewModel 是一个轻量级观察层，将 AgentJob 的 @Observable 属性映射为 UI 友好的渲染状态：

```
AgentJob (@Observable)
  ├── state: AgentJobState → ExecutionDisplayState（UI 渲染枚举）
  ├── steps: [AgentStep] → 直接传递给 StepCardView 渲染
  ├── reasoningMessages: [String] → ReasoningBubbleView 渲染
  ├── executionSummary: ExecutionSummary? → formattedSummary 计算属性
  └── error: DomainError? → 友好错误文本
```

**关键设计决策：**

1. **ViewModel 不持有 AgentJob**：ViewModel 接收 AgentJob 作为参数或通过绑定获取。AgentJob 的生命周期由 ChatInputViewModel 管理。AgentExecutionViewModel 只读观察。

2. **ExecutionDisplayState 映射**：
   - `nil` → `.empty`（无 AgentJob）
   - `.planning` → `.empty`（planning 由 QuickCommandSuggestions 处理）
   - `.running` → `.executing`
   - `.review` → `.review`
   - `.confirm` → `.executing`（仍在执行）
   - `.completed` → `.completed`
   - `.cancelled` → `.cancelled`
   - `.failed` → `.failed`

3. **无事件订阅**：AgentJob 本身就是 @Observable，SwiftUI 自动观察其属性变化。AgentExecutionViewModel 的计算属性会在 AgentJob 属性变化时自动重新计算。不需要单独订阅 AsyncStream。

### StepCardView SwiftUI 设计

**状态图标映射：**
- `.pending` → `clock.fill`（灰色）+ 文字"等待中"
- `.running` → `progress.indicator`（强调色）+ 旋转动画 + 文字"执行中"
- `.completed` → `checkmark.circle.fill`（绿色）+ 文字"已完成"
- `.failed` → `xmark.circle.fill`（红色）+ 文字"失败"

**进度数字格式化：**
- `completedCount > 0 && totalCount > 0` → `"已处理 {completed}/{total}"`
- 使用 `SF Mono` 字体（`Font.system(.body, design: .monospaced)`）
- 进度条使用 `ProgressView(value: step.progress, total: 1.0)`

**推理消息展示：**
- 步骤卡片下方展开推理气泡列表
- 每个 reasoningMessage 对应一个 ReasoningBubbleView

### ReasoningBubbleView 设计

**视觉规范（UX-DR10）：**
- 背景：靛蓝色系（`Color.indigo.opacity(0.08)` 亮色模式，`Color.indigo.opacity(0.2)` 暗色模式）
- 图标：`brain.head.profile`（SF Symbol），靛蓝色
- 文字：斜体 + `Color.secondary`
- 圆角：8pt
- 内边距：12pt
- 可展开/折叠：默认最多 2 行，点击展示全文

**展开/折叠实现：**
```swift
@State private var isExpanded = false
// 使用 lineLimit 和动画控制
Text(message)
    .font(.body.italic())
    .foregroundColor(.secondary)
    .lineLimit(isExpanded ? nil : 2)
```

### AgentExecutionPanel 布局

**主内容区布局：**
```
VStack(spacing: 0)
├── ScrollView（步骤卡片列表）
│   ├── ForEach steps: StepCardView
│   └── ScrollViewReader 自动滚动
├── Divider()
└── 底部摘要区域
    ├── executing → 总进度指示器
    ├── completed → ExecutionSummary 卡片
    ├── failed → 错误信息 + 重试建议
    └── cancelled → "已取消"提示
```

**自动滚动策略：**
- 使用 ScrollViewReader + scrollTarget
- 当新步骤开始（stepStarted 事件）时滚动到该步骤
- 使用 `withAnimation` 平滑滚动

### MainWorkspaceView 集成

**替换逻辑：**
```swift
// 当前代码（Story 3.3）
if chatInputViewModel.quickCommandsVisible {
    Spacer()
    QuickCommandSuggestions(viewModel: chatInputViewModel)
    Spacer()
} else {
    AgentContentAreaPlaceholder()  // ← 替换此处
}

// Story 3.4 后
if chatInputViewModel.quickCommandsVisible {
    Spacer()
    QuickCommandSuggestions(viewModel: chatInputViewModel)
    Spacer()
} else if let job = chatInputViewModel.agentJob {
    AgentExecutionPanel(viewModel: executionViewModel)
} else {
    EmptyView()
}
```

**executionViewModel 与 agentJob 同步：**
```swift
@State private var executionViewModel = AgentExecutionViewModel()

// 通过 .onChange 同步
.onChange(of: chatInputViewModel.agentJob) { _, newJob in
    executionViewModel.agentJob = newJob
}
```

### 文件组织

本 Story 需创建的文件：

```
Curator/
├── Features/AgentExecution/
│   ├── AgentExecutionViewModel.swift    # 新建：执行面板 ViewModel
│   ├── AgentExecutionPanel.swift        # 新建：执行面板主 View
│   ├── StepCardView.swift               # 新建：步骤卡片 View
│   └── ReasoningBubbleView.swift        # 新建：推理气泡 View

CuratorTests/
├── Features/AgentExecution/
│   └── AgentExecutionViewModelTests.swift  # 新建：ViewModel 测试
```

修改的文件：

```
Curator/
├── Features/MainWorkspace/
│   └── MainWorkspaceView.swift          # 修改：替换 AgentContentAreaPlaceholder 为 AgentExecutionPanel
```

### 测试策略

**ATDD 测试优先级：**

- **[P0] displayState 映射** — AgentJob 各种状态下 displayState 正确映射
- **[P0] steps 映射** — AgentJob.steps 正确暴露
- **[P0] reasoningMessages** — 推理消息正确获取
- **[P0] formattedSummary** — ExecutionSummary 格式化正确
- **[P1] empty state** — agentJob 为 nil 时正确处理
- **[P1] duration 格式化** — 耗时格式化为用户友好文本
- **[P1] 实时更新** — emit 事件后 ViewModel 状态正确变化

**Mock 策略：**
- 不需要 Mock — AgentJob 是 @Observable @MainActor 类，测试中可直接创建和操作
- 通过 `agentJob.emit()` 发送事件，验证 ViewModel 计算属性变化
- 通过 `agentJob.transition(to:)` 改变状态，验证 displayState 映射

### 不做什么（范围边界）

以下内容在本 Story 中 **不实现**：

- **审核 UI**（Epic 5/6）— PhotoComparisonCard、RenameSuggestionCard 等审核组件
- **操作确认工作流**（Epic 4）— 破坏性操作的二次确认
- **会话管理**（Story 3.5）— 多轮对话、历史恢复
- **流式通信优化**（Story 3.6）— 事件合并、partialMessage
- **结果摘要独立组件**（UX-DR6 AgentResultSummary）— 在此 Story 中简单展示，完整组件在 Epic 5/6
- **费用预估卡片**（UX-DR7 CostEstimateCard）— 已在 Story 2.6 实现
- **部分消息渲染**（流式文字逐字出现）— Story 3.6 范围

### 技术要求

- **Swift 6 strict concurrency**：AgentExecutionViewModel 标记 `@MainActor @Observable`
- **@Observable 模式**：使用 `@Observable` 宏而非 `ObservableObject`
- **不引入新第三方依赖** — 仅使用 SwiftUI + Foundation + Observation
- **构建通过**：`xcodebuild build` 必须成功
- **无回归**：全部 469 个现有测试必须仍然通过
- **xcodegen 自动发现**：新增文件通过 project.yml 的 `sources: - Curator` 配置自动发现

### 项目结构说明

- 所有新文件在 `Curator/Features/AgentExecution/` 目录 [Source: architecture.md#Feature-based 目录组织]
- 对应测试在 `CuratorTests/Features/AgentExecution/` 目录 [Source: project-context.md#测试目录镜像源码]
- MainWorkspaceView 修改限于替换 AgentContentAreaPlaceholder [Source: architecture.md#模块间数据流]
- 不触及 `Core/` 或 `Infrastructure/` 目录 — 本 Story 是纯 Presentation 层

### NFR 关注点

- **NFR3（500ms 更新延迟）**：AgentJob 是 @Observable，SwiftUI 直接观察其属性变化，属性变更到 UI 更新通常在 16ms 内完成（一个渲染帧），远优于 500ms 要求。
- **NFR7（UI 不阻塞）**：所有事件处理在 @MainActor 上但通过 @Observable 批量更新，不影响用户交互。
- **NFR6（500MB 内存上限）**：步骤卡片使用 ScrollView + LazyVStack 避免一次性加载所有卡片。推理消息使用 lineLimit 控制初始渲染量。

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 3.4] — 原始需求定义（Agent 执行面板）
- [Source: _bmad-output/planning-artifacts/architecture.md#决策2] — Agent 执行引擎：状态机驱动 + AsyncStream
- [Source: _bmad-output/planning-artifacts/architecture.md#模块间数据流] — AgentJob → ViewModel → SwiftUI 数据流
- [Source: _bmad-output/planning-artifacts/architecture.md#状态管理] — @Observable + Observation 框架
- [Source: _bmad-output/planning-artifacts/architecture.md#项目结构] — Features/AgentExecution/ 目录
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#AgentExecutionPanel] — 自定义组件定义：步骤卡片 + 推理气泡 + 进度数字
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#Agent 推理可视化] — UX-DR10：靛蓝色背景，斜体/灰色文字
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#Agent 工作空间] — 执行区作为主内容区
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#进度反馈] — 步骤状态更新 + 进度数字
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#按钮层级] — 按钮样式系统
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#颜色系统] — 语义色 + Agent 强调色（靛蓝色）
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#排版] — SF Mono 用于进度数字
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#减少动态效果] — 动画适配
- [Source: _bmad-output/planning-artifacts/prd.md#FR14] — 实时查看 Agent 执行进度
- [Source: _bmad-output/planning-artifacts/prd.md#FR15] — 查看 Agent 决策推理过程
- [Source: _bmad-output/planning-artifacts/prd.md#FR16] — Agent 更新流式传输到 UI
- [Source: _bmad-output/planning-artifacts/prd.md#NFR3] — 进度更新 500ms 内出现在 UI
- [Source: _bmad-output/planning-artifacts/prd.md#NFR7] — 所有后台 Agent 任务期间 UI 保持响应
- [Source: _bmad-output/project-context.md#Critical Implementation Rules] — Swift 6 严格并发、@MainActor ViewModel
- [Source: _bmad-output/project-context.md#Architecture Boundaries] — Features/ 目录映射
- [Source: Curator/Core/Agent/AgentJob.swift] — @Observable 状态机，核心数据源
- [Source: Curator/Core/Agent/AgentEvent.swift] — Sendable 事件枚举
- [Source: Curator/Core/Agent/AgentStep.swift] — 步骤模型（id, title, status, progress）
- [Source: Curator/Core/Agent/ExecutionSummary.swift] — 执行摘要模型
- [Source: Curator/Core/Agent/AgentJobState.swift] — 状态机状态枚举
- [Source: Curator/Features/ChatInput/ChatInputViewModel.swift] — agentJob 属性的来源
- [Source: Curator/Features/MainWorkspace/MainWorkspaceView.swift] — 当前 AgentContentAreaPlaceholder 需替换

### 与后续 Story 的关系

**本 Story（3.4）建立 Agent 执行过程的可视化基础：**

- **Story 3.5（会话管理）** 将为 AgentExecutionPanel 添加历史会话恢复时的状态重建
- **Story 3.6（流式通信优化）** 将优化大量事件时的渲染性能（事件合并、LazyVStack 优化）
- **Epic 5（去重）** 将在 AgentExecutionPanel 的 review 状态中嵌入 PhotoComparisonCard 审核组件
- **Epic 6（重命名）** 将在 review 状态中嵌入 RenameSuggestionCard 审核组件

## Dev Agent Record

### Agent Model Used

{{agent_model_name_version}}

### Debug Log References

### Completion Notes List

### File List

### Review Findings

- [x] [Review][Patch] @State 应改为 @Bindable — AgentExecutionPanel 中 ViewModel 持有模式错误 [`Curator/Features/AgentExecution/AgentExecutionPanel.swift:13`] — FIXED: 改为 @Bindable
- [x] [Review][Patch] onChange 监听 isAgentRunning 而非 agentJob — 可能丢失 agentJob 更新事件 [`Curator/Features/MainWorkspace/MainWorkspaceView.swift:98`] — FIXED: 改为 onChange(of: chatInputViewModel.agentJob)
- [x] [Review][Patch] AgentExecutionPanel.swift 超过 200 行限制（221 行不含 Preview） [`Curator/Features/AgentExecution/AgentExecutionPanel.swift`] — FIXED: 删除冗余包装属性，降至 186 行
- [x] [Review][Patch] AgentContentAreaPlaceholder.swift 未删除 — 死代码仍在编译 [`Curator/Features/MainWorkspace/AgentContentAreaPlaceholder.swift`] — FIXED: 已删除文件和 project.pbxproj 引用
- [x] [Review][Patch] 失败状态未展示实际错误信息 — failedSummary 使用硬编码文本 [`Curator/Features/AgentExecution/AgentExecutionPanel.swift:189`] — FIXED: 添加 errorMessage 属性并展示实际 DomainError
- [x] [Review][Patch] ReasoningBubbleView 未适配暗色模式 — colorOpacity 硬编码 0.1 [`Curator/Features/AgentExecution/ReasoningBubbleView.swift:50`] — FIXED: 使用 colorScheme 适配暗色模式
- [x] [Review][Defer] formattedDuration 仅展示整数秒，丢弃亚秒精度 — deferred, low priority design choice
- [x] [Review][Defer] UI 文本硬编码英文而非中文 — deferred, possible product decision
