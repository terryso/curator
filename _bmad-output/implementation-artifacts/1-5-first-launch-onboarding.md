# Story 1.5: 首次启动引导流程

Status: review

## Story

As a 新用户，
I want 通过简洁的引导流程了解 Curator 并授权照片访问，
So that 我可以快速开始使用应用。

## Acceptance Criteria

1. **AC1: 欢迎引导流程（最多 3 屏）**
   **Given** 用户首次打开 Curator（UX-DR8）
   **When** 进入引导流程
   **Then** 展示最多 3 屏：产品介绍、隐私说明、照片权限请求
   **And** 隐私说明包含"照片仅在会话中分析，发送到 LLM API 用于理解"
   **And** 每屏有"下一步"/"上一步"导航，最后一屏触发权限请求

2. **AC2: 权限授予与照片扫描**
   **Given** 用户授予照片读取权限
   **When** 权限授予成功
   **Then** 扫描照片库元数据，展示照片数量摘要（如"已发现 15,320 张照片"）
   **And** 进入主界面时输入框 placeholder 展示示例指令（UX-DR15）

3. **AC3: 权限拒绝降级处理**
   **Given** 用户拒绝照片权限（UX-DR9）
   **When** 权限被拒绝
   **Then** 展示只读模式说明和引导至系统设置的按钮
   **And** 应用仍可启动，但照片功能不可用

## Tasks / Subtasks

- [x] Task 1: 创建 OnboardingViewModel (AC: #1, #2, #3)
  - [x] 1.1 创建 `Curator/Features/Onboarding/OnboardingViewModel.swift` — @MainActor ObservableObject
  - [x] 1.2 定义 OnboardingStep 枚举：welcome / privacy / permission / scanning / complete / denied
  - [x] 1.3 管理 currentStep: OnboardingStep 状态和 isOnboardingComplete: Bool
  - [x] 1.4 实现 requestPhotoPermission() — 调用 photoRepository.requestReadAccess()
  - [x] 1.5 实现 scanLibrary() — 权限成功后调用 photoRepository.fetchAssets 获取照片数量
  - [x] 1.6 通过 init 注入 PhotoLibraryRepository? 协议（与 PhotoLibraryViewModel 一致）
  - [x] 1.7 处理权限拒绝状态 — 设置 currentStep = .denied，展示降级 UI

- [x] Task 2: 创建 WelcomeView (AC: #1)
  - [x] 2.1 创建 `Curator/Features/Onboarding/WelcomeView.swift` — 第一屏：产品介绍
  - [x] 2.2 展示应用名称"Curator"、图标、简短介绍（"AI 驱动的照片管理助手"）
  - [x] 2.3 底部"下一步"按钮（主要样式，UX-DR17），点击前进到 privacy 步骤
  - [x] 2.4 遵循 macOS 原生视觉语言，使用系统背景色，自适应亮色/暗色模式

- [x] Task 3: 创建 PrivacyExplanationView (AC: #1)
  - [x] 3.1 创建 `Curator/Features/Onboarding/PrivacyExplanationView.swift` — 第二屏：隐私说明
  - [x] 3.2 展示隐私要点："照片仅在会话中分析"、"发送到 LLM API 用于理解照片内容"、"不会上传存储到任何服务器"
  - [x] 3.3 底部"下一步"/"上一步"按钮组合
  - [x] 3.4 添加 SF Symbol 图标增强可读性（lock.shield、eye.slash 等）

- [x] Task 4: 创建 PermissionRequestView (AC: #1, #2, #3)
  - [x] 4.1 创建 `Curator/Features/Onboarding/PermissionRequestView.swift` — 第三屏：权限请求
  - [x] 4.2 展示权限说明文字和"授权照片访问"按钮（主要样式）
  - [x] 4.3 点击后调用 viewModel.requestPhotoPermission()
  - [x] 4.4 授权成功 → 进入扫描动画 + 照片数量摘要 → 完成
  - [x] 4.5 授权失败 → 进入 PermissionDeniedView 降级状态

- [x] Task 5: 创建 LibraryScanView 和 PermissionDeniedView (AC: #2, #3)
  - [x] 5.1 创建 `Curator/Features/Onboarding/LibraryScanView.swift` — 扫描中/扫描完成展示
  - [x] 5.2 扫描中：ProgressView + "正在扫描照片库..." 文字
  - [x] 5.3 扫描完成：展示照片数量摘要（如"已发现 15,320 张照片"）+ "开始使用"按钮
  - [x] 5.4 创建 `Curator/Features/Onboarding/PermissionDeniedView.swift` — 权限拒绝降级
  - [x] 5.5 展示说明文字："无法访问照片图库" + 引导至系统设置的按钮
  - [x] 5.6 "继续（功能受限）"按钮（次要样式）允许用户跳过

- [x] Task 6: 创建 OnboardingContainerView (AC: #1)
  - [x] 6.1 创建 `Curator/Features/Onboarding/OnboardingContainerView.swift` — 引导流程容器
  - [x] 6.2 根据 viewModel.currentStep 切换显示对应的子视图
  - [x] 6.3 步骤指示器（小圆点）显示当前进度（3 个步骤）
  - [x] 6.4 完成后设置 @AppStorage("hasCompletedOnboarding") = true

- [x] Task 7: 集成到 ContentView 和 CuratorApp (AC: #1, #2)
  - [x] 7.1 修改 `Curator/ContentView.swift` — 检查 @AppStorage("hasCompletedOnboarding")
  - [x] 7.2 未完成引导 → 显示 OnboardingContainerView；已完成 → 显示 PhotoGridView
  - [x] 7.3 引导完成后平滑过渡到主界面（withAnimation）
  - [x] 7.4 CuratorApp.swift 无需修改（已有 WindowGroup + ContentView）

- [x] Task 8: ATDD 测试和验证 (AC: #1, #2, #3)
  - [x] 8.1 创建 `CuratorTests/Features/Onboarding/OnboardingViewModelTests.swift`
  - [x] 8.2 测试步骤前进/后退逻辑
  - [x] 8.3 测试权限授予成功路径
  - [x] 8.4 测试权限拒绝降级路径
  - [x] 8.5 测试 @AppStorage onboarding 完成标记
  - [x] 8.6 完整构建验证：xcodebuild build 成功
  - [x] 8.7 运行全部测试确认无回归

## Dev Notes

### 架构约束

本 Story 实现 Presentation 层的首次启动引导功能。严格遵守以下规则：

1. **分层边界**：OnboardingViewModel 通过注入的 PhotoLibraryRepository 协议请求数据，不直接调用 PhotoKitRepository 或任何 Infrastructure 层代码 [Source: architecture.md#决策1, project-context.md#Architecture Boundaries]。
2. **@MainActor ViewModel**：OnboardingViewModel 标记 @MainActor，所有 UI 状态更新在主线程 [Source: project-context.md#Critical Implementation Rules]。
3. **三层错误体系**：PhotoLibraryRepository 抛出的错误通过 DomainError → UserFacingError 映射，UI 层只展示用户友好错误消息 [Source: architecture.md#决策9, project-context.md#三层错误体系]。
4. **@AppStorage 持久化**：使用 @AppStorage("hasCompletedOnboarding") 记录引导完成状态，UserDefaults 存储满足轻量需求 [Source: architecture.md#决策5]。
5. **避免命名冲突**：不使用 `Task` 作为类型名 [Source: CLAUDE.md#Swift Conventions]。

### Story 1.4 遗留上下文

Story 1.4 已完成以下工作（文件已存在且可用）：

**ContentView.swift 当前结构：**
- 使用 `@StateObject private var dependencies = AppDependencies()` 初始化依赖
- 使用 `@StateObject private var viewModel: PhotoLibraryViewModel` 管理照片网格
- `.task { dependencies.registerPhotoKitRepository() }` 触发注册
- `.onChange(of: dependencies.photoRepository != nil)` 监听仓库就绪

**本 Story 需要修改 ContentView**，在显示 PhotoGridView 之前检查引导状态：
```swift
// ContentView 修改后大致结构
struct ContentView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @StateObject private var dependencies = AppDependencies()
    @StateObject private var viewModel: PhotoLibraryViewModel
    // ...

    var body: some View {
        if hasCompletedOnboarding {
            PhotoGridView(viewModel: viewModel)
                // 现有逻辑保持不变
        } else {
            OnboardingContainerView(dependencies: dependencies)
        }
    }
}
```

**关键点：** 引导完成时，OnboardingContainerView 设置 `hasCompletedOnboarding = true`，ContentView 通过 @AppStorage 响应变化自动切换视图。AppDependencies 的 registerPhotoKitRepository() 在引导流程中权限授予成功后调用。

### Story 1.3 遗留上下文

以下 Infrastructure 层文件可直接使用（通过协议调用）：

- `Curator/Infrastructure/PhotoKit/PhotoKitRepository.swift` — actor 实现 PhotoLibraryRepository 协议
- `Curator/Infrastructure/PhotoKit/PhotoPermissionManager.swift` — 权限管理（注意：是 struct Sendable，不是 actor）
- `Curator/Core/Models/PhotoLibraryRepository.swift` — 协议，含 requestReadAccess()、fetchAssets(predicate:pageSize:pageOffset:)

**Domain 模型（直接使用，无需修改）：**
- `Curator/Core/Models/PhotoAsset.swift` — PhotoAsset: Sendable, Identifiable
- `Curator/Core/Models/AssetPage.swift` — AssetPage: Sendable，含 assets、hasMore、nextOffset?
- `Curator/Core/Models/PhotoPredicate.swift` — 支持 .all 过滤
- `Curator/Core/Models/LoadingState.swift` — LoadingState<T: Sendable>: Sendable
- `Curator/Core/Errors/DomainError.swift` — DomainError: Error, Sendable
- `Curator/Core/Errors/UserFacingError.swift` — UserFacingError: Sendable

**DI 容器：**
- `Curator/App/AppDependencies.swift` — @MainActor ObservableObject，@Published var photoRepository: (any PhotoLibraryRepository)?

### Onboarding 流程设计要点

**步骤定义（OnboardingStep 枚举）：**
```swift
enum OnboardingStep: Int, CaseIterable {
    case welcome      // 第一屏：产品介绍
    case privacy      // 第二屏：隐私说明
    case permission   // 第三屏：权限请求
    case scanning     // 扫描中（过渡状态）
    case complete     // 扫描完成，展示摘要
    case denied       // 权限被拒绝
}
```

**UX 关键决策（来自 UX 设计规格）：**
- 欢迎画面不超过 3 屏 — 产品介绍、隐私说明、权限请求 [Source: ux-design-specification.md#Journey 1]
- 隐私说明包含"Curator 只分析照片，不会上传到任何服务器" [Source: ux-design-specification.md#Journey 1]
- 首次进入主界面时，输入框 placeholder 展示示例指令（此 AC 在后续 Story 1.6/3.3 实现，本 Story 先标记 TODO）
- UX-DR9: 权限渐进授权 — 只读默认启动，拒绝时引导至系统设置 [Source: ux-design-specification.md#Design Direction]
- UX-DR15: 空状态处理 — 无照片时友好提示 [Source: ux-design-specification.md#Feedback Patterns]

**权限请求流程：**
1. OnboardingViewModel.requestPhotoPermission() 调用 photoRepository.requestReadAccess()
2. 成功 → 调用 scanLibrary() 获取照片数量
3. scanLibrary() 调用 photoRepository.fetchAssets(predicate: .all, pageSize: 1, pageOffset: 0) 获取 AssetPage
4. 如果 hasMore == true，需要获取总数 — 当前 AssetPage 不含 totalCount，需要策略处理
5. 失败 → 设置 currentStep = .denied

**照片数量摘要策略：**

当前 PhotoLibraryRepository.fetchAssets() 返回 AssetPage，不直接提供总数。推荐方案：
- 方案 A（简单）：展示第一页的实际资产数量 + "发现更多..." 文字
- 方案 B（推荐）：获取第一页（pageSize: 100），展示 "已发现 {assets.count}+ 张照片"（如果 hasMore 为 true 加 "+" 后缀）
- 方案 C：暂不展示具体数量，直接进入主界面，由 PhotoLibraryViewModel 加载实际数据

**推荐方案 B**：既给出有意义的信息，又不依赖不存在的 API。如果后续需要精确计数，可在 PhotoKitRepository 中新增 countAssets() 方法。

### SwiftUI 视图实现模式

遵循项目已建立的 SwiftUI 视图模式 [Source: project-context.md#Code Patterns]：

1. **视图不超过 200 行** — 复杂视图拆分子视图（本 Story 每个视图页面独立）
2. **Preview 覆盖亮色/暗色模式**
3. **macOS 原生视觉语言** — 使用系统背景色、系统控件
4. **按钮层级** — 主要（实色填充）、次要（描边）、文本（无背景）[Source: ux-design-specification.md#Button Hierarchy]
5. **每界面最多一个主要按钮**

### 文件组织

本 Story 需创建/修改的文件：

```
Curator/
├── Features/
│   └── Onboarding/                            # 新建目录
│       ├── OnboardingViewModel.swift           # 新建：@MainActor ViewModel
│       ├── OnboardingContainerView.swift       # 新建：引导流程容器
│       ├── WelcomeView.swift                   # 新建：第一屏 - 产品介绍
│       ├── PrivacyExplanationView.swift        # 新建：第二屏 - 隐私说明
│       ├── PermissionRequestView.swift         # 新建：第三屏 - 权限请求
│       ├── LibraryScanView.swift               # 新建：扫描中/扫描完成
│       └── PermissionDeniedView.swift          # 新建：权限拒绝降级
├── ContentView.swift                           # 修改：添加引导状态判断

CuratorTests/
├── Features/
│   └── Onboarding/                            # 新建目录
│       └── OnboardingViewModelTests.swift     # 新建
```

### 技术要求

- **Swift 6 strict concurrency**：ViewModel 用 @MainActor，所有跨线程传递用 Sendable 值类型
- **macOS 15+ API**：可使用 @AppStorage、withAnimation、ProgressView 等最新 API
- **文件命名**：类型名即文件名
- **访问控制**：internal（默认）即可
- **不引入新依赖**：仅使用 SwiftUI 和已有的 Domain 模型
- **构建通过**：`xcodebuild build -project Curator.xcodeproj -scheme Curator -destination 'platform=macOS,arch=arm64'` 必须成功
- **无回归**：Story 1.1~1.4 的现有测试必须仍然通过
- **xcodegen 自动发现**：新增文件通过 project.yml 的 `sources: - Curator` 配置自动发现

### UX 设计规格要求

本 Story 需满足以下 UX 设计规格 [Source: _bmad-output/planning-artifacts/ux-design-specification.md]：

1. **UX-DR8: 首次启动引导流程** — 欢迎画面（<=3 屏）含产品介绍、隐私说明、权限请求
2. **UX-DR9: 权限渐进授权 UI** — 只读默认启动，拒绝时引导至系统设置
3. **UX-DR15: 空状态处理** — 无照片/权限被拒时友好提示 + 替代操作建议
4. **WCAG AA 无障碍** — VoiceOver 标签覆盖、键盘导航支持
5. **macOS 原生视觉语言** — 使用系统背景色、自适应亮色/暗色模式
6. **按钮层级** — 遵循 UX-DR17（主要/次要/文本按钮）
7. **情感设计** — 首次启动目标情绪：好奇 + 安全感；避免：压迫、数据焦虑 [Source: ux-design-specification.md#Emotional Journey Mapping]

### 引导至系统设置

权限被拒绝后，需提供引导至系统设置的按钮。macOS 方案：

```swift
// 打开系统设置 → 隐私与安全性 → 照片
if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Photos") {
    NSWorkspace.shared.open(url)
}
```

注意：沙盒应用中 NSWorkspace.shared.open(url) 可能在某些 macOS 版本受限。备选方案：
```swift
// 备选：打开系统设置主页面
if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security") {
    NSWorkspace.shared.open(url)
}
```

### 测试策略

**ATDD 测试优先级：**

- **[P0] ViewModel 步骤导航测试**：验证步骤前进/后退逻辑、状态转换
- **[P0] 权限授予成功路径**：验证 requestPhotoPermission 成功后进入扫描状态
- **[P0] 权限拒绝路径**：验证拒绝后进入 denied 状态
- **[P1] 扫描完成测试**：验证照片数量摘要展示
- **[P1] 完成标记测试**：验证 @AppStorage 正确设置

**Mock 策略**：使用 MockPhotoLibraryRepository（实现 PhotoLibraryRepository 协议），控制权限请求结果和资产返回。

```swift
private struct MockPhotoLibraryRepository: PhotoLibraryRepository {
    var shouldGrantPermission: Bool
    var assetCount: Int

    func requestReadAccess() async throws -> Bool { shouldGrantPermission }
    func requestWriteAccess() async throws -> Bool { false }
    func fetchAssets(predicate: PhotoPredicate, pageSize: Int, pageOffset: Int) async throws -> AssetPage {
        // 返回 mock 数据
    }
    func fetchFullResolutionImage(for assetID: AssetID) async throws -> Data { Data() }
}
```

### References

- [Source: _bmad-output/planning-artifacts/architecture.md#决策1] — 分层架构（Presentation → Application → Domain → Infrastructure）
- [Source: _bmad-output/planning-artifacts/architecture.md#决策5] — 数据持久化（UserDefaults/@AppStorage 用于轻量偏好）
- [Source: _bmad-output/planning-artifacts/architecture.md#决策9] — 错误处理模式（Typed Error + 分层错误传播）
- [Source: _bmad-output/planning-artifacts/epics.md#Story 1.5] — 原始需求定义（UX-DR8, UX-DR9, UX-DR15）
- [Source: _bmad-output/planning-artifacts/prd.md#隐私与数据安全] — 隐私透明度要求
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#Journey 1] — 首次启动与权限授予流程
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#Button Hierarchy] — 按钮层级系统
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#Emotional Journey Mapping] — 情感旅程设计
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#Accessibility Strategy] — WCAG AA 合规要求
- [Source: _bmad-output/implementation-artifacts/1-4-photo-library-browse-grid.md] — Story 1.4 完成记录和 ContentView 当前结构
- [Source: _bmad-output/implementation-artifacts/1-3-photokit-read-service.md] — Story 1.3 完成记录（PhotoKit 基础设施）
- [Source: _bmad-output/project-context.md#Code Patterns] — SwiftUI 视图模式（200 行限制、Preview 覆盖亮暗色）
- [Source: _bmad-output/project-context.md#Architecture Boundaries] — 目录结构映射
- [Source: CLAUDE.md#Swift Conventions] — 避免命名类型为 Task

## Dev Agent Record

### Agent Model Used

Claude (GLM-5.1)

### Debug Log References

- Build initially failed after adding new files — resolved by running `xcodegen generate` to pick up new files
- Async closure type mismatch in OnboardingContainerView — fixed by wrapping async call in Task from synchronous context

### Completion Notes List

- Task 1: Implemented OnboardingViewModel with full navigation, permission, scanning, and denied-state logic. All stub methods replaced with working implementations. Uses injected PhotoLibraryRepository protocol (no direct PhotoKit dependency).
- Task 2: Created WelcomeView with app icon (SF Symbol), name, tagline, and primary Next button. Light/Dark mode previews included.
- Task 3: Created PrivacyExplanationView with 3 privacy points (local analysis, AI understanding, never stored) using SF Symbol icons. Next/Back navigation buttons.
- Task 4: Created PermissionRequestView with loading state during permission request, Grant Photo Access primary button, and Back navigation.
- Task 5: Created LibraryScanView (scanning spinner + photo count summary with "N+" format for hasMore) and PermissionDeniedView (Open System Settings + Continue with Limited Features buttons).
- Task 6: Created OnboardingContainerView as the flow coordinator — switches sub-views based on currentStep, includes 3-dot step indicator, sets @AppStorage on completion.
- Task 7: Modified ContentView to branch on hasCompletedOnboarding — shows OnboardingContainerView for new users, PhotoGridView for returning users.
- Task 8: All 26 ATDD tests pass (24 previously failing now green). Full suite of 144 tests passes with 0 failures. Build succeeds.

### File List

**New files:**
- Curator/Features/Onboarding/OnboardingViewModel.swift
- Curator/Features/Onboarding/OnboardingStep.swift (already existed, unchanged)
- Curator/Features/Onboarding/WelcomeView.swift
- Curator/Features/Onboarding/PrivacyExplanationView.swift
- Curator/Features/Onboarding/PermissionRequestView.swift
- Curator/Features/Onboarding/LibraryScanView.swift
- Curator/Features/Onboarding/PermissionDeniedView.swift
- Curator/Features/Onboarding/OnboardingContainerView.swift

**Modified files:**
- Curator/ContentView.swift — Added @AppStorage("hasCompletedOnboarding") check, shows OnboardingContainerView for new users

**Unchanged (pre-existing):**
- CuratorTests/Features/Onboarding/OnboardingViewModelTests.swift — All 26 tests now pass

### Change Log

- 2026-04-18: Story 1.5 created — first-launch onboarding flow with welcome, privacy, permission screens.
- 2026-04-18: Story 1.5 implementation complete — all 8 tasks done, 26 ATDD tests pass, 0 regressions.

### Review Findings
