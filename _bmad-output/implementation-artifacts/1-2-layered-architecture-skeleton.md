# Story 1.2: 分层架构骨架

Status: done

## Story

As a 开发者，
I want 建立分层架构的基础类型和错误体系，
So that 后续功能模块可以遵循一致的架构模式开发。

## Acceptance Criteria

1. **AC1: 错误类型体系**
   **Given** Core/Errors/ 目录已创建
   **When** 检查错误类型定义
   **Then** DomainError、InfrastructureError、UserFacingError 枚举已定义，符合架构文档
   **And** 错误映射规则：Infrastructure 错误可转换为 Domain 错误

2. **AC2: 领域模型**
   **Given** Core/Models/ 目录已创建
   **When** 检查领域模型
   **Then** PhotoAsset、AssetMetadata 值类型已定义（Sendable），包含日期、标题、描述、关键词、位置字段
   **And** LoadingState<T> 枚举已定义（idle/loading/loaded/failed）

3. **AC3: 依赖注入容器**
   **Given** App/AppDependencies.swift 已创建
   **When** 检查依赖注入容器
   **Then** AppDependencies 提供协议到具体实现的绑定
   **And** 支持测试时替换为 mock 实现

## Tasks / Subtasks

- [x] Task 1: 实现错误类型体系 (AC: #1)
  - [x] 1.1 创建 `Curator/Core/Errors/DomainError.swift` — 领域层错误枚举
  - [x] 1.2 创建 `Curator/Core/Errors/InfrastructureError.swift` — 基础设施层错误枚举
  - [x] 1.3 创建 `Curator/Core/Errors/UserFacingError.swift` — 用户可见错误枚举
  - [x] 1.4 创建 `Curator/Core/Errors/ErrorMapping.swift` — 跨层错误映射扩展

- [x] Task 2: 实现核心领域模型 (AC: #2)
  - [x] 2.1 创建 `Curator/Core/Models/PhotoAsset.swift` — 照片资产值类型（Sendable）
  - [x] 2.2 创建 `Curator/Core/Models/AssetMetadata.swift` — 元数据值类型（Sendable）
  - [x] 2.3 创建 `Curator/Core/Models/LoadingState.swift` — 泛型加载状态枚举
  - [x] 2.4 删除 Core/Models/.gitkeep 和 Core/Errors/.gitkeep（已有实际代码文件）

- [x] Task 3: 实现依赖注入容器 (AC: #3)
  - [x] 3.1 重写 `Curator/App/AppDependencies.swift` — 依赖注入容器
  - [x] 3.2 定义 PhotoLibraryRepository 协议（在 Domain 层）
  - [x] 3.3 定义 LLMProvider 协议（在 Domain 层）
  - [x] 3.4 在 AppDependencies 中注册协议→实现的绑定关系

- [x] Task 4: 补充 Core 层扩展和辅助类型
  - [x] 4.1 创建 `Curator/Core/Extensions/LoadableState.swift` — 从 LoadingState 派生的 View 扩展
  - [x] 4.2 创建 `Curator/Core/Models/AssetID.swift` — 照片资产唯一标识符类型

- [x] Task 5: 验证和收尾 (AC: #1, #2, #3)
  - [x] 5.1 完整构建验证：`xcodebuild build` 成功
  - [x] 5.2 确认所有类型符合 Swift 6 strict concurrency（Sendable）
  - [x] 5.3 确认目录结构与架构文档一致
  - [x] 5.4 运行现有测试确认无回归

## Dev Notes

### 架构约束

本项目采用分层架构（Presentation -> Application -> Domain -> Infrastructure），本 Story 建立 Domain 层和 Application 层的核心骨架。严格遵守以下规则：

1. **层级边界**：Domain 层不依赖任何其他层。协议定义在 Domain 层，具体实现在 Infrastructure 层。
2. **Swift 6 strict concurrency**：所有跨并发域传递的类型必须实现 `Sendable`。使用值类型（struct）而非引用类型（class）作为领域模型。
3. **避免命名冲突**：不使用 `Task` 作为类型名（与 Swift Concurrency 冲突）。[CLAUDE.md 约定]

### Story 1.1 遗留上下文

Story 1.1 已完成以下工作（文件已存在）：
- `Curator/App/AppDependencies.swift` — 当前为占位文件（将在此 Story 中重写）
- `Curator/App/AppDelegate.swift` — 当前为占位文件（保持不变）
- `Curator/App/NavigationModel.swift` — 当前为占位文件（保持不变）
- `Curator/Core/Errors/.gitkeep` — 空目录占位（实现后删除）
- `Curator/Core/Models/.gitkeep` — 空目录占位（实现后删除）
- `Curator/Core/Extensions/.gitkeep` — 空目录占位
- 项目使用 xcodegen（project.yml）管理 Xcode 配置
- OpenAgentSDKSwift 当前为本地 Package stub（`Packages/OpenAgentSDKSwift/`）
- 测试使用 `CuratorTestsHost.entitlements`（无沙盒）避免测试运行器崩溃

**Story 1.1 关键教训**：
- xcodegen 会覆盖 entitlements 设置，需在 target 级别而非 global 设置中配置
- 测试 target 需要独立的 entitlements 文件（无沙盒）
- `Bundle.main.bundleURL` 在测试中无法导航到源码根目录，Info.plist 中嵌入了 `$(SRCROOT)`

### 错误类型体系设计

根据架构文档 [Source: architecture.md#决策9]，错误体系包含三层：

**DomainError**（领域层）：
```swift
enum DomainError: Error {
    case assetNotFound(AssetID)
    case analysisFailed(reason: String)
    case insufficientPermission(required: PermissionLevel)
    case operationCancelled
    case invalidState(reason: String)
}
```

**InfrastructureError**（基础设施层）：
```swift
enum InfrastructureError: Error {
    case photoKitAccessDenied
    case photoKitFetchFailed(reason: String)
    case llmProviderUnavailable(provider: String)
    case llmProviderError(provider: String, statusCode: Int, message: String)
    case networkError(underlying: Error)
    case rateLimitExceeded(provider: String, retryAfter: TimeInterval)
    case keychainError(status: OSStatus)
    case cacheError(reason: String)
}
```

**UserFacingError**（展示层）：
```swift
enum UserFacingError {
    case readOnly(title: String, message: String)
    case retryable(title: String, message: String)
    case permissionRequired(title: String, action: String)
}
```

**错误映射规则**（ErrorMapping.swift）：
- `InfrastructureError` -> `DomainError` 转换（基础设施错误映射为领域错误向上传播）
- `DomainError` -> `UserFacingError` 转换（领域错误映射为用户可理解的提示）
- Infrastructure 层错误必须映射为 Domain 层错误再向上传播
- 永不向用户展示技术性错误消息（如 "PHImageErrorDomain"）

### 领域模型设计

**PhotoAsset**（照片资产值类型）：
```swift
struct PhotoAsset: Sendable, Identifiable {
    let id: AssetID
    let metadata: AssetMetadata
    let thumbnailData: Data?  // 缩略图可选，按需加载
}
```

**AssetMetadata**（元数据值类型）：
```swift
struct AssetMetadata: Sendable {
    let creationDate: Date?
    let title: String?
    let description: String?
    let keywords: [String]
    let location: LocationData?
}
```

**AssetID**（唯一标识符）：
```swift
struct AssetID: Sendable, Hashable, Codable {
    let rawValue: String  // PHAsset.localIdentifier 的封装
}
```

**LocationData**（位置数据）：
```swift
struct LocationData: Sendable {
    let latitude: Double
    let longitude: Double
}
```

**LoadingState<T>**（泛型加载状态）：
```swift
enum LoadingState<T> {
    case idle
    case loading
    case loaded(T)
    case failed(DomainError)
}
```

### 依赖注入容器设计

AppDependencies 是应用层的依赖注入容器，负责将 Domain 层协议绑定到 Infrastructure 层的具体实现。本 Story 只定义协议和容器结构，具体实现在后续 Story 中注册。

**关键协议定义**（本 Story 中定义协议，Infrastructure 实现在后续 Story）：

```swift
// PhotoLibraryRepository — 在 Core/Models/ 或 Core/ 中定义
protocol PhotoLibraryRepository: Sendable {
    func requestReadAccess() async throws -> Bool
    func requestWriteAccess() async throws -> Bool
    func fetchAssets(predicate: PhotoPredicate, pageSize: Int) async throws -> AssetPage
    func fetchFullResolutionImage(for assetID: AssetID) async throws -> Data
}

// LLMProvider — 在 Core/Models/ 或 Core/ 中定义
protocol LLMProvider: Sendable {
    var name: String { get }
    func analyze(images: [Data], prompt: String) async throws -> LLMResponse
    func estimateCost(imageCount: Int, model: String) -> CostEstimate
}
```

**注意**：由于具体 Infrastructure 实现尚未在后续 Story 中创建，AppDependencies 中的注册方法是声明式的（方法签名存在，但暂时不包含具体绑定）。支持测试时替换为 mock 实现：

```swift
@MainActor
final class AppDependencies: ObservableObject {
    // 协议属性，可替换为 mock
    var photoRepository: PhotoLibraryRepository?
    var llmProvider: LLMProvider?
}
```

### 项目结构参考

本 Story 需创建/修改的文件：

```
Curator/
├── App/
│   ├── AppDependencies.swift    # 重写：依赖注入容器
│   ├── AppDelegate.swift        # 保持不变
│   └── NavigationModel.swift    # 保持不变
├── Core/
│   ├── Agent/                   # 保持 .gitkeep（Story 3.x 实现）
│   ├── Operations/              # 保持 .gitkeep（Story 4.x 实现）
│   ├── Models/
│   │   ├── PhotoAsset.swift     # 新建：照片资产值类型
│   │   ├── AssetMetadata.swift  # 新建：元数据值类型
│   │   ├── AssetID.swift        # 新建：资产 ID 类型
│   │   ├── LoadingState.swift   # 新建：泛型加载状态
│   │   └── LocationData.swift   # 新建：位置数据（含在 AssetMetadata.swift 或独立文件）
│   ├── Errors/
│   │   ├── DomainError.swift        # 新建：领域错误
│   │   ├── InfrastructureError.swift # 新建：基础设施错误
│   │   ├── UserFacingError.swift    # 新建：用户可见错误
│   │   └── ErrorMapping.swift       # 新建：跨层错误映射
│   └── Extensions/
│       └── LoadableState.swift      # 新建：LoadingState SwiftUI 扩展
```

### 技术要求

- **Swift 6 strict concurrency**：所有值类型标记 `Sendable`，枚举关联值也必须 `Sendable`
- **文件命名**：类型名即文件名（`DomainError.swift`、`PhotoAsset.swift`）
- **访问控制**：internal（默认）即可，公开类型按需标记 `public`
- **不引入新依赖**：本 Story 仅使用 Swift 标准库和 Foundation
- **构建通过**：`xcodebuild build -scheme Curator -destination 'platform=macOS,arch=arm64'` 必须成功
- **无回归**：Story 1.1 的 5 个 ATDD 测试必须仍然通过

### 文件组织决策

- 协议定义放在 Domain 层（Core/Models/ 或独立协议文件），不在 Infrastructure 层
- `PhotoLibraryRepository` 协议和 `LLMProvider` 协议暂时放在 Core/Models/（因为它们描述领域概念），后续可移至独立目录
- `LocationData` 可包含在 `AssetMetadata.swift` 中（小型辅助类型），或独立文件
- `CostEstimate` 和 `LLMResponse` 等辅助类型本 Story 暂不定义，留到对应 Epic（Epic 2 LLM Gateway）时创建

### Project Structure Notes

- 目录结构严格遵循架构文档的 Feature-based 组织 [Source: architecture.md#完整项目目录结构]
- Core/Errors/ 和 Core/Models/ 已有 .gitkeep 占位，实现后删除
- 新增文件需要通过 xcodegen 自动发现（project.yml 的 `sources: - Curator` 已配置递归发现）
- 测试 target 镜像源码结构：CuratorTests/Core/Errors/、CuratorTests/Core/Models/

### References

- [Source: _bmad-output/planning-artifacts/architecture.md#决策1] — 分层架构 + 依赖注入
- [Source: _bmad-output/planning-artifacts/architecture.md#决策9] — 错误处理模式
- [Source: _bmad-output/planning-artifacts/architecture.md#决策3] — PhotoKit Repository 协议定义
- [Source: _bmad-output/planning-artifacts/architecture.md#决策4] — LLM Provider 协议定义
- [Source: _bmad-output/planning-artifacts/architecture.md#决策6] — 状态管理（LoadingState）
- [Source: _bmad-output/planning-artifacts/architecture.md#命名模式] — Swift 类型命名规范
- [Source: _bmad-output/planning-artifacts/architecture.md#通信模式] — AgentEvent 和 AsyncStream
- [Source: _bmad-output/planning-artifacts/architecture.md#强制执行指南] — 所有 AI Agent 必须遵循
- [Source: _bmad-output/planning-artifacts/epics.md#Story 1.2] — 原始需求定义
- [Source: _bmad-output/implementation-artifacts/1-1-project-init-and-build-config.md] — Story 1.1 完成记录和教训
- [Source: CLAUDE.md#Swift Conventions] — 避免命名类型为 Task

## ATDD Artifacts

- Checklist: `_bmad-output/test-artifacts/atdd-checklist-1-2-layered-architecture-skeleton.md`
- Error type tests: `CuratorTests/Core/Errors/ErrorTypeTests.swift`
- Core model tests: `CuratorTests/Core/Models/CoreModelsTests.swift`
- DI container tests: `CuratorTests/DependencyInjectionTests.swift`

## Dev Agent Record

### Agent Model Used

GLM-5.1

### Debug Log References

- Fixed `LoadingState<T>` Sendable conformance by adding `T: Sendable` constraint
- Fixed `DependencyInjectionTests.testReplacedMockPhotoRepoIsCallable` — `XCTUnwrap` autoclosure does not support `async` calls; extracted async call to separate let binding
- Fixed `CoreModelsTests.testAssetMetadataExistsWithAllFields` — `XCTEqual` with `accuracy:` parameter requires non-optional `Double`; removed accuracy overload

### Completion Notes List

- All 3 acceptance criteria satisfied: error type system (AC1), domain models (AC2), dependency injection container (AC3)
- 14 new source files created across Core/Errors/, Core/Models/, Core/Extensions/, and App/
- 2 ATDD test files fixed for Swift 6 strict concurrency compilation
- 48 tests pass (5 existing + 43 new), 0 failures, 0 regressions
- All types conform to Sendable for Swift 6 strict concurrency
- Build succeeds with `xcodebuild build`
- .gitkeep files removed from Core/Errors/ and Core/Models/

### File List

**New files:**
- Curator/Core/Errors/DomainError.swift
- Curator/Core/Errors/InfrastructureError.swift
- Curator/Core/Errors/UserFacingError.swift
- Curator/Core/Errors/ErrorMapping.swift
- Curator/Core/Errors/PermissionLevel.swift
- Curator/Core/Models/AssetID.swift
- Curator/Core/Models/AssetMetadata.swift
- Curator/Core/Models/PhotoAsset.swift
- Curator/Core/Models/LoadingState.swift
- Curator/Core/Models/PhotoLibraryRepository.swift
- Curator/Core/Models/LLMProvider.swift
- Curator/Core/Models/PhotoPredicate.swift
- Curator/Core/Models/AssetPage.swift
- Curator/Core/Models/LLMResponse.swift
- Curator/Core/Models/CostEstimate.swift
- Curator/Core/Extensions/LoadableState.swift

**Modified files:**
- Curator/App/AppDependencies.swift (rewritten from placeholder to DI container)
- CuratorTests/Core/Models/CoreModelsTests.swift (fixed Double? accuracy assertion)
- CuratorTests/DependencyInjectionTests.swift (fixed async in autoclosure)
- Curator.xcodeproj/project.pbxproj (regenerated by xcodegen)

**Deleted files:**
- Curator/Core/Errors/.gitkeep
- Curator/Core/Models/.gitkeep

### Review Findings

- [x] [Review][Patch] AppDependencies properties not @Published — SwiftUI views will not react when photoRepository or llmProvider change from nil to a concrete implementation. Add @Published to both properties in `Curator/App/AppDependencies.swift:14,18`. -- FIXED
- [x] [Review][Patch] Dead code in testReplacedMockPhotoRepoIsCallable — First AppDependencies instance (lines 435-437) is created and set but never used. Remove dead code in `CuratorTests/DependencyInjectionTests.swift:435-437`. -- FIXED
- [x] [Review][Defer] `networkError(underlying: any Error)` Sendable soundness — deferred, pre-existing; Swift's Error/Sendable model limitation
- [x] [Review][Defer] Uses ObservableObject instead of @Observable — deferred, DI container uses ObservableObject intentionally; @Observable pattern for ViewModels only
- [x] [Review][Defer] LoadableState.swift file naming convention — deferred, matches story spec; follow-up rename to View+Loadable.swift
- [x] [Review][Defer] Error mapping discards InfrastructureError associated values — deferred, matches architecture doc Decision 9; extend when Stories 2.x/3.x need richer context
- [x] [Review][Defer] Protocols in Core/Models/ directory — deferred, acknowledged temporary placement in story notes
