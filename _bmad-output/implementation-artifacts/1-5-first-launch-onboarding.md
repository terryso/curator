# Story 1.5: 首次启动引导流程

Status: done

<!-- 重写说明：MVP 照片来源策略从 PhotoKit 切换为本地文件夹。
     原始实现基于 PhotoKit 权限模型（requestReadAccess → PhotoPermissionManager → 系统权限弹窗），
     包含 4 屏引导流程（产品介绍、隐私说明、权限请求、LLM 配置）。
     Epic 1 更新后调整为本地文件夹选择模型，引导流程缩减为 3 屏。
     主要变更：
     - PhotoKit 权限请求 → NSOpenPanel 文件夹选择
     - PhotoPermissionManager → FolderBookmarkManager（security-scoped bookmark）
     - 4 屏 → 3 屏（移除 LLM 配置步骤，移至 Epic 2）
     - OnboardingStep.permission → OnboardingStep.folderSelection
     - OnboardingStep.denied → OnboardingStep.noFolder
     - PermissionRequestView → FolderSelectionView
     - PermissionDeniedView → NoFolderSelectedView
     现有代码文件需重写以匹配新流程。 -->

## Story

As a 新用户，
I want 通过简洁的引导流程了解 Curator 并选择照片文件夹，
So that 我可以快速开始使用应用。

## Acceptance Criteria

1. **AC1: 欢迎引导流程（最多 3 屏）**
   **Given** 用户首次打开 Curator（UX-DR8）
   **When** 进入引导流程
   **Then** 展示最多 3 屏：产品介绍、隐私说明、文件夹选择
   **And** 隐私说明包含"照片仅在会话中分析，发送到 LLM API 用于理解"
   **And** 每屏有"下一步"/"上一步"导航，最后一屏触发文件夹选择

2. **AC2: 文件夹选择与照片扫描**
   **Given** 用户选择了照片文件夹（FR1）
   **When** 通过 NSOpenPanel 选择目录且文件夹访问权限获取成功
   **Then** 访问权限通过 security-scoped bookmark 持久化
   **And** 扫描文件夹元数据，展示照片数量摘要（如"已发现 15,320 张照片"）
   **And** 进入主界面时输入框 placeholder 展示示例指令（UX-DR15）

3. **AC3: 未选择文件夹降级处理**
   **Given** 用户未选择文件夹或取消选择（UX-DR9）
   **When** 无文件夹访问权限
   **Then** 展示说明和引导选择文件夹的按钮
   **And** 应用仍可启动，但照片功能不可用

## Tasks / Subtasks

- [ ] Task 1: 更新 OnboardingStep 枚举 (AC: #1)
  - [ ] 1.1 修改 `Curator/Features/Onboarding/OnboardingStep.swift` — 移除 `llmConfig` case
  - [ ] 1.2 将 `permission` case 重命名为 `folderSelection`
  - [ ] 1.3 将 `denied` case 重命名为 `noFolder`
  - [ ] 1.4 最终枚举：welcome / privacy / folderSelection / scanning / complete / noFolder（6 个 case）
  - [ ] 1.5 更新 rawValue：welcome=0, privacy=1, folderSelection=2, scanning=3, complete=4, noFolder=5

- [ ] Task 2: 重写 OnboardingViewModel (AC: #1, #2, #3)
  - [ ] 2.1 重写 `Curator/Features/Onboarding/OnboardingViewModel.swift` — @MainActor ObservableObject
  - [ ] 2.2 移除 LLM 配置相关属性（baseURL、apiKey、modelID）和方法（saveLLMConfig、isLLMConfigValid）
  - [ ] 2.3 totalOnboardingSteps 改为 3（welcome, privacy, folderSelection）
  - [ ] 2.4 实现 `selectPhotoFolder()` — 通过 FolderBookmarkManager 的 selectAndBookmarkFolder() 打开 NSOpenPanel
  - [ ] 2.5 授权成功 → 调用 scanLibrary() 扫描文件夹获取照片数量
  - [ ] 2.6 授权失败/取消 → 设置 currentStep = .noFolder
  - [ ] 2.7 通过 init 注入 PhotoLibraryRepository? 协议（与 PhotoLibraryViewModel 一致）
  - [ ] 2.8 实现 `retryFolderSelection()` — 从 noFolder 状态重新触发文件夹选择

- [ ] Task 3: 保留 WelcomeView (AC: #1)
  - [ ] 3.1 验证 `Curator/Features/Onboarding/WelcomeView.swift` — 第一屏：产品介绍（无需修改）
  - [ ] 3.2 确认展示应用名称"Curator"、图标、简短介绍
  - [ ] 3.3 确认底部"下一步"按钮（主要样式，UX-DR17）

- [ ] Task 4: 保留 PrivacyExplanationView (AC: #1)
  - [ ] 4.1 验证 `Curator/Features/Onboarding/PrivacyExplanationView.swift` — 第二屏：隐私说明（无需修改）
  - [ ] 4.2 确认隐私要点："照片仅在会话中分析"、"发送到 LLM API 用于理解"、"不会上传存储"
  - [ ] 4.3 确认"下一步"/"上一步"按钮组合

- [ ] Task 5: 重写 PermissionRequestView → FolderSelectionView (AC: #1, #2, #3)
  - [ ] 5.1 创建 `Curator/Features/Onboarding/FolderSelectionView.swift` — 第三屏：文件夹选择
  - [ ] 5.2 展示文件夹选择说明文字和"选择照片文件夹"按钮（主要样式）
  - [ ] 5.3 点击后调用 viewModel.selectPhotoFolder()，触发 NSOpenPanel
  - [ ] 5.4 选择成功 → 进入扫描动画 + 照片数量摘要 → 完成
  - [ ] 5.5 选择失败/取消 → 进入 NoFolderSelectedView 降级状态
  - [ ] 5.6 删除 `Curator/Features/Onboarding/PermissionRequestView.swift`（不再需要）

- [ ] Task 6: 重写 PermissionDeniedView → NoFolderSelectedView (AC: #3)
  - [ ] 6.1 创建 `Curator/Features/Onboarding/NoFolderSelectedView.swift` — 未选择文件夹降级
  - [ ] 6.2 展示说明文字："未选择照片文件夹" + "选择文件夹"重试按钮（主要样式）
  - [ ] 6.3 "继续（功能受限）"按钮（次要样式）允许用户跳过
  - [ ] 6.4 删除 `Curator/Features/Onboarding/PermissionDeniedView.swift`（不再需要）

- [ ] Task 7: 更新 LibraryScanView (AC: #2)
  - [ ] 7.1 更新 `Curator/Features/Onboarding/LibraryScanView.swift` — 扫描文案调整
  - [ ] 7.2 扫描中文案改为"正在扫描照片文件夹..."（原来是"正在扫描照片库..."）
  - [ ] 7.3 扫描完成文案保持"已发现 N 张照片"格式不变

- [ ] Task 8: 更新 OnboardingContainerView (AC: #1)
  - [ ] 8.1 更新 `Curator/Features/Onboarding/OnboardingContainerView.swift` — 适配新流程
  - [ ] 8.2 根据 viewModel.currentStep 切换显示对应的子视图（6 个 case）
  - [ ] 8.3 步骤指示器改为 3 个小圆点（welcome, privacy, folderSelection）
  - [ ] 8.4 移除 llmConfig 对应的视图切换逻辑
  - [ ] 8.5 完成后设置 @AppStorage("hasCompletedOnboarding") = true

- [ ] Task 9: 更新 ContentView 集成 (AC: #1, #2)
  - [ ] 9.1 验证 `Curator/ContentView.swift` — 检查 @AppStorage("hasCompletedOnboarding") 逻辑
  - [ ] 9.2 确认 OnboardingContainerView 使用更新后的 OnboardingViewModel
  - [ ] 9.3 确认引导完成后平滑过渡到主界面（withAnimation）

- [ ] Task 10: 处理 LLMConfigView (AC: #1)
  - [ ] 10.1 评估 `Curator/Features/Onboarding/LLMConfigView.swift` — 移至 Epic 2 或删除
  - [ ] 10.2 如果 Epic 2 有独立的 LLM 设置 UI，则删除此文件
  - [ ] 10.3 如果此视图将复用，则保留但从 Onboarding 流程中移除引用

- [ ] Task 11: ATDD 测试更新和验证 (AC: #1, #2, #3)
  - [ ] 11.1 更新 `CuratorTests/Features/Onboarding/OnboardingViewModelTests.swift`
  - [ ] 11.2 更新测试以匹配新的 OnboardingStep 枚举（移除 llmConfig 相关测试）
  - [ ] 11.3 测试步骤前进/后退逻辑（3 屏流程）
  - [ ] 11.4 测试文件夹选择成功路径
  - [ ] 11.5 测试文件夹选择取消/降级路径
  - [ ] 11.6 测试 @AppStorage onboarding 完成标记
  - [ ] 11.7 完整构建验证：xcodebuild build 成功
  - [ ] 11.8 运行全部测试确认无回归

## Dev Notes

### 架构约束

本 Story 实现 Presentation 层的首次启动引导功能。严格遵守以下规则：

1. **分层边界**：OnboardingViewModel 通过注入的 PhotoLibraryRepository 协议请求数据，不直接调用 LocalFolderRepository 或任何 Infrastructure 层代码 [Source: architecture.md#决策1, project-context.md#Architecture Boundaries]。
2. **@MainActor ViewModel**：OnboardingViewModel 标记 @MainActor，所有 UI 状态更新在主线程 [Source: project-context.md#Critical Implementation Rules]。
3. **三层错误体系**：PhotoLibraryRepository 抛出的错误通过 DomainError → UserFacingError 映射，UI 层只展示用户友好错误消息 [Source: architecture.md#决策9, project-context.md#三层错误体系]。
4. **@AppStorage 持久化**：使用 @AppStorage("hasCompletedOnboarding") 记录引导完成状态，UserDefaults 存储满足轻量需求 [Source: architecture.md#决策5]。
5. **避免命名冲突**：不使用 `Task` 作为类型名 [Source: CLAUDE.md#Swift Conventions]。

### 关键变更说明

**从 PhotoKit 权限模型切换为本地文件夹选择模型：**

| 方面 | 旧实现（PhotoKit） | 新实现（本地文件夹） |
|------|-------------------|-------------------|
| 引导步骤 | 4 屏（welcome, privacy, permission, llmConfig） | 3 屏（welcome, privacy, folderSelection） |
| 权限请求 | `requestReadAccess()` → 系统权限弹窗 | `selectAndBookmarkFolder()` → NSOpenPanel |
| 持久化方式 | 系统权限（自动持久化） | Security-scoped bookmark（UserDefaults） |
| 降级视图 | PermissionDeniedView → "Open System Settings" | NoFolderSelectedView → "选择文件夹"重试 |
| LLM 配置 | 包含在引导流程中（第 4 屏） | 移至 Epic 2 独立设置 |

**OnboardingStep 枚举变更：**

```swift
// 旧（7 个 case）
enum OnboardingStep: Int, CaseIterable, Equatable, Sendable {
    case welcome = 0
    case privacy = 1
    case permission = 2    // → 重命名为 folderSelection
    case llmConfig = 3     // → 删除（移至 Epic 2）
    case scanning = 4
    case complete = 5
    case denied = 6        // → 重命名为 noFolder
}

// 新（6 个 case）
enum OnboardingStep: Int, CaseIterable, Equatable, Sendable {
    case welcome = 0
    case privacy = 1
    case folderSelection = 2
    case scanning = 3
    case complete = 4
    case noFolder = 5
}
```

### Story 1.3 遗留上下文

Story 1.3（本地文件夹读取服务）已提供以下 Infrastructure 层组件（通过协议调用）：

- `Curator/Infrastructure/PhotoSource/LocalFolderRepository.swift` — actor 实现 PhotoLibraryRepository 协议
- `Curator/Infrastructure/PhotoSource/FolderBookmarkManager.swift` — security-scoped bookmark 管理（selectAndBookmarkFolder, loadBookmark 等）
- `Curator/Infrastructure/PhotoSource/ExifMetadataReader.swift` — ImageIO EXIF 读取
- `Curator/Core/Models/PhotoLibraryRepository.swift` — 协议，含 requestReadAccess()、fetchAssets(predicate:pageSize:pageOffset:)

**Domain 模型（直接使用，无需修改）：**
- `Curator/Core/Models/PhotoAsset.swift` — PhotoAsset: Sendable, Identifiable
- `Curator/Core/Models/AssetPage.swift` — AssetPage: Sendable，含 assets、hasMore、nextOffset?
- `Curator/Core/Models/PhotoPredicate.swift` — 支持 .all 过滤
- `Curator/Core/Models/LoadingState.swift` — LoadingState<T: Sendable>: Sendable
- `Curator/Core/Models/FolderBookmarkManaging.swift` — 书签管理协议
- `Curator/Core/Errors/DomainError.swift` — DomainError: Error, Sendable
- `Curator/Core/Errors/UserFacingError.swift` — UserFacingError: Sendable

**DI 容器：**
- `Curator/App/AppDependencies.swift` — @MainActor ObservableObject，@Published var photoRepository: (any PhotoLibraryRepository)?

### Story 1.4 / 1.6 遗留上下文

**ContentView.swift 当前结构：**
- 使用 `@StateObject private var dependencies = AppDependencies()` 初始化依赖
- 使用 `@StateObject private var viewModel: PhotoLibraryViewModel` 管理照片网格
- 使用 `@StateObject private var onboardingViewModel: OnboardingViewModel` 管理引导流程
- `.task` 中调用 `dependencies.registerLocalFolderRepository()`
- `.onChange(of: dependencies.photoRepository != nil)` 监听仓库就绪

**ContentView 已正确使用 LocalFolderRepository。本 Story 需确保 OnboardingViewModel 的引导流程与文件夹选择模型匹配。**

### Onboarding 流程设计要点

**步骤定义（OnboardingStep 枚举）：**
```swift
enum OnboardingStep: Int, CaseIterable, Equatable, Sendable {
    case welcome = 0        // 第一屏：产品介绍
    case privacy = 1        // 第二屏：隐私说明
    case folderSelection = 2 // 第三屏：文件夹选择（NSOpenPanel）
    case scanning = 3       // 扫描中（过渡状态）
    case complete = 4       // 扫描完成，展示摘要
    case noFolder = 5       // 未选择文件夹
}
```

**UX 关键决策（来自 UX 设计规格）：**
- 欢迎画面不超过 3 屏 — 产品介绍、隐私说明、文件夹选择 [Source: ux-design-specification.md#Journey 1]
- 隐私说明包含"照片仅在会话中分析，发送到 LLM API 用于理解" [Source: ux-design-specification.md#Journey 1]
- 首次进入主界面时，输入框 placeholder 展示示例指令（此 AC 在 Story 1.6/3.3 实现，本 Story 先标记 TODO）
- UX-DR9: 权限渐进授权 — 用户可跳过文件夹选择，应用仍可用但照片功能受限 [Source: ux-design-specification.md#Design Direction]
- UX-DR15: 空状态处理 — 无照片时友好提示 [Source: ux-design-specification.md#Feedback Patterns]

**文件夹选择流程：**
1. OnboardingViewModel.selectPhotoFolder() 调用 photoRepository.requestReadAccess()
2. requestReadAccess() 内部通过 FolderBookmarkManager 的 selectAndBookmarkFolder() 打开 NSOpenPanel
3. 用户选择目录 → FolderBookmarkManager 创建 security-scoped bookmark 并持久化
4. 成功 → 调用 scanLibrary() 获取照片数量
5. scanLibrary() 调用 photoRepository.fetchAssets(predicate: .all, pageSize: 100, pageOffset: 0) 获取 AssetPage
6. 失败/取消 → 设置 currentStep = .noFolder

**照片数量摘要策略：**

沿用方案 B（已验证有效）：
- 获取第一页（pageSize: 100），展示 "已发现 {assets.count}+ 张照片"（如果 hasMore 为 true 加 "+" 后缀）
- 如果后续需要精确计数，可在 LocalFolderRepository 中新增 countAssets() 方法

### NSOpenPanel 文件夹选择实现

本 Story 的文件夹选择通过 LocalFolderRepository.requestReadAccess() → FolderBookmarkManager.selectAndBookmarkFolder() 实现。

**FolderBookmarkManager 内部实现（已在 Story 1.3 中完成）：**
```swift
func selectAndBookmarkFolder() async throws -> URL {
    let panel = NSOpenPanel()
    panel.canChooseDirectories = true
    panel.canChooseFiles = false
    panel.allowsMultipleSelection = false
    panel.message = "选择包含照片的文件夹"
    let response = panel.runModal()
    guard response == .OK, let url = panel.urls.first else {
        throw InfrastructureError.folderAccessDenied
    }
    let bookmarkData = try url.bookmarkData(
        options: .withSecurityScope,
        includingResourceValuesForKeys: nil,
        relativeTo: nil
    )
    UserDefaults.standard.set(bookmarkData, forKey: "folderBookmark")
    return url
}
```

**OnboardingViewModel 中的调用：**
```swift
func selectPhotoFolder() async {
    guard let repository = repository else {
        currentStep = .noFolder
        return
    }
    do {
        let granted = try await repository.requestReadAccess()
        if granted {
            currentStep = .scanning
            await scanLibrary(repository: repository)
        } else {
            currentStep = .noFolder
        }
    } catch {
        currentStep = .noFolder
    }
}
```

### SwiftUI 视图实现模式

遵循项目已建立的 SwiftUI 视图模式 [Source: project-context.md#Code Patterns]：

1. **视图不超过 200 行** — 复杂视图拆分子视图（本 Story 每个视图页面独立）
2. **Preview 覆盖亮色/暗色模式**
3. **macOS 原生视觉语言** — 使用系统背景色、系统控件
4. **按钮层级** — 主要（实色填充）、次要（描边）、文本（无背景）[Source: ux-design-specification.md#Button Hierarchy]
5. **每界面最多一个主要按钮**

### 文件组织

本 Story 需创建/修改/删除的文件：

```
Curator/
├── Features/
│   └── Onboarding/
│       ├── OnboardingStep.swift               # 修改：移除 llmConfig，重命名 case
│       ├── OnboardingViewModel.swift          # 重写：移除 LLM 配置，改用文件夹选择
│       ├── OnboardingContainerView.swift      # 修改：适配新流程和枚举
│       ├── WelcomeView.swift                  # 保留不变
│       ├── PrivacyExplanationView.swift       # 保留不变
│       ├── FolderSelectionView.swift          # 新建：替代 PermissionRequestView
│       ├── LibraryScanView.swift              # 修改：文案调整
│       ├── NoFolderSelectedView.swift         # 新建：替代 PermissionDeniedView
│       ├── PermissionRequestView.swift        # 删除
│       ├── PermissionDeniedView.swift         # 删除
│       └── LLMConfigView.swift               # 评估：移至 Epic 2 或删除

CuratorTests/
├── Features/
│   └── Onboarding/
│       └── OnboardingViewModelTests.swift     # 修改：适配新枚举和流程
```

### 技术要求

- **Swift 6 strict concurrency**：ViewModel 用 @MainActor，所有跨线程传递用 Sendable 值类型
- **macOS 15+ API**：可使用 @AppStorage、withAnimation、ProgressView 等最新 API
- **文件命名**：类型名即文件名
- **访问控制**：internal（默认）即可
- **不引入新依赖**：仅使用 SwiftUI 和已有的 Domain 模型
- **构建通过**：`xcodebuild build -project Curator.xcodeproj -scheme Curator -destination 'platform=macOS,arch=arm64'` 必须成功
- **无回归**：Story 1.1~1.4、1.6 的现有测试必须仍然通过
- **xcodegen 自动发现**：新增文件通过 project.yml 的 `sources: - Curator` 配置自动发现

### UX 设计规格要求

本 Story 需满足以下 UX 设计规格 [Source: _bmad-output/planning-artifacts/ux-design-specification.md]：

1. **UX-DR8: 首次启动引导流程** — 欢迎画面（<=3 屏）含产品介绍、隐私说明、文件夹选择
2. **UX-DR9: 权限渐进授权 UI** — 用户可跳过文件夹选择，应用仍可用但照片功能受限
3. **UX-DR15: 空状态处理** — 无照片/无文件夹时友好提示 + 替代操作建议
4. **WCAG AA 无障碍** — VoiceOver 标签覆盖、键盘导航支持
5. **macOS 原生视觉语言** — 使用系统背景色、自适应亮色/暗色模式
6. **按钮层级** — 遵循 UX-DR17（主要/次要/文本按钮）
7. **情感设计** — 首次启动目标情绪：好奇 + 安全感；避免：压迫、数据焦虑 [Source: ux-design-specification.md#Emotional Journey Mapping]

### 测试策略

**ATDD 测试优先级：**

- **[P0] ViewModel 步骤导航测试**：验证 3 屏步骤前进/后退逻辑、状态转换
- **[P0] 文件夹选择成功路径**：验证 selectPhotoFolder 成功后进入扫描状态
- **[P0] 文件夹选择取消路径**：验证取消后进入 noFolder 状态
- **[P1] 扫描完成测试**：验证照片数量摘要展示
- **[P1] 完成标记测试**：验证 @AppStorage 正确设置
- **[P1] OnboardingStep 枚举测试**：验证 6 个 case 存在且 rawValue 正确

**Mock 策略**：使用 MockPhotoLibraryRepository（已存在于 `Curator/Infrastructure/Mock/MockPhotoLibraryRepository.swift`），控制权限请求结果和资产返回。

```swift
// MockPhotoLibraryRepository（已存在，可直接使用）
// 控制参数：shouldGrantPermission、assetCount、hasMore
```

**需更新的测试：**
- 移除 `testTotalOnboardingStepsIsThree` 的硬编码检查（已经是 3 → 现在确认仍为 3）
- 移除所有 llmConfig 相关的测试（如果有）
- 将 `permission` 相关测试重命名为 `folderSelection`
- 将 `denied` 相关测试重命名为 `noFolder`
- 更新 `canGoBack` 测试：folderSelection 可返回，scanning/complete/noFolder 不可

### References

- [Source: _bmad-output/planning-artifacts/architecture.md#决策1] — 分层架构（Presentation → Application → Domain → Infrastructure）
- [Source: _bmad-output/planning-artifacts/architecture.md#决策3] — 照片来源服务层（Repository 模式 + Actor 隔离 + 本地文件夹）
- [Source: _bmad-output/planning-artifacts/architecture.md#决策5] — 数据持久化（UserDefaults/@AppStorage 用于轻量偏好）
- [Source: _bmad-output/planning-artifacts/architecture.md#决策9] — 错误处理模式（Typed Error + 分层错误传播）
- [Source: _bmad-output/planning-artifacts/epics.md#Story 1.5] — 更新后的需求定义（UX-DR8, UX-DR9, UX-DR15）
- [Source: _bmad-output/planning-artifacts/prd.md#隐私与数据安全] — 隐私透明度要求
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#Journey 1] — 首次启动与文件夹选择流程
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#Button Hierarchy] — 按钮层级系统
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#Emotional Journey Mapping] — 情感旅程设计
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#Accessibility Strategy] — WCAG AA 合规要求
- [Source: _bmad-output/implementation-artifacts/1-3-local-folder-read-service.md] — Story 1.3 完成记录（LocalFolderRepository、FolderBookmarkManager）
- [Source: _bmad-output/implementation-artifacts/1-4-photo-library-browse-grid.md] — Story 1.4 完成记录和 ContentView 当前结构
- [Source: _bmad-output/implementation-artifacts/1-6-main-ui-framework-and-window.md] — Story 1.6 完成记录
- [Source: _bmad-output/project-context.md#Code Patterns] — SwiftUI 视图模式（200 行限制、Preview 覆盖亮暗色）
- [Source: _bmad-output/project-context.md#Architecture Boundaries] — 目录结构映射
- [Source: CLAUDE.md#Swift Conventions] — 避免命名类型为 Task

### ATDD Artifacts

- Checklist: `_bmad-output/test-artifacts/atdd-checklist-1-5-first-launch-onboarding.md`（需更新）
- API tests: `CuratorTests/Features/Onboarding/OnboardingViewModelTests.swift`（需更新）
- Traceability: `_bmad-output/test-artifacts/traceability-matrix-1-5.md`（需更新）

## Dev Agent Record

### Agent Model Used

(待实现时填写)

### Debug Log References

(待实现时填写)

### Completion Notes List

(待实现时填写)

### File List

(待实现时填写)

## Change Log

- 2026-04-18: Story 1.5 原始实现完成（基于 PhotoKit 权限模型，4 屏引导流程含 LLM 配置）
- 2026-04-20: Story 1.5 规格重写——MVP 照片来源从 PhotoKit 切换为本地文件夹。引导流程从 4 屏缩减为 3 屏（移除 LLM 配置步骤）。PermissionRequestView → FolderSelectionView（NSOpenPanel），PermissionDeniedView → NoFolderSelectedView。OnboardingStep 枚举从 7 个 case 精简为 6 个。Status 从 review 回退为 todo。
- 2026-04-20: Story 1.5 代码已实现完毕——OnboardingStep 6 case 枚举、3 屏引导流程、FolderSelectionView、NoFolderSelectedView 全部就绪。状态从 todo 更新为 done。
