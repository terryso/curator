# Story 3.2: OpenAgentSDKSwift 集成

Status: review

## Story

As a 系统，
I want 将 Agent 操作注册为 OpenAgentSDKSwift 的工具，并桥接 SDK Agent 循环与 Curator 的 AgentJob 状态机，
So that SDK Agent 循环可以调用 Curator 的图库和分析功能，用户自然语言指令被正确解析和执行。

## Acceptance Criteria

1. **AC1: AgentToolRegistry 工具注册（FR9, FR13）**
   **Given** AgentToolRegistry 已实现
   **When** 注册自定义工具
   **Then** 支持使用 `defineTool()` 工厂函数动态注册符合 `ToolProtocol` 的自定义工具
   **And** 工具通过依赖注入获取基础设施服务（LocalFolderRepository、LLMGateway），不直接创建具体实例

2. **AC2: SDK Agent 循环启动与指令处理（FR8, FR9）**
   **Given** SDK Agent 已创建并配置了自定义工具
   **When** 用户发送自然语言指令
   **Then** SDK 解析意图并调用对应的注册工具
   **And** 工具执行在后台 Task 中进行，不阻塞 UI

3. **AC3: SDK 消息桥接到 AgentEvent（FR16, NFR3）**
   **Given** SDK Agent 循环通过 `stream()` 或 `prompt()` 产生 `SDKMessage` 事件
   **When** 收到 `.toolUse`、`.toolResult`、`.assistant`、`.result` 等 SDKMessage
   **Then** 正确映射为 Curator 的 `AgentEvent`（stepStarted、stepProgress、stepCompleted、executionCompleted 等）
   **And** 映射通过 AsyncStream<AgentEvent> 传递到 AgentJob，500ms 内更新 UI

4. **AC4: 工具执行与基础设施集成（FR13）**
   **Given** 工具执行需要访问文件系统或 LLM
   **When** 工具调用基础设施服务
   **Then** 通过 AppDependencies 依赖注入获取协议实现，不直接创建具体实例
   **And** 工具执行结果正确映射为 ToolResult

5. **AC5: Agent 桥接层配置（FR43, FR44）**
   **Given** 用户已在设置中配置了 API Key 和模型
   **When** 创建 SDK Agent
   **Then** 使用用户配置的 apiKey、model、provider 创建 `AgentOptions`
   **And** 自定义工具列表通过 `tools` 参数注册
   **And** systemPrompt 包含 Curator 的照片管理 Agent 角色定义

## Tasks / Subtasks

- [x] Task 1: 创建 AgentToolRegistry 工具注册中心 (AC: #1)
  - [x] 1.1 创建 `Curator/Core/Agent/AgentToolRegistry.swift`
  - [x] 1.2 定义 `final class AgentToolRegistry: @unchecked Sendable` — 管理自定义工具集合
  - [x] 1.3 实现注册方法 `func register(_ tool: ToolProtocol)` — 添加工具到内部数组
  - [x] 1.4 实现 `var allTools: [ToolProtocol]` — 返回所有已注册工具的副本
  - [x] 1.5 实现按需注册工具的便利方法（占位，Epic 5/6 填充具体工具）
  - [x] 1.6 实现工具查找 `func tool(named: String) -> ToolProtocol?`

- [x] Task 2: 创建 SDK-Agent 消息桥接层 (AC: #3)
  - [x] 2.1 创建 `Curator/Core/Agent/SDKMessageBridge.swift`
  - [x] 2.2 定义 `struct SDKMessageBridge: Sendable` — 将 SDKMessage 转换为 AgentEvent
  - [x] 2.3 实现映射方法 `func mapSDKMessage(_ message: SDKMessage) -> [AgentEvent]` — 一个 SDKMessage 可能映射为多个 AgentEvent
  - [x] 2.4 映射规则：
    - `.toolUse` → `AgentEvent.stepStarted`
    - `.toolResult` → `AgentEvent.stepCompleted`
    - `.assistant` → `AgentEvent.stepReasoning`（如果有推理文本）
    - `.result(subtype: .success)` → `AgentEvent.executionCompleted`
    - `.result(subtype: .cancelled)` → 对应 AgentJob 取消
    - `.result(subtype: .error*)` → `AgentEvent.stepFailed`
    - `.partialMessage` → 忽略（Story 3.6 优化时处理）
    - `.system` → 忽略（初始化元数据，不需要映射）
  - [x] 2.5 实现累积上下文追踪 — 桥接层维护步骤 ID 映射（SDK toolUseId → AgentStep UUID）

- [x] Task 3: 创建 CuratorAgent 桥接类 (AC: #2, #5)
  - [x] 3.1 创建 `Curator/Core/Agent/CuratorAgent.swift`
  - [x] 3.2 定义 `actor CuratorAgent` — 封装 SDK Agent 创建和配置
  - [x] 3.3 实现 `init(apiKey:model:provider:baseURL:tools:systemPrompt:)` — 创建 SDK `Agent`
  - [x] 3.4 实现 `func execute(_ userMessage: String) -> AsyncStream<AgentEvent>` — 完整桥接：
    - 调用 `agent.stream(userMessage)` 获取 `AsyncStream<SDKMessage>`
    - 通过 `SDKMessageBridge` 将每个 SDKMessage 转换为 `[AgentEvent]`
    - 展平并输出 `AsyncStream<AgentEvent>`
  - [x] 3.5 实现 `func cancel()` — 调用 `agent.interrupt()`
  - [x] 3.6 实现 Curator 系统 Prompt 模板 — 定义照片管理 Agent 角色和可用工具描述
  - [x] 3.7 处理 SDK Agent 的 cost 信息 — 从 QueryResult/SDKMessage 中提取 tokenUsage 传递给 CostTracker

- [x] Task 4: 更新 AppDependencies 注册 Agent 基础设施 (AC: #4, #5)
  - [x] 4.1 在 `AppDependencies` 中添加 `var toolRegistry: AgentToolRegistry?` 属性
  - [x] 4.2 在 `AppDependencies` 中添加 `var curatorAgentFactory: CuratorAgentFactory?` 属性
  - [x] 4.3 创建 `Curator/Core/Agent/CuratorAgentFactory.swift` — 工厂类，根据 AppDependencies 中的配置创建 CuratorAgent
  - [x] 4.4 实现 `func registerAgentInfrastructure()` — 注册工具注册中心和 Agent 工厂
  - [x] 4.5 工厂使用 llmGateway 的 apiKey/model 配置创建 Agent

- [x] Task 5: 创建示例 SDK 工具（占位，验证集成）(AC: #1, #4)
  - [x] 5.1 创建 `Curator/Infrastructure/SDKTools/ScanLibraryTool.swift` — 扫描图库工具（简化版，Epic 5 完善）
  - [x] 5.2 使用 `defineTool()` 工厂函数创建工具
  - [x] 5.3 工具内部通过注入的 `PhotoLibraryRepository` 协议调用 `fetchAssets()`
  - [x] 5.4 工具返回 JSON 格式的扫描结果（照片数量、元数据摘要）
  - [x] 5.5 将 ScanLibraryTool 注册到 AgentToolRegistry

- [x] Task 6: ATDD 测试 (AC: #1, #2, #3, #4, #5)
  - [x] 6.1 创建 `CuratorTests/Core/Agent/AgentToolRegistryTests.swift`
  - [x] 6.2 [P0] testToolRegistration — 注册工具后 allTools 包含该工具
  - [x] 6.3 [P0] testToolLookupByName — 按 name 查找已注册工具
  - [x] 6.4 [P0] testSDKMessageBridgeToolUse — .toolUse 映射为 stepStarted
  - [x] 6.5 [P0] testSDKMessageBridgeResult — .result(.success) 映射为 executionCompleted
  - [x] 6.6 [P0] testSDKMessageBridgeError — .result(.errorDuringExecution) 映射为 stepFailed
  - [x] 6.7 [P0] testCuratorAgentCreation — 使用配置参数创建 CuratorAgent
  - [x] 6.8 [P0] testScanLibraryToolExecution — ScanLibraryTool 调用 PhotoLibraryRepository
  - [x] 6.9 [P0] testToolProtocolConformance — 自定义工具实现 ToolProtocol 所有必需属性
  - [x] 6.10 [P1] testCuratorSystemPrompt — 系统 Prompt 包含照片管理角色定义
  - [x] 6.11 [P1] testSDKMessageBridgeCancellation — .result(.cancelled) 正确处理
  - [x] 6.12 [P1] testMultipleToolRegistration — 多个工具注册后 allTools 返回全部
  - [x] 6.13 构建通过 + 全部测试通过（含现有 410 个测试）

## Dev Notes

### 架构约束

1. **分层边界严格**：AgentToolRegistry 和 CuratorAgent 在 `Core/Agent/`（Application 层）。SDKTools 在 `Infrastructure/SDKTools/`。工具通过 AppDependencies 获取 Infrastructure 层的协议实现 [Source: architecture.md#分层架构]。
2. **SDK 依赖方向**：Curator 的 `Core/Agent/` 层可以 `import OpenAgentSDK`，因为 SDK 提供的是基础设施级别的类型（`ToolProtocol`、`Agent`、`AgentOptions`、`SDKMessage`、`ToolResult` 等）。这与分层架构一致——SDK 类似于 Foundation，是系统级依赖。
3. **Sendable 合规**：AgentToolRegistry 需要是 `Sendable` 或 `actor`，因为它被 CuratorAgent（actor）使用。由于内部持有 `[ToolProtocol]`（ToolProtocol 继承 Sendable），使用 `@unchecked Sendable` 或 actor 均可。
4. **禁止使用 `Task` 作为类型名**：与 Swift Concurrency 冲突 [Source: CLAUDE.md]。
5. **@MainActor 用于 ViewModel**：AgentToolRegistry 和 CuratorAgent 不是 ViewModel，不需要 @MainActor。CuratorAgent 是 `actor`，AgentToolRegistry 是普通 class 或 actor。

### SDK API 关键信息（基于实际源码分析）

以下是从 OpenAgentSDKSwift 源码中提取的关键 API：

**`ToolProtocol`** — 工具协议：
```swift
public protocol ToolProtocol: Sendable {
    var name: String { get }
    var description: String { get }
    var inputSchema: ToolInputSchema { get }  // ToolInputSchema = [String: Any]
    var isReadOnly: Bool { get }
    var annotations: ToolAnnotations? { get }
    func call(input: Any, context: ToolContext) async -> ToolResult
}
```

**`defineTool()` 工厂函数** — 推荐，最简洁的创建工具方式：
```swift
// Codable Input 版本（推荐）
func defineTool<Input: Codable>(
    name: String,
    description: String,
    inputSchema: ToolInputSchema,
    isReadOnly: Bool = false,
    annotations: ToolAnnotations? = nil,
    execute: @Sendable @escaping (Input, ToolContext) async throws -> String
) -> ToolProtocol
```

**`ToolAnnotations`** — 工具行为标注：
```swift
public struct ToolAnnotations: Sendable, Equatable {
    public let readOnlyHint: Bool      // 默认 false
    public let destructiveHint: Bool   // 默认 true（保守）
    public let idempotentHint: Bool    // 默认 false
    public let openWorldHint: Bool     // 默认 false
}
```

**`ToolResult`** — 工具执行结果：
```swift
public struct ToolResult: Sendable, Equatable {
    public let toolUseId: String
    public let content: String  // 文本内容
    public let isError: Bool
}
```

**`Agent` 类** — SDK Agent 核心：
```swift
public class Agent: @unchecked Sendable {
    init(options: AgentOptions)
    func prompt(_ text: String) async -> QueryResult
    func stream(_ text: String) -> AsyncStream<SDKMessage>
    func interrupt()
    func close() async throws
}
```

**`AgentOptions`** — Agent 配置：
```swift
public struct AgentOptions: Sendable {
    var apiKey: String?
    var model: String  // 默认 "claude-sonnet-4-6"
    var provider: LLMProvider  // .anthropic 或 .openai
    var baseURL: String?
    var systemPrompt: String?
    var maxTurns: Int  // 默认 10
    var maxTokens: Int  // 默认 16384
    var tools: [ToolProtocol]?
    var maxBudgetUsd: Double?
    var permissionMode: PermissionMode
    // ... 其他配置字段
}
```

**`SDKMessage`** — 流式事件枚举（关键类型）：
```swift
public enum SDKMessage {
    case system(SystemData)
    case userMessage(UserMessageData)
    case assistant(AssistantData)     // LLM 响应文本 + stopReason
    case toolUse(ToolUseData)         // 工具被调用（name, toolUseId, input）
    case toolProgress(ToolProgressData) // 工具进度
    case toolResult(ToolResultData)   // 工具执行结果
    case toolUseSummary(ToolUseSummaryData)
    case partialMessage(PartialData)  // 流式文本片段
    case result(ResultData)           // 最终结果
}
```

### 前置 Story 上下文

**Story 3.1 已完成的核心类型（位于 `Curator/Core/Agent/`）：**

- `AgentJob.swift` — @Observable @MainActor 状态机，持有 `state`、`steps`、`executionSummary`、`error`，以及 `eventStream: AsyncStream<AgentEvent>`
- `AgentEvent.swift` — 8 个 case 的 Sendable 枚举（planGenerated、stepStarted、stepProgress、stepReasoning、stepCompleted、stepFailed、reviewReady、executionCompleted）
- `AgentJobState.swift` — 7 个状态（planning、running、review、confirm、completed、cancelled、failed）
- `AgentStep.swift` — 执行步骤值类型（id、title、status、completedCount、totalCount、reasoningMessages）
- `StepResult.swift` — 步骤结果（stepID、message、data）
- `ReviewItem.swift` — 审核项（id、title、description、requiresConfirmation）
- `ExecutionSummary.swift` — 执行摘要（totalSteps、completedSteps、failedSteps、duration、message）

**Epic 2 已完成的基础设施：**
- `AppDependencies.swift` — 依赖注入容器，已有 photoRepository、llmGateway、costTracker
- `LLMGateway.swift` — actor，统一网关，已有 analyze()、estimateCost()
- `AnthropicProvider` / `OpenAICompatibleProvider` — 具体实现
- `CostTracker` — 成本追踪（通过协议注入）
- `LLMConfig` — 持久化配置（apiKey、model、baseURL、fallback）

### CuratorAgent 设计

```
用户输入
    ↓
ChatInputViewModel（@MainActor）  ← Story 3.3 实现
    ↓ 创建 CuratorAgent 或复用
CuratorAgent（actor）
    ↓ agent.stream(userMessage) 返回 AsyncStream<SDKMessage>
SDKMessageBridge
    ↓ 映射为 [AgentEvent]
AsyncStream<AgentEvent>
    ↓ 消费
AgentJob（@MainActor @Observable）→ SwiftUI 更新
```

**CuratorAgent 是中间桥梁层**，连接 SDK Agent 循环和 Curator 的 AgentJob 状态机。它：
1. 持有一个 SDK `Agent` 实例
2. 调用 `agent.stream()` 获取 `AsyncStream<SDKMessage>`
3. 通过 `SDKMessageBridge` 转换每个 SDKMessage 为 AgentEvent
4. 输出 `AsyncStream<AgentEvent>` 供 AgentJob 消费

### SDKMessage → AgentEvent 映射策略

| SDKMessage | AgentEvent | 说明 |
|------------|------------|------|
| `.system(.init)` | 无 | 初始化元数据，忽略 |
| `.userMessage` | 无 | 已在 AgentJob 外部处理，忽略 |
| `.assistant(text, stopReason: "tool_use")` | `.stepReasoning` | LLM 决定使用工具前的推理文本 |
| `.assistant(text, stopReason: "end_turn")` | `.stepReasoning` + `.executionCompleted` | 最终回复 |
| `.toolUse(name, toolUseId, input)` | `.stepStarted` | 工具开始执行 |
| `.toolProgress(toolUseId, toolName)` | `.stepProgress` | 工具进度 |
| `.toolResult(toolUseId, content, isError: false)` | `.stepCompleted` | 工具成功完成 |
| `.toolResult(toolUseId, content, isError: true)` | `.stepFailed` | 工具执行失败 |
| `.result(.success, text, usage, ...)` | `.executionCompleted` | Agent 循环正常结束 |
| `.result(.cancelled, ...)` | 无（由 AgentJob 处理取消） | 用户取消 |
| `.result(.error*, ...)` | `.stepFailed` | Agent 循环错误 |
| `.partialMessage` | 忽略 | Story 3.6 优化 |
| `.toolUseSummary` | 忽略 | 汇总信息 |
| `.system(.compactBoundary)` | 忽略 | 上下文压缩 |

**累积追踪**：SDKMessageBridge 需要维护 `toolUseId → stepID` 映射，因为：
- `.toolUse` 创建新步骤 → 生成 UUID 作为 stepID
- `.toolResult` 引用 toolUseId → 需要映射回 stepID
- `.toolProgress` 引用 toolUseId → 需要映射回 stepID

### Curator 系统 Prompt 设计

```swift
let curatorSystemPrompt = """
You are Curator, an AI photo management assistant for macOS.
You help users organize, analyze, and manage their photo library using natural language commands.

## Available Tools

- **scan_library**: Scan the user's photo folder and return a summary of photos found.
  (More tools will be available as the application evolves.)

## Guidelines

- Always explain what you're doing before taking action.
- For operations that modify files (rename, move, delete), clearly state what will happen and wait for confirmation.
- Report photo counts and progress updates during long operations.
- If the user's intent is unclear, ask for clarification rather than guessing.
- Never modify original image files — only operate on metadata (filenames, directory structure).
"""
```

### ScanLibraryTool 设计

```swift
// 使用 defineTool Codable 工厂函数
struct ScanLibraryInput: Codable {
    let maxResults: Int?  // 可选，限制返回数量
}

let scanLibraryTool = defineTool(
    name: "scan_library",
    description: "Scan the user's photo folder and return a summary of photos found, including count, formats, and date range.",
    inputSchema: [
        "type": "object",
        "properties": [
            "maxResults": ["type": "integer", "description": "Maximum number of photos to return in the summary"]
        ]
    ],
    isReadOnly: true,
    annotations: ToolAnnotations(readOnlyHint: true, destructiveHint: false)
) { (input: ScanLibraryInput, context: ToolContext) async throws -> String in
    // 通过注入的 repository 获取照片
    // 返回 JSON 格式结果
}
```

**问题：工具如何获取 PhotoLibraryRepository？**

`defineTool` 的 execute 闭包签名是 `(Input, ToolContext) async throws -> String`，不直接接受额外参数。解决方案：

**方案：闭包捕获依赖**。在创建工具时，通过闭包捕获注入的 repository：

```swift
func createScanLibraryTool(repository: any PhotoLibraryRepository) -> ToolProtocol {
    return defineTool(name: "scan_library", ...) { (input: ScanLibraryInput, context: ToolContext) in
        let page = try await repository.fetchAssets(predicate: .all, pageSize: input.maxResults ?? 100)
        // 格式化为 JSON 字符串返回
        return jsonString
    }
}
```

这符合架构约束——通过依赖注入获取协议实现，不直接创建具体实例。AgentToolRegistry 或 CuratorAgentFactory 在创建工具时注入 repository。

### 文件组织

本 Story 需创建的文件：

```
Curator/
├── Core/Agent/
│   ├── AgentToolRegistry.swift              # 新建：工具注册中心
│   ├── SDKMessageBridge.swift              # 新建：SDK消息 → AgentEvent 桥接
│   ├── CuratorAgent.swift                  # 新建：SDK Agent 封装
│   └── CuratorAgentFactory.swift           # 新建：Agent 工厂

Curator/
├── Infrastructure/SDKTools/
│   ├── .gitkeep                            # 删除（有实际文件后）
│   └── ScanLibraryTool.swift               # 新建：扫描图库工具

CuratorTests/
├── Core/Agent/
│   ├── AgentToolRegistryTests.swift        # 新建：注册中心测试
│   ├── SDKMessageBridgeTests.swift         # 新建：桥接层测试
│   └── CuratorAgentTests.swift             # 新建：Agent 桥接测试
```

### 测试策略

**ATDD 测试优先级：**

- **[P0] 工具注册** — 注册后 allTools 包含、按名查找
- **[P0] 消息桥接 .toolUse** — 正确映射为 stepStarted
- **[P0] 消息桥接 .result(.success)** — 映射为 executionCompleted
- **[P0] 消息桥接 .result(.error)** — 映射为 stepFailed
- **[P0] CuratorAgent 创建** — 使用配置参数创建，工具已注册
- **[P0] ScanLibraryTool 执行** — 调用 repository，返回正确格式
- **[P0] ToolProtocol 合规** — name、description、inputSchema、isReadOnly、call()
- **[P1] 系统 Prompt** — 包含照片管理角色定义
- **[P1] 取消处理** — SDKMessage .cancelled 正确映射
- **[P1] 多工具注册** — 多个工具正确管理
- **[P1] ToolAnnotations** — 正确标注 readOnly/destructive

**测试 Mock 策略：**
- `MockPhotoLibraryRepository` — 已存在于测试中，复用
- 不需要 Mock SDK Agent — 只测试桥接层逻辑和工具执行

### 不做什么（范围边界）

以下内容在本 Story 中 **不实现**：

- **AgentInputBar UI**（Story 3.3）— 输入栏视图和 ChatInputViewModel
- **AgentExecutionPanel UI**（Story 3.4）— 执行面板 UI
- **会话管理**（Story 3.5）— 会话持久化和历史恢复
- **流式通信优化**（Story 3.6）— partialMessage 处理、事件合并
- **具体业务工具**（Epic 5/6）— 去重工具、重命名工具等（只创建 ScanLibraryTool 作为示例验证集成）
- **OperationManager 集成**（Epic 4）— 写操作的安全保障
- **SDK Agent 的所有配置项** — 只使用与 Curator 相关的配置（apiKey、model、tools、systemPrompt）
- **UI 测试** — 本 Story 是纯逻辑层，无 UI 变更

### 技术要求

- **Swift 6 strict concurrency**：所有跨并发域类型 `Sendable`，CuratorAgent 使用 `actor`
- **import OpenAgentSDK** — 在 Core/Agent/ 和 Infrastructure/SDKTools/ 中导入 SDK
- **复用已有错误类型**：DomainError.operationCancelled、DomainError.invalidState
- **不引入新第三方依赖** — 仅使用已有的 OpenAgentSDK + Foundation + Swift Concurrency
- **构建通过**：`xcodebuild build` 必须成功
- **无回归**：全部 410 个现有测试必须仍然通过
- **xcodegen 自动发现**：新增文件通过 project.yml 的 `sources: - Curator` 配置自动发现

### 项目结构说明

- AgentToolRegistry、SDKMessageBridge、CuratorAgent、CuratorAgentFactory 都在 `Curator/Core/Agent/` 目录 [Source: architecture.md#目录组织, project-context.md#Architecture Boundaries]
- ScanLibraryTool 在 `Curator/Infrastructure/SDKTools/` 目录 [Source: architecture.md#SDKTools 目录]
- 对应测试在 `CuratorTests/Core/Agent/` 目录 [Source: project-context.md#测试目录镜像源码]
- 本 Story 不触及 `Features/` 目录（UI 在后续 Story）
- AppDependencies 修改仅添加新属性和注册方法

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 3.2] — 原始需求定义（OpenAgentSDKSwift 集成）
- [Source: _bmad-output/planning-artifacts/architecture.md#决策2] — Agent 执行引擎：状态机驱动 + AsyncStream 流式输出
- [Source: _bmad-output/planning-artifacts/architecture.md#SDKTools 目录] — Infrastructure/SDKTools/ 下放置 ScanLibraryTool 等
- [Source: _bmad-output/planning-artifacts/architecture.md#模块间数据流] — SDKTool → LocalFolderRepository → LLMGateway → AsyncStream<AgentEvent>
- [Source: _bmad-output/planning-artifacts/prd.md#FR8] — 用户输入自然语言指令
- [Source: _bmad-output/planning-artifacts/prd.md#FR9] — 解析自然语言为 Agent 任务
- [Source: _bmad-output/planning-artifacts/prd.md#FR13] — Agent 自主执行多步工作流
- [Source: _bmad-output/planning-artifacts/prd.md#FR16] — Agent 更新流式传输到 UI
- [Source: _bmad-output/planning-artifacts/prd.md#FR43] — 配置 LLM 供应商 API Key
- [Source: _bmad-output/planning-artifacts/prd.md#FR44] — 选择默认供应商
- [Source: _bmad-output/planning-artifacts/prd.md#NFR3] — 进度更新 500ms 内出现在 UI
- [Source: _bmad-output/project-context.md#Critical Implementation Rules] — Swift 6 严格并发、禁止 Task 类型名
- [Source: _bmad-output/project-context.md#Architecture Boundaries] — Core/Agent/ 和 Infrastructure/SDKTools/ 目录映射
- [Source: OpenAgentSDKSwift/Sources/OpenAgentSDK/Types/ToolTypes.swift] — ToolProtocol、ToolResult、ToolContext 定义
- [Source: OpenAgentSDKSwift/Sources/OpenAgentSDK/Tools/ToolBuilder.swift] — defineTool() 工厂函数
- [Source: OpenAgentSDKSwift/Sources/OpenAgentSDK/Core/Agent.swift] — Agent 类、stream()、prompt()
- [Source: OpenAgentSDKSwift/Sources/OpenAgentSDK/Types/AgentTypes.swift] — AgentOptions、QueryResult、SDKMessage
- [Source: _bmad-output/implementation-artifacts/3-1-agent-execution-engine.md] — 前置 Story（AgentJob 状态机），410 测试通过

### 与后续 Story 的关系

**本 Story（3.2）为 Epic 3 建立 SDK 集成基础设施：**

- **Story 3.3（Agent 输入栏）** 将通过 ChatInputViewModel 使用 CuratorAgentFactory 创建 CuratorAgent，并连接到 AgentJob
- **Story 3.4（Agent 执行面板）** 将观察 AgentJob 的 @Observable 属性渲染 UI（已有 SDKMessageBridge 提供事件）
- **Story 3.5（会话管理）** 将使用 SDK 的 SessionStore 配置持久化 Agent 会话
- **Story 3.6（流式通信优化）** 将优化 SDKMessageBridge 的 partialMessage 处理和事件合并
- **Epic 5（去重）** 将注册 ScanLibraryTool、AnalyzeDuplicatesTool、DeleteAssetsTool、EstimateCostTool
- **Epic 6（重命名）** 将注册 AnalyzeContentTool、RenameAssetsTool

## Dev Agent Record

### Agent Model Used

GLM-5.1

### Debug Log References

- Build succeeded with `xcodebuild build` after resolving LLMProvider name collision (Curator's `LLMProvider` protocol vs SDK's `LLMProvider` enum). Used `OpenAgentSDK.LLMProvider` disambiguation in CuratorAgent, CuratorAgentFactory, and AppDependencies.
- Fixed `Dictionary.Values.last` unavailability by tracking `lastInsertedKey` in NSLockingDictionary.
- ScanLibraryTool uses `(fileName as NSString).pathExtension` instead of `fileURL.pathExtension` since PhotoAsset stores fileName in metadata, not as a URL.

### Completion Notes List

- All 6 tasks with 32 subtasks completed
- 442 total tests pass (0 failures), including 32 new Story 3.2 ATDD tests
- All 5 acceptance criteria verified through tests
- LLMProvider name collision between Curator protocol and SDK enum resolved with explicit `OpenAgentSDK.` prefix
- AgentToolRegistry uses `@unchecked Sendable` with NSLock for thread safety
- SDKMessageBridge uses internal NSLockingDictionary for toolUseId -> stepID mapping
- CuratorAgent is an actor wrapping SDK Agent, producing AsyncStream<AgentEvent>
- CuratorAgentFactory is a Sendable struct encapsulating agent creation config
- ScanLibraryTool demonstrates DI pattern via closure-captured repository
- AppDependencies.registerAgentInfrastructure() creates registry and factory from LLMConfig

### File List

#### New Files
- Curator/Core/Agent/AgentToolRegistry.swift
- Curator/Core/Agent/SDKMessageBridge.swift
- Curator/Core/Agent/CuratorAgent.swift
- Curator/Core/Agent/CuratorAgentFactory.swift
- Curator/Infrastructure/SDKTools/ScanLibraryTool.swift

#### Modified Files
- Curator/App/AppDependencies.swift (added toolRegistry, curatorAgentFactory, registerAgentInfrastructure())
- Curator/Infrastructure/SDKTools/.gitkeep (deleted)

#### Test Files (pre-existing, now green)
- CuratorTests/Core/Agent/AgentToolRegistryTests.swift (9 tests)
- CuratorTests/Core/Agent/SDKMessageBridgeTests.swift (12 tests)
- CuratorTests/Core/Agent/CuratorAgentTests.swift (9 tests)

### Change Log

- 2026-04-21: Story 3.2 implementation complete — OpenAgentSDKSwift integration with tool registry, message bridge, agent actor, factory, and scan_library tool. All 442 tests pass.
