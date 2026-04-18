---
stepsCompleted:
  - 1
  - 2
  - 3
  - 4
  - 5
  - 6
  - 7
  - 8
inputDocuments:
  - _bmad-output/planning-artifacts/prd.md
  - _bmad-output/planning-artifacts/ux-design-specification.md
workflowType: 'architecture'
project_name: 'Curator'
user_name: 'Nick'
date: '2026-04-18'
status: 'complete'
completedAt: '2026-04-18'
---

# Architecture Decision Document

_This document builds collaboratively through step-by-step discovery. Sections are appended as we work through each architectural decision together._

## 项目上下文分析

### 需求概览

**功能需求（52 项，9 个类别）：**

| 类别 | 需求范围 | 架构影响 |
|------|---------|---------|
| 照片图库访问 | FR1-FR7 | PhotoKit 服务层——读写权限分离、分页、资源管理 |
| 自然语言交互 | FR8-FR12 | Agent 指令解析层——意图识别、多轮对话、会话管理 |
| Agent 执行与可视化 | FR13-FR17 | Agent 执行引擎——状态机、流式传输、进度追踪 |
| 去重分析 | FR18-FR23 | 图像分析管线——pHash + LLM 双阶段处理 |
| AI 重命名 | FR24-FR28 | 内容分析 + 命名生成管线 |
| 用户控制与安全 | FR33-FR38 | 操作管理器——确认工作流、快照/回滚系统 |
| 隐私与透明度 | FR39-FR42 | 审计日志 + 数据流追踪 |
| 供应商与成本管理 | FR43-FR48 | LLM 网关——多供应商抽象、故障转移、成本计量 |
| 应用基础设施 | FR49-FR52 | 更新、离线模式、本地缓存 |

**非功能需求（23 项，4 个类别）：**

- **性能（NFR1-NFR8）：** 3 秒启动、60fps 滚动、500ms 进度更新、500MB 内存上限——决定后台处理架构和缓存策略
- **安全（NFR9-NFR14）：** Keychain 存储、TLS 传输、沙盒隔离、Apple 签名公证——决定凭证管理和数据存储方案
- **数据完整性（NFR15-NFR18）：** 零文件损坏容忍、5 秒回滚、崩溃恢复——决定操作日志和事务系统设计
- **集成质量（NFR19-NFR23）：** 权限变更处理、指数退避重试、10 秒故障转移——决定错误恢复和韧性策略

### 规模与复杂度

- **主要领域：** 原生 macOS 桌面应用（SwiftUI + AppKit）
- **复杂度级别：** 中等偏高
- **预估核心组件：** 10-12 个

**复杂度驱动因素：**
1. Agent 执行引擎——多步状态机 + 流式通信 + 取消支持
2. PhotoKit 集成——权限管理 + 大规模数据分页 + 线程安全
3. 双阶段图像分析——本地计算与远程 API 的协调
4. 操作可逆性——快照/回滚/事务系统
5. 多供应商 LLM 网关——统一抽象 + 故障转移 + 成本追踪

### 技术约束与依赖

**硬约束：**
- macOS 15+（Sequoia）、Apple Silicon（arm64）仅限
- OpenAgentSDKSwift 作为 Agent 基础设施（Swift Package Manager）
- PhotoKit 作为唯一的照片图库访问方式
- App Store 外分发——需 Apple Developer ID 签名 + 公证

**技术依赖：**
- OpenAgentSDKSwift：Agent 循环、工具执行、会话管理、流式传输
- PhotoKit：图库读写、资源访问、变更监听
- Sparkle 2：自动更新（最新稳定版 2.9.x，支持 SPM）
- SwiftUI + AppKit：UI 层 + 系统集成

**平台约束：**
- 沙盒应用——文件系统访问受限
- Keychain 存储凭证——非明文配置文件
- 后台线程执行所有 I/O 和计算密集操作
- 500MB 内存预算

### 已识别的跨切关注点

1. **权限管理** — 只读/写入渐进授权，贯穿 PhotoKit 服务、Agent 工具、UI 层
2. **操作可逆性** — 快照创建、回滚机制，影响所有写操作
3. **成本追踪** — API 调用计量和费用展示，贯穿 LLM 网关和 UI
4. **错误恢复** — API 故障转移、崩溃恢复、部分完成回滚
5. **后台执行** — 所有 PhotoKit、图像处理、API 调用需后台线程
6. **流式通信** — Agent 状态 → UI 的实时更新，贯穿执行引擎和视图层
7. **审计与透明** — 记录哪些数据发送到 LLM、为什么，贯穿整个数据流

## 启动模板评估

### 主要技术领域

原生 macOS 桌面应用（Swift/SwiftUI + AppKit），基于 PRD 和 UX 设计规格确定。

### 评估结果

Curator 是原生 macOS 应用，不适用传统 Web 框架启动模板（如 Next.js、Vite）。项目初始化方案基于以下考量：

**已确定的技术选型（来自 PRD/CLAUDE.md 约束）：**
- 语言：Swift（macOS 15+）
- UI 框架：SwiftUI（主体） + AppKit（互操作）
- 包管理：Swift Package Manager
- Agent SDK：OpenAgentSDKSwift
- 自动更新：Sparkle 2（~2.9.x）
- 分发：DMG + Apple Developer ID 签名 + 公证

**选择方案：Xcode 项目 + Swift Package Manager**

不使用第三方项目模板，采用标准 Xcode macOS App 项目结构。原因：
1. 原生 macOS 应用没有类似 create-react-app 的脚手架工具
2. SwiftUI + AppKit 互操作需要 Xcode 项目正确配置
3. OpenAgentSDKSwift 作为 SPM 依赖直接添加
4. Sparkle 2 原生支持 SPM 集成

### 初始化命令

```bash
# 1. 通过 Xcode 创建项目（或使用 mint/tuist 等工具）
# 目标：macOS App, SwiftUI Lifecycle, Swift 6, arm64 only

# 2. 添加 SPM 依赖
# OpenAgentSDKSwift: https://github.com/terryso/open-agent-sdk-swift
# Sparkle 2: https://github.com/sparkle-project/Sparkle

# 3. 配置 Entitlements
# - com.apple.security.app-sandbox
# - com.apple.security.personal-information.photos
# - com.apple.security.network.client (LLM API)
# - com.apple.security.keychain (API Key 存储)
```

### 启动模板提供的架构决策

**语言与运行时：**
- Swift 6（严格并发模式）
- macOS 15.0 部署目标
- Apple Silicon（arm64）仅限

**构建工具：**
- Xcode 构建系统
- Swift Package Manager 依赖管理
- Xcode Scheme 配置 Debug/Release

**项目组织：**
- Feature-based 目录结构（按功能模块组织）
- SwiftUI App 生命周期入口点

## 核心架构决策

### 决策优先级分析

**关键决策（阻塞实现）：**
1. 应用整体架构模式
2. Agent 执行引擎设计
3. PhotoKit 服务层设计
4. LLM 网关抽象层
5. 数据持久化策略

**重要决策（塑造架构）：**
6. 状态管理方案
7. 操作回滚系统
8. 缓存策略
9. 错误处理模式

**延后决策（MVP 后）：**
10. 智能相册引擎（FR29-FR32）
11. 菜单栏 / Finder 集成
12. 离线队列

### 决策 1：应用整体架构模式

**选择：分层架构（Layered Architecture）+ 依赖注入**

```
┌─────────────────────────────────┐
│         Presentation Layer       │  SwiftUI Views + ViewModels
├─────────────────────────────────┤
│         Application Layer        │  Agent 编排、操作管理、会话管理
├─────────────────────────────────┤
│         Domain Layer             │  业务模型、分析算法、去重逻辑
├─────────────────────────────────┤
│         Infrastructure Layer     │  PhotoKit、LLM Gateway、Keychain、Cache
└─────────────────────────────────┘
```

**理由：**
- 清晰的层级边界让每个 AI Agent 可以独立工作在不同层
- 依赖注入使各层可独立测试和替换
- 领域层不依赖具体框架，保护核心业务逻辑

**实现方式：**
- 使用 Swift 6 的 strict concurrency（`Sendable`、actor 隔离）
- 依赖注入通过 `@Dependency` 属性包装器或构造器注入
- 各层通过 `protocol` 定义接口，具体实现在 Infrastructure 层

### 决策 2：Agent 执行引擎

**选择：状态机驱动 + AsyncStream 流式输出**

```
AgentJob (状态机)
  ┌──────┐    ┌───────┐    ┌──────┐    ┌──────┐    ┌────────┐
  │Planning├───►│Running├───►│Review├───►│Confirm├───►│Completed│
  └──┬───┘    └──┬────┘    └──┬───┘    └──┬───┘    └────────┘
     │           │              │           │
     ▼           ▼              ▼           ▼
  Cancelled   Cancelled     Rejected    Cancelled
```

**AgentJob 生命周期：**
1. **Planning** — Agent 解析用户意图，生成执行步骤列表，展示费用预估
2. **Running** — 逐步执行，通过 `AsyncStream<AgentEvent>` 流式推送进度更新
3. **Review** — 展示结果供用户审核（可逐项或批量）
4. **Confirm** — 用户确认破坏性操作
5. **Completed / Cancelled / Failed** — 终态

**关键设计：**
- `AgentJob` 是 `@Observable` 类，SwiftUI 直接观察状态变化
- `AgentEvent` 枚举涵盖所有可能的更新类型（进度、推理、结果、错误）
- 支持 `Task` 取消——用户随时可中断
- 所有步骤通过 `OpenAgentSDKSwift` 的工具系统注册为 SDK Tool

### 决策 3：PhotoKit 服务层

**选择：Repository 模式 + Actor 隔离**

```swift
protocol PhotoLibraryRepository: Sendable {
    func requestReadAccess() async throws -> Bool
    func requestWriteAccess() async throws -> Bool
    func fetchAssets(predicate: PhotoPredicate, pageSize: Int) async throws -> AssetPage
    func fetchFullResolutionImage(for assetID: AssetID) async throws -> Data
    func updateAsset(_ assetID: AssetID, title: String?) async throws
    func deleteAssets(_ assetIDs: [AssetID]) async throws
    func createAlbum(name: String) async throws -> AlbumID
    func observeLibraryChanges() -> AsyncStream<LibraryChange>
}

actor PhotoKitRepository: PhotoLibraryRepository {
    // 所有 PhotoKit 操作在此 actor 内串行化执行
    // 确保线程安全和权限一致性
}
```

**理由：**
- Actor 隔离确保所有 PhotoKit 操作线程安全
- Repository 协议使测试可用 mock 替换
- 分页模型（`AssetPage`）控制内存使用
- 权限检查集中在 Repository 内，不泄露到上层

### 决策 4：LLM 网关抽象层

**选择：Provider 协议 + 故障转移链 + 成本追踪**

```swift
protocol LLMProvider: Sendable {
    var name: String { get }
    func analyze(images: [ImageData], prompt: String) async throws -> LLMResponse
    func estimateCost(imageCount: Int, model: ModelID) -> CostEstimate
}

actor LLMGateway {
    let providers: [LLMProvider]         // 主供应商 + 备用
    var costTracker: CostTracker          // 累计成本追踪

    func analyze(images: [ImageData], prompt: String) async throws -> LLMResponse {
        // 1. 尝试主供应商
        // 2. 失败后指数退避重试（最多 3 次）
        // 3. 回退到备用供应商
        // 4. 记录成本
    }
}
```

**供应商实现：**
- `AnthropicProvider` — Claude API（主要）
- `OpenAICompatibleProvider` — OpenAI / DeepSeek / 其他兼容 API（备用）

**凭证管理：**
- API Key 存储在 macOS Keychain
- 通过 `Security` 框架的 `SecItem` API 读写
- 永不在内存外明文暴露

### 决策 5：数据持久化

**选择：SwiftData（本地缓存）+ 文件系统（分析结果）**

- **SwiftData** — 缓存照片元数据索引、分析结果、操作历史、会话记录
- **文件系统（应用沙盒）** — 缩略图缓存、pHash 索引文件
- **Keychain** — API Key、敏感凭证
- **UserDefaults / @AppStorage** — 用户偏好、窗口状态

**不使用外部数据库的理由：**
- SwiftData 是 Apple 原生方案，与 SwiftUI 深度集成
- 数据量可控（元数据索引，非图像文件）
- 无额外依赖，沙盒友好

### 决策 6：状态管理

**选择：@Observable + Observation 框架（Swift 原生）**

不引入第三方状态管理库（如 TCA/Composable Architecture），使用 Swift 5.9+ 的 `@Observable` 宏：

- **视图状态** — `@State`、`@Binding`（SwiftUI 内置）
- **应用状态** — `@Observable` 类通过 `@Environment` 注入
- **Agent 执行状态** — `AgentJob` 作为 `@Observable` 对象
- **持久化状态** — `@AppStorage`、SwiftData `@Query`

**理由：**
- macOS 15+ 原生支持，零额外依赖
- 性能优于 Combine/ObservableObject
- 与 SwiftUI 视图更新机制直接集成

### 决策 7：操作回滚系统

**选择：快照 + 操作日志模式**

```swift
struct OperationSnapshot: Codable {
    let id: UUID
    let timestamp: Date
    let operationType: OperationType  // .rename, .delete, .move, .metadataChange
    let assetID: AssetID
    let beforeState: AssetMetadata    // 操作前的元数据快照
}

actor OperationManager {
    func beginBatch(operations: [PlannedOperation]) async throws -> BatchID
    func executeBatch(_ batchID: BatchID) async throws
    func rollbackBatch(_ batchID: BatchID) async throws  // 5 秒内完成
    func rollbackLastBatch() async throws                 // ⌘Z 撤销
}
```

**关键规则：**
- 每次批量操作前创建所有受影响资产的元数据快照
- 操作日志按 BatchID 分组，支持整批回滚
- 回滚操作本身也可回滚（双次撤销恢复）
- 快照存储在 SwiftData 中，应用重启后仍可访问

### 决策 8：缓存策略

**选择：两级缓存（内存 + 磁盘）**

| 数据类型 | 内存缓存 | 磁盘缓存 | 过期策略 |
|---------|---------|---------|---------|
| 缩略图 | NSCache（LRU，100MB 上限） | 沙盒目录 | LRU 淘汰 |
| 照片元数据 | SwiftData 查询 | SwiftData | 图库变更时失效 |
| pHash 值 | 无 | 二进制索引文件 | 图库变更时重建 |
| LLM 分析结果 | 无 | SwiftData | 30 天或会话结束 |
| Agent 会话 | 内存 | SwiftData | 手动清除 |

### 决策 9：错误处理模式

**选择：Typed Error + 分层错误传播**

```swift
// 领域层错误
enum DomainError: Error {
    case assetNotFound(AssetID)
    case analysisFailed(reason: String)
    case insufficientPermission(required: PermissionLevel)
}

// 基础设施层错误
enum InfrastructureError: Error {
    case photoKitAccessDenied
    case llmProviderUnavailable(provider: String)
    case networkError(underlying: Error)
    case rateLimitExceeded(retryAfter: TimeInterval)
}

// 统一展示层错误（用户可见）
enum UserFacingError {
    case readOnly(title: String, message: String)      // 不需要操作
    case retryable(title: String, message: String)      // 可重试
    case permissionRequired(title: String, action: String) // 需要授权
}
```

**错误恢复策略：**
- LLM API：指数退避重试 3 次 → 故障转移备用供应商 → 报告失败
- PhotoKit：检测权限变更 → 引导用户到系统设置 → 优雅降级
- 批量操作：单项失败不中断批次 → 失败项收集 → 部分完成报告

## 实现模式与一致性规则

### 命名模式

**Swift 类型命名：**
- 类型名用 UpperCamelCase：`PhotoLibraryRepository`、`AgentJob`、`LLMGateway`
- 协议名用名词或 "able" 后缀：`Repository`、`Provider`、`EventHandler`
- 避免使用 `Task` 作为类型名（与 Swift Concurrency 冲突），使用 `AgentJob`、`AgentWork` 替代
- 枚举用 UpperCamelCase 类型名 + lowerCamelCase case：`AgentEvent.stepCompleted`

**文件命名：**
- 一致使用类型名作为文件名：`PhotoLibraryRepository.swift`、`AgentJob.swift`
- 扩展文件：`UIView+PhotoGrid.swift` 格式
- 协议 + 实现在同一文件（小于 300 行时）

**函数与变量：**
- 函数：lowerCamelCase：`fetchAssets()`、`requestReadAccess()`
- 变量：lowerCamelCase：`assetCount`、`isExecuting`
- 布尔变量：`is`/`has`/`should` 前缀：`isProcessing`、`hasWritePermission`
- 常量：lowerCamelCase（Swift 惯例）：`defaultPageSize`

### 结构模式

**目录组织（Feature-based）：**
- 每个功能模块一个目录，内含 Views / ViewModels / Services
- 共享组件在 `Shared/` 或 `Core/` 目录
- 测试镜像源码结构

**SwiftUI 视图结构：**
- 视图文件不超过 200 行，复杂视图拆分子视图
- ViewModels 使用 `@Observable` 类，通过 `@Environment` 注入
- 预览（Preview）覆盖亮色/暗色模式

**协议与实现分离：**
- 协议定义在 Domain 层
- 实现在 Infrastructure 层
- 通过依赖注入容器绑定

### 通信模式

**Agent 事件流：**
```swift
enum AgentEvent: Sendable {
    case planGenerated(steps: [AgentStep])
    case stepStarted(stepID: UUID, title: String)
    case stepProgress(stepID: UUID, completed: Int, total: Int)
    case stepReasoning(stepID: UUID, message: String)
    case stepCompleted(stepID: UUID, result: StepResult)
    case stepFailed(stepID: UUID, error: DomainError)
    case reviewReady(items: [ReviewItem])
    case executionCompleted(summary: ExecutionSummary)
}
```

**UI 更新模式：**
- `@Observable` 对象属性变化 → SwiftUI 自动更新
- `AsyncStream<AgentEvent>` → ViewModel 转换为 `@Observable` 状态
- 永不从后台线程直接更新 UI——通过 `@MainActor` 标记 ViewModel

**Service 层通信：**
- Service 之间通过协议定义的异步函数调用
- 不使用 NotificationCenter——用 AsyncStream 替代
- 跨层数据传递使用值类型（`struct` + `Sendable`）

### 进程模式

**错误处理规则：**
- 所有 `throws` 函数在调用处必须有 `do/catch` 或 `try?` 处理
- Infrastructure 层错误必须映射为 Domain 层错误再向上传播
- 永不向用户展示技术性错误消息（如 "PHImageErrorDomain"）
- 错误消息包含建议的下一步操作

**加载状态管理：**
```swift
enum LoadingState<T> {
    case idle
    case loading
    case loaded(T)
    case failed(DomainError)
}
```

**后台执行规则：**
- 所有 PhotoKit 操作在 `actor` 内执行
- LLM API 调用在 `Task` 中执行，支持取消
- 图像处理（pHash、缩略图）在 `Task` 中分批执行
- UI 线程（`@MainActor`）只做视图更新

### 强制执行指南

**所有 AI Agent 必须：**
1. 遵循分层架构——Presentation 不直接调用 Infrastructure
2. 使用 `Sendable` 类型跨并发域传递数据
3. 所有 I/O 操作在 actor 或 Task 中执行，不在 `@MainActor` 上
4. 破坏性操作必须通过 `OperationManager` 创建快照
5. API 调用必须通过 `LLMGateway`，不直接调用供应商 API
6. 不在代码中硬编码 API Key 或敏感信息
7. 使用 `protocol` 定义跨层接口，不直接依赖具体实现

## 项目结构与边界

### 完整项目目录结构

```
Curator/
├── Curator.xcodeproj
├── Curator/
│   ├── CuratorApp.swift                    # SwiftUI App 入口
│   ├── Info.plist
│   ├── Curator.entitlements                # 沙盒 + PhotoKit 权限
│   │
│   ├── App/                                # 应用层
│   │   ├── AppDelegate.swift               # AppKit 代理（如需要）
│   │   ├── AppDependencies.swift           # 依赖注入容器
│   │   └── NavigationModel.swift           # 导航状态
│   │
│   ├── Core/                               # 核心共享组件
│   │   ├── Agent/                          # Agent 引擎
│   │   │   ├── AgentJob.swift              # Agent 任务状态机
│   │   │   ├── AgentEvent.swift            # 事件类型定义
│   │   │   ├── AgentStep.swift             # 执行步骤模型
│   │   │   └── AgentToolRegistry.swift     # SDK 工具注册
│   │   │
│   │   ├── Operations/                     # 操作管理
│   │   │   ├── OperationManager.swift      # 快照 + 回滚
│   │   │   ├── OperationSnapshot.swift     # 操作快照模型
│   │   │   └── BatchOperation.swift        # 批量操作模型
│   │   │
│   │   ├── Models/                         # 领域模型
│   │   │   ├── PhotoAsset.swift            # 照片资产（值类型）
│   │   │   ├── AssetMetadata.swift         # 元数据模型
│   │   │   ├── DuplicateGroup.swift        # 去重分组
│   │   │   ├── RenameSuggestion.swift      # 重命名建议
│   │   │   └── ReviewItem.swift            # 审核项
│   │   │
│   │   ├── Errors/                         # 错误定义
│   │   │   ├── DomainError.swift
│   │   │   ├── InfrastructureError.swift
│   │   │   └── UserFacingError.swift
│   │   │
│   │   └── Extensions/                     # Swift 扩展
│   │       ├── AsyncStream+Extensions.swift
│   │       └── LoadableState.swift
│   │
│   ├── Features/                           # 功能模块
│   │   ├── ChatInput/                      # 自然语言输入
│   │   │   ├── ChatInputView.swift
│   │   │   ├── ChatInputViewModel.swift
│   │   │   └── QuickCommandSuggestions.swift
│   │   │
│   │   ├── AgentExecution/                 # Agent 执行可视化
│   │   │   ├── AgentExecutionPanel.swift
│   │   │   ├── AgentExecutionViewModel.swift
│   │   │   ├── StepCardView.swift
│   │   │   └── ReasoningBubbleView.swift
│   │   │
│   │   ├── Deduplication/                  # 去重功能
│   │   │   ├── DeduplicationViewModel.swift
│   │   │   ├── PhotoComparisonCard.swift
│   │   │   ├── DuplicateReviewView.swift
│   │   │   └── BatchApprovalView.swift
│   │   │
│   │   ├── Rename/                         # AI 重命名
│   │   │   ├── RenameViewModel.swift
│   │   │   ├── RenameSuggestionCard.swift
│   │   │   └── RenameReviewView.swift
│   │   │
│   │   ├── PhotoLibrary/                   # 图库浏览
│   │   │   ├── PhotoLibraryViewModel.swift
│   │   │   ├── PhotoGridView.swift
│   │   │   └── PhotoDetailSheet.swift
│   │   │
│   │   ├── Settings/                       # 设置
│   │   │   ├── SettingsView.swift
│   │   │   ├── APIKeyManagementView.swift
│   │   │   ├── ModelSelectionView.swift
│   │   │   ├── CostTrackingView.swift
│   │   │   └── SettingsViewModel.swift
│   │   │
│   │   ├── Onboarding/                     # 首次启动
│   │   │   ├── WelcomeView.swift
│   │   │   ├── PermissionGuideView.swift
│   │   │   └── OnboardingViewModel.swift
│   │   │
│   │   └── ResultSummary/                  # 成果摘要
│   │       ├── ResultSummaryView.swift
│   │       └── ResultSummaryViewModel.swift
│   │
│   ├── Infrastructure/                     # 基础设施层
│   │   ├── PhotoKit/                       # PhotoKit 集成
│   │   │   ├── PhotoKitRepository.swift    # Repository 实现（actor）
│   │   │   ├── PhotoPermissionManager.swift
│   │   │   ├── PHAssetMapper.swift         # PHAsset → 领域模型映射
│   │   │   └── LibraryChangeObserver.swift
│   │   │
│   │   ├── LLM/                            # LLM 网关
│   │   │   ├── LLMGateway.swift            # 统一网关（actor）
│   │   │   ├── AnthropicProvider.swift      # Anthropic 实现
│   │   │   ├── OpenAICompatibleProvider.swift
│   │   │   ├── CostTracker.swift
│   │   │   └── LLMModels.swift             # 模型定义
│   │   │
│   │   ├── Analysis/                       # 图像分析
│   │   │   ├── PerceptualHasher.swift      # pHash 本地计算
│   │   │   ├── ImageAnalysisPipeline.swift  # 双阶段管线
│   │   │   └── ThumbnailGenerator.swift
│   │   │
│   │   ├── Storage/                        # 数据持久化
│   │   │   ├── CacheManager.swift          # 两级缓存管理
│   │   │   ├── KeychainManager.swift       # API Key 存储
│   │   │   └── SwiftDataManager.swift      # SwiftData 配置
│   │   │
│   │   ├── SDKTools/                       # OpenAgentSDKSwift 工具
│   │   │   ├── ScanLibraryTool.swift       # 扫描图库
│   │   │   ├── AnalyzeDuplicatesTool.swift # 去重分析
│   │   │   ├── AnalyzeContentTool.swift    # 内容分析（重命名）
│   │   │   ├── RenameAssetsTool.swift      # 重命名执行
│   │   │   ├── DeleteAssetsTool.swift      # 删除执行
│   │   │   └── EstimateCostTool.swift      # 费用预估
│   │   │
│   │   └── Update/                         # 自动更新
│   │       └── SparkleManager.swift
│   │
│   └── Resources/
│       ├── Assets.xcassets
│       └── Localizable.strings             # 本地化（MVP 后）
│
├── CuratorTests/                           # 单元测试
│   ├── Core/
│   │   ├── AgentJobTests.swift
│   │   ├── OperationManagerTests.swift
│   │   └── PerceptualHasherTests.swift
│   ├── Features/
│   │   ├── DeduplicationTests.swift
│   │   └── RenameTests.swift
│   └── Infrastructure/
│       ├── PhotoKitRepositoryTests.swift
│       ├── LLMGatewayTests.swift
│       └── KeychainManagerTests.swift
│
├── CuratorUITests/                         # UI 测试
│   ├── OnboardingFlowTests.swift
│   ├── DeduplicationFlowTests.swift
│   └── SettingsFlowTests.swift
│
├── Package.swift                           # SPM 配置（如使用）
├── .github/
│   └── workflows/
│       └── ci.yml                          # CI（Xcode build + test）
└── README.md
```

### 架构边界

**层间通信规则：**

| 层 | 可调用 | 不可调用 |
|---|-------|---------|
| Presentation (Views/ViewModels) | Application Layer | Infrastructure Layer |
| Application Layer | Domain Layer, Infrastructure（通过协议） | 直接操作 SwiftUI Views |
| Domain Layer | 自身模型和协议 | 任何其他层 |
| Infrastructure Layer | Domain Layer（实现其协议） | Presentation Layer |

**模块间数据流：**

```
用户输入 (View)
    → ViewModel（@MainActor）
        → AgentJob（状态机）
            → SDKTool（OpenAgentSDKSwift）
                → PhotoKitRepository（actor）
                → LLMGateway（actor）
                → ImageAnalysisPipeline
            ← AsyncStream<AgentEvent>
        ← @Observable 状态更新
    ← SwiftUI 自动刷新
```

### 需求到结构映射

**功能需求类别 → 目录映射：**

| FR 类别 | 目录 |
|---------|------|
| 照片图库访问 (FR1-FR7) | `Infrastructure/PhotoKit/` |
| 自然语言交互 (FR8-FR12) | `Core/Agent/` + `Features/ChatInput/` |
| Agent 执行与可视化 (FR13-FR17) | `Core/Agent/` + `Features/AgentExecution/` |
| 去重分析 (FR18-FR23) | `Infrastructure/Analysis/` + `Features/Deduplication/` |
| AI 重命名 (FR24-FR28) | `Infrastructure/Analysis/` + `Features/Rename/` |
| 用户控制与安全 (FR33-FR38) | `Core/Operations/` + 贯穿所有写操作 |
| 隐私与透明度 (FR39-FR42) | `Infrastructure/LLM/CostTracker.swift` + `Core/Agent/AgentEvent.swift` |
| 供应商与成本管理 (FR43-FR48) | `Infrastructure/LLM/` + `Features/Settings/` |
| 应用基础设施 (FR49-FR52) | `Infrastructure/Update/` + `Infrastructure/Storage/` |

**跨切关注点 → 目录映射：**

| 关注点 | 实现位置 |
|-------|---------|
| 权限管理 | `Infrastructure/PhotoKit/PhotoPermissionManager.swift` |
| 操作回滚 | `Core/Operations/OperationManager.swift` |
| 成本追踪 | `Infrastructure/LLM/CostTracker.swift` |
| 错误恢复 | `Core/Errors/` + 各层错误处理 |
| 缓存 | `Infrastructure/Storage/CacheManager.swift` |

## 架构验证结果

### 一致性验证

**决策兼容性：** 所有技术选型相互兼容。SwiftUI + @Observable + AsyncStream 是 macOS 15+ 原生技术栈。OpenAgentSDKSwift 通过 SPM 集成，不影响架构层级。

**模式一致性：** 命名规范（UpperCamelCase 类型、lowerCamelCase 函数）与 Swift 社区标准一致。Repository 模式、Actor 隔离、AsyncStream 流式通信在所有模块中一致应用。

**结构对齐：** Feature-based 目录结构支持分层架构——每个功能目录只包含 Presentation 层代码，核心逻辑在 `Core/`，基础设施在 `Infrastructure/`。

### 需求覆盖验证

**功能需求覆盖：**

| FR 类别 | 架构支持 | 状态 |
|---------|---------|------|
| 照片图库访问 (FR1-FR7) | PhotoKitRepository + PhotoPermissionManager | 完全覆盖 |
| 自然语言交互 (FR8-FR12) | AgentJob + OpenAgentSDKSwift 工具系统 | 完全覆盖 |
| Agent 执行与可视化 (FR13-FR17) | AgentJob 状态机 + AsyncStream + AgentExecutionPanel | 完全覆盖 |
| 去重分析 (FR18-FR23) | PerceptualHasher + LLMGateway + PhotoComparisonCard | 完全覆盖 |
| AI 重命名 (FR24-FR28) | ImageAnalysisPipeline + LLMGateway + RenameSuggestionCard | 完全覆盖 |
| 用户控制与安全 (FR33-FR38) | OperationManager（快照+回滚）+ 确认工作流 | 完全覆盖 |
| 隐私与透明度 (FR39-FR42) | AgentEvent 推理推送 + 审计日志 | 完全覆盖 |
| 供应商与成本管理 (FR43-FR48) | LLMGateway + CostTracker + 多 Provider | 完全覆盖 |
| 应用基础设施 (FR49-FR52) | SparkleManager + CacheManager + 离线指示 | 完全覆盖 |

**非功能需求覆盖：**

| NFR 类别 | 架构支持 | 状态 |
|---------|---------|------|
| 性能 (NFR1-NFR8) | Actor 隔离 + 分页 + 两级缓存 + 后台 Task | 完全覆盖 |
| 安全 (NFR9-NFR14) | KeychainManager + TLS（URLSession 默认）+ 沙盒 | 完全覆盖 |
| 数据完整性 (NFR15-NFR18) | OperationManager 快照 + 回滚 + 只修改元数据 | 完全覆盖 |
| 集成质量 (NFR19-NFR23) | LLMGateway 重试/故障转移 + PhotoKit 权限监听 | 完全覆盖 |

### 实现就绪验证

**决策完整性：** 所有 9 个关键架构决策已文档化，包含具体的协议定义、actor 隔离方案和错误处理模式。

**结构完整性：** 完整目录结构已定义，包含所有源文件、测试文件和资源文件。需求到目录的映射关系明确。

**模式完整性：** 命名、通信、错误处理、加载状态等模式已定义，并提供了具体的 Swift 类型示例。

### 架构完整性检查清单

**需求分析**
- [x] 项目上下文已深入分析
- [x] 规模和复杂度已评估
- [x] 技术约束已识别
- [x] 跨切关注点已映射

**架构决策**
- [x] 关键决策已文档化并说明版本
- [x] 技术栈已完全确定
- [x] 集成模式已定义
- [x] 性能考量已处理

**实现模式**
- [x] 命名规范已建立
- [x] 结构模式已定义
- [x] 通信模式已指定
- [x] 进程模式已文档化

**项目结构**
- [x] 完整目录结构已定义
- [x] 组件边界已建立
- [x] 集成点已映射
- [x] 需求到结构映射已完成

### 架构就绪评估

**整体状态：** 已就绪，可开始实现

**信心水平：** 高

**关键优势：**
- 分层架构 + Actor 隔离确保线程安全和可测试性
- OpenAgentSDKSwift 工具系统将 PhotoKit 和 LLM 操作统一为 Agent 可调用的工具
- 状态机驱动的 AgentJob 提供清晰的执行生命周期和 UI 同步机制
- 快照 + 回滚系统满足严格的数据完整性要求
- 多供应商 LLM 网关支持灵活的成本和可靠性管理

**未来可增强领域：**
- 智能相册引擎（MVP 后，FR29-FR32）
- 本地模型支持（Ollama 集成）
- 多语言本地化
- iCloud 图库深度集成

### 实现交接

**AI Agent 指南：**
- 严格遵循分层架构——Presentation 层不直接调用 Infrastructure 层
- 使用本文档中定义的实现模式保持一致性
- 尊重项目结构和边界定义
- 所有架构相关问题以本文档为权威来源

**首个实现优先级：**
1. 初始化 Xcode 项目 + SPM 依赖配置
2. 实现 `PhotoLibraryRepository` 协议和 `PhotoKitRepository`
3. 实现 `LLMGateway` 和 `AnthropicProvider`
4. 实现 `AgentJob` 状态机和事件流
5. 实现基础 UI 框架（Agent 工作空间三栏布局）
