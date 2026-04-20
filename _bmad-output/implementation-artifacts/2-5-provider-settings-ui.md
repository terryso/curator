# Story 2.5: 供应商设置 UI

Status: done

## Story

As a 用户，
I want 在设置页面配置 API Key 和选择默认供应商，
So that 我可以使用自己的 AI 账户。

## Acceptance Criteria

1. **AC1: 设置页面渲染（FR44）**
   **Given** 用户打开设置页面（⌘,）
   **When** SettingsView 渲染
   **Then** 展示标准 macOS Settings 窗口：API Key 管理、模型选择、费用追踪入口
   **And** APIKeyManagementView 使用 SecureField 输入 Key

2. **AC2: API Key 验证与存储**
   **Given** 用户输入 Anthropic API Key
   **When** 点击"验证"
   **Then** 发送测试请求验证 Key 有效性，展示成功/失败反馈
   **And** 验证成功后 Key 存储到 UserDefaults（通过 LLMConfig.save()）
   **And** AppDependencies.registerLLMGateway() 使用更新后的配置

3. **AC3: 默认模型选择（FR44）**
   **Given** 用户选择默认模型
   **When** 在 ModelSelectionView 中切换
   **Then** 设置更新立即生效，后续 LLM 调用使用新选择的模型

## Tasks / Subtasks

- [x] Task 1: 创建 SettingsViewModel (AC: #1, #2, #3)
  - [x] 1.1 创建 `Curator/Features/Settings/SettingsViewModel.swift` — @MainActor @Observable，管理 LLMConfig 的读写
  - [x] 1.2 实现 `loadCurrentConfig()` — 从 LLMConfig.load() 加载当前配置到 @Published 属性
  - [x] 1.3 实现 `saveConfig()` — 将编辑中的配置通过 LLMConfig.save() 持久化
  - [x] 1.4 实现 `validateAPIKey()` — 通过 LLMGateway 发送测试请求验证 Key 有效性
  - [x] 1.5 实现 `rebuildGateway()` — 保存后调用 AppDependencies.registerLLMGateway() 重建网关

- [x] Task 2: 创建 SettingsView 主视图 (AC: #1)
  - [x] 2.1 创建 `Curator/Features/Settings/SettingsView.swift` — 标准 macOS Settings 窗口布局
  - [x] 2.2 实现左侧导航列表：供应商配置（主/备用）、模型选择、费用追踪
  - [x] 2.3 使用 NavigationSplitView 或 TabView 组织设置分类
  - [x] 2.4 替换 CuratorApp.swift 中的 SettingsPlaceholderView 为 SettingsView

- [x] Task 3: 创建 APIKeyManagementView (AC: #1, #2)
  - [x] 3.1 创建 `Curator/Features/Settings/APIKeyManagementView.swift` — Form 布局，包含 provider type picker、base URL、API Key SecureField
  - [x] 3.2 实现主供应商配置区域 — providerType picker、baseURL TextField、apiKey SecureField、modelID Picker
  - [x] 3.3 实现备用供应商配置区域（可折叠） — 同上字段 + displayName TextField
  - [x] 3.4 实现"验证"按钮 — 调用 SettingsViewModel.validateAPIKey()，显示 loading/success/error 状态

- [x] Task 4: 创建 ModelSelectionView (AC: #3)
  - [x] 4.1 创建 `Curator/Features/Settings/ModelSelectionView.swift` — 展示可用模型列表（来自 LLMModelID.allCases）
  - [x] 4.2 实现模型选择 — 绑定到 SettingsViewModel 的 selectedModelID
  - [x] 4.3 显示每个模型的定价信息（input/output price per million tokens）

- [x] Task 5: 创建 CostTrackingSettingsView（入口占位） (AC: #1)
  - [x] 5.1 创建 `Curator/Features/Settings/CostTrackingSettingsView.swift` — 展示当月费用摘要 + 链接到 Story 2.6 的完整追踪面板
  - [x] 5.2 从 CostTrackerProtocol.monthlySummary() 读取并展示当月累计费用

- [x] Task 6: 注册 SettingsViewModel 到环境 (AC: #1, #2, #3)
  - [x] 6.1 修改 `Curator/App/AppDependencies.swift` — 添加 settingsViewModel 属性
  - [x] 6.2 修改 `Curator/CuratorApp.swift` — 通过 @EnvironmentObject 注入 SettingsViewModel
  - [x] 6.3 SettingsViewModel 通过 AppDependencies 获取 costTracker 和 llmGateway 引用

- [x] Task 7: ATDD 测试 (AC: #1, #2, #3)
  - [x] 7.1 创建 `CuratorTests/Features/Settings/SettingsViewModelTests.swift`
  - [x] 7.2 [P0] testLoadCurrentConfigLoadsFromLLMConfig — LLMConfig 存在时正确加载
  - [x] 7.3 [P0] testSaveConfigPersistsToLLMConfig — 保存后 LLMConfig.load() 返回新值
  - [x] 7.4 [P0] testValidateAPIKeySuccess — Mock LLMGateway 返回成功，验证状态更新
  - [x] 7.5 [P0] testValidateAPIKeyFailure — Mock LLMGateway 抛出错误，验证错误状态
  - [x] 7.6 [P0] testRebuildGatewayAfterSave — 保存配置后 AppDependencies.registerLLMGateway() 被调用
  - [x] 7.7 [P1] testModelSelectionUpdatesConfig — 切换模型后配置立即更新
  - [x] 7.8 [P1] testFallbackProviderToggle — 启用/禁用备用供应商的配置状态
  - [x] 7.9 构建通过 + 全部测试通过

## Dev Notes

### 架构约束

1. **分层边界**：SettingsViewModel 在 `Features/Settings/`（Presentation 层）。它通过 `AppDependencies`（Application 层）访问 `LLMGatewayProtocol` 和 `CostTrackerProtocol`（Domain 层定义的协议），不直接依赖 Infrastructure 层 [Source: project-context.md#分层架构]。
2. **@MainActor**：SettingsViewModel 是 `@MainActor @Observable`，所有 UI 状态更新在主线程 [Source: project-context.md#Swift 6 严格并发]。
3. **已有配置模型**：`LLMConfig` 已实现多供应商配置（primary + optional fallback），支持 UserDefaults 持久化和向后兼容迁移 [Source: Curator/Core/Models/LLMConfig.swift]。
4. **已有模型枚举**：`LLMModelID` 已有 `allCases`（CaseIterable）和 pricing 属性 [Source: Curator/Infrastructure/LLM/LLMModels.swift]。
5. **避免命名冲突**：不使用 `Task` 作为类型名 [Source: CLAUDE.md#Swift Conventions]。

### 前置 Story 上下文（Story 2.1, 2.3, 2.4 已完成）

**已有的相关文件：**
- `Curator/Features/Settings/SettingsPlaceholderView.swift` — 当前占位设置视图（100 行），需替换为正式 SettingsView
- `Curator/Core/Models/LLMConfig.swift` — 多供应商配置（118 行），已有 load/save/clear/isStored 方法
- `Curator/Core/Models/LLMProviderConfig.swift` — 单供应商配置值类型，providerType/baseURL/apiKey/modelID/displayName（36 行）
- `Curator/Core/Models/LLMProvider.swift` — LLMProvider 协议（11 行）
- `Curator/Core/Models/LLMGatewayProtocol.swift` — LLMGatewayProtocol 协议（25 行）
- `Curator/Core/Models/LLMResponse.swift` — LLMResponse 值类型（18 行）
- `Curator/Core/Models/CostEstimate.swift` — CostEstimate 值类型（20 行）
- `Curator/Core/Models/CostTrackerProtocol.swift` — CostTrackerProtocol 协议（14 行）
- `Curator/Core/Models/CostSummary.swift` — CostSummary 聚合值类型，含 totalCost/byProvider/dateRange
- `Curator/Core/Models/SessionContext.swift` — SessionContext Task-local 传递
- `Curator/Infrastructure/LLM/LLMGateway.swift` — actor，已有 providers + 重试 + failover + costTracker 注入
- `Curator/Infrastructure/LLM/LLMModels.swift` — LLMModelID 枚举（5 个模型），含 pricing（60 行）
- `Curator/Infrastructure/LLM/AnthropicProvider.swift` — AnthropicProvider 实现
- `Curator/Infrastructure/LLM/OpenAICompatibleProvider.swift` — OpenAICompatibleProvider 实现
- `Curator/Infrastructure/LLM/CostTracker.swift` — CostTracker 实现
- `Curator/Infrastructure/Storage/SwiftDataManager.swift` — SwiftData ModelContainer 管理
- `Curator/Infrastructure/Storage/SwiftDataModels.swift` — CostRecordEntity @Model
- `Curator/App/AppDependencies.swift` — registerLLMGateway() 当前注册多供应商 + CostTracker（109 行）
- `Curator/CuratorApp.swift` — Settings 场景当前使用 SettingsPlaceholderView（51 行）

**SettingsPlaceholderView 分析：**
当前占位视图已实现基本功能（baseURL + apiKey + modelID 表单 + 自动保存），但不支持：
- 多供应商配置（只有单一 provider）
- 备用供应商配置
- API Key 验证功能
- 模型选择与定价展示
- 费用追踪面板入口
- 标准 macOS Settings 窗口布局

**策略：** 创建新的 SettingsView 替换 SettingsPlaceholderView，保留其自动保存模式但扩展为完整的多供应商配置界面。

### 设计方案

**SettingsView 布局：**

```
┌─────────────────────────────────────────────┐
│  Settings                                     │
├──────────┬──────────────────────────────────┤
│ 供应商配置 │  [主供应商配置 Form]              │
│ 模型选择   │  Type: [Anthropic ▾]              │
│ 费用追踪   │  Base URL: [https://api.anthropic] │
│           │  API Key: [••••••••] [验证]         │
│           │  Model: [claude-sonnet-4 ▾]         │
│           │                                     │
│           │  [✓] 启用备用供应商                  │
│           │  Type: [OpenAI 兼容 ▾]               │
│           │  Name: [DeepSeek]                    │
│           │  Base URL: [https://api.deepseek]    │
│           │  API Key: [••••••••] [验证]           │
│           │  Model: [deepseek-chat ▾]            │
└──────────┴──────────────────────────────────┘
```

**SettingsViewModel 设计：**

```swift
/// ViewModel for the Settings window, managing LLM provider configuration.
///
/// Loads/saves LLMConfig and triggers gateway rebuild when config changes.
/// Validates API keys by sending a lightweight test request through LLMGateway.
@MainActor
@Observable
final class SettingsViewModel {
    // 主供应商
    var primaryProviderType: LLMProviderType = .anthropic
    var primaryBaseURL: String = ""
    var primaryAPIKey: String = ""
    var primaryModelID: String = LLMModelID.claudeSonnet.rawValue

    // 备用供应商
    var hasFallback: Bool = false
    var fallbackProviderType: LLMProviderType = .openAICompatible
    var fallbackDisplayName: String = ""
    var fallbackBaseURL: String = ""
    var fallbackAPIKey: String = ""
    var fallbackModelID: String = LLMModelID.gpt4oMini.rawValue

    // 验证状态
    var isValidatingPrimary: Bool = false
    var primaryValidationResult: ValidationResult?
    var isValidatingFallback: Bool = false
    var fallbackValidationResult: ValidationResult?

    enum ValidationResult {
        case success
        case failure(String)
    }

    private let dependencies: AppDependencies

    init(dependencies: AppDependencies) { ... }
    func loadCurrentConfig() { ... }
    func saveConfig() { ... }
    func validatePrimaryAPIKey() async { ... }
    func validateFallbackAPIKey() async { ... }
}
```

**API Key 验证策略：**

发送一个最小化请求（单个 token prompt）来验证 Key 有效性。使用 LLMProviderProtocol 的 analyze 方法：

```swift
func validatePrimaryAPIKey() async {
    isValidatingPrimary = true
    primaryValidationResult = nil

    let provider: any LLMProvider = primaryProviderType == .anthropic
        ? AnthropicProvider(apiKey: primaryAPIKey, baseURL: primaryBaseURL)
        : OpenAICompatibleProvider(name: "Validation", apiKey: primaryAPIKey, baseURL: primaryBaseURL)

    do {
        _ = try await provider.analyze(
            images: [],
            prompt: "Hello",
            model: primaryModelID
        )
        primaryValidationResult = .success
    } catch {
        primaryValidationResult = .failure(error.localizedDescription)
    }
    isValidatingPrimary = false
}
```

**保存后重建网关：**

```swift
func saveConfig() {
    let primary = LLMProviderConfig(
        providerType: primaryProviderType,
        baseURL: primaryBaseURL,
        apiKey: primaryAPIKey,
        modelID: primaryModelID,
        displayName: nil
    )
    let fallback: LLMProviderConfig? = hasFallback
        ? LLMProviderConfig(
            providerType: fallbackProviderType,
            baseURL: fallbackBaseURL,
            apiKey: fallbackAPIKey,
            modelID: fallbackModelID,
            displayName: fallbackDisplayName.isEmpty ? nil : fallbackDisplayName
        )
        : nil

    let config = LLMConfig(primary: primary, fallback: fallback)
    config.save()

    // 重建网关使配置立即生效
    dependencies.registerLLMGateway()
}
```

### 文件组织

本 Story 需创建/修改的文件：

```
Curator/
├── Features/Settings/
│   ├── SettingsView.swift                 # 新建：主设置视图（NavigationSplitView 布局）
│   ├── SettingsViewModel.swift            # 新建：设置 ViewModel（@MainActor @Observable）
│   ├── APIKeyManagementView.swift         # 新建：API Key 管理 + 验证
│   ├── ModelSelectionView.swift           # 新建：模型选择 + 定价展示
│   ├── CostTrackingSettingsView.swift     # 新建：费用追踪设置（摘要 + Story 2.6 入口）
│   └── SettingsPlaceholderView.swift      # 删除：被 SettingsView 替换
├── App/
│   ├── AppDependencies.swift              # 修改：添加 settingsViewModel 属性
│   └── CuratorApp.swift                   # 修改：替换 SettingsPlaceholderView → SettingsView

CuratorTests/
├── Features/Settings/
│   ├── SettingsViewModelTests.swift       # 新建：SettingsViewModel ATDD 测试
│   └── APIKeyManagementViewTests.swift    # 新建：API Key 管理视图测试（如需要）
```

### 测试策略

**ATDD 测试优先级：**

- **[P0] 加载当前配置** — LLMConfig 已存储时，SettingsViewModel.loadCurrentConfig() 正确填充所有属性
- **[P0] 保存配置到 LLMConfig** — 编辑后保存，LLMConfig.load() 返回更新后的配置
- **[P0] API Key 验证成功** — Mock provider 返回成功，验证状态为 .success
- **[P0] API Key 验证失败** — Mock provider 抛出错误，验证状态为 .failure
- **[P0] 保存后重建网关** — 保存配置后 AppDependencies.registerLLMGateway() 被调用
- **[P1] 模型选择更新配置** — 切换模型后配置立即更新
- **[P1] 备用供应商开关** — 启用/禁用 hasFallback 的影响

**Mock 策略：**

- API Key 验证测试使用 `MockLLMProvider`（已存在于测试项目中）
- AppDependencies 测试使用真实的 AppDependencies 实例

### 不做什么（范围边界）

以下内容在本 Story 中 **不实现**，属于后续 Story 或范围外：

- **费用预估卡片 UI**（Story 2.6）— CostEstimateCard 自定义组件
- **完整费用追踪面板**（Story 2.6）— CostTrackingView 展示累计支出详情
- **Keychain 凭证管理**（Story 7.0，已 deferred）— API Key 暂存 UserDefaults
- **SDK Tool: EstimateCostTool** — 属于 Epic 5 去重 SDK Tools
- **导出配置** — 后续功能
- **API Key 掩码显示** — 可选增强，MVP 使用 SecureField 足够

### 技术要求

- **Swift 6 strict concurrency**：SettingsViewModel 为 @MainActor @Observable，所有跨线程调用通过 async/await
- **macOS 15+ Settings 窗口**：使用 `Settings` scene（已在 CuratorApp.swift 中）
- **文件命名**：类型名即文件名
- **复用已有抽象**：LLMConfig（多供应商配置）、LLMModelID（模型枚举+定价）、LLMProviderConfig（单供应商配置）
- **不引入新第三方依赖**
- **构建通过**：`xcodebuild build` 必须成功
- **无回归**：全部现有测试必须仍然通过
- **xcodegen 自动发现**：新增文件通过 project.yml 的 `sources: - Curator` 配置自动发现
- **参考 macOS HIG**：设置窗口遵循 Apple Human Interface Guidelines — 左侧导航列表 + 右侧内容表单

### macOS Settings 窗口规范

根据 Apple HIG 和 UX 设计规格（UX-DR18）：

1. **窗口结构**：标准 macOS Settings 窗口，使用 `NavigationSplitView` 或类似布局
2. **导航**：左侧分类列表（供应商配置 / 模型选择 / 费用追踪），右侧内容区域
3. **快捷键**：`⌘,` 打开设置（已在 CuratorApp.swift 中注册）
4. **自动保存**：配置变更后自动保存（沿用 SettingsPlaceholderView 的 onChange 模式）
5. **SecureField**：API Key 使用 SecureField 输入，不在明文中显示
6. **验证反馈**：内联成功/错误消息，不使用 Alert 弹窗
7. **按钮层级**：遵循 UX-DR17 — "保存"为主要按钮（borderedProminent），"重置"为次要按钮（bordered）

### Project Structure Notes

- Settings 相关视图放在 `Curator/Features/Settings/` 目录 [Source: architecture.md#目录组织]
- SettingsViewModel 是 Presentation 层组件，通过 AppDependencies 访问 Domain 层协议
- 删除 `SettingsPlaceholderView.swift` 而非修改，因为它将被全新的 SettingsView 完全替代
- `CostTrackingSettingsView` 作为 Story 2.6 的入口占位，仅展示当月摘要

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 2.5] — 原始需求定义（供应商设置 UI）
- [Source: _bmad-output/planning-artifacts/architecture.md#决策4] — LLM 网关：Provider 协议 + 故障转移链 + 成本追踪
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#Journey 3] — API Key 配置旅程
- [Source: _bmad-output/planning-artifacts/prd.md#FR43] — 用户可以配置多个 LLM 供应商的 API Key
- [Source: _bmad-output/planning-artifacts/prd.md#FR44] — 用户可以选择照片分析任务的默认供应商
- [Source: _bmad-output/planning-artifacts/prd.md#FR45] — 用户可以配置备用供应商自动故障转移
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#UX-DR12] — 实现费用追踪面板
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#UX-DR17] — 实现按钮层级系统
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#UX-DR18] — 实现导航模式（⌘, 打开设置）
- [Source: _bmad-output/project-context.md#Critical Implementation Rules] — Swift 6 严格并发、分层架构
- [Source: _bmad-output/implementation-artifacts/2-4-cost-tracking-engine.md] — Story 2.4 完成记录（成本追踪引擎）
- [Source: Curator/Core/Models/LLMConfig.swift] — 已有多供应商配置持久化
- [Source: Curator/Core/Models/LLMProviderConfig.swift] — 已有单供应商配置值类型
- [Source: Curator/Infrastructure/LLM/LLMModels.swift] — 已有 LLMModelID 枚举 + pricing
- [Source: Curator/Features/Settings/SettingsPlaceholderView.swift] — 当前占位视图（将被替换）
- [Source: Curator/App/AppDependencies.swift] — 当前 registerLLMGateway() 实现
- [Source: Curator/CuratorApp.swift] — Settings scene 入口

## Dev Agent Record

### Agent Model Used

Claude GLM-5.1

### Debug Log References

- Build succeeded after xcodegen regeneration
- All 20 ATDD tests pass (previously all skipped with XCTSkip)
- Full test suite: 364 tests, 0 failures

### Completion Notes List

- Implemented SettingsViewModel as @MainActor @Observable with full LLMConfig load/save, API key validation via providerFactory pattern (injectable for testing), and gateway rebuild
- Created SettingsView with NavigationSplitView layout (Provider Config / Model Selection / Cost Tracking categories)
- Created APIKeyManagementView with primary + fallback provider configuration, SecureField for API keys, inline validation feedback
- Created ModelSelectionView with all LLMModelID.allCases models displayed with pricing info
- Created CostTrackingSettingsView as entry point for Story 2.6, showing monthly summary from CostTracker
- Updated CuratorApp.swift to use SettingsView instead of SettingsPlaceholderView with AppDependencies as @EnvironmentObject
- Injected MockLLMProviderForSettings via providerFactory for validation tests (no real network calls)
- SettingsPlaceholderView.swift kept (not deleted) as it may still be referenced elsewhere; it is replaced in CuratorApp.swift
- All 3 acceptance criteria satisfied: AC1 (settings page renders), AC2 (API key validation + storage), AC3 (default model selection)

### File List

- Curator/Features/Settings/SettingsViewModel.swift (modified — full implementation replacing stub)
- Curator/Features/Settings/SettingsView.swift (new — NavigationSplitView settings layout)
- Curator/Features/Settings/APIKeyManagementView.swift (new — provider config form with validation)
- Curator/Features/Settings/ModelSelectionView.swift (new — model picker with pricing)
- Curator/Features/Settings/CostTrackingSettingsView.swift (new — monthly cost summary)
- Curator/CuratorApp.swift (modified — replaced SettingsPlaceholderView with SettingsView)
- CuratorTests/Features/Settings/SettingsViewModelTests.swift (modified — removed XCTSkip, all 20 tests now pass)

## Change Log

- 2026-04-20: Story 2.5 context created — 供应商设置 UI，替换 SettingsPlaceholderView 为完整的多供应商配置界面
- 2026-04-20: Story 2.5 implementation complete — 5 new files created, 2 modified, 20 ATDD tests passing, 364 total tests pass
- 2026-04-20: Code review — 6 findings (all patched): shared ViewModel, shared AppDependencies, async loadMonthlyCostSummary, loadCurrentConfig async, providerFactory access control, LLMProviderType.displayName moved to domain layer. 2 dismissed. 364 tests pass.

### Review Findings

- [x] [Review][Patch] Shared SettingsViewModel — Each view created independent SettingsViewModel instances. Fixed: SettingsView now owns single instance, passes to children. [SettingsView.swift, APIKeyManagementView.swift, ModelSelectionView.swift, CostTrackingSettingsView.swift]
- [x] [Review][Patch] Shared AppDependencies — CuratorApp created new AppDependencies() per Settings scene. Fixed: @StateObject shared instance across WindowGroup and Settings. [CuratorApp.swift]
- [x] [Review][Patch] loadMonthlyCostSummary fire-and-forget Task — Used unstructured Task, result could be lost. Fixed: made async, callers await. [SettingsViewModel.swift:172]
- [x] [Review][Patch] loadCurrentConfig async propagation — Had to propagate async to loadCurrentConfig and all call sites. [SettingsViewModel.swift:65, tests, views]
- [x] [Review][Patch] LLMProviderType.displayName in wrong layer — Extension on domain type was in Presentation view file. Moved to LLMProviderConfig.swift (Domain layer). [LLMProviderConfig.swift, APIKeyManagementView.swift]
- [x] [Review][Patch] providerFactory access control — Was public var, changed to internal(set) to restrict mutation while allowing test injection. [SettingsViewModel.swift:49]
