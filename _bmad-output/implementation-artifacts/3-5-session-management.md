# Story 3.5: 会话管理

Status: ready-for-dev

## Story

As a 用户，
I want 保存和恢复之前的对话会话，
So that 我可以继续之前的照片管理任务。

## Acceptance Criteria

1. **AC1: 多轮对话上下文传递（FR10, FR12）**
   **Given** 用户与 Agent 进行了多轮对话
   **When** 对话上下文传递给 Agent
   **Then** Agent 能理解之前的指令和结果，进行连贯的多轮交互
   **And** 意图不明确时 Agent 提出澄清问题（FR10）

2. **AC2: 会话数据 SwiftData 持久化（FR11）**
   **Given** 会话数据已持久化到 SwiftData
   **When** 用户重新打开应用
   **Then** 可查看历史会话列表
   **And** 点击历史会话恢复完整上下文，继续对话

3. **AC3: 新建会话（UX-DR18）**
   **Given** 用户按 ⌘N
   **When** 创建新会话
   **Then** 清空当前 Agent 上下文，开始全新对话
   **And** 前一个会话自动保存

4. **AC4: 会话历史列表 UI**
   **Given** 存在历史会话记录
   **When** 用户点击工具栏的会话历史按钮
   **Then** 以 Sheet 弹出历史会话列表
   **And** 每条记录显示：首个用户消息摘要、创建时间、状态（活跃/已完成）
   **And** 点击历史会话恢复该会话并继续对话

5. **AC5: SessionContext 集成**
   **Given** SessionContext.current Task-local 已设置
   **When** LLM 调用发生
   **Then** 成本记录关联到正确的 sessionID
   **And** 会话恢复后成本追踪继续累加

## Tasks / Subtasks

- [ ] Task 1: 定义会话模型与 SwiftData 实体 (AC: #2, #5)
  - [ ] 1.1 创建 `Curator/Core/Models/Session.swift` — 定义 `Session` 值类型（Sendable）：`id: UUID`、`title: String`、`createdAt: Date`、`updatedAt: Date`、`messages: [SessionMessage]`、`isActive: Bool`
  - [ ] 1.2 创建 `Curator/Core/Models/SessionMessage.swift` — 定义 `SessionMessage` 值类型（Sendable, Codable）：`id: UUID`、`role: MessageRole`（.user / .assistant）、`content: String`、`timestamp: Date`
  - [ ] 1.3 定义 `enum MessageRole: String, Codable, Sendable` — `.user` / `.assistant`
  - [ ] 1.4 创建 `Curator/Infrastructure/Storage/SessionEntity.swift` — SwiftData `@Model` 实体：`id: UUID`、`title: String`、`createdAt: Date`、`updatedAt: Date`、`messagesData: Data`（JSON 序列化 `[SessionMessage]`）、`isActive: Bool`
  - [ ] 1.5 更新 `SwiftDataManager` — 将 `SessionEntity.self` 添加到 Schema：`Schema([CostRecordEntity.self, SessionEntity.self])`
  - [ ] 1.6 为 `SessionEntity` 添加便利方法 `toSession() -> Session` 和 `update(from:)` 用于值类型-实体映射

- [ ] Task 2: 创建 SessionManager 服务 (AC: #1, #2, #3)
  - [ ] 2.1 创建 `Curator/Core/Models/SessionManagerProtocol.swift` — 定义 `SessionManagerProtocol: Sendable` 协议：`createSession() -> Session`、`activeSession: Session?`、`loadSession(_ id: UUID) async throws -> Session`、`saveSession(_ session: Session) async throws`、`listSessions() async throws -> [Session]`、`switchToSession(_ id: UUID) async throws -> Session`、`deleteSession(_ id: UUID) async throws`
  - [ ] 2.2 创建 `Curator/Infrastructure/Storage/SessionManager.swift` — actor 实现 `SessionManagerProtocol`
  - [ ] 2.3 `createSession()` — 生成新 UUID、设置 title 为"新会话"、创建空消息列表、持久化到 SwiftData、设为 activeSession
  - [ ] 2.4 `saveSession(_:)` — 将 Session 的 messages JSON 编码为 Data、更新 SessionEntity、更新 updatedAt
  - [ ] 2.5 `loadSession(_:)` — 从 SwiftData 按 UUID 查询、解码 messagesData 为 [SessionMessage]、返回 Session 值类型
  - [ ] 2.6 `listSessions()` — 查询所有 SessionEntity、按 updatedAt 降序排列、返回轻量 Session 列表（不含消息内容）
  - [ ] 2.7 `switchToSession(_:)` — 保存当前 activeSession、标记旧 active 为 false、加载目标 Session、标记为 active、返回完整 Session
  - [ ] 2.8 `deleteSession(_:)` — 从 SwiftData 删除 SessionEntity
  - [ ] 2.9 使用 `@Dependency` 模式注入到 AppDependencies：`var sessionManager: (any SessionManagerProtocol)?`

- [ ] Task 3: 集成会话到 ChatInputViewModel (AC: #1, #3)
  - [ ] 3.1 为 ChatInputViewModel 添加 `sessionManager: SessionManagerProtocol?` 依赖
  - [ ] 3.2 添加 `currentSession: Session?` 属性 — 当前活跃会话
  - [ ] 3.3 修改 `createAndStartAgent(for:)` — 提交指令时追加 `SessionMessage(role: .user, content: message)` 到 currentSession.messages
  - [ ] 3.4 在 Agent 执行完成时追加 assistant 回复 — 监听 AgentJob 完成事件，将 executionSummary.message 或步骤摘要追加为 `.assistant` 消息
  - [ ] 3.5 保存会话 — 每次追加消息后调用 `sessionManager.saveSession(currentSession)`
  - [ ] 3.6 更新 title — 如果会话 title 仍为"新会话"，用首条用户消息的前 50 字符更新
  - [ ] 3.7 SessionContext 集成 — 在 `createAndStartAgent` 中设置 `SessionContext.current = currentSession?.id.uuidString`

- [ ] Task 4: 集成多轮对话到 CuratorAgent (AC: #1)
  - [ ] 4.1 为 CuratorAgent 添加 `execute(_ userMessage: String, history: [SessionMessage])` 重载方法
  - [ ] 4.2 将 history 中的 `[SessionMessage]` 构造为 SDK 可理解的对话上下文格式
  - [ ] 4.3 传递 history 到 `agent.stream()` — 将历史消息作为上下文发送，使 Agent 理解之前的交互
  - [ ] 4.4 更新 CuratorAgentFactory — 不需要修改，会话上下文在 execute 调用时传入

- [ ] Task 5: 实现新建会话 ⌘N (AC: #3)
  - [ ] 5.1 更新 `NavigationModel.newSession()` — 调用 delegate/回调通知 ChatInputViewModel 创建新会话
  - [ ] 5.2 在 MainWorkspaceView 中连接 NavigationModel.newSession 到 ChatInputViewModel：保存当前会话 → 创建新会话 → 清空 agentJob
  - [ ] 5.3 更新 `CuratorApp.swift` 中 "New Session" 按钮的 action — 通过 NavigationModel 触发
  - [ ] 5.4 新会话创建流程：保存 currentSession → sessionManager.createSession() → 重置 agentJob = nil → 显示 QuickCommandSuggestions

- [ ] Task 6: 创建会话历史列表 UI (AC: #4)
  - [ ] 6.1 创建 `Curator/Features/SessionHistory/SessionHistorySheet.swift` — Sheet 视图，展示历史会话列表
  - [ ] 6.2 创建 `Curator/Features/SessionHistory/SessionHistoryViewModel.swift` — @MainActor @Observable ViewModel
  - [ ] 6.3 SessionHistoryViewModel 属性：`sessions: [Session]`、`isLoading: Bool`、`errorMessage: String?`
  - [ ] 6.4 SessionHistoryViewModel 方法：`loadSessions()` — 调用 sessionManager.listSessions()
  - [ ] 6.5 每条会话行显示：title（或首条消息摘要）、updatedAt（相对时间格式，如"3 小时前"）、活跃标记
  - [ ] 6.6 点击会话行 — 关闭 Sheet → 调用 sessionManager.switchToSession → 恢复会话到 ChatInputViewModel
  - [ ] 6.7 滑动删除 — 调用 sessionManager.deleteSession、刷新列表
  - [ ] 6.8 空状态："还没有历史会话"提示

- [ ] Task 7: 连接工具栏会话历史按钮 (AC: #4)
  - [ ] 7.1 在 MainWorkspaceView 中添加 `@State private var showSessionHistory = false`
  - [ ] 7.2 替换 Session History 工具栏按钮的 placeholder action 为 `showSessionHistory = true`
  - [ ] 7.3 添加 `.sheet(isPresented: $showSessionHistory)` 展示 SessionHistorySheet
  - [ ] 7.4 传递 sessionManager 和回调到 SessionHistorySheet

- [ ] Task 8: ATDD 测试 (AC: #1, #2, #3, #4, #5)
  - [ ] 8.1 创建 `CuratorTests/Core/Models/SessionManagerTests.swift`
  - [ ] 8.2 [P0] testCreateSession — 创建新会话，验证 id、title、messages 为空、isActive 为 true
  - [ ] 8.3 [P0] testSaveAndLoadSession — 保存含消息的会话、重新加载、验证消息完整
  - [ ] 8.4 [P0] testListSessions — 创建多个会话、验证 list 返回按 updatedAt 降序排列
  - [ ] 8.5 [P0] testSwitchSession — 切换到另一个会话、验证旧会话保存、新会话激活
  - [ ] 8.6 [P0] testDeleteSession — 删除会话、验证列表不再包含
  - [ ] 8.7 [P1] testMultiTurnContext — 追加多轮消息到会话、验证顺序和内容
  - [ ] 8.8 [P1] testSessionContextTaskLocal — 设置 SessionContext.current、验证在同一 Task 内可读
  - [ ] 8.9 创建 `CuratorTests/Features/SessionHistory/SessionHistoryViewModelTests.swift`
  - [ ] 8.10 [P0] testLoadSessions — ViewModel 加载会话列表
  - [ ] 8.11 [P0] testDeleteSessionUpdatesList — 删除后列表更新
  - [ ] 8.12 构建通过 + 全部现有测试通过

## Dev Notes

### 架构约束

1. **分层边界严格**：SessionManagerProtocol 定义在 Domain 层（`Core/Models/`），SessionManager 实现在 Infrastructure 层（`Infrastructure/Storage/`）。SessionHistoryViewModel 在 Presentation 层（`Features/SessionHistory/`）。[Source: architecture.md#分层架构]
2. **@MainActor ViewModel**：SessionHistoryViewModel 标记 `@MainActor @Observable`。[Source: project-context.md#Critical Implementation Rules]
3. **Actor 隔离 I/O**：SessionManager 使用 `actor` 隔离，所有 SwiftData 操作在 actor 内执行。[Source: architecture.md#决策3]
4. **Sendable 类型**：Session、SessionMessage、MessageRole 均为 Sendable 值类型。跨层传递使用值类型。[Source: project-context.md#Code Patterns]
5. **禁止使用 `Task` 作为类型名**。[Source: CLAUDE.md]
6. **SwiftUI 视图不超过 200 行**。[Source: project-context.md#SwiftUI 视图模式]

### 前置 Story 上下文

**Story 3.1-3.4 已完成的核心类型：**

- `AgentJob` (@Observable @MainActor) — 状态机，本 Story 需要在完成后提取 assistant 回复并存入会话
- `ChatInputViewModel` (@MainActor @Observable) — 当前管理 AgentJob 生命周期，本 Story 添加会话管理职责
- `CuratorAgent` (actor) — 封装 SDK Agent，本 Story 添加 history 参数支持多轮对话
- `CuratorAgentFactory` — 创建 CuratorAgent 实例，不需要修改（history 在 execute 时传入）
- `MainWorkspaceView` — 包含 Session History 工具栏按钮 placeholder，本 Story 需连接真实行为
- `NavigationModel.newSession()` — 当前为 placeholder no-op，本 Story 需实现

**已有的基础设施：**

- `SwiftDataManager` — 已配置 ModelContainer，当前 Schema 仅含 `CostRecordEntity`，需添加 `SessionEntity`
- `CostRecordEntity` — 已有 `sessionID: String` 字段，与 `SessionContext.current` 配合使用
- `SessionContext` — Task-local 值，当前仅用于成本追踪关联，本 Story 在创建会话时设置
- `AppDependencies` — 依赖注入容器，需注册 `SessionManager`

### 多轮对话设计

**关键挑战**：CuratorAgent 当前通过 `agent.stream(userMessage)` 每次发送单条消息，不携带历史上下文。OpenAgentSDKSwift 的 `Agent.stream()` 是否支持 history 取决于 SDK API。

**设计方案**：

1. **CuratorAgent.execute 扩展**：添加 `history: [SessionMessage]` 参数。将 history 构造为 SDK 可理解的格式。如果 SDK 的 `Agent.stream()` 不支持 history，则将历史消息作为前缀拼接到 userMessage 中（如："以下是之前的对话上下文：\n{history}\n\n用户最新指令：{userMessage}"）。

2. **消息格式转换**：`SessionMessage` 需要映射为 SDK 能理解的格式。需要检查 `OpenAgentSDK` 的 `AgentOptions` 或 `Agent.stream()` 签名是否支持对话历史。如果不支持，使用上下文前缀方案作为 fallback。

3. **上下文窗口管理**：为避免 token 过多，保留最近 N 条消息（建议 20 条）。如果总消息超过限制，保留最早 2 条（上下文）+ 最近 18 条。

### SessionEntity 设计

**为什么用 JSON Data 而非 SwiftData 关系**：SessionMessage 可能频繁变化（追加、更新），使用 JSON 编码到 Data 字段比 SwiftData @Model 关系更简单，避免级联删除和关系维护的复杂性。

```swift
@Model
final class SessionEntity {
    @Attribute(.unique) var id: UUID
    var title: String
    var createdAt: Date
    var updatedAt: Date
    @Attribute(.externalStorage) var messagesData: Data  // JSON 编码的 [SessionMessage]
    var isActive: Bool

    // 便利属性：解码 messagesData
    var messages: [SessionMessage] {
        get {
            guard let data = messagesData else { return [] }
            return (try? JSONDecoder().decode([SessionMessage].self, from: data)) ?? []
        }
        set {
            messagesData = try? JSONEncoder().encode(newValue)
            updatedAt = Date()
        }
    }
}
```

### SessionHistorySheet 设计

**布局**：标准 macOS Sheet，使用 List 展示会话列表：

```
Sheet (600pt x 400pt)
├── Toolbar: "会话历史" 标题 + 关闭按钮
├── List (selection: single)
│   ├── ForEach sessions:
│   │   ├── HStack
│   │   │   ├── VStack(alignment: .leading)
│   │   │   │   ├── Text(session.title) — .headline
│   │   │   │   └── Text(session.updatedAt, style: .relative) — .caption, .secondary
│   │   │   └── if isActive → Text("活跃") — 绿色标签
│   │   └── .swipeActions { Button("删除", role: .destructive) }
│   └── 空状态: "还没有历史会话"
└── 底部: "新建会话" 按钮
```

**恢复会话流程**：
1. 用户点击会话行
2. Sheet 关闭
3. MainWorkspaceView 收到回调
4. ChatInputViewModel 保存当前会话
5. SessionManager.switchToSession() 加载目标会话
6. ChatInputViewModel 更新 currentSession、清空 agentJob
7. QuickCommandSuggestions 显示（因为 agentJob 为 nil）

### MainWorkspaceView 修改

**需要修改的代码区域**：

1. **Session History 按钮连接**（约 line 77-81）：
```swift
// 当前（placeholder）
Button {
    // Placeholder: session history
} label: {
    Label("Session History", systemImage: "clock.arrow.circlepath")
}

// 修改为
Button {
    showSessionHistory = true
} label: {
    Label("Session History", systemImage: "clock.arrow.circlepath")
}
```

2. **添加 Sheet 和状态**：
```swift
@State private var showSessionHistory = false
// ...
.sheet(isPresented: $showSessionHistory) {
    SessionHistorySheet(
        sessionManager: dependencies.sessionManager,
        onSessionSelected: { session in
            // 恢复会话逻辑
        }
    )
}
```

### NavigationModel.newSession() 实现

**设计方案**：NavigationModel 不应直接持有 ChatInputViewModel 引用（违反分层）。使用回调模式：

```swift
// NavigationModel
var onNewSession: (() -> Void)?

func newSession() {
    onNewSession?()
}

// MainWorkspaceView — 在 init 或 onAppear 中连接
navigationModel.onNewSession = { [chatInputViewModel] in
    chatInputViewModel.createNewSession()
}
```

**ChatInputViewModel.createNewSession()**：
1. 保存当前 currentSession（如果存在）
2. 调用 sessionManager.createSession()
3. 设置 currentSession = newSession
4. 清空 agentJob = nil（触发 QuickCommandSuggestions 显示）
5. 设置 SessionContext.current

### CuratorApp.swift 修改

**当前代码**（line 41-45）：
```swift
CommandGroup(replacing: .newItem) {
    Button("New Session") {
        // Story 3.5 will implement full session management
    }
    .keyboardShortcut("n", modifiers: .command)
}
```

**修改为**：需要通过 NavigationModel 触发。由于 CuratorApp 不持有 NavigationModel 引用，需要通过 Notification 或 FocusedValue 传递。

**推荐方案**：使用 NotificationCenter：
```swift
// CuratorApp
Button("New Session") {
    NotificationCenter.default.post(name: .newSessionRequested, key: nil)
}

// MainWorkspaceView — 监听
.onReceive(NotificationCenter.default.publisher(for: .newSessionRequested)) { _ in
    chatInputViewModel.createNewSession()
}
```

### 不做什么（范围边界）

以下内容在本 Story 中 **不实现**：

- **流式通信优化**（Story 3.6）— 事件合并、partialMessage 渲染
- **审核 UI**（Epic 5/6）— PhotoComparisonCard、RenameSuggestionCard
- **操作确认工作流**（Epic 4）— 破坏性操作的二次确认
- **会话搜索/过滤** — MVP 只提供按时间排序的列表，搜索功能延后
- **会话导出** — 不在 MVP 范围内
- **会话合并** — 不在 MVP 范围内
- **Agent 执行结果的完整回复重建** — 仅保存 executionSummary.message 作为 assistant 消息，不保存逐步推理
- **离线会话缓存** — 会话数据通过 SwiftData 本地持久化，天然支持离线

### 技术要求

- **Swift 6 strict concurrency**：所有新增类型标注 `Sendable`，SessionManager 使用 `actor`
- **@Observable 模式**：SessionHistoryViewModel 使用 `@Observable` 宏
- **不引入新第三方依赖** — 仅使用 SwiftUI + Foundation + SwiftData + Observation
- **构建通过**：`xcodebuild build` 必须成功
- **无回归**：全部现有测试必须仍然通过
- **xcodegen 自动发现**：新增文件通过 project.yml 的 `sources: - Curator` 配置自动发现

### 项目结构说明

本 Story 新增的文件：

```
Curator/
├── Core/Models/
│   ├── Session.swift                          # 新建：会话值类型
│   ├── SessionMessage.swift                   # 新建：消息值类型
│   └── SessionManagerProtocol.swift           # 新建：会话管理协议
├── Infrastructure/Storage/
│   ├── SessionEntity.swift                    # 新建：SwiftData 会话实体
│   └── SessionManager.swift                   # 新建：会话管理实现（actor）
├── Features/SessionHistory/
│   ├── SessionHistorySheet.swift              # 新建：历史会话列表 Sheet
│   └── SessionHistoryViewModel.swift          # 新建：历史会话 ViewModel

CuratorTests/
├── Core/Models/
│   └── SessionManagerTests.swift              # 新建：SessionManager 单元测试
├── Features/SessionHistory/
│   └── SessionHistoryViewModelTests.swift     # 新建：ViewModel 测试
```

修改的文件：

```
Curator/
├── App/AppDependencies.swift                  # 修改：注册 SessionManager
├── Core/Agent/CuratorAgent.swift              # 修改：添加 history 参数重载
├── Features/ChatInput/ChatInputViewModel.swift # 修改：添加会话管理职责
├── Features/MainWorkspace/MainWorkspaceView.swift # 修改：连接历史按钮和新建会话
├── App/NavigationModel.swift                  # 修改：实现 newSession()
├── CuratorApp.swift                           # 修改：⌘N 发送通知
├── Infrastructure/Storage/SwiftDataManager.swift # 修改：Schema 添加 SessionEntity
```

### NFR 关注点

- **NFR1（3 秒启动）**：会话列表懒加载，不阻塞启动。应用启动时仅加载 activeSession，历史列表在用户点击时才查询。
- **NFR3（500ms 更新）**：会话保存通过 actor 在后台执行，不影响 UI 响应。
- **NFR7（UI 不阻塞）**：所有 SwiftData 操作在 SessionManager actor 内执行，MainActor 不等待 I/O。
- **NFR6（500MB 内存）**：会话消息使用 JSON Data 存储，不在内存中缓存所有历史。仅 activeSession 的消息在内存中。

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 3.5] — 原始需求定义（会话管理）
- [Source: _bmad-output/planning-artifacts/architecture.md#决策1] — 分层架构 + 依赖注入
- [Source: _bmad-output/planning-artifacts/architecture.md#决策5] — SwiftData 本地缓存
- [Source: _bmad-output/planning-artifacts/architecture.md#决策6] — @Observable + Observation 框架
- [Source: _bmad-output/planning-artifacts/architecture.md#状态管理] — @State、@Binding、@Observable
- [Source: _bmad-output/planning-artifacts/architecture.md#缓存策略] — Agent 会话：内存 + SwiftData
- [Source: _bmad-output/planning-artifacts/architecture.md#项目结构] — Infrastructure/Storage/ 目录
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#导航模式] — UX-DR18：⌘N 新建会话、工具栏含会话历史
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#会话历史] — Sheet 弹出列表，点击恢复
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#空状态] — 无会话时的空状态提示
- [Source: _bmad-output/planning-artifacts/prd.md#FR10] — 意图不明确时提出澄清问题
- [Source: _bmad-output/planning-artifacts/prd.md#FR11] — 查看和继续历史会话
- [Source: _bmad-output/planning-artifacts/prd.md#FR12] — 多轮对话完成任务
- [Source: _bmad-output/project-context.md#Critical Implementation Rules] — Swift 6 严格并发、@MainActor ViewModel、Sendable 类型
- [Source: _bmad-output/project-context.md#Architecture Boundaries] — Features/ 和 Infrastructure/ 目录映射
- [Source: _bmad-output/project-context.md#Testing Rules] — ATDD 风格、Mock 模式
- [Source: Curator/Core/Agent/CuratorAgent.swift] — 需添加 history 参数
- [Source: Curator/Core/Agent/CuratorAgentFactory.swift] — 不需要修改
- [Source: Curator/Core/Models/SessionContext.swift] — Task-local sessionID
- [Source: Curator/Features/ChatInput/ChatInputViewModel.swift] — 需添加会话管理
- [Source: Curator/Features/MainWorkspace/MainWorkspaceView.swift] — 需连接 Session History 按钮
- [Source: Curator/App/NavigationModel.swift] — newSession() placeholder 需实现
- [Source: Curator/CuratorApp.swift] — ⌘N 按钮需连接
- [Source: Curator/Infrastructure/Storage/SwiftDataManager.swift] — Schema 需扩展
- [Source: Curator/Infrastructure/Storage/SwiftDataModels.swift] — CostRecordEntity 参考模式
- [Source: Curator/App/AppDependencies.swift] — 需注册 SessionManager

### 与后续 Story 的关系

**本 Story（3.5）建立会话管理基础：**

- **Story 3.6（流式通信优化）** — 会话中将保存更丰富的部分消息内容
- **Epic 5（去重）** — 去重任务的完整结果将作为会话消息保存
- **Epic 6（重命名）** — 重命名任务的结果将作为会话消息保存
- **Epic 4（Safety Net）** — 操作历史与会话关联，支持按会话查看操作记录
- **Epic 7（Always Ready）** — 离线时可查看缓存的历史会话

## Dev Agent Record

### Agent Model Used

{{agent_model_name_version}}

### Debug Log References

### Completion Notes List

### File List
