---
project_name: 'Curator'
user_name: 'Nick'
date: '2026-04-18'
sections_completed:
  ['technology_stack', 'implementation_rules', 'code_patterns', 'testing_rules', 'architecture_boundaries', 'usage_guidelines']
status: 'complete'
rule_count: 30
optimized_for_llm: true
---

# Project Context for AI Agents

_Curator — AI 驱动的 macOS 照片管理代理。本文档包含 AI Agent 实现代码时必须遵循的关键规则和模式。_

---

## Technology Stack & Versions

| 技术 | 版本 | 备注 |
|------|------|------|
| Swift | 6.0 | `SWIFT_STRICT_CONCURRENCY: complete` — 所有跨并发域类型必须 `Sendable` |
| macOS Deployment Target | 15.0 (Sequoia) | 仅 Apple Silicon (arm64) |
| SwiftUI | macOS 15 内置 | 主体 UI 框架 |
| AppKit | macOS 15 内置 | 系统集成互操作 |
| OpenAgentSDKSwift | main branch (SPM) | Agent 基础设施 — 循环、工具执行、会话、流式传输 |
| Sparkle | 2.0.0+ (SPM) | 自动更新框架 |
| XcodeGen | CLI tool | 从 `project.yml` 生成 `.xcodeproj` |
| XCTest | Xcode 内置 | 单元测试 + UI 测试 |
| CI | GitHub Actions | `macos-15` runner, xcodegen + xcodebuild |

**项目生成命令：**
```bash
xcodegen generate   # 从 project.yml 生成 Xcode 项目
xcodebuild build -project Curator.xcodeproj -scheme Curator -destination 'platform=macOS,arch=arm64'
xcodebuild test -project Curator.xcodeproj -scheme Curator -destination 'platform=macOS,arch=arm64' -enableCodeCoverage YES -only-testing:CuratorTests
```

---

## Critical Implementation Rules

### 1. Swift 6 严格并发 — 必须遵守

- **所有跨并发域的类型必须 `Sendable`**：模型（struct）、错误（enum）、事件（enum）
- **Service 用 `actor` 隔离**：PhotoKit 操作、LLM 网关、操作管理器
- **ViewModel 用 `@MainActor`**：所有 UI 状态更新必须在主线程
- **永不从后台线程直接更新 UI**：通过 `@MainActor` 标记 ViewModel
- **跨层数据传递只用值类型**：`struct` + `Sendable`，不用 class

```swift
// 正确：Sendable 值类型
struct PhotoAsset: Sendable, Identifiable { ... }
enum DomainError: Error, Sendable { ... }
protocol PhotoLibraryRepository: Sendable { ... }

// 正确：Actor 隔离的 Service
actor PhotoKitRepository: PhotoLibraryRepository { ... }

// 正确：@MainActor ViewModel
@MainActor
final class SomeViewModel: ObservableObject { ... }
```

### 2. 禁止使用 `Task` 作为类型名

与 Swift Concurrency 的 `Task` 冲突。使用 `AgentJob`、`AgentWork` 等项目特定前缀。

### 3. 三层错误体系

错误必须按以下链路映射，不可跳层：

```
InfrastructureError → DomainError → UserFacingError
```

- **InfrastructureError**：PhotoKit、网络、Keychain、缓存等技术错误
- **DomainError**：业务规则错误（资产未找到、权限不足等）
- **UserFacingError**：用户可见错误（永不暴露技术细节）

```swift
// 映射方法已定义：
InfrastructureError.toDomainError() -> DomainError
DomainError.toUserFacingError() -> UserFacingError
```

**规则：**
- Infrastructure 层错误必须映射为 DomainError 再向上传播
- 永不向用户展示 HTTP 状态码、错误域等技术信息
- 所有 `throws` 函数在调用处必须有 `do/catch` 或 `try?`

### 4. 分层架构 — 严格边界

```
Presentation (Views/ViewModels)
    ↓ 可调用
Application Layer (Agent 编排、操作管理)
    ↓ 可调用
Domain Layer (业务模型、协议)
    ↑ 实现
Infrastructure Layer (PhotoKit、LLM、Storage)
```

**禁止：**
- Presentation 层直接调用 Infrastructure 层
- Domain 层依赖任何其他层
- 在代码中硬编码 API Key 或敏感信息

### 5. 协议在 Domain 层定义，实现在 Infrastructure 层

```swift
// Domain 层：协议定义
protocol PhotoLibraryRepository: Sendable { ... }
protocol LLMProvider: Sendable { ... }

// Infrastructure 层：具体实现
actor PhotoKitRepository: PhotoLibraryRepository { ... }
class AnthropicProvider: LLMProvider { ... }
```

### 6. 依赖注入通过 AppDependencies

```swift
@MainActor
final class AppDependencies: ObservableObject {
    @Published var photoRepository: (any PhotoLibraryRepository)?
    @Published var llmProvider: (any LLMProvider)?
}
```

测试时替换为 mock 实现。协议属性为 `optional`，启动时注册。

### 7. 破坏性操作必须通过 OperationManager

- 每次批量操作前创建元数据快照
- 支持整批回滚（5 秒内完成）
- 回滚操作本身也可回滚

---

## Code Patterns

### 命名规范

| 类别 | 规则 | 示例 |
|------|------|------|
| 类型名 | UpperCamelCase | `PhotoAsset`, `AgentJob`, `LLMGateway` |
| 协议名 | 名词或 "able" 后缀 | `PhotoLibraryRepository`, `LLMProvider` |
| 文件名 | 与类型名一致 | `PhotoAsset.swift`, `DomainError.swift` |
| 函数名 | lowerCamelCase | `fetchAssets()`, `requestReadAccess()` |
| 变量名 | lowerCamelCase | `assetCount`, `isProcessing` |
| 布尔变量 | is/has/should 前缀 | `isProcessing`, `hasWritePermission` |
| 枚举 case | lowerCamelCase | `.assetNotFound`, `.stepCompleted` |
| 扩展文件 | Type+Feature 格式 | `View+LoadableState.swift` |

### 文档注释规范

- 所有类型和协议必须有 `///` 文档注释
- 注释说明 WHY（设计原因），不说明 WHAT（代码已表达）
- Placeholder 文件注明将实现的 Story 编号

```swift
/// User-visible errors for presentation in the UI layer.
///
/// These errors never expose technical details (HTTP codes, error domains, etc.).
/// They are produced by mapping DomainError through `toUserFacingError()`.
enum UserFacingError: Sendable { ... }
```

### 模型定义模式

所有领域模型遵循以下模式：

```swift
// 1. import Foundation（不导入多余框架）
import Foundation

// 2. Sendable 值类型 struct
struct AssetID: Sendable, Hashable, Codable {
    let rawValue: String
}

// 3. 泛型枚举带 Sendable 约束
enum LoadingState<T: Sendable>: Sendable {
    case idle
    case loading
    case loaded(T)
    case failed(DomainError)
}
```

### SwiftUI 视图模式

```swift
// Preview 同时覆盖亮色/暗色模式
#Preview {
    ContentView()
}

// 视图不超过 200 行，复杂视图拆分子视图
// 使用 View extension 减少重复代码
extension View {
    @ViewBuilder
    func loadable<T, Content: View>(
        _ state: LoadingState<T>,
        idle: @escaping () -> Content,
        loading: @escaping () -> Content,
        loaded: @escaping (T) -> Content,
        failed: @escaping (DomainError) -> Content
    ) -> some View { ... }
}
```

---

## Testing Rules

### 测试结构

```swift
import XCTest
@testable import Curator

/// ATDD Tests for Story X.Y - AC描述
///
/// Tests verify:
/// - 验证项1
/// - 验证项2
final class SomeTests: XCTestCase {

    // MARK: - AC1: 验收标准描述

    /// [P0] 优先级标记 + 简短描述
    func testSomething() throws { ... }

    /// [P1] 次要优先级测试
    func testSomethingElse() async throws { ... }
}
```

### 测试约定

- **ATDD 风格**：每个测试关联 Story 和验收标准（AC）
- **优先级标记**：`[P0]`（关键）和 `[P1]`（重要）写在测试注释中
- **中文注释**：测试类注释和断言消息使用中文
- **MARK 分区**：用 `// MARK: - AC1: 描述` 组织测试方法
- **Mock 实现**：定义为测试文件内的 `private struct`，实现协议方法返回 stub 数据
- **测试类**：`final class` + `XCTestCase`
- **运行完整测试套件**：每次改动后运行并报告总数

### Mock 模式

```swift
private struct MockPhotoLibraryRepository: PhotoLibraryRepository {
    func requestReadAccess() async throws -> Bool { return true }
    func requestWriteAccess() async throws -> Bool { return true }
    func fetchAssets(predicate: PhotoPredicate, pageSize: Int) async throws -> AssetPage {
        return AssetPage(assets: [], hasMore: false)
    }
    func fetchFullResolutionImage(for assetID: AssetID) async throws -> Data {
        return Data()
    }
}
```

### UI 测试约定

- **目录**：`CuratorUITests/`，文件命名 `XxxUITests.swift`
- **基类**：所有 UI 测试继承 `CuratorUITestBase`
- **Happy-path 必须覆盖**：每个 Story 开发完成后必须补充至少一条 happy-path UI 测试
- **元素查询**：使用 `accessibilityLabel` 查找元素，不依赖原始文本
- **状态重置**：通过 launch arguments 控制应用状态（如 `--uitest-reset-onboarding`）
- **环境依赖跳过**：权限不可用时使用 `throw XCTSkip()` 优雅跳过，不标记为失败
- **运行 UI 测试**：`xcodebuild test -only-testing:CuratorUITests`

```swift
// UI 测试结构示例
final class SomeFeatureUITests: CuratorUITestBase {
    override func setUp() {
        super.setUp()
        launchApp(resetOnboarding: false)  // 或 true，取决于测试场景
    }

    func testHappyPath() throws {
        guard somePrecondition else {
            throw XCTSkip("前置条件不满足")
        }
        // 测试逻辑
    }
}
```

### 构建验证测试

项目包含 ATDD 测试验证项目结构：
- `DirectoryStructureTests` — 验证 feature-based 目录存在
- `EntitlementsTests` — 验证沙盒和权限配置
- `BuildConfigurationTests` — 验证部署目标和架构
- `SPMDependencyTests` — 验证 SPM 依赖解析

---

## Architecture Boundaries

### 目录结构映射

```
Curator/
├── App/                    → Application 层（依赖注入、导航）
├── Core/
│   ├── Agent/              → Agent 引擎（状态机、事件、步骤）
│   ├── Operations/         → 操作管理（快照、回滚）
│   ├── Models/             → 领域模型 + Repository 协议
│   ├── Errors/             → 三层错误定义 + 映射
│   └── Extensions/         → Swift 扩展（LoadableState 等）
├── Features/               → Presentation 层（每个功能一个目录）
│   ├── ChatInput/
│   ├── AgentExecution/
│   ├── Deduplication/
│   ├── Rename/
│   ├── PhotoLibrary/
│   ├── Settings/
│   ├── Onboarding/
│   └── ResultSummary/
├── Infrastructure/          → Infrastructure 层
│   ├── PhotoKit/           → PhotoKit 集成（actor 隔离）
│   ├── LLM/                → LLM 网关（actor 隔离、多 Provider）
│   ├── Analysis/           → 图像分析（pHash、管线）
│   ├── Storage/            → 数据持久化（缓存、Keychain、SwiftData）
│   ├── SDKTools/           → OpenAgentSDKSwift 工具注册
│   └── Update/             → Sparkle 自动更新
└── Resources/              → Assets、本地化
```

### 测试目录镜像源码

```
CuratorTests/
├── Core/
│   ├── Errors/             → ErrorTypeTests
│   └── Models/             → CoreModelsTests
├── DirectoryStructureTests
├── EntitlementsTests
├── BuildConfigurationTests
├── SPMDependencyTests
└── DependencyInjectionTests
```

### Entitlements（沙盒应用）

```xml
com.apple.security.app-sandbox                    → 沙盒模式
com.apple.security.personal-information.photos    → PhotoKit 访问
com.apple.security.network.client                 → LLM API 网络请求
com.apple.security.keychain                       → API Key 安全存储
```

---

## AI Agent 执行清单

实现代码时逐条检查：

- [ ] 类型是否 `Sendable`？（Swift 6 严格并发要求）
- [ ] 是否避免使用 `Task` 作为类型名？（用 `AgentJob` 替代）
- [ ] I/O 操作是否在 `actor` 或 `Task` 中执行？（不在 `@MainActor` 上）
- [ ] 破坏性操作是否通过 `OperationManager` 创建快照？
- [ ] API 调用是否通过 `LLMGateway`？（不直接调用供应商 API）
- [ ] 错误是否按三层链路映射？（Infra → Domain → UserFacing）
- [ ] 用户可见消息是否不含技术细节？
- [ ] 协议是否定义在 Domain 层？
- [ ] 跨层数据是否使用值类型（struct + Sendable）？
- [ ] 是否有对应的 ATDD 测试？
- [ ] 是否有对应的 UI 测试 happy-path 覆盖？
- [ ] 故事涉及 macOS UI 时，实现前是否已参考 /macos-design-guidelines 中的 HIG 规范？

---

## Usage Guidelines

**For AI Agents:**
- 实现代码前先阅读本文档
- 严格遵守所有规则
- 有疑问时选择更严格的选项
- 发现新模式时更新本文档

**For Humans:**
- 保持文档精简，聚焦 Agent 需求
- 技术栈变更时更新
- 季度审查过时规则
- 移除已成为常识的规则

Last Updated: 2026-04-19
