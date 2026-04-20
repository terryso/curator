# Story 2.4: 成本追踪引擎

Status: done

## Story

As a 系统，
I want 追踪每次 LLM API 调用的成本，
So that 可以为用户展示费用预估和累计支出。

## Acceptance Criteria

1. **AC1: CostTracker 记录每次 LLM 调用成本（FR47）**
   **Given** CostTracker 已实现
   **When** 每次 LLM 调用完成
   **Then** 记录供应商名称、模型、输入/输出 token 数、成本金额
   **And** 数据持久化到 SwiftData，按会话和按月聚合

2. **AC2: 费用预估计算（FR46）**
   **Given** 用户即将执行大规模分析任务
   **When** 系统计算费用预估
   **Then** 基于照片数量和所选模型返回 CostEstimate（预估调用次数 × 单价）
   **And** 预估展示在执行确认前

3. **AC3: 月度成本查询（FR47）**
   **Given** 成本数据已累积
   **When** 查询月度成本
   **Then** 返回当月累计支出和按供应商的明细
   **And** 支持按会话查询单次操作的成本

## Tasks / Subtasks

- [x] Task 1: 定义成本追踪领域模型 (AC: #1)
  - [x] 1.1 创建 `Curator/Core/Models/CostRecord.swift` — 单次 LLM 调用的成本记录值类型（Sendable, Codable），包含 id、providerName、modelID、inputTokens、outputTokens、costUSD、timestamp、sessionID
  - [x] 1.2 创建 `Curator/Core/Models/CostSummary.swift` — 聚合成本汇总值类型，包含 totalCost、byProvider 字典、bySession 字典、dateRange

- [x] Task 2: 定义 CostTrackerProtocol (AC: #1, #3)
  - [x] 2.1 创建 `Curator/Core/Models/CostTrackerProtocol.swift` — 协议定义 `record(_:)`、`monthlySummary()`、`sessionSummary(_:)` 方法
  - [x] 2.2 协议遵循 `Sendable`，方法均为 `async throws`

- [x] Task 3: 实现 SwiftData 持久化模型 (AC: #1)
  - [x] 3.1 创建 `Curator/Infrastructure/Storage/SwiftDataModels.swift` — `CostRecordEntity` 使用 `@Model` 宏定义 SwiftData 持久化模型
  - [x] 3.2 创建 `Curator/Infrastructure/Storage/SwiftDataManager.swift` — 配置 `ModelContainer`，注册 `CostRecordEntity`
  - [x] 3.3 SwiftData ModelContainer 在 `registerLLMGateway()` 中初始化

- [x] Task 4: 实现 CostTracker (AC: #1, #2, #3)
  - [x] 4.1 创建 `Curator/Infrastructure/LLM/CostTracker.swift` — final class @unchecked Sendable，实现 `CostTrackerProtocol`
  - [x] 4.2 实现 `record(_:)` — 将 `CostRecord` 转为 `CostRecordEntity` 存入 SwiftData
  - [x] 4.3 实现 `monthlySummary()` — 查询当月所有记录，按供应商聚合返回 `CostSummary`
  - [x] 4.4 实现 `sessionSummary(_:)` — 按 sessionID 查询记录，返回该会话的 `CostSummary`
  - [x] 4.5 实现 `calculateCost(model:inputTokens:outputTokens:)` 静态方法 — 基于 `LLMModelID` pricing 计算

- [x] Task 5: 集成 CostTracker 到 LLMGateway (AC: #1)
  - [x] 5.1 修改 `LLMGateway.swift` — 添加可选 `costTracker` 属性
  - [x] 5.2 在 `analyze()` 成功调用后通过 `recordCostIfNeeded()` 记录成本
  - [x] 5.3 创建 `SessionContext` Task-local 传递会话标识

- [x] Task 6: 增强 CostEstimate 计算 (AC: #2)
  - [x] 6.1 修改 `CostEstimate.swift` — 添加 `estimatedAPICalls` 和 `currency` 字段
  - [x] 6.2 更新所有 CostEstimate 构造点（AnthropicProvider、OpenAICompatibleProvider、LLMGateway、测试文件）

- [x] Task 7: 注册 CostTracker 到 AppDependencies (AC: #1)
  - [x] 7.1 添加 `swiftDataManager` 和 `costTracker` 属性到 `AppDependencies`
  - [x] 7.2 在 `registerLLMGateway()` 中初始化 SwiftDataManager + CostTracker 并注入 LLMGateway

- [x] Task 8: ATDD 测试 (AC: #1, #2, #3)
  - [x] 8.1 创建 `CostTrackerTests.swift`、`CostTrackerIntegrationTests.swift`、`CostRecordTests.swift`
  - [x] 8.2 [P0] testRecordStoresSingleCostRecord
  - [x] 8.3 [P0] testLLMGatewayRecordsCostAfterSuccessfulCall
  - [x] 8.4 [P0] testMonthlySummaryAggregatesByProvider
  - [x] 8.5 [P0] testSessionSummaryReturnsSessionRecords
  - [x] 8.6 [P1] testCostEstimateContainsEnhancedFields
  - [x] 8.7 [P1] testMonthlySummaryReturnsZeroWhenNoRecords
  - [x] 8.8 [P1] testMonthlySummaryExcludesOtherMonths
  - [x] 8.9 构建通过 + 全部 344 测试通过（0 failures）

## Dev Notes

### 架构约束

1. **分层边界**：`CostTrackerProtocol` 在 `Core/Models/`（Domain 层）定义。`CostTracker` 实现在 `Infrastructure/LLM/`（Infrastructure 层）。SwiftData 持久化模型在 `Infrastructure/Storage/` [Source: project-context.md#Architecture Boundaries]。
2. **三层错误映射**：SwiftData 操作错误映射为 `InfrastructureError.cacheError`，再通过 ErrorMapping 传播 [Source: Curator/Core/Errors/InfrastructureError.swift]。
3. **Actor 隔离**：`CostTracker` 必须是 actor，所有 SwiftData 操作在 actor 内执行，不阻塞主线程 [Source: project-context.md#Swift 6 严格并发]。
4. **所有模型 Sendable**：`CostRecord`、`CostSummary` 必须符合 `Sendable` [Source: project-context.md#Swift 6 严格并发]。
5. **避免命名冲突**：不使用 `Task` 作为类型名 [Source: CLAUDE.md#Swift Conventions]。

### 前置 Story 上下文（Story 2.1, 2.3 已完成）

**已有的相关文件：**
- `Curator/Infrastructure/LLM/LLMGateway.swift` — actor，已有 provider 列表 + 指数退避重试 + failover 循环逻辑（157 行）
- `Curator/Infrastructure/LLM/LLMModels.swift` — `LLMModelID` 枚举，包含 pricing（inputPricePerMillionTokens, outputPricePerMillionTokens）（60 行）
- `Curator/Core/Models/CostEstimate.swift` — `CostEstimate` 值类型（estimatedTokens, estimatedCost, modelID, providerName）（17 行）
- `Curator/Core/Models/LLMResponse.swift` — `LLMResponse` 值类型（text, modelID, providerName, inputTokens, outputTokens）（18 行）
- `Curator/Core/Models/LLMProvider.swift` — `LLMProvider` 协议（11 行）
- `Curator/Core/Models/LLMGatewayProtocol.swift` — `LLMGatewayProtocol` 协议（25 行）
- `Curator/Core/Models/LLMConfig.swift` — 多供应商配置（118 行）
- `Curator/Core/Models/LLMProviderConfig.swift` — 单供应商配置值类型
- `Curator/App/AppDependencies.swift` — `registerLLMGateway()` 当前注册多供应商（95 行）
- `Curator/Core/Errors/InfrastructureError.swift` — 已有 `.cacheError(reason:)` case（23 行）

**LLMGateway 已有 estimateCost：**
LLMGateway 已实现 `estimateCost(imageCount:model:)` 方法，委托给 primary provider。本 Story 需要增强 CostEstimate 结构而非替换此方法。

**LLMResponse 已有 token 信息：**
`LLMResponse` 已包含 `inputTokens` 和 `outputTokens` 字段，可直接用于成本计算。

**LLMModelID 已有 pricing：**
`LLMModelID` 枚举已有 `inputPricePerMillionTokens` 和 `outputPricePerMillionTokens` 属性，直接复用计算实际成本。

### SwiftData 集成设计

本项目尚未使用 SwiftData（Infrastructure/Storage/ 目录为空）。本 Story 是第一个引入 SwiftData 的 Story。

**SwiftData 初始化方案：**

```swift
/// SwiftData model container for persistent storage.
///
/// Registers all SwiftData models and provides a shared ModelContainer.
/// The container is initialized once at app startup and injected where needed.
@MainActor
final class SwiftDataManager: ObservableObject {
    let container: ModelContainer

    init() {
        let schema = Schema([CostRecordEntity.self])
        let config = ModelConfiguration(schema: schema)
        do {
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }
}
```

**CostRecordEntity 设计：**

```swift
/// SwiftData persistent model for LLM call cost records.
@Model
final class CostRecordEntity {
    @Attribute(.unique) var id: UUID
    var providerName: String
    var modelID: String
    var inputTokens: Int
    var outputTokens: Int
    var costUSD: Double
    var timestamp: Date
    var sessionID: String

    init(providerName: String, modelID: String, inputTokens: Int,
         outputTokens: Int, costUSD: Double, sessionID: String) {
        self.id = UUID()
        self.providerName = providerName
        self.modelID = modelID
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.costUSD = costUSD
        self.timestamp = Date()
        self.sessionID = sessionID
    }
}
```

### CostTracker 协议设计

```swift
/// Protocol for tracking LLM API call costs.
///
/// Defined in Domain layer; CostTracker actor implementation in Infrastructure.
protocol CostTrackerProtocol: Sendable {
    /// Records a completed LLM call's cost.
    func record(_ record: CostRecord) async throws
    /// Returns the cost summary for the current calendar month.
    func monthlySummary() async throws -> CostSummary
    /// Returns the cost summary for a specific session.
    func sessionSummary(_ sessionID: String) async throws -> CostSummary
}
```

### CostTracker 集成到 LLMGateway

LLMGateway 的 `analyze()` 方法在成功返回 `LLMResponse` 后，需要记录成本。由于 LLMGateway 是 actor，需要通过注入的 `CostTrackerProtocol` 来记录：

```swift
actor LLMGateway: LLMGatewayProtocol {
    private let providers: [any LLMProvider]
    private let maxRetries: Int
    // ...existing properties...
    private let costTracker: (any CostTrackerProtocol)?

    init(providers: [any LLMProvider],
         costTracker: (any CostTrackerProtocol)? = nil,
         maxRetries: Int = 3, ...) {
        self.providers = providers
        self.costTracker = costTracker
        // ...
    }

    func analyze(images: [Data], prompt: String, model: String) async throws -> LLMResponse {
        // ...existing failover logic...
        let response = // successful response

        // Record cost
        if let tracker = costTracker {
            let cost = calculateCost(model: response.modelID,
                                     inputTokens: response.inputTokens,
                                     outputTokens: response.outputTokens)
            let record = CostRecord(providerName: response.providerName,
                                    modelID: response.modelID,
                                    inputTokens: response.inputTokens,
                                    outputTokens: response.outputTokens,
                                    costUSD: cost,
                                    sessionID: SessionContext.current ?? "unknown")
            try? await tracker.record(record)
        }
        return response
    }
}
```

### 成本计算逻辑

复用 `LLMModelID` 的 pricing 属性：

```swift
/// Calculates the actual cost of an LLM call based on token usage.
func calculateCost(model: String, inputTokens: Int, outputTokens: Int) -> Double {
    guard let modelID = LLMModelID(rawValue: model) else {
        // Unknown model: use a conservative default estimate
        return Double(inputTokens + outputTokens) * 0.003 / 1000.0
    }
    let inputCost = Double(inputTokens) * modelID.inputPricePerMillionTokens / 1_000_000.0
    let outputCost = Double(outputTokens) * modelID.outputPricePerMillionTokens / 1_000_000.0
    return inputCost + outputCost
}
```

### 文件组织

本 Story 需创建/修改的文件：

```
Curator/
├── Core/Models/
│   ├── CostRecord.swift               # 新建：单次调用成本记录值类型
│   ├── CostSummary.swift              # 新建：聚合成本汇总值类型
│   ├── CostTrackerProtocol.swift      # 新建：成本追踪协议
│   └── CostEstimate.swift             # 修改：添加 estimatedAPICalls、currency 字段
├── Infrastructure/
│   ├── LLM/
│   │   ├── CostTracker.swift          # 新建：CostTracker actor 实现
│   │   └── LLMGateway.swift          # 修改：注入 CostTracker，记录成本
│   └── Storage/
│       ├── SwiftDataManager.swift     # 新建：SwiftData ModelContainer 管理
│       └── SwiftDataModels.swift      # 新建：CostRecordEntity @Model
├── App/
│   └── AppDependencies.swift         # 修改：初始化 SwiftDataManager + CostTracker

CuratorTests/
├── Infrastructure/LLM/
│   └── CostTrackerTests.swift        # 新建：CostTracker ATDD 测试
├── Core/Models/
│   └── CostSummaryTests.swift        # 新建：CostSummary 单元测试
```

### 测试策略

**ATDD 测试优先级：**

- **[P0] CostTracker 记录单次调用成本** — 创建 CostRecord，通过 CostTracker.record() 存储，验证 SwiftData 中记录存在
- **[P0] LLMGateway 成功调用后自动记录成本** — Mock LLMProvider 返回带 token 信息的 LLMResponse，验证 CostTracker 收到 record 调用
- **[P0] 月度成本汇总按供应商聚合** — 插入多条记录（不同供应商、不同月份），验证 monthlySummary() 正确聚合
- **[P0] 会话成本查询** — 插入多条记录（不同 sessionID），验证 sessionSummary() 返回正确记录
- **[P1] CostEstimate 增强字段** — 验证 estimatedAPICalls 和 currency 字段正确
- **[P1] 空数据汇总返回零值** — 无记录时 monthlySummary() 和 sessionSummary() 返回零值 CostSummary
- **[P1] 跨月份记录隔离** — 上月记录不出现在当月汇总中

**Mock 策略：**

- CostTracker 测试使用内存 `ModelContainer`（`ModelConfiguration.isStoredInMemoryOnly = true`）避免磁盘 IO
- LLMGateway + CostTracker 集成测试使用 `MockCostTracker` 验证调用

### 不做什么（范围边界）

以下内容在本 Story 中 **不实现**，属于后续 Story：

- **费用预估卡片 UI**（Story 2.6）— CostEstimateCard 自定义组件
- **费用追踪面板 UI**（Story 2.6）— CostTrackingView 展示累计支出
- **供应商设置 UI**（Story 2.5）— Settings 界面中的 API Key 管理
- **SDK Tool: EstimateCostTool** — Agent 工具注册（属于 Epic 5 去重 SDK Tools）
- **按日/按周统计** — MVP 只支持按月和按会话查询
- **导出成本报告** — 后续功能

### 技术要求

- **Swift 6 strict concurrency**：所有新类型必须 `Sendable`
- **macOS 15+ API**：SwiftData 需要 macOS 14+，本项目 macOS 15+ 已满足
- **文件命名**：类型名即文件名
- **复用已有抽象**：`LLMModelID` pricing、`LLMResponse` token 字段、`InfrastructureError.cacheError`
- **不引入新第三方依赖**：仅使用 SwiftData（系统框架）
- **构建通过**：`xcodebuild build -project Curator.xcodeproj -scheme Curator -destination 'platform=macOS,arch=arm64'` 必须成功
- **无回归**：全部现有测试必须仍然通过
- **xcodegen 自动发现**：新增文件通过 project.yml 的 `sources: - Curator` 配置自动发现

### SessionID 传递策略

MVP 阶段使用简单的全局 `SessionContext` 传递当前会话标识：

```swift
/// Lightweight session context for cost tracking correlation.
///
/// In MVP, this uses Task-local values to pass the current session ID
/// without requiring changes to the LLMGatewayProtocol signature.
enum SessionContext {
    @TaskLocal static var current: String?
}
```

调用方在发起 LLM 调用前设置：
```swift
await SessionContext.$current.withValue("session-uuid") {
    let response = try await gateway.analyze(...)
}
```

这种方式避免修改 `LLMGatewayProtocol` 签名，保持向后兼容。

### Project Structure Notes

- `CostTracker.swift` 放在 `Infrastructure/LLM/` 目录，与 `LLMGateway.swift` 同级 [Source: architecture.md#目录组织]
- `CostTrackerProtocol` 放在 `Core/Models/`，遵循"协议在 Domain 层定义"规则 [Source: project-context.md#协议在 Domain 层定义]
- `SwiftDataManager` 和 `SwiftDataModels` 放在 `Infrastructure/Storage/`，与架构目录结构一致
- `CostRecord` 和 `CostSummary` 值类型放在 `Core/Models/`

### References

- [Source: _bmad-output/planning-artifacts/architecture.md#决策4] — LLM 网关：Provider 协议 + 故障转移链 + 成本追踪
- [Source: _bmad-output/planning-artifacts/architecture.md#决策5] — 数据持久化策略：SwiftData（元数据缓存、分析结果、操作历史）
- [Source: _bmad-output/planning-artifacts/epics.md#Story 2.4] — 原始需求定义（成本追踪引擎）
- [Source: _bmad-output/planning-artifacts/prd.md#FR46] — 系统在分析任务执行前展示费用预估
- [Source: _bmad-output/planning-artifacts/prd.md#FR47] — 系统追踪并展示累计 API 支出（按会话和按月）
- [Source: _bmad-output/planning-artifacts/prd.md#NFR20] — LLM API 调用实现指数退避，最多 3 次重试后报告失败
- [Source: _bmad-output/project-context.md#Critical Implementation Rules] — Swift 6 严格并发、三层错误体系
- [Source: _bmad-output/implementation-artifacts/2-3-multi-provider-support.md] — Story 2.3 完成记录（多供应商支持）
- [Source: Curator/Infrastructure/LLM/LLMGateway.swift] — 已有 failover 循环和指数退避重试
- [Source: Curator/Infrastructure/LLM/LLMModels.swift] — 已有 pricing（inputPrice/outputPrice per million tokens）
- [Source: Curator/Core/Models/LLMResponse.swift] — 已有 inputTokens/outputTokens 字段
- [Source: Curator/Core/Models/CostEstimate.swift] — 当前 CostEstimate 值类型
- [Source: Curator/App/AppDependencies.swift] — 当前 registerLLMGateway() 实现

## Dev Agent Record

### Agent Model Used

Claude Opus 4.7 (GLM-5.1)

### Debug Log References

No blocking issues encountered during implementation.

### Completion Notes List

- Task 1: Created `CostRecord` value type (Sendable, Codable, Identifiable) with id, providerName, modelID, inputTokens, outputTokens, costUSD, timestamp, sessionID. Created `CostSummary` value type with totalCost, totalInputTokens, totalOutputTokens, callCount, byProvider, bySession, dateRange, and static `.zero`.
- Task 2: Created `CostTrackerProtocol` in Domain layer with `record(_:)`, `monthlySummary()`, `sessionSummary(_:)` methods.
- Task 3: Created `CostRecordEntity` @Model for SwiftData persistence and `SwiftDataManager` for ModelContainer initialization. Used `ModelConfiguration(isStoredInMemoryOnly:)` for testing.
- Task 4: Implemented `CostTracker` as `final class: @unchecked Sendable` (not actor) because SwiftData's `ModelContext` is MainActor-isolated. Implemented all CRUD operations: record, monthly summary with date-range filtering, session summary. Added `calculateCost(model:inputTokens:outputTokens:)` static method using `LLMModelID` pricing.
- Task 5: Modified `LLMGateway` to accept optional `costTracker` in init. Added `recordCostIfNeeded(response:)` private method called after successful analysis. Created `SessionContext` enum with `@TaskLocal` for session ID propagation.
- Task 6: Enhanced `CostEstimate` with `estimatedAPICalls: Int` and `currency: String` fields. Updated all 7 construction sites across source and test files.
- Task 7: Added `swiftDataManager` and `costTracker` properties to `AppDependencies`. `registerLLMGateway()` now creates SwiftDataManager → CostTracker → injects into LLMGateway.
- Task 8: 22 new tests across 3 test files. All 344 tests pass (0 failures).

### File List

**New Files:**
- Curator/Core/Models/CostRecord.swift
- Curator/Core/Models/CostSummary.swift
- Curator/Core/Models/CostTrackerProtocol.swift
- Curator/Core/Models/SessionContext.swift
- Curator/Infrastructure/LLM/CostTracker.swift
- Curator/Infrastructure/Storage/SwiftDataModels.swift
- Curator/Infrastructure/Storage/SwiftDataManager.swift
- CuratorTests/Infrastructure/LLM/CostTrackerTests.swift
- CuratorTests/Infrastructure/LLM/CostTrackerIntegrationTests.swift
- CuratorTests/Core/Models/CostRecordTests.swift

**Modified Files:**
- Curator/Core/Models/CostEstimate.swift
- Curator/Infrastructure/LLM/LLMGateway.swift
- Curator/App/AppDependencies.swift
- CuratorTests/Infrastructure/LLM/LLMGatewayTests.swift
- CuratorTests/Infrastructure/LLM/MultiProviderFailoverTests.swift
- CuratorTests/DependencyInjectionTests.swift
- _bmad-output/implementation-artifacts/sprint-status.yaml

## Change Log

- 2026-04-20: Story 2.4 implementation complete — CostTracker with SwiftData persistence, LLMGateway cost recording integration, SessionContext for session correlation, CostEstimate enhancement (estimatedAPICalls + currency fields), CostSummary aggregation by provider and session. All 344 tests pass (0 failures).
- 2026-04-20: Code review — replaced silent `try?` with do/catch + os_log warning for cost recording failures, changed SwiftUI→Combine import in SwiftDataManager. 2 items deferred.

### Review Findings

- [x] [Review][Patch] Silent error swallowing in LLMGateway cost recording [Curator/Infrastructure/LLM/LLMGateway.swift:124-127] — fixed: replaced `try?` with do/catch + Self.logger.warning
- [x] [Review][Patch] Unnecessary SwiftUI import in SwiftDataManager [Curator/Infrastructure/Storage/SwiftDataManager.swift:1] — fixed: changed to `import Combine`
- [x] [Review][Defer] fatalError in SwiftDataManager init [Curator/Infrastructure/Storage/SwiftDataManager.swift:19] — deferred: pre-existing DI initialization pattern
- [x] [Review][Defer] @unchecked Sendable on CostTracker [Curator/Infrastructure/LLM/CostTracker.swift:10] — deferred: architectural constraint due to SwiftData MainActor isolation, documented
