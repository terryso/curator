# Story 3.3: Agent 输入栏

Status: done

## Story

As a 用户，
I want 在底部输入栏键入自然语言指令与 Agent 交互，
So that 我可以用自然语言描述我的照片管理需求。

## Acceptance Criteria

1. **AC1: AgentInputBar 组件渲染（UX-DR2）**
   **Given** AgentInputBar 组件已渲染
   **When** 检查输入栏
   **Then** 底部固定的单行输入区域（默认），支持 Enter 提交、Shift+Enter 换行
   **And** placeholder 展示示例指令："试试'找出所有重复照片'"
   **And** 输入栏在 Agent 执行期间禁用并显示加载指示器

2. **AC2: 指令提交与 Agent 连接（FR8）**
   **Given** 用户在输入栏键入内容
   **When** 按 Enter（非 Shift+Enter）
   **Then** 指令发送给 Agent，输入栏清空
   **And** ChatInputViewModel（@MainActor）通过 CuratorAgentFactory 创建 CuratorAgent
   **And** CuratorAgent.execute() 的 AsyncStream<AgentEvent> 连接到 AgentJob
   **And** AgentJob.state 从 planning 转换为 running

3. **AC3: 快捷指令建议（UX-DR2, UX-DR15）**
   **Given** 首次使用且输入栏为空（AgentJob 状态为 planning 且无历史指令）
   **When** QuickCommandSuggestions 渲染
   **Then** 展示 3-4 个快捷指令建议卡片（如"找出重复照片"、"重命名照片"、"分析我的照片"）
   **And** 点击建议直接提交指令（等同于手动输入并 Enter）

4. **AC4: 输入栏状态管理（FR17）**
   **Given** Agent 正在执行（AgentJob.state == .running）
   **When** 检查输入栏
   **Then** 输入栏禁用，展示"Agent 正在工作中..."提示
   **And** 显示取消按钮，点击后调用 AgentJob.cancel()

5. **AC5: MainWorkspaceView 集成**
   **Given** MainWorkspaceView 已渲染
   **When** InputBarPlaceholder 被替换为 AgentInputBar
   **Then** 输入栏固定在底部，Agent 执行区占据主内容区
   **And** ChatInputViewModel 通过 AppDependencies 获取 CuratorAgentFactory 和 AgentToolRegistry

## Tasks / Subtasks

- [x] Task 1: 创建 ChatInputViewModel (AC: #2, #4, #5)
  - [x] 1.1 创建 `Curator/Features/ChatInput/ChatInputViewModel.swift`
  - [x] 1.2 定义 `@MainActor @Observable final class ChatInputViewModel`
  - [x] 1.3 属性：`inputText: String`、`isSubmitting: Bool`、`agentJob: AgentJob?`
  - [x] 1.4 属性：`dependencies: AppDependencies`（通过 init 注入）
  - [x] 1.5 实现 `func submitInput()` — 验证非空输入，创建 CuratorAgent，启动 AgentJob
  - [x] 1.6 实现 `func submitQuickCommand(_ command: String)` — 快捷指令直接提交
  - [x] 1.7 实现 `func cancelExecution()` — 调用 agentJob.cancel()
  - [x] 1.8 计算属性 `var isAgentRunning: Bool` — 基于 agentJob.state 判断
  - [x] 1.9 计算属性 `var isInputEnabled: Bool` — 非空文本且 Agent 未运行
  - [x] 1.10 实现 `private func createAndStartAgent(for userMessage: String)` — 核心连接逻辑：
    - 从 dependencies 获取 toolRegistry 和 curatorAgentFactory
    - 使用 factory.createAgent(tools:systemPrompt:) 创建 CuratorAgent
    - 创建新 AgentJob 并调用 job.start()
    - 调用 curatorAgent.execute(userMessage) 获取 AsyncStream<AgentEvent>
    - 在后台 Task 中将事件流 forward 到 AgentJob.emit()

- [x] Task 2: 创建 AgentInputBar 视图 (AC: #1, #4)
  - [x] 2.1 创建 `Curator/Features/ChatInput/AgentInputBar.swift`
  - [x] 2.2 实现 SwiftUI View，底部固定布局
  - [x] 2.3 使用 TextField + onKeyPress 处理 Enter/Shift+Enter 区分
  - [x] 2.4 Enter 键调用 viewModel.submitInput()
  - [x] 2.5 Shift+Enter 插入换行（多行输入）
  - [x] 2.6 placeholder 展示示例指令
  - [x] 2.7 Agent 执行中状态：禁用输入框 + ProgressView + "Agent 正在工作中..."
  - [x] 2.8 取消按钮：仅 Agent 运行时显示，点击调用 viewModel.cancelExecution()
  - [x] 2.9 添加 accessibilityLabel 和 accessibilityHint
  - [x] 2.10 添加 .keyboardShortcut 支持

- [x] Task 3: 创建 QuickCommandSuggestions 视图 (AC: #3)
  - [x] 3.1 创建 `Curator/Features/ChatInput/QuickCommandSuggestions.swift`
  - [x] 3.2 定义快捷指令数据：4 个建议（"找出重复照片"、"重命名照片"、"分析我的照片"、"帮我整理照片库"）
  - [x] 3.3 每个建议为一个可点击的卡片（圆角矩形 + 图标 + 文字）
  - [x] 3.4 点击建议调用 viewModel.submitQuickCommand(_:)
  - [x] 3.5 仅在 AgentJob 状态为 planning 且无历史指令时显示
  - [x] 3.6 添加 hover 效果和 accessibilityLabel

- [x] Task 4: 更新 MainWorkspaceView 集成 (AC: #5)
  - [x] 4.1 在 MainWorkspaceView 中添加 @State var chatInputViewModel: ChatInputViewModel
  - [x] 4.2 替换 InputBarPlaceholder 为 AgentInputBar(viewModel:)
  - [x] 4.3 在主内容区添加 QuickCommandSuggestions（条件渲染）
  - [x] 4.4 将 chatInputViewModel.agentJob 传递给后续 AgentExecutionPanel（Story 3.4 占位）
  - [x] 4.5 删除 InputBarPlaceholder 私有结构体

- [x] Task 5: ATDD 测试 (AC: #1, #2, #3, #4, #5)
  - [x] 5.1 创建 `CuratorTests/Features/ChatInput/ChatInputViewModelTests.swift`
  - [x] 5.2 [P0] testSubmitInput — 验证 submitInput() 清空 inputText 并设置 agentJob
  - [x] 5.3 [P0] testSubmitInputEmptyText — 空文本不触发提交
  - [x] 5.4 [P0] testCancelExecution — cancelExecution() 调用 agentJob.cancel()
  - [x] 5.5 [P0] testIsAgentRunning — Agent 运行时 isAgentRunning == true
  - [x] 5.6 [P0] testSubmitQuickCommand — 快捷指令直接提交
  - [x] 5.7 [P1] testInputDisabledDuringExecution — Agent 运行时输入禁用
  - [x] 5.8 [P1] testQuickCommandsHiddenDuringExecution — Agent 运行时隐藏快捷建议
  - [x] 5.9 构建通过 + 全部现有测试通过

## Dev Notes

### 架构约束

1. **分层边界严格**：ChatInputViewModel 和 AgentInputBar 都在 `Features/ChatInput/`（Presentation 层）。ViewModel 通过 AppDependencies（Application 层）获取 CuratorAgentFactory（Application 层）。不直接访问 Infrastructure 层 [Source: architecture.md#分层架构]。
2. **@MainActor ViewModel**：ChatInputViewModel 标记 `@MainActor`，所有 UI 状态更新在主线程。AgentJob 也是 `@MainActor`，两者可直接交互 [Source: project-context.md#Critical Implementation Rules]。
3. **Sendable 合规**：跨并发域传递的数据必须是 Sendable。AgentEvent 是 Sendable 枚举。AsyncStream<AgentEvent> 天然支持跨并发域 [Source: project-context.md#Swift 6 严格并发]。
4. **禁止使用 `Task` 作为类型名**：与 Swift Concurrency 冲突 [Source: CLAUDE.md]。
5. **SwiftUI 视图不超过 200 行**：AgentInputBar 拆分子视图（如 QuickCommandSuggestions 独立文件）[Source: project-context.md#SwiftUI 视图模式]。

### 前置 Story 上下文

**Story 3.1 已完成的核心类型（`Curator/Core/Agent/`）：**

- `AgentJob.swift` — @Observable @MainActor 状态机，核心方法：
  - `start()` — 开始消费 eventStream
  - `emit(_ event: AgentEvent)` — 向 eventStream 发送事件
  - `cancel()` — 取消执行
  - `transition(to: AgentJobState)` — 状态转换
  - 属性：`state`、`steps`、`executionSummary`、`error`、`reasoningMessages`
- `AgentEvent.swift` — 8 个 case 的 Sendable 枚举
- `AgentJobState.swift` — 7 个状态（planning、running、review、confirm、completed、cancelled、failed）

**Story 3.2 已完成的 SDK 集成（`Curator/Core/Agent/`）：**

- `CuratorAgent.swift` — actor，核心方法 `func execute(_ userMessage: String) -> AsyncStream<AgentEvent>`
- `CuratorAgentFactory.swift` — Sendable struct，核心方法 `func createAgent(tools: [ToolProtocol], systemPrompt: String?) -> CuratorAgent`
- `AgentToolRegistry.swift` — @unchecked Sendable class，核心属性 `var allTools: [ToolProtocol]`
- `SDKMessageBridge.swift` — SDKMessage → AgentEvent 映射
- `ScanLibraryTool.swift` — 示例工具，在 `Curator/Infrastructure/SDKTools/`

**AppDependencies 已有属性：**
- `toolRegistry: AgentToolRegistry?`
- `curatorAgentFactory: CuratorAgentFactory?`
- `photoRepository: (any PhotoLibraryRepository)?`
- `llmGateway: (any LLMGatewayProtocol)?`
- `costTracker: (any CostTrackerProtocol)?`

**关键教训（来自 Story 3.2）：**
- LLMProvider 名称冲突已解决：Curator 的 `LLMProvider` 协议 vs SDK 的 `LLMProvider` 枚举，使用 `OpenAgentSDK.LLMProvider` 消歧
- AgentToolRegistry 使用 `@unchecked Sendable` + NSLock
- 闭包捕获依赖是创建 SDK 工具的推荐模式

### ChatInputViewModel 设计

```
用户在 AgentInputBar 输入文本 → 按 Enter
    ↓
ChatInputViewModel.submitInput()
    ↓ 验证非空
    ↓ 从 AppDependencies 获取 toolRegistry + curatorAgentFactory
    ↓ factory.createAgent(tools: registry.allTools, systemPrompt: nil) → CuratorAgent
    ↓ 创建新 AgentJob()
    ↓ agentJob.start() — 开始消费 eventStream
    ↓ agent.execute(userMessage) → AsyncStream<AgentEvent>
    ↓ 后台 Task: for await event in agentStream { agentJob.emit(event) }
    ↓ AgentJob 通过 @Observable 更新 SwiftUI
```

**关键设计决策：**

1. **每次提交创建新 CuratorAgent**：CuratorAgent 是轻量封装，创建成本低。每次指令创建新 Agent 保持状态干净，避免上下文污染（会话管理在 Story 3.5）。

2. **每次提交创建新 AgentJob**：与 CuratorAgent 1:1 对应。ChatInputViewModel 持有当前 agentJob 引用供 UI 观察。

3. **事件转发在后台 Task**：`agent.execute()` 返回的 AsyncStream 在后台消费，每个事件通过 `agentJob.emit()` 发送到 @MainActor 的 AgentJob。AgentJob.emit() 内部 continuation.yield() 是线程安全的。

4. **提交期间禁用输入**：防止用户在 Agent 执行中发送新指令。Agent 完成或取消后恢复输入。

### AgentInputBar SwiftUI 实现

**键盘处理：**
```swift
// macOS 上区分 Enter 和 Shift+Enter
TextField("试试'找出所有重复照片'...", text: $viewModel.inputText, axis: .vertical)
    .lineLimit(1...5)
    .onKeyPress(.return) {
        if modifiers.contains(.shift) {
            return .ignored  // 允许换行
        }
        viewModel.submitInput()
        return .handled
    }
```

**状态驱动的 UI：**
- `viewModel.isAgentRunning == false` → 正常输入框 + 发送按钮
- `viewModel.isAgentRunning == true` → 禁用输入框 + ProgressView + 取消按钮

### QuickCommandSuggestions 设计

4 个建议指令：
1. "找出重复照片" — 图标：doc.on.doc.fill
2. "重命名照片" — 图标：pencil.line
3. "分析我的照片" — 图标：eye.fill
4. "帮我整理照片库" — 图标：folder.fill.badge.gearshape

显示条件：`viewModel.agentJob == nil || viewModel.agentJob?.state == .planning`

### 文件组织

本 Story 需创建的文件：

```
Curator/
├── Features/ChatInput/
│   ├── ChatInputViewModel.swift       # 新建：输入栏 ViewModel
│   ├── AgentInputBar.swift            # 新建：输入栏 View
│   └── QuickCommandSuggestions.swift   # 新建：快捷指令建议

CuratorTests/
├── Features/ChatInput/
│   └── ChatInputViewModelTests.swift  # 新建：ViewModel 测试
```

修改的文件：

```
Curator/
├── Features/MainWorkspace/
│   └── MainWorkspaceView.swift        # 修改：替换 InputBarPlaceholder 为 AgentInputBar
```

### 测试策略

**ATDD 测试优先级：**

- **[P0] submitInput 提交** — 验证 inputText 清空、agentJob 被设置、isSubmitting 变为 true
- **[P0] submitInput 空文本** — 空文本和纯空白不触发提交
- **[P0] cancelExecution 取消** — cancelExecution() 正确调用 agentJob.cancel()
- **[P0] isAgentRunning 状态** — Agent 运行时 isAgentRunning == true，完成后 false
- **[P0] submitQuickCommand 快捷指令** — 直接提交预设指令文本
- **[P1] 输入禁用** — Agent 运行时 isInputEnabled == false
- **[P1] 快捷指令隐藏** — Agent 运行时快捷指令不显示

**Mock 策略：**
- 不需要 Mock CuratorAgent（ChatInputViewModel 只创建它，不直接测试 Agent 行为）
- 可通过检查 `viewModel.agentJob` 是否非 nil 来验证创建成功
- 可通过设置 `viewModel.agentJob` 的状态来测试 UI 状态逻辑

### 不做什么（范围边界）

以下内容在本 Story 中 **不实现**：

- **AgentExecutionPanel UI**（Story 3.4）— 执行面板可视化，AgentJob 的 steps/状态展示
- **会话管理**（Story 3.5）— 多轮对话、会话持久化、历史恢复
- **流式通信优化**（Story 3.6）— partialMessage 处理、事件合并
- **输入历史**（下拉选择历史指令）— MVP 后功能
- **自动补全**（指令建议下拉）— MVP 后功能
- **多行输入展开动画** — 简单实现，不做复杂动画
- **Agent 推理实时展示** — Story 3.4 在 AgentExecutionPanel 中实现
- **UI 测试** — 本 Story 的 UI 变更较小（输入栏），UI 测试在 Story 3.4 整体验证

### 技术要求

- **Swift 6 strict concurrency**：ChatInputViewModel 标记 `@MainActor @Observable`
- **@Observable 模式**：使用 `@Observable` 宏而非 `ObservableObject`（macOS 15+ 原生支持）
- **不引入新第三方依赖** — 仅使用 SwiftUI + Foundation + 已有的 OpenAgentSDK
- **构建通过**：`xcodebuild build` 必须成功
- **无回归**：全部 442 个现有测试必须仍然通过
- **xcodegen 自动发现**：新增文件通过 project.yml 的 `sources: - Curator` 配置自动发现

### 项目结构说明

- ChatInputViewModel、AgentInputBar、QuickCommandSuggestions 都在 `Curator/Features/ChatInput/` 目录 [Source: architecture.md#Feature-based 目录组织]
- 对应测试在 `CuratorTests/Features/ChatInput/` 目录 [Source: project-context.md#测试目录镜像源码]
- MainWorkspaceView 修改限于替换 InputBarPlaceholder [Source: architecture.md#模块间数据流]
- 不触及 `Core/` 或 `Infrastructure/` 目录 — 本 Story 是纯 Presentation 层

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 3.3] — 原始需求定义（Agent 输入栏）
- [Source: _bmad-output/planning-artifacts/architecture.md#决策2] — Agent 执行引擎：状态机驱动 + AsyncStream
- [Source: _bmad-output/planning-artifacts/architecture.md#模块间数据流] — 用户输入 → ViewModel → AgentJob → SDKTool → AsyncStream<AgentEvent>
- [Source: _bmad-output/planning-artifacts/architecture.md#状态管理] — @Observable + Observation 框架
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#AgentInputBar] — 自定义组件定义
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#Agent 工作空间] — 底部输入区固定布局
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#空状态处理] — 首次使用快捷指令建议
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#按钮层级] — 主要/次要/危险/文本按钮层级
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#键盘导航] — Tab/Enter/Esc/⌘Z 导航
- [Source: _bmad-output/planning-artifacts/prd.md#FR8] — 用户输入自然语言指令
- [Source: _bmad-output/planning-artifacts/prd.md#FR17] — 随时取消 Agent 任务
- [Source: _bmad-output/planning-artifacts/prd.md#NFR3] — 进度更新 500ms 内出现在 UI
- [Source: _bmad-output/planning-artifacts/prd.md#NFR7] — 所有后台 Agent 任务期间 UI 保持响应
- [Source: _bmad-output/project-context.md#Critical Implementation Rules] — Swift 6 严格并发、@MainActor ViewModel
- [Source: _bmad-output/project-context.md#Architecture Boundaries] — Features/ 目录映射
- [Source: _bmad-output/implementation-artifacts/3-2-open-agent-sdk-integration.md] — 前置 Story（SDK 集成），442 测试通过
- [Source: Curator/Features/MainWorkspace/MainWorkspaceView.swift] — 当前 InputBarPlaceholder 需替换

### 与后续 Story 的关系

**本 Story（3.3）建立用户输入到 Agent 执行的 UI 通道：**

- **Story 3.4（Agent 执行面板）** 将使用 ChatInputViewModel.agentJob 的 @Observable 属性渲染执行步骤和推理气泡
- **Story 3.5（会话管理）** 将为 ChatInputViewModel 添加多轮对话支持和会话恢复
- **Story 3.6（流式通信优化）** 将优化事件合并和 partialMessage 处理
- **Epic 5/6** 将为 AgentToolRegistry 注册更多工具，AgentInputBar 自动获得新能力

## Dev Agent Record

### Agent Model Used

GLM-5.1

### Debug Log References

- Fixed test race condition: AgentJob.emit() must be called after start() to ensure eventStream continuation is initialized
- Fixed rapid submit protection: Added isSubmitting guard alongside isAgentRunning to prevent double job creation
- Fixed SwiftUI onKeyPress API usage: Used `onKeyPress { press in ... }` with `press.key == .return` and `press.modifiers.contains(.shift)` for Enter/Shift+Enter distinction
- Fixed ShapeStyle conformance: Used `Color.accentColor` instead of `.accentColor` for foregroundStyle

### Completion Notes List

- All 5 tasks and 29 subtasks completed
- ChatInputViewModel: @MainActor @Observable ViewModel with submitInput(), submitQuickCommand(), cancelExecution()
- AgentInputBar: SwiftUI view with Enter submit, Shift+Enter newline, loading state, cancel button
- QuickCommandSuggestions: 4 quick command cards with hover effects and accessibility
- MainWorkspaceView: Integrated AgentInputBar + QuickCommandSuggestions, removed InputBarPlaceholder
- 19 ATDD tests (all pass): P0 tests for submit, empty text, cancel, isAgentRunning, quick commands; P1 tests for input disabled, quick commands hidden, edge cases
- Full regression suite: 469 tests, 0 failures
- Build passes with Swift 6 strict concurrency
- No new dependencies introduced

### File List

**New files:**
- Curator/Features/ChatInput/ChatInputViewModel.swift
- Curator/Features/ChatInput/AgentInputBar.swift
- Curator/Features/ChatInput/QuickCommandSuggestions.swift
- CuratorTests/Features/ChatInput/ChatInputViewModelTests.swift

**Modified files:**
- Curator/Features/MainWorkspace/MainWorkspaceView.swift

## Change Log

- 2026-04-21: Story 3.3 implementation complete — ChatInputViewModel + AgentInputBar + QuickCommandSuggestions + MainWorkspaceView integration + 19 ATDD tests (469 total tests pass)

### Review Findings

- [x] [Review][Patch] Cancel does not propagate to CuratorAgent [ChatInputViewModel.swift:103-121] — `cancelExecution()` only cancelled AgentJob state machine, not the underlying SDK agent. Fixed by storing `currentAgent` and `executionTask` references and propagating cancellation to both.
- [x] [Review][Patch] Misleading MARK comment "Published State" [ChatInputViewModel.swift:15] — @Observable does not use @Published. Fixed to "Observable State".
- [x] [Review][Defer] Tests use `Task.sleep(for:)` for state transitions [ChatInputViewModelTests.swift:217,233,273,301,384,391] — deferred, pre-existing pattern from earlier stories
