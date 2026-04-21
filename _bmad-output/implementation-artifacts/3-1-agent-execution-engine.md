# Story 3.1: Agent 执行引擎

Status: review

## Story

As a 系统，
I want 使用状态机驱动的 Agent 执行引擎管理任务生命周期，
So that Agent 工作流有清晰的阶段和状态转换。

## Acceptance Criteria

1. **AC1: AgentJob 状态机完整生命周期（FR13）**
   **Given** AgentJob @Observable 类已实现
   **When** 检查状态机
   **Then** 支持完整生命周期：Planning -> Running -> Review -> Confirm -> Completed/Cancelled/Failed
   **And** 每次状态变更通过 @Observable 触发 SwiftUI 更新

2. **AC2: AgentEvent Sendable 枚举定义（FR14, FR15）**
   **Given** AgentEvent Sendable 枚举已定义
   **When** 检查事件类型
   **Then** 包含 planGenerated、stepStarted、stepProgress、stepReasoning、stepCompleted、stepFailed、reviewReady、executionCompleted
   **And** 所有事件类型实现 Sendable，可安全跨并发域传递

3. **AC3: AgentStep 执行步骤模型（FR14）**
   **Given** AgentStep 模型已定义
   **When** 检查字段
   **Then** 包含 id（UUID）、title、status（pending/running/completed/failed）、progress（completed/total）、reasoning 消息列表
   **And** 实现为 Sendable 值类型

4. **AC4: 用户取消支持（FR17）**
   **Given** AgentJob 正在 Running 状态
   **When** 用户点击取消按钮
   **Then** Task.cancel() 被调用，状态转换为 Cancelled
   **And** 已完成的部分结果被保留

5. **AC5: AsyncStream 流式管道（FR16, NFR3）**
   **Given** AgentJob 执行过程中产生事件
   **When** 通过 AsyncStream<AgentEvent> 发送
   **Then** 事件可被 ViewModel 消费并触发 UI 更新
   **And** Stream 随 AgentJob 生命周期正确创建和终止

## Tasks / Subtasks

- [x] Task 1: 创建 AgentJobState 枚举 (AC: #1)
  - [x] 1.1 创建 `Curator/Core/Agent/AgentJobState.swift` — 定义状态枚举
  - [x] 1.2 实现所有状态：.planning, .running, .review, .confirm, .completed, .cancelled, .failed
  - [x] 1.3 实现 Sendable 和 Equatable 协议
  - [x] 1.4 添加合法状态转换的文档注释（Planning -> Running/Cancelled, Running -> Review/Cancelled/Failed 等）

- [x] Task 2: 创建 AgentStep 模型 (AC: #3)
  - [x] 2.1 创建 `Curator/Core/Agent/AgentStep.swift` — 执行步骤值类型
  - [x] 2.2 定义字段：id (UUID), title (String), status (StepStatus), completedCount (Int), totalCount (Int), reasoningMessages ([String])
  - [x] 2.3 定义 StepStatus 枚举：.pending, .running, .completed, .failed
  - [x] 2.4 实现 Sendable, Identifiable, Equatable
  - [x] 2.5 添加 `var progress: Double` 计算属性（completedCount/totalCount 或 0）

- [x] Task 3: 创建 AgentEvent 枚举 (AC: #2)
  - [x] 3.1 创建 `Curator/Core/Agent/AgentEvent.swift` — 事件类型枚举
  - [x] 3.2 实现所有 case：
    - `planGenerated(steps: [AgentStep])`
    - `stepStarted(stepID: UUID, title: String)`
    - `stepProgress(stepID: UUID, completed: Int, total: Int)`
    - `stepReasoning(stepID: UUID, message: String)`
    - `stepCompleted(stepID: UUID, result: StepResult)`
    - `stepFailed(stepID: UUID, error: DomainError)`
    - `reviewReady(items: [ReviewItem])`
    - `executionCompleted(summary: ExecutionSummary)`
  - [x] 3.3 创建 `Curator/Core/Agent/StepResult.swift` — 步骤结果值类型（Sendable）
  - [x] 3.4 创建 `Curator/Core/Agent/ReviewItem.swift` — 审核项值类型（Sendable, 占位，Epic 4/5 填充）
  - [x] 3.5 创建 `Curator/Core/Agent/ExecutionSummary.swift` — 执行摘要值类型（Sendable, 含 totalSteps, completedSteps, failedSteps, duration, message）
  - [x] 3.6 实现 AgentEvent: Sendable

- [x] Task 4: 创建 AgentJob @Observable 类 (AC: #1, #4, #5)
  - [x] 4.1 创建 `Curator/Core/Agent/AgentJob.swift` — 核心状态机类
  - [x] 4.2 使用 @Observable 宏标记类（不是 ObservableObject + @Published）
  - [x] 4.3 实现状态属性：`var state: AgentJobState = .planning`
  - [x] 4.4 实现步骤属性：`var steps: [AgentStep] = []`
  - [x] 4.5 实现执行摘要属性：`var executionSummary: ExecutionSummary?`
  - [x] 4.6 实现错误属性：`var error: DomainError?`
  - [x] 4.7 实现取消方法 `func cancel()` — 调用内部 Task.cancel()，保留部分结果
  - [x] 4.8 实现 `var eventStream: AsyncStream<AgentEvent>` — 通过 AsyncStream.makeStream 创建
  - [x] 4.9 实现 `func start() async` — 启动执行循环，消耗内部事件
  - [x] 4.10 实现状态转换保护 — 非法转换触发 assertionFailure（Debug）或被忽略（Release）
  - [x] 4.11 添加 `@MainActor` 标注 — 因为 SwiftUI 直接观察此对象

- [x] Task 5: ATDD 测试 (AC: #1, #2, #3, #4, #5)
  - [x] 5.1 创建 `CuratorTests/Core/Agent/AgentJobTests.swift`
  - [x] 5.2 [P0] testAgentJobInitialState — AgentJob 初始状态为 .planning
  - [x] 5.3 [P0] testAgentJobStateTransitions — 合法状态转换：planning -> running -> review -> confirm -> completed
  - [x] 5.4 [P0] testAgentJobCancellation — Running 状态下取消后转换为 .cancelled，部分结果保留
  - [x] 5.5 [P0] testAgentJobFailure — 运行中失败转换为 .failed，错误信息保存
  - [x] 5.6 [P0] testAgentEventSendable — AgentEvent 所有 case 可跨并发域传递
  - [x] 5.7 [P0] testAgentStepModel — AgentStep 字段完整、progress 计算正确
  - [x] 5.8 [P0] testAsyncStreamEvents — AsyncStream<AgentEvent> 正确传递事件序列
  - [x] 5.9 [P0] testExecutionSummary — ExecutionSummary 字段完整、Sendable
  - [x] 5.10 [P1] testAgentJobObservable — 状态变更触发 SwiftUI 更新（通过 withObservationTracking 或直接验证）
  - [x] 5.11 [P1] testStepResultAndReviewItemSendable — 辅助值类型 Sendable 合规
  - [x] 5.12 构建通过 + 全部测试通过

## Dev Notes

### 架构约束

1. **分层边界**：AgentJob、AgentEvent、AgentStep、AgentJobState 全部在 `Core/Agent/`（Application + Domain 层）。AgentJob 是 Application 层的编排对象，不直接调用 Infrastructure 层——它通过 AsyncStream 接收事件，事件来源是后续 Story 3.2 注册的 SDK 工具 [Source: architecture.md#决策2]。
2. **@Observable 而非 ObservableObject**：AgentJob 使用 Swift 5.9+ 的 `@Observable` 宏（不是 `ObservableObject` + `@Published`）。这是 project-context.md 明确规定的状态管理方案 [Source: project-context.md#状态管理, architecture.md#决策6]。
3. **@MainActor 标注**：AgentJob 被 SwiftUI 直接观察，标注 `@MainActor` 确保所有状态变更在主线程 [Source: project-context.md#Swift 6 严格并发]。
4. **禁止使用 `Task` 作为类型名**：与 Swift Concurrency 的 `Task` 冲突。本 Story 使用 `AgentJob` [Source: CLAUDE.md#Swift Conventions]。
5. **Sendable 合规**：AgentEvent、AgentStep、AgentJobState、StepResult、ReviewItem、ExecutionSummary 全部实现 Sendable [Source: project-context.md#Swift 6 严格并发]。

### 前置 Story 上下文

**已有的相关基础设施（Epic 1 + Epic 2 已完成）：**

- `Curator/Core/Models/` — PhotoAsset、AssetID、AssetMetadata、LoadingState<T>、DomainError、LLMGatewayProtocol、CostTrackerProtocol 等值类型和协议已就绪
- `Curator/Core/Errors/DomainError.swift` — 已有 `operationCancelled` 和 `invalidState(reason:)` case，AgentJob 可直接复用
- `Curator/Core/Models/SessionContext.swift` — 已定义 SessionContext（16 行），为会话管理预留
- `Curator/App/AppDependencies.swift` — 依赖注入容器已有 photoRepository、llmGateway、costTracker
- `Curator/Infrastructure/LLM/LLMGateway.swift` — actor，已有 analyze() 和 estimateCost()
- `Curator/Features/MainWorkspace/AgentContentAreaPlaceholder.swift` — 当前 Agent 区域的占位视图，Story 3.4 将替换为 AgentExecutionPanel

**Epic 2 完成的关键模式：**

- ViewModel 使用 `@MainActor` + `@Observable`（非 ObservableObject）
- 协议在 `Core/Models/` 定义，实现在 `Infrastructure/` 
- CostTrackerProtocol 提供了典型的 Domain 层协议范例
- 385 个测试全部通过，新增代码不可破坏现有测试

### AgentJob 状态机设计

```
                    ┌──────────────┐
                    │   Planning   │
                    └──────┬───────┘
                           │ planGenerated
                    ┌──────▼───────┐
         ┌──────────│    Running   │──────────┐
         │ cancel   └──────┬───────┘  error   │
         │                 │ stepCompleted    │
  ┌──────▼──────┐   ┌──────▼───────┐   ┌──────▼──────┐
  │  Cancelled  │   │    Review    │   │    Failed   │
  └─────────────┘   └──────┬───────┘   └─────────────┘
         ┌─────────────────┘ reviewReady
         │
  ┌──────▼──────┐
  │   Confirm   │
  └──────┬───────┘
         │ executionCompleted
  ┌──────▼──────┐
  │  Completed  │
  └─────────────┘
```

**合法状态转换：**
- Planning -> Running（收到 planGenerated 事件）
- Planning -> Cancelled（用户在规划阶段取消）
- Running -> Review（收到 reviewReady 事件）
- Running -> Cancelled（用户取消）
- Running -> Failed（收到 stepFailed 且为致命错误）
- Review -> Confirm（用户确认审核结果）
- Review -> Cancelled（用户拒绝/取消）
- Confirm -> Completed（收到 executionCompleted 事件）
- Confirm -> Failed（执行确认失败）
- Review -> Running（Agent 需要额外处理，如用户修改了审核结果）

**注意**：Running -> Review 和 Running -> Failed 不是互斥的，取决于任务性质。分析任务通常走 Review，简单任务可以直接 Completed。

### AgentEvent 设计

```swift
/// Events emitted by an AgentJob during execution.
///
/// These events flow through AsyncStream<AgentEvent> from the AgentJob
/// to the ViewModel, which translates them into @Observable state updates
/// for SwiftUI consumption.
enum AgentEvent: Sendable {
    /// Agent generated an execution plan with steps.
    case planGenerated(steps: [AgentStep])

    /// A specific step started executing.
    case stepStarted(stepID: UUID, title: String)

    /// Progress update for a specific step.
    case stepProgress(stepID: UUID, completed: Int, total: Int)

    /// Agent reasoning/explanation for current step.
    case stepReasoning(stepID: UUID, message: String)

    /// A step completed successfully with a result.
    case stepCompleted(stepID: UUID, result: StepResult)

    /// A step failed with an error.
    case stepFailed(stepID: UUID, error: DomainError)

    /// Agent has results ready for user review.
    case reviewReady(items: [ReviewItem])

    /// Entire execution completed with a summary.
    case executionCompleted(summary: ExecutionSummary)
}
```

### AgentJob 核心实现思路

```swift
/// State machine-driven Agent execution engine.
///
/// Manages the complete lifecycle of an Agent task:
/// Planning -> Running -> Review -> Confirm -> Completed/Cancelled/Failed.
///
/// Emits events through AsyncStream<AgentEvent> for ViewModel consumption.
/// SwiftUI views observe this object directly via @Observable.
@MainActor
@Observable
final class AgentJob {
    var state: AgentJobState = .planning
    var steps: [AgentStep] = []
    var executionSummary: ExecutionSummary?
    var error: DomainError?

    private var continuation: AsyncStream<AgentEvent>.Continuation?
    private var executionTask: Task<Void, Never>?

    /// Event stream for ViewModels to consume.
    lazy var eventStream: AsyncStream<AgentEvent> = {
        AsyncStream { continuation in
            self.continuation = continuation
        }
    }()

    /// Start execution by consuming the event stream.
    func start() { ... }

    /// Cancel the running execution, preserving partial results.
    func cancel() { ... }

    /// Transition state with validation.
    private func transition(to newState: AgentJobState) { ... }

    /// Process a single event, updating state accordingly.
    private func processEvent(_ event: AgentEvent) { ... }
}
```

**关键实现细节：**

1. **AsyncStream.makeStream**：使用 `AsyncStream.makeStream(of: AgentEvent.self)` 创建 stream 和 continuation。AgentJob 持有 continuation 用于发送事件，ViewModel 消费 stream。
2. **Task 取消**：`cancel()` 调用 `executionTask?.cancel()`。在事件处理循环中检查 `Task.isCancelled`，设置 `.cancelled` 状态并结束 stream。
3. **状态转换保护**：`transition(to:)` 方法验证转换合法性，非法转换时 `assertionFailure()`（Debug）或静默忽略（Release）。
4. **部分结果保留**：取消时不清空 `steps` 和 `executionSummary`，UI 可展示"已完成 3/5 步"。

### StepResult 设计

```swift
/// Result of a completed Agent step.
///
/// Contains the step output data and optional metadata.
/// Specific step types (scan, analyze, rename) will extend this
/// with typed payloads in later Stories (Epic 5, 6).
struct StepResult: Sendable, Equatable {
    let stepID: UUID
    let message: String
    let data: [String: String]  // Flexible key-value payload
}
```

### ReviewItem 设计

```swift
/// An item presented to the user for review.
///
/// Initially a generic container; will be extended with typed
/// review data in Epic 4 (operation confirmation) and
/// Epic 5 (dedup review).
struct ReviewItem: Sendable, Identifiable, Equatable {
    let id: UUID
    let title: String
    let description: String
    let requiresConfirmation: Bool
}
```

### ExecutionSummary 设计

```swift
/// Summary of a completed Agent execution.
///
/// Captures overall execution statistics for result display.
struct ExecutionSummary: Sendable, Equatable {
    let totalSteps: Int
    let completedSteps: Int
    let failedSteps: Int
    let duration: TimeInterval
    let message: String
}
```

### 文件组织

本 Story 需创建的文件（全部在 `Core/Agent/` 目录）：

```
Curator/
├── Core/Agent/
│   ├── .gitkeep                            # 删除，替换为实际文件
│   ├── AgentJobState.swift                 # 新建：状态枚举
│   ├── AgentStep.swift                     # 新建：执行步骤模型
│   ├── AgentEvent.swift                    # 新建：事件类型枚举
│   ├── AgentJob.swift                      # 新建：核心状态机类
│   ├── StepResult.swift                    # 新建：步骤结果值类型
│   ├── ReviewItem.swift                    # 新建：审核项值类型
│   └── ExecutionSummary.swift             # 新建：执行摘要值类型

CuratorTests/
├── Core/Agent/
│   └── AgentJobTests.swift                 # 新建：ATDD 测试
```

### 测试策略

**ATDD 测试优先级：**

- **[P0] AgentJob 初始状态** — 创建后 state == .planning, steps 为空
- **[P0] 合法状态转换** — planning -> running -> review -> confirm -> completed 完整链路
- **[P0] 取消支持** — running 状态下 cancel() 后 state == .cancelled，steps 保留已完成的
- **[P0] 失败处理** — stepFailed 后 state == .failed，error 非空
- **[P0] AgentEvent Sendable** — 所有 case 可在 async 上下文中安全使用
- **[P0] AgentStep 模型** — 字段完整、progress 计算正确（0.0-1.0）
- **[P0] AsyncStream 事件传递** — 事件序列完整传递，stream 随 job 终止
- **[P0] ExecutionSummary** — 字段完整、Sendable 合规
- **[P1] @Observable 更新** — 状态变更可被 SwiftUI 感知
- **[P1] 辅助类型 Sendable** — StepResult、ReviewItem Sendable 合规

**测试不依赖 OpenAgentSDKSwift**：本 Story 只创建 AgentJob 状态机和事件模型，不涉及 SDK 集成（Story 3.2）。测试通过直接调用 AgentJob 方法和发送事件来验证。

### 不做什么（范围边界）

以下内容在本 Story 中 **不实现**：

- **OpenAgentSDKSwift 工具注册**（Story 3.2）— AgentToolRegistry 和 SDK Tool 协议适配
- **AgentInputBar UI**（Story 3.3）— 输入栏视图和 ChatInputViewModel
- **AgentExecutionPanel UI**（Story 3.4）— 执行面板、步骤卡片、推理气泡视图
- **会话管理**（Story 3.5）— 会话持久化和历史恢复
- **流式通信优化**（Story 3.6）— 事件合并、UI 不阻塞等高级优化
- **具体工具实现**（Epic 5/6）— 去重、重命名等 SDK Tool
- **OperationManager 集成**（Epic 4）— 写操作的安全保障
- **UI 测试** — 本 Story 是纯逻辑层，无 UI 变更（AgentContentAreaPlaceholder 不变）
- **修改已有测试的行为** — 所有现有测试必须继续通过

### 技术要求

- **Swift 6 strict concurrency**：所有跨并发域类型 `Sendable`，AgentJob `@MainActor`
- **@Observable 宏**：使用 Swift 5.9+ 的 @Observable（不是 ObservableObject）
- **复用已有错误类型**：DomainError.operationCancelled、DomainError.invalidState
- **不引入新第三方依赖** — 仅使用 Foundation + Swift Concurrency
- **构建通过**：`xcodebuild build` 必须成功
- **无回归**：全部 385 个现有测试必须仍然通过
- **xcodegen 自动发现**：新增文件通过 project.yml 的 `sources: - Curator` 配置自动发现

### 项目结构说明

- AgentJobState、AgentStep、AgentEvent、AgentJob、StepResult、ReviewItem、ExecutionSummary 都在 `Curator/Core/Agent/` 目录 [Source: architecture.md#目录组织, project-context.md#Architecture Boundaries]
- `Core/Agent/` 目录当前只有 `.gitkeep`（空），本 Story 将填入所有 Agent 核心类型
- 对应测试在 `CuratorTests/Core/Agent/` 目录 [Source: project-context.md#测试目录镜像源码]
- 本 Story 不触及 `Features/` 目录（UI 在后续 Story）
- 本 Story 不触及 `Infrastructure/` 目录（SDK 集成在 Story 3.2）

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 3.1] — 原始需求定义（Agent 执行引擎）
- [Source: _bmad-output/planning-artifacts/architecture.md#决策2] — Agent 执行引擎：状态机驱动 + AsyncStream 流式输出
- [Source: _bmad-output/planning-artifacts/architecture.md#AgentJob 生命周期] — Planning -> Running -> Review -> Confirm -> Completed/Cancelled/Failed
- [Source: _bmad-output/planning-artifacts/architecture.md#通信模式] — Agent 事件流定义（AgentEvent 枚举）
- [Source: _bmad-output/planning-artifacts/architecture.md#项目结构] — Core/Agent/ 目录下放置 AgentJob.swift、AgentEvent.swift、AgentStep.swift、AgentToolRegistry.swift
- [Source: _bmad-output/planning-artifacts/prd.md#FR13] — Agent 自主执行多步工作流
- [Source: _bmad-output/planning-artifacts/prd.md#FR14] — 实时查看 Agent 执行进度
- [Source: _bmad-output/planning-artifacts/prd.md#FR15] — 查看 Agent 决策推理过程
- [Source: _bmad-output/planning-artifacts/prd.md#FR16] — Agent 更新流式传输到 UI
- [Source: _bmad-output/planning-artifacts/prd.md#FR17] — 随时取消 Agent 任务
- [Source: _bmad-output/planning-artifacts/prd.md#NFR3] — 进度更新 500ms 内出现在 UI
- [Source: _bmad-output/planning-artifacts/prd.md#NFR7] — 后台 Agent 任务期间 UI 保持响应
- [Source: _bmad-output/project-context.md#Critical Implementation Rules] — Swift 6 严格并发、禁止 Task 类型名、三层错误体系
- [Source: _bmad-output/project-context.md#状态管理] — @Observable + Observation 框架
- [Source: _bmad-output/project-context.md#Architecture Boundaries] — Core/Agent/ 目录映射
- [Source: _bmad-output/implementation-artifacts/2-6-cost-estimate-and-tracking.md] — 最近完成的 Story（Epic 2 收尾），385 测试通过

### 与后续 Story 的关系

**本 Story（3.1）为 Epic 3 奠定核心基础：**

- **Story 3.2（OpenAgentSDKSwift 集成）** 将使用 AgentJob 和 AgentEvent，注册 SDK 工具产生事件
- **Story 3.3（Agent 输入栏）** 将通过 ChatInputViewModel 创建 AgentJob 并调用 start()
- **Story 3.4（Agent 执行面板）** 将观察 AgentJob 的 @Observable 属性渲染 UI
- **Story 3.5（会话管理）** 将持久化 AgentJob 的执行历史
- **Story 3.6（流式通信优化）** 将优化 AsyncStream 的事件处理性能
- **Epic 5（去重）** 将注册具体的 ScanLibraryTool、AnalyzeDuplicatesTool 等，产生 AgentEvent
- **Epic 6（重命名）** 将注册 AnalyzeContentTool、RenameAssetsTool，产生 AgentEvent
- **Epic 4（操作安全）** 将在 Confirm 阶段集成 OperationManager 的确认工作流

## Dev Agent Record

### Agent Model Used

GLM-5.1

### Debug Log References

No issues encountered. All implementations were pre-created during ATDD phase and verified during dev phase.

### Completion Notes List

- All 7 production files created in `Curator/Core/Agent/` as specified
- AgentJobState: 7-case enum (Sendable, Equatable) with documented legal transitions
- AgentStep: Value type with id, title, status, progress, reasoningMessages (Sendable, Identifiable, Equatable)
- AgentEvent: 8-case enum covering full lifecycle (Sendable)
- AgentJob: @Observable @MainActor state machine with AsyncStream event pipeline, cancellation support, state transition validation
- StepResult, ReviewItem, ExecutionSummary: Supporting value types (all Sendable)
- 25 ATDD tests in AgentJobTests.swift covering all 5 ACs (17 P0, 8 P1)
- Full test suite: 410 tests, 0 failures -- TEST SUCCEEDED
- No regressions introduced
- AsyncStream uses `makeStream()` factory pattern (compatible with @Observable macro)
- State transition validation uses switch-based `isLegalTransition(from:to:)` method

### File List

**New files:**
- Curator/Core/Agent/AgentJobState.swift
- Curator/Core/Agent/AgentStep.swift
- Curator/Core/Agent/AgentEvent.swift
- Curator/Core/Agent/AgentJob.swift
- Curator/Core/Agent/StepResult.swift
- Curator/Core/Agent/ReviewItem.swift
- Curator/Core/Agent/ExecutionSummary.swift
- CuratorTests/Core/Agent/AgentJobTests.swift

**Modified files:**
- _bmad-output/implementation-artifacts/sprint-status.yaml (status: ready-for-dev -> in-progress -> review)
- _bmad-output/implementation-artifacts/3-1-agent-execution-engine.md (tasks completed, status -> review)

### Change Log

- 2026-04-21: Story 3.1 implementation verified and completed. All 7 production files and 25 ATDD tests confirmed working. 410 total tests pass with 0 failures.
