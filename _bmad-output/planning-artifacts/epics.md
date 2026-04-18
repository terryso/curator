---
stepsCompleted:
  - step-01-validate-prerequisites
  - step-02-design-epics
  - step-03-create-stories
  - step-04-final-validation
inputDocuments:
  - _bmad-output/planning-artifacts/prd.md
  - _bmad-output/planning-artifacts/architecture.md
  - _bmad-output/planning-artifacts/ux-design-specification.md
status: complete
completedAt: '2026-04-18'
validation:
  frCoverage: complete
  uxDrCoverage: complete
  storyCount: 39
  epicCount: 7
---

# Curator - Epic Breakdown

## Overview

This document provides the complete epic and story breakdown for Curator, decomposing the requirements from the PRD, UX Design if it exists, and Architecture requirements into implementable stories.

## Requirements Inventory

### Functional Requirements

FR1: 用户可以授予应用 Apple 照片图库的读取权限
FR2: 用户可以浏览完整的照片图库，包括相册、智能相册和文件夹
FR3: 用户可以查看照片缩略图和元数据（日期、标题、描述、关键词、位置）
FR4: 系统可以检测照片图库的外部变更（如从 iPhone 同步的新照片）
FR5: 系统可以分页浏览大型照片图库而不阻塞 UI
FR6: 用户可以授予应用写入权限以修改照片元数据和创建/删除相册
FR7: 系统可以访问全分辨率照片资源用于 AI 分析
FR8: 用户可以输入自然语言指令指导 Agent（如"找出所有重复照片"）
FR9: 系统可以将自然语言指令解析为可执行的 Agent 任务
FR10: 系统可以在用户意图不明确时提出澄清问题
FR11: 用户可以查看和继续之前的对话会话
FR12: 系统可以处理多轮对话以完成复杂的照片管理任务
FR13: 系统可以基于用户指令自主执行多步 Agent 工作流
FR14: 用户可以实时查看 Agent 执行进度（当前步骤、已处理照片数、当前动作）
FR15: 用户可以查看 Agent 每个决策的推理过程（为什么标记为重复、为什么建议这个名称）
FR16: 系统可以将 Agent 执行更新流式传输到 UI 而不阻塞用户交互
FR17: 用户可以随时取消进行中的 Agent 任务
FR18: 用户可以请求对整个图库进行重复照片检测
FR19: 系统可以使用本地感知哈希算法检测视觉相似的照片
FR20: 系统可以使用基于 LLM 的分析确认视觉相似的照片是否为真正重复
FR21: 用户可以审核重复分组，包含并排对比和每个匹配的 AI 说明
FR22: 用户可以在任何删除操作前批准或拒绝单个重复分组
FR23: 用户可以批量批准或批量拒绝所有建议的重复移除
FR24: 用户可以请求对选定照片或整个相册进行 AI 驱动重命名
FR25: 系统可以分析照片内容并以用户偏好语言生成描述性标题
FR26: 用户可以在应用建议名称前进行审核
FR27: 用户可以在批准前修改单个建议名称
FR28: 系统可以在用户批准后批量重命名照片
FR29: 用户可以请求按事件、主题或人物自动创建相册（MVP 后）
FR30: 系统可以按视觉相似度、时间邻近性和地理位置聚类照片（MVP 后）
FR31: 用户可以在创建前交互式调整建议的相册分组（MVP 后）
FR32: 系统可以在用户批准后在 Apple 照片中创建相册（MVP 后）
FR33: 系统在任何破坏性操作（删除、移动、重命名）前需要用户明确批准
FR34: 用户可以在可配置的时间窗口内撤销任何批量操作
FR35: 系统在任何批量修改前创建元数据快照用于回滚
FR36: 系统在批量操作中途失败时自动回滚已完成的项目
FR37: 用户可以在只读分析模式下操作，不执行任何写操作
FR38: 系统绝不修改原始图像文件——仅操作元数据和组织结构
FR39: 系统展示清晰的隐私声明，说明发送了什么数据到 LLM API
FR40: 用户可以查看哪些具体照片被发送到 LLM 分析以及原因
FR41: 系统不在任何第三方服务器上存储用户照片（除 LLM API 调用外）
FR42: 所有本地缓存（缩略图、分析结果）仅存储在设备上
FR43: 用户可以配置多个 LLM 供应商的 API Key（Anthropic、OpenAI 兼容）
FR44: 用户可以选择照片分析任务的默认供应商
FR45: 用户可以配置备用供应商，在主供应商不可用时自动故障转移
FR46: 系统在大规模分析任务执行前展示费用预估
FR47: 系统追踪并展示累计 API 支出（按会话和按月）
FR48: 系统通过排队、重试或回退来优雅处理 API 速率限制
FR49: 系统通过 Sparkle 框架自动检查并安装应用更新
FR50: 系统可以在离线时启动并展示缓存的照片图库数据
FR51: 系统在 LLM 相关功能因无网络不可用时明确提示
FR52: 本地操作（浏览、感知哈希、元数据分析）无需网络即可工作

### NonFunctional Requirements

NFR1: 应用在 Apple Silicon Mac 上 3 秒内启动到可交互状态
NFR2: 照片图库浏览在缩略图网格视图中以 60fps 滚动
NFR3: Agent 执行进度更新在事件发生后 500ms 内出现在 UI 中
NFR4: 感知哈希在 Apple Silicon 上每分钟处理 100 张照片
NFR5: 10,000 张照片的图库扫描在 60 秒内完成初始元数据索引
NFR6: 照片处理操作期间内存使用保持在 500MB 以下
NFR7: 所有后台 Agent 任务期间 UI 保持响应（无旋转光标）
NFR8: 照片缩略图网格滚动时下一页在 200ms 内加载
NFR9: API Key 存储在 macOS 钥匙串中，不以明文或配置文件形式存储
NFR10: 发送到 LLM API 的照片数据使用 HTTPS/TLS 加密传输
NFR11: 本地分析缓存存储在应用沙盒容器中，其他应用无法访问
NFR12: 分析完成后应用不记录或缓存全分辨率照片数据
NFR13: 用户可以从设置中清除所有本地缓存和分析历史
NFR14: 应用二进制文件使用 Apple Developer ID 签名并通过 Apple 公证
NFR15: 对照片文件损坏零容忍——应用绝不写入原始图像文件
NFR16: 批量操作执行前创建元数据备份；回滚在 5 秒内完成
NFR17: 应用优雅处理意外终止（崩溃、强制退出）而不丢失进行中的元数据变更
NFR18: 图库扫描检测并报告照片图库状态的不一致
NFR19: PhotoKit 操作优雅处理权限变更（用户在会话中途撤销访问）
NFR20: LLM API 调用实现指数退避，最多 3 次重试后报告失败
NFR21: 供应商故障转移在主供应商失败后 10 秒内完成
NFR22: Sparkle 自动更新每天检查一次，不中断活跃的 Agent 任务
NFR23: 当 PhotoKit 返回部分结果时（如 iCloud 照片尚未下载）应用保持功能正常

### Additional Requirements

- **项目初始化:** 使用 Xcode 项目 + SPM（无第三方启动模板），macOS App 目标，SwiftUI Lifecycle，Swift 6，arm64 only
- **SPM 依赖:** OpenAgentSDKSwift（Agent 基础设施）+ Sparkle 2（自动更新）
- **Entitlements 配置:** 沙盒、PhotoKit 权限、网络客户端、Keychain
- **架构模式:** 分层架构（Presentation → Application → Domain → Infrastructure）+ 依赖注入
- **Agent 执行引擎:** 状态机驱动（Planning → Running → Review → Confirm → Completed/Cancelled），AsyncStream 流式输出
- **PhotoKit 服务层:** Repository 模式 + Actor 隔离，所有 PhotoKit 操作串行化
- **LLM 网关:** Provider 协议 + 故障转移链 + 成本追踪，AnthropicProvider + OpenAICompatibleProvider
- **数据持久化:** SwiftData（元数据缓存、分析结果、操作历史）+ 文件系统（缩略图、pHash 索引）+ Keychain（API Key）
- **状态管理:** @Observable + Observation 框架（Swift 原生），不引入 TCA
- **操作回滚:** 快照 + 操作日志模式，支持批量回滚和 ⌘Z 撤销
- **缓存策略:** 两级缓存（内存 NSCache 100MB + 磁盘），LRU 淘汰
- **错误处理:** Typed Error + 分层错误传播，LLM 指数退避重试 + 故障转移
- **并发模型:** Swift 6 strict concurrency，Sendable 类型，actor 隔离，所有 I/O 后台执行
- **Feature-based 目录结构:** 按功能模块组织，每个模块含 Views/ViewModels/Services

### UX Design Requirements

UX-DR1: 实现 Agent 工作空间三栏布局——输入区（底部固定）+ 执行区（主内容）+ 图库区（可折叠侧边），使用 NavigationSplitView，窗口最小宽度 900pt
UX-DR2: 实现 AgentInputBar 自定义组件——底部固定的自然语言输入区域，支持 Enter 提交、Shift+Enter 换行、输入历史下拉、快捷指令建议
UX-DR3: 实现 AgentExecutionPanel 自定义组件——步骤卡片列表 + 推理气泡 + 进度数字，支持计划展示/执行中/完成三种状态
UX-DR4: 实现 PhotoComparisonCard 自定义组件——去重审核单元，两张照片并排 + 匹配说明 + 保留/移除操作，支持点击放大
UX-DR5: 实现 RenameSuggestionCard 自定义组件——重命名审核单元，缩略图 + 当前名称→建议名称（含动画过渡），支持内联编辑
UX-DR6: 实现 AgentResultSummary 自定义组件——任务完成后的成果展示卡片，含操作统计和撤销按钮
UX-DR7: 实现 CostEstimateCard 自定义组件——大规模操作前的费用预估展示，含预估 API 调用次数和费用
UX-DR8: 实现首次启动引导流程——欢迎画面（≤3 屏）含产品介绍、隐私说明、权限请求，首次进入时 placeholder 展示示例指令
UX-DR9: 实现权限渐进授权 UI——只读默认启动，写入操作时自然提示升级，拒绝时引导至系统设置
UX-DR10: 实现 Agent 推理可视化——靛蓝色背景卡片呈现 Agent 输出，推理内容用斜体/灰色文字，区分于用户和系统内容
UX-DR11: 实现操作确认分级模式——只读操作无需确认、写入操作批量确认+执行按钮、破坏性操作二次确认 Sheet
UX-DR12: 实现费用追踪面板——在设置中展示按会话和按月的累计 API 支出
UX-DR13: 实现照片网格自适应列数——最小列宽 120pt，列间距 4pt，根据窗口宽度自动计算
UX-DR14: 实现 WCAG AA 无障碍合规——VoiceOver 标签覆盖自定义组件、键盘导航、动态字体、颜色对比度 4.5:1、减少动态效果适配
UX-DR15: 实现空状态处理——首次启动快捷指令建议、无结果友好提示+替代操作建议、离线模式指示+可用本地功能列表
UX-DR16: 实现窗口状态保持——使用 @AppStorage 记住窗口大小和面板展开状态
UX-DR17: 实现按钮层级系统——主要（实色填充+强调色）、次要（描边）、危险（红色+二次确认）、文本（无背景），每界面最多一个主要按钮
UX-DR18: 实现导航模式——无传统侧边栏、窗口工具栏含照片库切换/设置入口/会话历史、⌘N 新建会话、⌘, 打开设置

### FR Coverage Map

FR1: Epic 1 — 授予照片图库读取权限
FR2: Epic 1 — 浏览照片图库（相册、智能相册、文件夹）
FR3: Epic 1 — 查看照片缩略图和元数据
FR4: Epic 7 — 检测照片图库外部变更
FR5: Epic 1 — 分页浏览大型照片图库
FR6: Epic 4 — 授予写入权限（渐进授权）
FR7: Epic 1 — 访问全分辨率照片资源
FR8: Epic 3 — 输入自然语言指令
FR9: Epic 3 — 解析自然语言为 Agent 任务
FR10: Epic 3 — 意图不明确时提出澄清
FR11: Epic 3 — 查看和继续历史会话
FR12: Epic 3 — 多轮对话完成任务
FR13: Epic 3 — Agent 自主执行多步工作流
FR14: Epic 3 — 实时查看 Agent 执行进度
FR15: Epic 3 — 查看 Agent 决策推理过程
FR16: Epic 3 — Agent 更新流式传输到 UI
FR17: Epic 3 — 随时取消 Agent 任务
FR18: Epic 5 — 请求重复照片检测
FR19: Epic 5 — 本地感知哈希检测相似照片
FR20: Epic 5 — LLM 确认视觉相似照片是否重复
FR21: Epic 5 — 审核重复分组（并排对比 + AI 说明）
FR22: Epic 5 — 批准或拒绝单个重复分组
FR23: Epic 5 — 批量批准或批量拒绝
FR24: Epic 6 — 请求 AI 驱动重命名
FR25: Epic 6 — 分析照片内容生成描述性标题
FR26: Epic 6 — 审核建议名称
FR27: Epic 6 — 修改单个建议名称
FR28: Epic 6 — 批量执行重命名
FR29: MVP 后 — 按事件/主题/人物创建智能相册
FR30: MVP 后 — 视觉/时间/地理聚类照片
FR31: MVP 后 — 交互式调整相册分组
FR32: MVP 后 — 在 Apple 照片中创建相册
FR33: Epic 4 — 破坏性操作前需用户批准
FR34: Epic 4 — 可配置时间窗口内撤销批量操作
FR35: Epic 4 — 批量修改前创建元数据快照
FR36: Epic 4 — 批量操作中途失败自动回滚
FR37: Epic 4 — 只读分析模式
FR38: Epic 4 — 绝不修改原始图像文件
FR39: Epic 7 — 展示隐私声明
FR40: Epic 7 — 查看哪些照片被发送到 LLM
FR41: Epic 7 — 不在第三方服务器存储照片
FR42: Epic 7 — 本地缓存仅存储在设备上
FR43: Epic 2 — 配置多个 LLM 供应商 API Key
FR44: Epic 2 — 选择默认供应商
FR45: Epic 2 — 配置备用供应商自动故障转移
FR46: Epic 2 — 大规模操作前展示费用预估
FR47: Epic 2 — 追踪并展示累计 API 支出
FR48: Epic 2 — 优雅处理 API 速率限制
FR49: Epic 7 — Sparkle 自动更新
FR50: Epic 7 — 离线启动并展示缓存数据
FR51: Epic 7 — 无网络时明确提示
FR52: Epic 7 — 本地操作无需网络

## Epic List

### Epic 1: "Hello Curator" — 首次启动与照片图库访问
用户首次打开 Curator，授予照片库读取权限，浏览照片缩略图和元数据。应用以原生 macOS 体验呈现图库，为后续 Agent 功能奠定基础。
**FRs covered:** FR1, FR2, FR3, FR5, FR7
**UX-DRs covered:** UX-DR8, UX-DR9, UX-DR13, UX-DR15, UX-DR16
**Architecture:** 项目脚手架、Xcode 配置、SPM 依赖、Entitlements、分层目录结构、PhotoKitRepository（actor）、PhotoPermissionManager、SwiftData 初始化、基础 UI 框架

### Epic 2: "Your AI Setup" — AI 供应商配置与成本管理
用户配置 Anthropic 和 OpenAI 兼容的 API Key，选择默认模型和备用供应商，查看费用预估和累计支出。LLM 网关提供统一的供应商抽象、自动故障转移和成本追踪。
**FRs covered:** FR43, FR44, FR45, FR46, FR47, FR48
**UX-DRs covered:** UX-DR7, UX-DR12, UX-DR17
**Architecture:** LLMGateway（actor）、AnthropicProvider、OpenAICompatibleProvider、KeychainManager、CostTracker、LLMModels

### Epic 3: "Agent Workspace" — 自然语言照片管理
用户通过自然语言输入与 Agent 交互，实时观看 Agent 规划和执行多步工作流。Agent 执行过程以步骤卡片、推理气泡和进度数字形式可视化。这是 Curator 的核心差异化体验。
**FRs covered:** FR8, FR9, FR10, FR11, FR12, FR13, FR14, FR15, FR16, FR17
**UX-DRs covered:** UX-DR1, UX-DR2, UX-DR3, UX-DR10, UX-DR18
**Architecture:** AgentJob 状态机、AgentEvent 枚举、AsyncStream 流式管道、OpenAgentSDKSwift 工具注册、AgentToolRegistry、AgentExecutionViewModel、ChatInputViewModel、NavigationModel

### Epic 4: "Safety Net" — 操作安全与数据保护
用户在进行任何写操作前获得充分的安全保障：破坏性操作需确认、所有操作可撤销、批量操作前创建快照、失败自动回滚。只读模式让用户安全探索，写入权限渐进授权。这是信任建立的基石。
**FRs covered:** FR6, FR33, FR34, FR35, FR36, FR37, FR38
**UX-DRs covered:** UX-DR11, UX-DR15, UX-DR17
**Architecture:** OperationManager（actor）、OperationSnapshot、BatchOperation、写入权限流程、确认工作流 UI、SwiftData 操作历史持久化

### Epic 5: "Find Duplicates" — 智能去重
用户用自然语言请求去重，Agent 自动执行扫描→本地 pHash 分析→LLM 确认→分组展示的完整流程。用户逐组或批量审核重复结果，每对照片有并排对比和 AI 匹配说明。这是 MVP 的旗舰功能，最高频的照片管理需求。
**FRs covered:** FR18, FR19, FR20, FR21, FR22, FR23
**UX-DRs covered:** UX-DR4, UX-DR6
**Architecture:** PerceptualHasher、ImageAnalysisPipeline、ThumbnailGenerator、DeduplicationViewModel、PhotoComparisonCard、DuplicateReviewView、BatchApprovalView、SDK Tools（ScanLibraryTool、AnalyzeDuplicatesTool、DeleteAssetsTool、EstimateCostTool）

### Epic 6: "Smart Rename" — AI 智能重命名
用户请求 AI 为照片生成描述性标题，Agent 分析每张照片的内容并建议名称。用户逐个审核或批量接受建议，可内联修改名称。展示 AI 对照片内容的理解能力，第二高频需求。
**FRs covered:** FR24, FR25, FR26, FR27, FR28
**UX-DRs covered:** UX-DR5, UX-DR6
**Architecture:** 内容分析管线（复用 ImageAnalysisPipeline）、RenameViewModel、RenameSuggestionCard、RenameReviewView、SDK Tools（AnalyzeContentTool、RenameAssetsTool）

### Epic 7: "Always Ready" — 隐私、更新与离线能力
用户获得完整的隐私透明度——了解什么数据发送到 LLM、为什么发送。应用通过 Sparkle 自动更新，离线时仍可浏览图库和执行本地分析。图库变更监控确保数据始终同步。
**FRs covered:** FR4, FR39, FR40, FR41, FR42, FR49, FR50, FR51, FR52
**UX-DRs covered:** UX-DR14, UX-DR15
**Architecture:** SparkleManager、LibraryChangeObserver、CacheManager（两级缓存）、SwiftDataManager、离线模式指示器、隐私审计日志、可达性监控

---

## Epic 1: "Hello Curator" — 首次启动与照片图库访问

用户首次打开 Curator，授予照片库读取权限，浏览照片缩略图和元数据。应用以原生 macOS 体验呈现图库，为后续 Agent 功能奠定基础。

### Story 1.1: 项目初始化与构建配置

As a 开发者，
I want 创建 Xcode 项目并配置所有必要的依赖和权限，
So that 项目可以成功构建并运行在 macOS 15+ Apple Silicon 上。

**Acceptance Criteria:**

**Given** 项目已创建
**When** 执行 `xcodebuild build`
**Then** 项目成功编译，无错误
**And** 目标平台为 macOS 15.0，架构 arm64

**Given** SPM 依赖已配置
**When** Xcode 解析 Package.resolved
**Then** OpenAgentSDKSwift 和 Sparkle 2 依赖已正确添加
**And** Feature-based 目录结构已创建（App/, Core/, Features/, Infrastructure/, Resources/）

**Given** Entitlements 文件已配置
**When** 检查 Curator.entitlements
**Then** 包含 app-sandbox、personal-information.photos、network.client、keychain 权限声明

### Story 1.2: 分层架构骨架

As a 开发者，
I want 建立分层架构的基础类型和错误体系，
So that 后续功能模块可以遵循一致的架构模式开发。

**Acceptance Criteria:**

**Given** Core/Errors/ 目录已创建
**When** 检查错误类型定义
**Then** DomainError、InfrastructureError、UserFacingError 枚举已定义，符合架构文档
**And** 错误映射规则：Infrastructure 错误可转换为 Domain 错误

**Given** Core/Models/ 目录已创建
**When** 检查领域模型
**Then** PhotoAsset、AssetMetadata 值类型已定义（Sendable），包含日期、标题、描述、关键词、位置字段
**And** LoadingState<T> 枚举已定义（idle/loading/loaded/failed）

**Given** App/AppDependencies.swift 已创建
**When** 检查依赖注入容器
**Then** AppDependencies 提供协议到具体实现的绑定
**And** 支持测试时替换为 mock 实现

### Story 1.3: PhotoKit 读取服务

As a 用户，
I want 授予应用照片图库读取权限并浏览我的照片，
So that 我可以在 Curator 中查看所有照片和相册。

**Acceptance Criteria:**

**Given** 应用首次启动且未获得照片权限（FR1）
**When** 请求读取权限
**Then** 系统弹出权限对话框，用户授权后 PhotoKitRepository 可读取图库
**And** 用户拒绝时返回友好的错误提示，引导至系统设置

**Given** PhotoKitRepository 已获得读取权限（FR2, FR3）
**When** 调用 fetchAssets()
**Then** 返回照片列表，包含缩略图和元数据（日期、标题、描述、关键词、位置）
**And** PHAssetMapper 正确将 PHAsset 映射为领域模型 PhotoAsset

**Given** 图库中有大量照片（10,000+）（FR5）
**When** 使用分页参数调用 fetchAssets(pageSize: 100)
**Then** 返回 AssetPage 包含当前页照片和下一页游标
**And** 所有 PhotoKit 操作在 actor 内执行，不阻塞主线程

**Given** 需要访问照片全分辨率图像（FR7）
**When** 调用 fetchFullResolutionImage(for: assetID)
**Then** 返回该照片的全分辨率 Data，用于后续 AI 分析

### Story 1.4: 照片图库浏览网格

As a 用户，
I want 在网格视图中浏览照片缩略图，
So that 我可以快速浏览和管理我的照片库。

**Acceptance Criteria:**

**Given** PhotoLibraryViewModel 已加载照片数据
**When** 渲染 PhotoGridView
**Then** 照片以自适应列数的网格展示（UX-DR13：最小列宽 120pt，间距 4pt）
**And** 窗口宽度变化时列数自动调整

**Given** 用户滚动照片网格（FR5）
**When** 滚动到当前页末尾
**Then** 自动加载下一页（200ms 内加载，NFR8）
**And** 滚动流畅，达到 60fps（NFR2）

**Given** 点击某张照片
**When** 打开照片详情
**Then** PhotoDetailSheet 展示完整元数据（日期、标题、描述、关键词、位置）
**And** 缩略图缓存（NSCache，100MB 上限）避免重复加载

### Story 1.5: 首次启动引导流程

As a 新用户，
I want 通过简洁的引导流程了解 Curator 并授权照片访问，
So that 我可以快速开始使用应用。

**Acceptance Criteria:**

**Given** 用户首次打开 Curator（UX-DR8）
**When** 进入引导流程
**Then** 展示最多 3 屏：产品介绍、隐私说明、照片权限请求
**And** 隐私说明包含"照片仅在会话中分析，发送到 LLM API 用于理解"

**Given** 用户授予照片读取权限
**When** 权限授予成功
**Then** 扫描照片库元数据，展示照片数量摘要（如"已发现 15,320 张照片"）
**And** 进入主界面时输入框 placeholder 展示示例指令（UX-DR15）

**Given** 用户拒绝照片权限（UX-DR9）
**When** 权限被拒绝
**Then** 展示只读模式说明和引导至系统设置的按钮
**And** 应用仍可启动，但照片功能不可用

### Story 1.6: 主界面框架与窗口管理

As a 用户，
I want 看到清晰的 Agent 工作空间布局并保持窗口状态，
So that 我有稳定的工作环境。

**Acceptance Criteria:**

**Given** 应用已启动并进入主界面（UX-DR1）
**When** 渲染主界面
**Then** 使用 NavigationSplitView 实现三栏布局：照片库面板（可折叠）+ Agent 执行区 + 输入区
**And** 窗口最小宽度 900pt

**Given** 用户调整了窗口大小或面板展开状态（UX-DR16）
**When** 关闭应用
**Then** 窗口大小和面板状态通过 @AppStorage 持久化
**And** 下次启动时恢复上次的状态

**Given** 窗口工具栏已渲染（UX-DR18）
**When** 检查工具栏内容
**Then** 包含照片库切换按钮、设置入口、会话历史按钮
**And** ⌘N 新建会话、⌘, 打开设置的快捷键已注册

---

## Epic 2: "Your AI Setup" — AI 供应商配置与成本管理

用户配置 Anthropic 和 OpenAI 兼容的 API Key，选择默认模型和备用供应商，查看费用预估和累计支出。LLM 网关提供统一的供应商抽象、自动故障转移和成本追踪。

### Story 2.1: LLM 网关核心

As a 系统，
I want 通过统一的 LLM 网关调用 AI 供应商 API，
So that 上层代码不依赖具体供应商实现，支持故障转移和重试。

**Acceptance Criteria:**

**Given** LLMProvider 协议已定义
**When** 检查协议方法
**Then** 包含 analyze(images:prompt:) 和 estimateCost(imageCount:model:) 方法
**And** LLMGateway actor 已实现，统一管理供应商调用

**Given** AnthropicProvider 已实现并配置了 API Key
**When** LLMGateway 调用 analyze()
**Then** 通过 URLSession 发送 HTTPS 请求到 Claude API（NFR10）
**And** 使用 JSON 格式传递图片数据和提示词

**Given** 主供应商调用失败（NFR20）
**When** LLMGateway 检测到错误
**Then** 执行指数退避重试（最多 3 次）
**And** 重试全部失败后回退到备用供应商（NFR21: 10 秒内完成）

### Story 2.2: Keychain 凭证管理

As a 用户，
I want 我的 API Key 安全存储在 macOS Keychain 中，
So that 凭证不会被泄露到配置文件或日志中。

**Acceptance Criteria:**

**Given** KeychainManager 已实现（NFR9）
**When** 存储 API Key
**Then** 使用 Security 框架的 SecItemAdd API 存储到 Keychain
**And** API Key 不以明文出现在任何配置文件或日志中

**Given** API Key 已存储在 Keychain
**When** 应用启动时读取
**Then** KeychainManager 通过 SecItemCopyMatching 检索 API Key
**And** 读取失败时返回 nil 而非崩溃

**Given** 用户在设置中删除 API Key
**When** 调用 KeychainManager.delete()
**Then** 通过 SecItemDelete 从 Keychain 移除对应条目

### Story 2.3: 多供应商支持

As a 用户，
I want 配置备用 AI 供应商以实现自动故障转移，
So that 即使主供应商不可用，我的任务也能继续执行。

**Acceptance Criteria:**

**Given** 用户配置了 Anthropic（主）和 OpenAI 兼容（备用）供应商（FR43, FR45）
**When** Anthropic API 返回 5xx 错误或超时
**Then** LLMGateway 自动回退到 OpenAICompatibleProvider 继续处理
**And** 故障转移在 10 秒内完成（NFR21）

**Given** OpenAICompatibleProvider 已实现
**When** 配置 DeepSeek API endpoint
**Then** 支持任何 OpenAI 兼容的 API（自定义 base URL + API Key）
**And** 请求格式符合 OpenAI Chat Completions API 规范

**Given** API 速率限制被触发（FR48）
**When** 收到 429 响应
**Then** LLMGateway 排队等待 retry-after 时间后重试
**And** 超过重试上限时回退到备用供应商

### Story 2.4: 成本追踪引擎

As a 系统，
I want 追踪每次 LLM API 调用的成本，
So that 可以为用户展示费用预估和累计支出。

**Acceptance Criteria:**

**Given** CostTracker 已实现
**When** 每次 LLM 调用完成
**Then** 记录供应商名称、模型、输入/输出 token 数、成本金额
**And** 数据持久化到 SwiftData，按会话和按月聚合（FR47）

**Given** 用户即将执行大规模分析任务（FR46）
**When** 系统计算费用预估
**Then** 基于照片数量和所选模型返回 CostEstimate（预估调用次数 × 单价）
**And** 预估展示在执行确认前

**Given** 成本数据已累积
**When** 查询月度成本
**Then** 返回当月累计支出和按供应商的明细
**And** 支持按会话查询单次操作的成本

### Story 2.5: 供应商设置 UI

As a 用户，
I want 在设置页面配置 API Key 和选择默认供应商，
So that 我可以使用自己的 AI 账户。

**Acceptance Criteria:**

**Given** 用户打开设置页面（⌘,）
**When** SettingsView 渲染
**Then** 展示标准 macOS Settings 窗口：API Key 管理、模型选择、费用追踪（FR44）
**And** APIKeyManagementView 使用 SecureField 输入 Key

**Given** 用户输入 Anthropic API Key
**When** 点击"验证"
**Then** 发送测试请求验证 Key 有效性，展示成功/失败反馈
**And** 验证成功后 Key 存储到 Keychain（通过 KeychainManager）

**Given** 用户选择默认模型
**When** 在 ModelSelectionView 中切换
**Then** 设置更新立即生效，后续 LLM 调用使用新选择的模型

### Story 2.6: 费用预估与追踪面板

As a 用户，
I want 查看操作费用预估和历史支出记录，
So that 我可以控制 AI 使用成本。

**Acceptance Criteria:**

**Given** 即将执行大规模分析任务
**When** CostEstimateCard 渲染（UX-DR7）
**Then** 展示预估 API 调用次数、预估费用、所选模型
**And** 支持切换模型查看不同费用

**Given** 用户查看 CostTrackingView（FR47, UX-DR12）
**When** 费用追踪面板加载
**Then** 展示按会话和按月的累计 API 支出
**And** 显示各供应商的使用明细和费用占比

---

## Epic 3: "Agent Workspace" — 自然语言照片管理

用户通过自然语言输入与 Agent 交互，实时观看 Agent 规划和执行多步工作流。Agent 执行过程以步骤卡片、推理气泡和进度数字形式可视化。这是 Curator 的核心差异化体验。

### Story 3.1: Agent 执行引擎

As a 系统，
I want 使用状态机驱动的 Agent 执行引擎管理任务生命周期，
So that Agent 工作流有清晰的阶段和状态转换。

**Acceptance Criteria:**

**Given** AgentJob @Observable 类已实现
**When** 检查状态机
**Then** 支持完整生命周期：Planning → Running → Review → Confirm → Completed/Cancelled/Failed
**And** 每次状态变更通过 @Observable 触发 SwiftUI 更新

**Given** AgentEvent Sendable 枚举已定义
**When** 检查事件类型
**Then** 包含 planGenerated、stepStarted、stepProgress、stepReasoning、stepCompleted、stepFailed、reviewReady、executionCompleted
**And** 所有事件类型实现 Sendable，可安全跨并发域传递

**Given** AgentJob 正在 Running 状态（FR17）
**When** 用户点击取消按钮
**Then** Task.cancel() 被调用，状态转换为 Cancelled
**And** 已完成的部分结果被保留

### Story 3.2: OpenAgentSDKSwift 集成

As a 系统，
I want 将 Agent 操作注册为 OpenAgentSDKSwift 的工具，
So that SDK Agent 循环可以调用 Curator 的图库和分析功能。

**Acceptance Criteria:**

**Given** AgentToolRegistry 已实现
**When** 注册自定义工具
**Then** 支持动态注册符合 SDK Tool 协议的自定义工具
**And** 工具执行结果通过 AsyncStream<AgentEvent> 回传到 AgentJob

**Given** SDK Agent 循环已启动
**When** 用户发送自然语言指令
**Then** SDK 解析意图并调用对应的注册工具
**And** 工具执行在后台 Task 中进行，不阻塞 UI

**Given** 工具执行需要访问 PhotoKit 或 LLM
**When** 工具调用基础设施服务
**Then** 通过依赖注入获取协议实现，不直接创建具体实例
**And** 工具执行结果正确映射为 AgentEvent

### Story 3.3: Agent 输入栏

As a 用户，
I want 在底部输入栏键入自然语言指令与 Agent 交互，
So that 我可以用自然语言描述我的照片管理需求。

**Acceptance Criteria:**

**Given** AgentInputBar 组件已渲染（UX-DR2）
**When** 检查输入栏
**Then** 底部固定的单行输入区域（默认），支持 Enter 提交、Shift+Enter 换行
**And** placeholder 展示示例指令："试试'找出所有重复照片'"

**Given** 用户在输入栏键入内容（FR8）
**When** 按 Enter
**Then** 指令发送给 Agent，输入栏清空
**And** ChatInputViewModel（@MainActor）将指令传递给 AgentJob

**Given** 首次使用且输入栏为空
**When** QuickCommandSuggestions 渲染
**Then** 展示 3-4 个快捷指令建议卡片（如"找出重复照片"、"重命名照片"）
**And** 点击建议直接填入输入栏

### Story 3.4: Agent 执行面板

As a 用户，
I want 实时查看 Agent 的执行进度和推理过程，
So that 我了解 Agent 正在做什么以及为什么这样做决策。

**Acceptance Criteria:**

**Given** AgentJob 进入 Running 状态（FR14, FR15）
**When** AgentExecutionPanel 渲染（UX-DR3）
**Then** 展示步骤卡片列表，每步显示状态图标（等待/执行中/完成/失败）
**And** 实时更新进度数字（如"已处理 1,200/15,000"）

**Given** Agent 发布推理事件（stepReasoning）
**When** ReasoningBubbleView 渲染（UX-DR10）
**Then** 以靛蓝色背景卡片展示推理内容
**And** 推理内容用斜体或灰色文字，区别于陈述性内容

**Given** AgentExecutionViewModel 已绑定 AgentJob（FR16）
**When** AsyncStream<AgentEvent> 收到新事件
**Then** 500ms 内 UI 更新（NFR3）
**And** 更新过程不阻塞用户交互（NFR7）

### Story 3.5: 会话管理

As a 用户，
I want 保存和恢复之前的对话会话，
So that 我可以继续之前的照片管理任务。

**Acceptance Criteria:**

**Given** 用户与 Agent 进行了多轮对话（FR12）
**When** 对话上下文传递给 Agent
**Then** Agent 能理解之前的指令和结果，进行连贯的多轮交互
**And** 意图不明确时 Agent 提出澄清问题（FR10）

**Given** 会话数据已持久化到 SwiftData（FR11）
**When** 用户重新打开应用
**Then** 可查看历史会话列表
**And** 点击历史会话恢复完整上下文，继续对话

**Given** 用户按 ⌘N（UX-DR18）
**When** 创建新会话
**Then** 清空当前 Agent 上下文，开始全新对话
**And** 前一个会话自动保存

### Story 3.6: Agent 实时流式通信

As a 用户，
I want Agent 的执行过程实时流式更新到界面，
So that 我不需要等待整个任务完成才看到结果。

**Acceptance Criteria:**

**Given** 完整的 AsyncStream 管道已连接
**When** SDK 工具产生执行事件
**Then** 事件通过 AsyncStream<AgentEvent> → AgentJob → AgentExecutionViewModel → SwiftUI 传递
**And** UI 在 500ms 内反映变化（NFR3）

**Given** 大量 AgentEvent 快速产生
**When** UI 处理不及
**Then** 合并同类事件（如多个 stepProgress），避免过度渲染
**And** UI 线程不被阻塞（NFR7）

**Given** 用户点击取消按钮
**When** Task.cancel() 被调用
**Then** AsyncStream 正常结束，UI 展示已取消状态
**And** 不产生内存泄漏

---

## Epic 4: "Safety Net" — 操作安全与数据保护

所有写操作需确认，所有操作可撤销，批量操作有快照和回滚，只读模式可用。这是信任建立的基石。

### Story 4.1: 写入权限渐进授权

As a 用户，
I want 应用以只读模式启动，仅在需要写入时请求权限，
So that 我对应用的操作权限有完全控制。

**Acceptance Criteria:**

**Given** 应用默认以只读权限启动（FR37）
**When** 应用首次打开
**Then** 仅请求照片图库读取权限
**And** 不主动请求写入权限

**Given** Agent 需要执行写操作（FR6）
**When** 触发删除、重命名或创建相册
**Then** PhotoPermissionManager 弹出写入权限请求
**And** 用户授权后操作继续执行

**Given** 用户拒绝写入权限（UX-DR9）
**When** Agent 尝试写操作
**Then** 展示引导至系统设置的说明
**And** 操作结果被保存，用户授权后可重新执行

### Story 4.2: 操作管理器核心

As a 系统，
I want 在每次批量操作前创建元数据快照，
So that 所有修改都可以安全回滚。

**Acceptance Criteria:**

**Given** OperationManager actor 已实现（FR35）
**When** 调用 beginBatch(operations:)
**Then** 为每个受影响的资产创建 OperationSnapshot（操作前元数据）
**And** 快照持久化到 SwiftData

**Given** OperationSnapshot 模型已定义
**When** 检查字段
**Then** 包含 id、timestamp、operationType（.rename/.delete/.move/.metadataChange）、assetID、beforeState
**And** BatchOperation 模型关联多个 OperationSnapshot

**Given** 批量操作执行完成（FR38）
**When** 检查操作记录
**Then** 原始图像文件未被修改，仅操作元数据和组织结构
**And** NFR15（零文件损坏）得到保证

### Story 4.3: 批量回滚与撤销系统

As a 用户，
I want 随时撤销任何批量操作，
So that 我知道即使犯错也能恢复。

**Acceptance Criteria:**

**Given** 批量操作已完成（FR34）
**When** 用户按 ⌘Z 或点击撤销按钮
**Then** OperationManager.rollbackLastBatch() 执行，5 秒内完成（NFR16）
**And** 所有受影响资产恢复到操作前的元数据状态

**Given** 批量操作执行中途失败（FR36）
**When** 某个操作项失败
**Then** OperationManager 自动回滚已完成的操作项
**And** 向用户报告失败原因

**Given** 用户执行了回滚操作
**When** 再次按 ⌘Z
**Then** 回滚操作本身也可撤销（恢复到回滚前状态）
**And** 操作日志记录所有变更

**Given** 应用意外崩溃（NFR17）
**When** 重新启动
**Then** 未完成的批量操作通过持久化快照被检测到
**And** 提示用户是否回滚未完成的操作

### Story 4.4: 操作确认工作流 UI

As a 用户，
I want 在执行破坏性操作前看到明确的确认界面，
So that 我不会意外删除或修改照片。

**Acceptance Criteria:**

**Given** Agent 完成了只读分析任务（UX-DR11）
**When** 展示分析结果
**Then** 无需用户确认，直接显示结果

**Given** Agent 请求执行写操作（重命名、移动）— UX-DR11
**When** 展示批量确认摘要
**Then** 包含操作数量和缩略图预览
**And** 展示"执行"按钮（主要样式，UX-DR17）和"取消"按钮（次要样式）

**Given** Agent 请求执行破坏性操作（删除）— UX-DR11
**When** 展示确认界面
**Then** 先展示批量确认摘要 + "执行"按钮（危险样式，红色）
**Then** 用户点击"执行"后弹出二次确认 Sheet
**And** 所有写入操作展示撤销路径和时间窗口

### Story 4.5: 只读模式保障

As a 谨慎的用户，
I want 在只读模式下安全地使用所有分析功能，
So that 我可以先验证 Agent 能力再决定是否授予写入权限。

**Acceptance Criteria:**

**Given** 应用处于只读模式（FR37）
**When** 用户执行任何分析操作（去重检测、重命名建议）
**Then** 分析正常执行，结果正常展示
**And** 界面明确指示当前为只读模式

**Given** 只读模式下 Agent 生成了修改建议
**When** 用户尝试执行写操作
**Then** 系统请求写入权限升级
**And** 用户拒绝时建议保存结果供稍后执行

**Given** PhotoKitRepository 收到写操作请求（FR38）
**When** 检查权限
**Then** 如果无写入权限，拒绝操作并返回 DomainError.insufficientPermission
**And** 绝不直接修改原始图像文件

---

## Epic 5: "Find Duplicates" — 智能去重

用户用自然语言请求去重，Agent 执行完整去重流程，用户逐组或批量审核。这是 MVP 的旗舰功能。

### Story 5.1: 感知哈希引擎

As a 用户，
I want Curator 能在本地高效计算照片的感知哈希值，
So that 可以快速识别视觉相似的照片而不依赖网络。

**Acceptance Criteria:**

**Given** 系统中存在至少 100 张照片（FR19）
**When** 触发感知哈希批量计算
**Then** 引擎在 1 分钟内完成全部 100 张照片的 pHash 计算（NFR4）
**And** 计算过程在后台 Task 中执行，不阻塞主线程

**Given** PerceptualHasher 已初始化
**When** 对一张照片计算 pHash
**Then** 利用 Apple Silicon 加速完成计算
**And** 返回固定长度的哈希值用于相似度比对

**Given** 用户取消正在进行的批量计算
**When** Task.cancel() 被调用
**Then** 后台 Task 被正确取消，已计算的结果被保留
**And** 不导致内存泄漏或数据不一致

### Story 5.2: 图像分析管线

As a 用户，
I want 系统自动执行两阶段分析来精准识别重复照片，
So that 不会出现误报。

**Acceptance Criteria:**

**Given** 图库中存在视觉相似的重复照片组（FR20）
**When** ImageAnalysisPipeline 执行分析流程
**Then** 第一阶段通过本地 pHash 计算筛选出候选重复组
**And** 第二阶段将候选组发送至 LLM 进行语义确认
**And** 生成 DuplicateGroup 模型，包含相似度分数和组内照片引用

**Given** 分析管线正在处理大量照片
**When** 需要展示重复组供用户审核
**Then** ThumbnailGenerator 为每组照片生成缩略图用于快速预览
**And** DuplicateGroup 包含足够信息以支持后续审核操作

**Given** 两阶段分析已完成
**When** 生成分析结果
**Then** 每组重复照片附带 LLM 提供的匹配原因说明
**And** 相似度分数可用于排序展示优先级最高的重复组

### Story 5.3: 去重 SDK 工具

As a AI Agent，
I want 拥有一套完整的去重工具，
So that 能够自主执行完整的去重工作流。

**Acceptance Criteria:**

**Given** Agent 收到用户的去重请求（FR18）
**When** Agent 调用 ScanLibraryTool 扫描图库
**Then** 工具返回图库照片清单及其元数据
**And** AnalyzeDuplicatesTool 将 pHash 分析与 LLM 确认串联执行

**Given** 用户已审核并确认要删除的重复照片
**When** Agent 调用 DeleteAssetsTool 执行删除
**Then** 工具通过 OperationManager 安全执行删除操作，支持回滚
**And** 删除操作在执行前需要用户确认

**Given** Agent 需要告知用户去重操作的预估成本
**When** Agent 调用 EstimateCostTool
**Then** 工具通过 CostTracker 返回预计的 LLM API 调用成本
**And** 所有去重工具已注册至 AgentToolRegistry

### Story 5.4: 去重审核界面

As a 用户，
I want 以并排对比的方式查看重复照片组并附带匹配原因，
So that 我可以做出明智的保留/移除决策。

**Acceptance Criteria:**

**Given** 去重分析已完成并生成重复组（FR21）
**When** 进入去重审核界面（DuplicateReviewView）
**Then** 界面展示可展开的 PhotoComparisonCard 列表
**And** 每张卡片遵循 UX-DR4：两张照片并排展示、匹配原因说明、保留/移除操作按钮

**Given** 用户正在查看某个重复组（FR22）
**When** 点击保留或移除按钮
**Then** 对应的照片被标记为保留或移除状态
**And** DeduplicationViewModel 实时更新审核状态

**Given** 审核界面加载完成
**When** 用户浏览重复组
**Then** 缩略图加载流畅，支持滚动浏览大量重复组
**And** 已审核和未审核的组有明确的视觉区分

### Story 5.5: 批量审批与执行

As a 用户，
I want 能够批量审批所有重复项，
So that 在处理大量重复照片时节省时间。

**Acceptance Criteria:**

**Given** 审核界面中存在多个待处理的重复组（FR23）
**When** 用户点击"全部移除"或"全部保留"按钮
**Then** BatchApprovalView 展示批量确认摘要，列出将要执行的操作数量
**And** 用户确认后通过 OperationManager 批量执行操作

**Given** 用户执行了批量操作
**When** 操作完成后
**Then** 系统展示执行结果摘要（成功数、失败数、跳过数）
**And** 提供撤销选项以回滚批量操作

**Given** 批量操作正在进行
**When** 某个操作失败
**Then** 系统跳过失败项继续处理后续项
**And** 操作完成后汇总所有失败项供用户处理

### Story 5.6: 去重结果摘要

As a 用户，
I want 在去重完成后看到清晰的结果摘要，
So that 我了解本次去重的实际效果。

**Acceptance Criteria:**

**Given** 去重操作已全部完成
**When** 展示结果界面（UX-DR6）
**Then** AgentResultSummary 显示已移除的照片数量、节省的磁盘空间、操作耗时
**And** ResultSummaryViewModel 提供庆祝动画反馈

**Given** 结果摘要界面已展示
**When** 用户点击撤销按钮
**Then** 系统通过 OperationManager 回滚本次去重操作
**And** 所有被移除的照片恢复至原始位置

**Given** 用户完成一次去重流程
**When** 查看历史记录
**Then** 本次去重结果被记录，包含日期、处理数量、节省空间等信息

---

## Epic 6: "Smart Rename" — AI 智能重命名

用户请求 AI 为照片生成描述性标题，Agent 分析每张照片的内容并建议名称。用户逐个审核或批量接受建议。

### Story 6.1: 内容分析与命名生成

As a 用户，
I want AI 能分析照片内容并生成描述性标题，
So that 为无意义的文件名赋予有意义的名称。

**Acceptance Criteria:**

**Given** 用户选择了需要重命名的照片（FR24）
**When** AnalyzeContentTool 分析照片内容（FR25）
**Then** 工具通过 LLM 识别照片中的场景、人物、地点等关键元素
**And** 在用户偏好语言下生成描述性标题

**Given** LLM 已完成对照片的内容分析
**When** 生成 RenameSuggestion 模型
**Then** 包含原始文件名、建议的新名称、分析置信度
**And** 建议名称符合文件系统命名规范

**Given** 分析过程中 LLM 不可用或返回错误
**When** 命名生成失败
**Then** 该照片被标记为"未能生成建议"并跳过
**And** 不影响其他照片的分析流程继续进行

### Story 6.2: 重命名 SDK 工具

As a AI Agent，
I want 拥有批量重命名工具并通过安全机制执行，
So that 在用户确认后可靠地完成重命名。

**Acceptance Criteria:**

**Given** 用户已审核并接受了重命名建议（FR28）
**When** Agent 调用 RenameAssetsTool 执行批量重命名
**Then** 工具通过 PhotoKit 执行重命名操作，保留原始文件的元数据
**And** 通过 OperationManager 执行以确保操作安全和可回滚

**Given** Agent 需要估算重命名操作的 LLM 成本
**When** 调用成本估算功能
**Then** 返回每张照片的分析成本及总成本预估
**And** RenameAssetsTool 已注册至 AgentToolRegistry

**Given** 批量重命名过程中某张照片操作失败
**When** 文件被占用或权限不足
**Then** 系统跳过该文件继续处理其余照片
**And** 操作完成后汇总所有失败项及失败原因

### Story 6.3: 重命名审核界面

As a 用户，
I want 以直观的方式查看重命名建议并支持内联编辑，
So that 我可以在接受之前确认或修改建议的名称。

**Acceptance Criteria:**

**Given** AI 已为多张照片生成重命名建议（FR26）
**When** 进入重命名审核界面（RenameReviewView）
**Then** 每张照片以 RenameSuggestionCard（UX-DR5）形式展示：缩略图、当前文件名、建议文件名
**And** 当前名称到建议名称之间有平滑的过渡动画效果

**Given** 用户正在查看某张照片的重命名建议（FR27）
**When** 点击建议名称进行编辑
**Then** 支持内联编辑，用户可直接修改建议的文件名
**And** 编辑后的名称实时验证文件系统命名合规性

**Given** 用户对单张照片做出决策
**When** 点击接受或拒绝按钮
**Then** 该照片的重命名建议被标记为已接受或已拒绝
**And** RenameViewModel 更新审核进度，界面自动聚焦到下一张未审核的照片

### Story 6.4: 批量重命名执行

As a 用户，
I want 在审核完所有建议后一次性批量执行重命名，
So that 高效完成整个重命名流程。

**Acceptance Criteria:**

**Given** 用户已完成所有重命名建议的审核
**When** 点击"全部接受"或"全部拒绝"按钮
**Then** 系统展示批量确认摘要，列出将要重命名的照片数量
**And** 用户确认后通过 OperationManager 批量执行重命名操作

**Given** 批量重命名操作已完成
**When** 展示结果界面（UX-DR6）
**Then** AgentResultSummary 显示已重命名的照片数量、跳过数量、失败数量
**And** 提供撤销按钮支持回滚本次批量重命名

**Given** 用户触发了撤销操作
**When** 系统通过 OperationManager 回滚
**Then** 所有照片恢复至原始文件名
**And** 操作日志记录本次回滚事件

---

## Epic 7: "Always Ready" — 隐私、更新与离线能力

用户获得完整的隐私透明度、自动更新和离线能力。

### Story 7.1: 图库变更监控

As a 用户，
I want Curator 能自动检测外部对照片图库的修改，
So that 应用中的数据始终保持最新。

**Acceptance Criteria:**

**Given** Curator 正在运行（FR4）
**When** 用户在系统"照片"App 中新增、删除或修改了照片
**Then** LibraryChangeObserver 通过 PHPhotoLibraryChangeObserver 检测到变更
**And** 自动使受影响照片的缓存元数据失效

**Given** 图库变更已被检测到
**When** 缓存失效处理完成
**Then** 通知 UI 层刷新受影响的视图
**And** 正在进行中的操作收到变更通知以避免数据冲突

**Given** 外部发生大量照片变更
**When** LibraryChangeObserver 接收到批量变更通知
**Then** 系统合并变更事件避免重复刷新，检测数据不一致性（NFR18）
**And** 不影响应用性能

### Story 7.2: 两级缓存管理

As a 用户，
I want Curator 能高效管理内存和磁盘缓存，
So that 在保持应用流畅的同时控制资源占用。

**Acceptance Criteria:**

**Given** 应用正在浏览照片缩略图
**When** 加载缩略图
**Then** 首先从内存缓存（NSCache）读取，命中则直接展示（NFR8: 200ms 以内）
**And** 未命中则从磁盘缓存读取，仍未命中则生成缩略图

**Given** 应用运行过程中内存使用增长（NFR6）
**When** 总内存接近 500MB 上限
**Then** CacheManager 自动淘汰最久未使用的内存缓存项
**And** 磁盘缓存仅在沙盒存储目录中操作（NFR11）

**Given** LibraryChangeObserver 检测到图库变更
**When** 变更涉及已缓存的照片
**Then** CacheManager 使对应照片的内存缓存和磁盘缓存失效
**And** 下次访问时重新生成最新的缓存数据

### Story 7.3: 隐私透明度

As a 用户，
I want 清楚了解 Curator 如何处理我的照片数据，
So that 我可以信任应用的隐私保护措施。

**Acceptance Criteria:**

**Given** 用户首次使用涉及 LLM 的功能（FR39）
**When** 进入隐私设置页面
**Then** 应用展示隐私声明，明确说明哪些数据发送至 LLM、传输方式、保留策略
**And** 隐私声明包含"照片仅在会话中分析"说明

**Given** 照片被发送至 LLM 进行分析（FR40）
**When** 分析完成后
**Then** 审计日志记录每次 LLM 调用涉及的照片标识
**And** 用户可在设置中查看"已发送至 LLM 的照片"历史记录

**Given** 照片分析完成且结果已返回
**When** 处理后续流程
**Then** 系统不缓存照片的全分辨率数据（NFR12），仅保留分析结果和缩略图
**And** 用户可在设置中一键清除所有缓存（NFR13）
**And** 不将照片数据传输至任何第三方存储服务（FR41, FR42）

### Story 7.4: 离线模式

As a 用户，
I want 在没有网络时仍能使用基本功能，
So that 在任何环境下都能管理照片。

**Acceptance Criteria:**

**Given** 用户启动 Curator 时没有网络连接（FR50）
**When** 应用完成启动流程
**Then** 应用正常启动并展示上次缓存的照片数据
**And** 状态栏显示离线指示器（FR51）

**Given** 应用正在离线状态运行（FR52）
**When** 用户执行仅依赖本地资源的操作
**Then** 本地去重（pHash 计算）、图库浏览、已完成的审核操作可正常使用
**And** 需要网络的功能（LLM 分析）被标记为不可用

**Given** 用户在离线状态尝试使用 LLM 功能
**When** 点击需要网络的功能按钮
**Then** 界面展示离线空状态提示（UX-DR15），说明需要网络连接
**And** 网络恢复时离线指示器自动消失

### Story 7.5: Sparkle 自动更新

As a 用户，
I want Curator 自动检查并安装更新，
So that 我始终使用最新版本。

**Acceptance Criteria:**

**Given** Sparkle 2 已集成（FR49）
**When** 应用启动后或在每日例行检查时（NFR22）
**Then** SparkleManager 检查服务器上是否有新版本
**And** 检查过程在后台静默进行，不干扰用户操作

**Given** Sparkle 发现了新版本
**When** Agent 正在执行活跃任务
**Then** 更新通知延迟展示，不中断正在进行的 Agent 任务（NFR22）
**And** Agent 任务完成后提示用户更新

**Given** 用户收到更新通知
**When** 确认安装更新
**Then** Sparkle 自动下载、验证并安装更新
**And** 用户也可通过菜单手动触发"检查更新"

### Story 7.6: 无障碍合规

As a 视障或行动不便的用户，
I want Curator 完全支持 macOS 无障碍功能，
So that 我能高效地使用所有功能。

**Acceptance Criteria:**

**Given** 用户启用 VoiceOver（UX-DR14）
**When** 浏览 Curator 的所有自定义界面组件
**Then** 所有自定义控件具有 accessibilityLabel、accessibilityValue、accessibilityHint
**And** Agent 状态更新通过 AccessibilityNotification.announcement 进行语音播报

**Given** 用户仅使用键盘操作
**When** 在审核界面中导航
**Then** Tab 键在可交互元素间切换，Enter 确认操作，Esc 取消，⌘Z 撤销
**And** 焦点顺序符合逻辑

**Given** 用户启用了系统"动态字体"或"减弱动态效果"
**When** 使用 Curator 界面
**Then** 界面文字大小跟随系统动态字体设置缩放
**And** 动画在"减弱动态效果"模式下被简化或移除
**And** 所有文本与背景对比度达到 WCAG AA 标准（4.5:1）
