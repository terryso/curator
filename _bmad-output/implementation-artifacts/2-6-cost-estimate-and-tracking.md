# Story 2.6: 费用预估与追踪面板

Status: done

## Story

As a 用户，
I want 查看操作费用预估和历史支出记录，
So that 我可以控制 AI 使用成本。

## Acceptance Criteria

1. **AC1: 费用预估卡片渲染（FR46, UX-DR7）**
   **Given** 即将执行大规模分析任务
   **When** CostEstimateCard 渲染
   **Then** 展示预估 API 调用次数、预估费用、所选模型
   **And** 支持切换模型查看不同费用

2. **AC2: 费用追踪面板（FR47, UX-DR12）**
   **Given** 用户查看 CostTrackingView
   **When** 费用追踪面板加载
   **Then** 展示按会话和按月的累计 API 支出
   **And** 显示各供应商的使用明细和费用占比

## Tasks / Subtasks

- [x] Task 1: 创建 CostEstimateCard 组件 (AC: #1)
  - [x] 1.1 创建 `Curator/Features/Settings/CostEstimateCard.swift` — @MainActor @Observable 视图组件
  - [x] 1.2 实现预估展示 — 接收 `CostEstimate` 参数，渲染预估调用次数、费用（USD）、所选模型名称
  - [x] 1.3 实现模型切换对比 — 模型 Picker 下拉，切换后通过 `LLMGatewayProtocol.estimateCost()` 实时重新计算
  - [x] 1.4 实现费用格式化 — USD 金额保留 4 位小数，千位分隔符

- [x] Task 2: 扩展 CostTrackingSettingsView 为完整追踪面板 (AC: #2)
  - [x] 2.1 修改 `Curator/Features/Settings/CostTrackingSettingsView.swift` — 从简单摘要扩展为完整面板
  - [x] 2.2 添加按供应商明细视图 — 使用 `CostSummary.byProvider` 字典，展示各供应商名称+费用+占比
  - [x] 2.3 添加按会话明细视图 — 使用 `CostSummary.bySession` 字典，展示各会话 ID+费用
  - [x] 2.4 添加时间范围选择器 — 按月/按周/全部的 Picker 切换查询范围
  - [x] 2.5 添加数据可视化 — 使用 SwiftUI Chart（macOS 13+）展示费用趋势柱状图或饼图

- [x] Task 3: 扩展 SettingsViewModel 支持追踪面板 (AC: #2)
  - [x] 3.1 修改 `Curator/Features/Settings/SettingsViewModel.swift` — 添加费用追踪面板所需的状态属性
  - [x] 3.2 添加 `allTimeSummary: CostSummary?` — 全部历史费用汇总
  - [x] 3.3 添加 `selectedTimeTimeRange: CostTimeRange` 枚举（.month / .all）
  - [x] 3.4 添加 `loadAllTimeSummary()` 方法 — 从 CostTracker 查询全量汇总
  - [x] 3.5 添加 `refreshCostData()` 方法 — 根据选中的时间范围刷新费用数据

- [x] Task 4: 扩展 CostTrackerProtocol 查询能力 (AC: #2)
  - [x] 4.1 修改 `Curator/Core/Models/CostTrackerProtocol.swift` — 添加新的查询方法
  - [x] 4.2 添加 `func allTimeSummary() async throws -> CostSummary` — 全部历史费用
  - [x] 4.3 添加 `func recentRecords(limit: Int) async throws -> [CostRecord]` — 最近 N 条记录

- [x] Task 5: 实现 CostTracker 新查询方法 (AC: #2)
  - [x] 5.1 修改 `Curator/Infrastructure/LLM/CostTracker.swift` — 实现 CostTrackerProtocol 新方法
  - [x] 5.2 实现 `allTimeSummary()` — 查询全量 CostRecordEntity 并聚合
  - [x] 5.3 实现 `recentRecords(limit:)` — FetchDescriptor 排序按 timestamp 降序，限制条数

- [x] Task 6: 创建 CostTimeRange 查询辅助 (AC: #2)
  - [x] 6.1 创建 `Curator/Core/Models/CostTimeRange.swift` — 枚举定义（.month / .all）
  - [x] 6.2 添加 `dateRange()` 计算属性 — 返回对应时间范围的 DateInterval

- [x] Task 7: ATDD 测试 (AC: #1, #2)
  - [x] 7.1 修改 `CuratorTests/Features/Settings/SettingsViewModelTests.swift` — 添加费用追踪面板测试
  - [x] 7.2 [P0] testCostEstimateCardDisplaysEstimate — CostEstimateCard 正确渲染预估数据
  - [x] 7.3 [P0] testCostTrackingPanelLoadsMonthlySummary — 按月查询费用汇总
  - [x] 7.4 [P0] testCostTrackingPanelLoadsAllTimeSummary — 全量查询费用汇总
  - [x] 7.5 [P0] testCostTrackingPanelProviderBreakdown — 供应商费用明细展示
  - [x] 7.6 [P0] testAllTimeSummaryReturnsAllRecords — allTimeSummary 返回所有记录聚合
  - [x] 7.7 [P0] testRecentRecordsReturnsLimitedResults — recentRecords 返回指定条数
  - [x] 7.8 [P1] testModelSwitchRecalculatesEstimate — 切换模型后费用预估重新计算
  - [x] 7.9 构建通过 + 全部测试通过

## Dev Notes

### 架构约束

1. **分层边界**：CostEstimateCard 和 CostTrackingSettingsView 在 `Features/Settings/`（Presentation 层）。它们通过 `SettingsViewModel`（Presentation 层）访问 `CostTrackerProtocol`（Domain 层定义的协议）和 `LLMGatewayProtocol`（Domain 层定义的协议），不直接依赖 Infrastructure 层 [Source: project-context.md#分层架构]。
2. **@MainActor**：SettingsViewModel 为 `@MainActor @Observable`，所有 UI 状态更新在主线程 [Source: project-context.md#Swift 6 严格并发]。
3. **CostTrackerProtocol 扩展**：新增查询方法需同时更新协议（Domain 层）和实现（Infrastructure 层）[Source: architecture.md#决策4]。
4. **避免命名冲突**：不使用 `Task` 作为类型名 [Source: CLAUDE.md#Swift Conventions]。

### 前置 Story 上下文（Story 2.1-2.5 已完成）

**已有的相关文件（已验证存在且功能完整）：**

- `Curator/Core/Models/CostTrackerProtocol.swift`（14 行）— 协议定义 `record()`、`monthlySummary()`、`sessionSummary()`
- `Curator/Core/Models/CostEstimate.swift`（20 行）— 值类型：estimatedTokens、estimatedCost、modelID、providerName、estimatedAPICalls、currency
- `Curator/Core/Models/CostSummary.swift`（32 行）— 聚合值类型：totalCost、totalInputTokens、totalOutputTokens、callCount、byProvider、bySession、dateRange，含 `static let zero`
- `Curator/Core/Models/CostRecord.swift`（45 行）— 单次调用记录：providerName、modelID、inputTokens、outputTokens、costUSD、timestamp、sessionID
- `Curator/Infrastructure/LLM/CostTracker.swift`（108 行）— 实现 CostTrackerProtocol，使用 SwiftData ModelContext，包含 `calculateCost()` 静态方法和 `buildSummary()` 私有方法
- `Curator/Infrastructure/Storage/SwiftDataModels.swift`（38 行）— CostRecordEntity @Model，字段与 CostRecord 一一对应
- `Curator/Infrastructure/LLM/LLMGateway.swift`（193 行）— actor，已有 `estimateCost(imageCount:model:)` 方法，委托给 primary provider
- `Curator/Core/Models/LLMGatewayProtocol.swift`（25 行）— 包含 `estimateCost(imageCount:model:) async -> CostEstimate`
- `Curator/Infrastructure/LLM/LLMModels.swift`（60 行）— LLMModelID 枚举（5 个模型），含 pricing 和 `estimatedTokensPerImage`
- `Curator/Features/Settings/CostTrackingSettingsView.swift`（79 行）— Story 2.5 创建的摘要视图，展示当月费用，作为本 Story 的起点
- `Curator/Features/Settings/SettingsViewModel.swift`（184 行）— 已有 `monthlyCostSummary` 属性和 `loadMonthlyCostSummary()` 方法
- `Curator/Features/Settings/SettingsView.swift`（76 行）— NavigationSplitView，costTracking 分类指向 CostTrackingSettingsView
- `Curator/App/AppDependencies.swift`（108 行）— 已有 `costTracker: (any CostTrackerProtocol)?` 和 `llmGateway: (any LLMGatewayProtocol)?`

**Story 2.5 遗留的关键上下文：**

- CostTrackingSettingsView 当前是简单摘要（当月费用 + 刷新按钮），本 Story 需将其扩展为完整面板
- SettingsViewModel 已有 `loadMonthlyCostSummary()` 方法（异步从 costTracker 读取月度汇总）
- `dependencies.costTracker` 和 `dependencies.llmGateway` 已在 AppDependencies 中正确注入

### 设计方案

**CostEstimateCard 组件：**

```swift
/// Cost estimate card showing projected LLM API costs before execution.
///
/// Displays estimated API calls, cost, and selected model.
/// Supports model switching to compare costs across different models.
struct CostEstimateCard: View {
    let gateway: any LLMGatewayProtocol
    let imageCount: Int
    @State private var selectedModel: String = LLMModelID.claudeSonnet.rawValue
    @State private var estimate: CostEstimate?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Cost Estimate")
                .font(.headline)
            // Model picker + estimated calls + cost display
        }
        .task { await loadEstimate() }
        .onChange(of: selectedModel) { _, _ in Task { await loadEstimate() } }
    }

    private func loadEstimate() async {
        estimate = await gateway.estimateCost(imageCount: imageCount, model: selectedModel)
    }
}
```

**CostTrackingSettingsView 扩展（完整面板）：**

在现有月度摘要基础上添加：
1. **供应商明细区域** — 遍历 `CostSummary.byProvider`，展示各供应商名称、费用金额、百分比占比
2. **会话明细区域** — 遍历 `CostSummary.bySession`，展示各会话费用
3. **时间范围选择** — Picker 切换（本月 / 全部）控制查询范围
4. **最近调用记录** — 展示最近 10 条 `CostRecord`（provider、model、cost、time）

**SettingsViewModel 扩展：**

```swift
// 新增属性
var allTimeSummary: CostSummary?
var selectedTimeRange: CostTimeRange = .month
var recentRecords: [CostRecord] = []

// 新增方法
func loadAllTimeSummary() async { ... }
func refreshCostData() async { ... }
func loadRecentRecords() async { ... }
```

**CostTrackerProtocol 扩展：**

```swift
protocol CostTrackerProtocol: Sendable {
    // 已有方法
    func record(_ record: CostRecord) async throws
    func monthlySummary() async throws -> CostSummary
    func sessionSummary(_ sessionID: String) async throws -> CostSummary

    // 新增方法
    func allTimeSummary() async throws -> CostSummary
    func recentRecords(limit: Int) async throws -> [CostRecord]
}
```

### CostEstimateCard 使用场景

CostEstimateCard 是一个独立可复用组件，预期使用场景：
1. **设置面板** — 用户可在费用追踪页面预览不同模型的成本差异
2. **Agent 执行前**（后续 Epic 3 集成）— 大规模分析任务执行前展示费用预估，用户确认后才继续
3. **SDK Tool: EstimateCostTool**（后续 Epic 5）— Agent 调用此工具向用户展示预估成本

本 Story 实现场景 1（设置面板中的成本计算器），为后续场景提供可复用组件。

### 文件组织

本 Story 需创建/修改的文件：

```
Curator/
├── Core/Models/
│   ├── CostTrackerProtocol.swift     # 修改：添加 allTimeSummary()、recentRecords()
│   └── CostTimeRange.swift           # 新建：时间范围枚举（.month / .all）
├── Features/Settings/
│   ├── CostTrackingSettingsView.swift # 修改：扩展为完整追踪面板
│   ├── CostEstimateCard.swift        # 新建：费用预估卡片组件
│   └── SettingsViewModel.swift       # 修改：添加追踪面板状态和方法
├── Infrastructure/LLM/
│   └── CostTracker.swift             # 修改：实现新的查询方法

CuratorTests/
├── Features/Settings/
│   └── SettingsViewModelTests.swift  # 修改：添加费用追踪面板测试
```

### 测试策略

**ATDD 测试优先级：**

- **[P0] CostEstimateCard 渲染** — 传入 CostEstimate 后正确展示预估数据
- **[P0] 月度费用汇总** — 面板加载时查询当月费用
- **[P0] 全量费用汇总** — 切换时间范围后查询全部历史费用
- **[P0] 供应商明细** — CostSummary.byProvider 数据正确展示
- **[P0] allTimeSummary 返回全量** — CostTracker 新方法正确聚合所有记录
- **[P0] recentRecords 限制条数** — CostTracker 新方法返回正确数量
- **[P1] 模型切换重新计算** — CostEstimateCard 切换模型后费用更新

**Mock 策略：**

- 使用 MockCostTracker（已有或新建）注入 SettingsViewModel
- 使用 MockLLMGateway 注入 CostEstimateCard

### 不做什么（范围边界）

以下内容在本 Story 中 **不实现**：

- **Agent 执行前费用预估集成**（Epic 3）— CostEstimateCard 作为独立组件创建，Agent 执行流程集成在 Epic 3
- **SDK Tool: EstimateCostTool**（Epic 5）— Agent 调用的成本预估工具
- **费用导出/报告生成** — 后续增强
- **费用预算警告/限额** — 后续增强
- **Sparkle 自动更新**（Epic 7）— 与本 Story 无关
- **修改已有测试的行为** — 所有现有测试必须继续通过

### 技术要求

- **Swift 6 strict concurrency**：所有跨并发域类型 `Sendable`，ViewModel `@MainActor`
- **复用已有抽象**：CostEstimate、CostSummary、CostRecord 值类型；CostTrackerProtocol 协议；LLMGatewayProtocol.estimateCost()
- **不引入新第三方依赖** — SwiftUI Chart（macOS 13+ 内置）可用于可视化
- **构建通过**：`xcodebuild build` 必须成功
- **无回归**：全部现有测试必须仍然通过
- **xcodegen 自动发现**：新增文件通过 project.yml 的 `sources: - Curator` 配置自动发现
- **参考 macOS HIG**：设置面板遵循 Apple Human Interface Guidelines

### 项目结构说明

- CostTimeRange 是 Domain 层值类型，放在 `Curator/Core/Models/` [Source: architecture.md#目录组织]
- CostEstimateCard 是 Presentation 层自定义组件，放在 `Curator/Features/Settings/` [Source: architecture.md#Feature-based 目录结构]
- CostTrackerProtocol 扩展方法在 Domain 层定义、Infrastructure 层实现 [Source: architecture.md#分层架构]
- CostTrackingSettingsView 已存在，本 Story 在其基础上扩展 [Source: Story 2.5 File List]

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 2.6] — 原始需求定义（费用预估与追踪面板）
- [Source: _bmad-output/planning-artifacts/architecture.md#决策4] — LLM 网关：Provider 协议 + 故障转移链 + 成本追踪
- [Source: _bmad-output/planning-artifacts/prd.md#FR46] — 分析任务执行前展示费用预估
- [Source: _bmad-output/planning-artifacts/prd.md#FR47] — 追踪并展示累计 API 支出
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#UX-DR7] — CostEstimateCard 费用预估卡片
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#UX-DR12] — 费用追踪面板
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#Journey 4] — Alex 旅程（API Key 配置和成本追踪）
- [Source: _bmad-output/project-context.md#Critical Implementation Rules] — Swift 6 严格并发、分层架构
- [Source: _bmad-output/implementation-artifacts/2-5-provider-settings-ui.md] — Story 2.5 完成记录（供应商设置 UI）
- [Source: _bmad-output/implementation-artifacts/2-4-cost-tracking-engine.md] — Story 2.4 完成记录（成本追踪引擎）
- [Source: Curator/Core/Models/CostTrackerProtocol.swift] — 当前协议定义
- [Source: Curator/Core/Models/CostEstimate.swift] — 费用预估值类型
- [Source: Curator/Core/Models/CostSummary.swift] — 费用汇总值类型
- [Source: Curator/Core/Models/CostRecord.swift] — 单次调用记录值类型
- [Source: Curator/Infrastructure/LLM/CostTracker.swift] — CostTracker 实现
- [Source: Curator/Infrastructure/LLM/LLMGateway.swift] — estimateCost() 实现
- [Source: Curator/Infrastructure/LLM/LLMModels.swift] — LLMModelID + pricing
- [Source: Curator/Features/Settings/CostTrackingSettingsView.swift] — 当前费用追踪视图（待扩展）
- [Source: Curator/Features/Settings/SettingsViewModel.swift] — 当前 SettingsViewModel（待扩展）
- [Source: Curator/App/AppDependencies.swift] — costTracker 和 llmGateway 注入

## Dev Agent Record

### Agent Model Used

GLM-5.1

### Debug Log References

- All tests pass: 385 tests, 0 failures (verified via xcodebuild)

### Completion Notes List

- Task 1: CostEstimateCard fully implemented with model Picker, USD formatting (4 decimal places, thousands separator), provider name display, and model switching via `LLMGatewayProtocol.estimateCost()`
- Task 2: CostTrackingSettingsView expanded from simple monthly summary to full panel with: time range segmented picker (.month/.all), provider breakdown with cost and percentage, session breakdown, SwiftUI Charts bar chart visualization, recent records list with relative timestamps, and auto-load on appear
- Task 3: SettingsViewModel stubs finalized — `allTimeSummary`, `selectedTimeRange`, `recentRecords` properties and `loadAllTimeSummary()`, `refreshCostData()`, `loadRecentRecords()` methods are fully functional
- Task 4: CostTrackerProtocol extended with `allTimeSummary()` and `recentRecords(limit:)` — protocol defined in Domain layer
- Task 5: CostTracker implementations finalized — `allTimeSummary()` fetches all records and aggregates; `recentRecords(limit:)` handles limit=0 edge case by returning empty array
- Task 6: CostTimeRange enum with `.month` and `.all` cases, `dateRange` computed property returns current month interval or nil
- Task 7: All 23 ATDD tests activated (removed XCTSkip), previously skipped `testRecentRecordsReturnsEmptyForLimitZero` now passes with limit=0 edge case fix. Full suite: 385 tests, 0 failures

### File List

**Modified:**
- `Curator/Core/Models/CostTrackerProtocol.swift` — Added `allTimeSummary()` and `recentRecords(limit:)` protocol methods
- `Curator/Core/Models/CostTimeRange.swift` — Removed RED stub comments, working implementation
- `Curator/Infrastructure/LLM/CostTracker.swift` — Implemented `allTimeSummary()` and `recentRecords(limit:)` with limit=0 edge case handling
- `Curator/Features/Settings/CostEstimateCard.swift` — Full implementation with model Picker, USD formatting, provider display
- `Curator/Features/Settings/CostTrackingSettingsView.swift` — Expanded to full panel with provider/session breakdown, time range picker, Chart visualization, recent records
- `Curator/Features/Settings/SettingsViewModel.swift` — Removed RED comments, functional stubs finalized
- `CuratorTests/Features/Settings/CostEstimateCardTests.swift` — Removed all XCTSkip, 6 tests active
- `CuratorTests/Features/Settings/CostTrackingPanelTests.swift` — Removed all XCTSkip, 8 tests active (including previously skipped limit=0 test)
- `CuratorTests/Features/Settings/SettingsViewModelTests.swift` — Removed all XCTSkip for Story 2.6 tests, 9 new tests active

### Review Findings

- [x] [Review][Defer] `allTimeSummary()` fetches all records without limit (unbounded memory) [Curator/Infrastructure/LLM/CostTracker.swift:72] — deferred, pre-existing pattern consistent with `monthlySummary()` and `sessionSummary()`
- [x] [Review][Defer] Silent error swallowing in SettingsViewModel with no logging [Curator/Features/Settings/SettingsViewModel.swift:199-209] — deferred, consistent with pre-existing `loadMonthlyCostSummary()` pattern from Story 2.5
- [x] [Review][Patch] NumberFormatter created on every render in CostEstimateCard and CostTrackingSettingsView [Curator/Features/Settings/CostEstimateCard.swift:58-64, Curator/Features/Settings/CostTrackingSettingsView.swift:246-253] — fixed: extracted to static let formatters
- [x] [Review][Patch] `allTimeSummary()` uses min/max after sorted fetch — should use first/last [Curator/Infrastructure/LLM/CostTracker.swift:78-79] — fixed: replaced min/max with first/last
- [x] [Review][Patch] `ProviderCostData` not marked Sendable under Swift 6 strict concurrency [Curator/Features/Settings/CostTrackingSettingsView.swift:264] — fixed: added Sendable conformance
- [x] [Review][Patch] `onChange(of: selectedModel)` creates unstructured Task that may race with `.task` modifier [Curator/Features/Settings/CostEstimateCard.swift:46-47] — fixed: replaced with .task(id:)
- [x] [Review][Patch] Dead `if #available(macOS 13.0, *)` check — project targets macOS 15 [Curator/Features/Settings/CostTrackingSettingsView.swift:190] — fixed: removed dead availability check

### Change Log

- 2026-04-20: Story 2.6 implementation complete — CostEstimateCard component, full CostTrackingSettingsView panel, SettingsViewModel extensions, CostTrackerProtocol/CostTracker extensions, CostTimeRange enum. All 385 tests pass, 0 failures.
- 2026-04-20: Code review — 0 decision-needed, 5 patch (all fixed), 2 deferred, 1 dismissed. 385 tests still pass.
