# Story 1.6: 主界面框架与窗口管理

Status: done

## Story

As a 用户，
I want 看到清晰的 Agent 工作空间布局并保持窗口状态，
So that 我有稳定的工作环境。

## Acceptance Criteria

1. **AC1: NavigationSplitView 三栏布局**
   **Given** 应用已启动并进入主界面（UX-DR1）
   **When** 渲染主界面
   **Then** 使用 NavigationSplitView 实现三栏布局：照片库面板（可折叠侧边栏）+ Agent 执行区（主内容区）+ 底部输入区
   **And** 窗口最小宽度 900pt

2. **AC2: 窗口状态持久化与恢复**
   **Given** 用户调整了窗口大小或面板展开状态（UX-DR16）
   **When** 关闭应用
   **Then** 窗口大小和面板状态通过 @AppStorage 持久化
   **And** 下次启动时恢复上次的状态

3. **AC3: 窗口工具栏与快捷键**
   **Given** 窗口工具栏已渲染（UX-DR18）
   **When** 检查工具栏内容
   **Then** 包含照片库切换按钮、设置入口、会话历史按钮
   **And** ⌘N 新建会话、⌘, 打开设置的快捷键已注册

## Tasks / Subtasks

- [x] Task 1: 创建 MainWorkspaceView — Agent 工作空间主视图 (AC: #1)
  - [x] 1.1 创建 `Curator/Features/MainWorkspace/MainWorkspaceView.swift`
  - [x] 1.2 使用 NavigationSplitView 实现三栏布局：sidebar（照片库）+ content（Agent 执行区）+ 底部输入栏区域
  - [x] 1.3 Sidebar 嵌入 PhotoGridView（可折叠），使用 NavigationSplitViewVisibility 控制显示/隐藏
  - [x] 1.4 Content 区域作为 Agent 执行面板的占位（显示欢迎/空状态）
  - [x] 1.5 底部固定输入栏占位区域（Story 3.3 将实现 AgentInputBar）
  - [x] 1.6 设置 frame(minWidth: 900, minHeight: 600)

- [x] Task 2: 实现窗口状态持久化 (AC: #2)
  - [x] 2.1 在 MainWorkspaceView 中使用 @AppStorage 存储窗口宽度、高度
  - [x] 2.2 使用 @AppStorage 存储侧边栏展开/折叠状态
  - [x] 2.3 使用 @AppStorage("sidebarCollapsible") 或类似 key 持久化 NavigationSplitViewVisibility
  - [x] 2.4 通过 `.frame()` modifier 和 @AppStorage 绑定实现窗口尺寸恢复
  - [x] 2.5 验证应用重启后窗口位置和大小恢复正确

- [x] Task 3: 实现窗口工具栏 (AC: #3)
  - [x] 3.1 在 MainWorkspaceView 中添加 `.toolbar` 修饰符
  - [x] 3.2 添加照片库切换 ToolbarItem — 控制 sidebar 可见性
  - [x] 3.3 添加设置入口 ToolbarItem — 打开 Settings 窗口（使用 Settings scene 占位）
  - [x] 3.4 添加会话历史 ToolbarItem — 占位（功能在 Story 3.5 实现）
  - [x] 3.5 注册 ⌘N 快捷键（新建会话 — 占位）
  - [x] 3.6 注册 ⌘, 快捷键（打开设置 — 占位）

- [x] Task 4: 修改 ContentView 集成 MainWorkspaceView (AC: #1, #2)
  - [x] 4.1 修改 ContentView — onboarding 完成后显示 MainWorkspaceView 替代 PhotoGridView
  - [x] 4.2 确保 AppDependencies 正确传递给 MainWorkspaceView
  - [x] 4.3 确保 PhotoLibraryViewModel 在 MainWorkspaceView 中可用
  - [x] 4.4 保持 onboarding → MainWorkspaceView 过渡动画

- [x] Task 5: 修改 CuratorApp 配置窗口 (AC: #2, #3)
  - [x] 5.1 在 CuratorApp 中添加 Settings scene（占位 SettingsView）
  - [x] 5.2 创建最小占位 SettingsView（后续 Story 2.5 实现）
  - [x] 5.3 配置 WindowGroup 默认窗口大小（如 1200x800）

- [x] Task 6: 更新 NavigationModel (AC: #1, #3)
  - [x] 6.1 替换 NavigationModel.swift 占位为实际导航状态管理
  - [x] 6.2 定义侧边栏可见性状态（@Published var sidebarVisible: Bool）
  - [x] 6.3 定义当前活跃面板状态（@Published var activePanel: ActivePanel 枚举）
  - [x] 6.4 NavigationModel 标记 @MainActor + ObservableObject

- [x] Task 7: ATDD 测试和验证 (AC: #1, #2, #3)
  - [x] 7.1 创建 `CuratorTests/Features/MainWorkspace/MainWorkspaceTests.swift`
  - [x] 7.2 测试 NavigationModel 侧边栏切换逻辑
  - [x] 7.3 测试 NavigationModel 面板状态切换
  - [x] 7.4 测试 @AppStorage 状态持久化（窗口大小、侧边栏状态）
  - [x] 7.5 构建验证：xcodebuild build 成功
  - [x] 7.6 运行全部测试确认无回归

## Dev Notes

### 架构约束

本 Story 实现 Presentation 层的主界面框架和窗口管理。严格遵守以下规则：

1. **分层边界**：MainWorkspaceView 只组合已有的 View 组件和 ViewModel，不直接调用 Infrastructure 层 [Source: architecture.md#决策1, project-context.md#Architecture Boundaries]。
2. **@MainActor ViewModel**：NavigationModel 标记 @MainActor，所有 UI 状态更新在主线程 [Source: project-context.md#Critical Implementation Rules]。
3. **依赖注入**：通过 AppDependencies 传递 ViewModel 和 Repository，不直接创建 Infrastructure 实例 [Source: project-context.md#依赖注入通过 AppDependencies]。
4. **@AppStorage 持久化**：窗口大小和侧边栏状态使用 @AppStorage，UserDefaults 存储满足轻量需求 [Source: architecture.md#决策5]。
5. **避免命名冲突**：不使用 `Task` 作为类型名 [Source: CLAUDE.md#Swift Conventions]。

### Story 1-5 遗留上下文

Story 1-5 已完成首次启动引导流程。以下是当前代码库状态：

**ContentView.swift 当前结构：**
- 使用 `@AppStorage("hasCompletedOnboarding")` 判断引导完成状态
- 引导完成 → 显示 `PhotoGridView(viewModel: viewModel)`
- 未完成 → 显示 `OnboardingContainerView(viewModel: onboardingViewModel)`
- 使用 `@StateObject private var dependencies = AppDependencies()` 管理依赖
- frame(minWidth: 800, minHeight: 600) — 需要更新为 900pt 最小宽度

**本 Story 需修改 ContentView**，将 PhotoGridView 替换为 MainWorkspaceView：
```swift
// ContentView 修改后大致结构
struct ContentView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @StateObject private var dependencies = AppDependencies()
    @StateObject private var viewModel: PhotoLibraryViewModel
    @StateObject private var onboardingViewModel: OnboardingViewModel
    @StateObject private var navigationModel = NavigationModel()

    var body: some View {
        if hasCompletedOnboarding {
            MainWorkspaceView(
                photoViewModel: viewModel,
                dependencies: dependencies,
                navigationModel: navigationModel
            )
            .frame(minWidth: 900, minHeight: 600)
            // ... .task / .onChange 逻辑
        } else {
            OnboardingContainerView(viewModel: onboardingViewModel)
            // ... 保持不变
        }
    }
}
```

**关键点：** MainWorkspaceView 内部通过 NavigationSplitView 包裹 PhotoGridView 作为侧边栏，主内容区作为 Agent 工作空间的占位。

**已有可复用组件（直接使用，无需修改）：**
- `Curator/Features/PhotoLibrary/PhotoGridView.swift` — 照片网格视图
- `Curator/Features/PhotoLibrary/PhotoLibraryViewModel.swift` — 照片库 ViewModel
- `Curator/Features/PhotoLibrary/PhotoDetailSheet.swift` — 照片详情
- `Curator/Features/PhotoLibrary/GridColumnCalculator.swift` — 网格列计算
- `Curator/Features/PhotoLibrary/PhotoThumbnailView.swift` — 缩略图视图
- `Curator/App/AppDependencies.swift` — 依赖注入容器（含 photoRepository、llmProvider）
- `Curator/Core/Models/LoadingState.swift` — LoadingState<T>
- `Curator/Core/Errors/DomainError.swift` — DomainError
- `Curator/Core/Errors/UserFacingError.swift` — UserFacingError

### UX 设计规格关键要求

本 Story 需满足以下 UX 设计规格 [Source: _bmad-output/planning-artifacts/ux-design-specification.md]：

1. **UX-DR1: Agent 工作空间三栏布局** — 输入区（底部固定）+ 执行区（主内容）+ 图库区（可折叠侧边），使用 NavigationSplitView，窗口最小宽度 900pt
2. **UX-DR16: 窗口状态保持** — 使用 @AppStorage 记住窗口大小和面板展开状态
3. **UX-DR18: 导航模式** — 无传统侧边栏菜单、窗口工具栏含照片库切换/设置入口/会话历史、⌘N 新建会话、⌘, 打开设置
4. **按钮层级** — 遵循 UX-DR17（主要/次要/文本按钮样式）
5. **macOS 原生视觉语言** — 使用系统背景色，自适应亮色/暗色模式

### NavigationSplitView 布局方案

UX 设计规格明确要求使用 NavigationSplitView 实现三栏布局 [Source: ux-design-specification.md#Design Direction Decision]。实现要点：

```swift
// 推荐的 NavigationSplitView 布局
NavigationSplitView {
    // Sidebar: 照片库面板（可折叠）
    PhotoGridView(viewModel: photoViewModel)
} detail: {
    // Detail: Agent 执行区 + 底部输入区
    VStack(spacing: 0) {
        // 主内容区 — Agent 执行/结果展示
        AgentContentArea() // 占位

        Spacer()

        // 底部固定输入区
        InputBarPlaceholder() // Story 3.3 将替换为 AgentInputBar
    }
}
```

**窗口宽度响应策略**（来自 UX 设计规格）：
- >= 1200pt：完整三栏（照片库 + Agent 执行区 + 详情）
- 900-1199pt：两栏（Agent 执行区 + 可折叠照片库）
- < 900pt：不支持（最小宽度 900pt）

**NavigationSplitViewVisibility 控制：**
```swift
@AppStorage("sidebarVisibility") var sidebarVisibilityRaw: String = "automatic"

var sidebarVisibility: NavigationSplitViewVisibility {
    get { NavigationSplitViewVisibility(rawValue: sidebarVisibilityRaw) ?? .automatic }
    set { sidebarVisibilityRaw = newValue.rawValue }
}
```

### 窗口状态持久化方案

使用 @AppStorage 存储以下窗口状态 [Source: architecture.md#决策5]：

```swift
@AppStorage("windowWidth") var windowWidth: Double = 1200
@AppStorage("windowHeight") var windowHeight: Double = 800
@AppStorage("sidebarCollapsed") var sidebarCollapsed: Bool = false
```

**注意：** SwiftUI 的 WindowGroup 默认管理窗口位置。窗口大小可通过 `.frame()` 和 `UserDefaults` 标准键值恢复。更精确的窗口控制可在 AppDelegate 中通过 NSWindow 实现，但 MVP 阶段 @AppStorage 方案足够。

### 工具栏实现

窗口工具栏包含以下元素 [Source: ux-design-specification.md#Navigation Patterns]：

1. **照片库切换按钮** — SF Symbol `sidebar.leading`，点击切换侧边栏显示/隐藏
2. **设置入口** — SF Symbol `gear`，⌘, 快捷键打开 Settings scene
3. **会话历史按钮** — SF Symbol `clock.arrow.circlepath`，占位（Story 3.5 实现）

```swift
.toolbar {
    ToolbarItemGroup(placement: .primaryAction) {
        Button {
            navigationModel.toggleSidebar()
        } label: {
            Label("Photo Library", systemImage: "sidebar.leading")
        }

        Button {
            // 占位：会话历史（Story 3.5）
        } label: {
            Label("Session History", systemImage: "clock.arrow.circlepath")
        }

        Button {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        } label: {
            Label("Settings", systemImage: "gear")
        }
    }
}
```

### Settings Scene 配置

CuratorApp 需要添加 Settings scene 以支持 ⌘, 快捷键 [Source: ux-design-specification.md#Journey 3]：

```swift
@main
struct CuratorApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }

        Settings {
            SettingsPlaceholderView()
        }
    }
}
```

**SettingsPlaceholderView** 是一个最小占位视图，后续 Story 2.5 将实现完整设置 UI。

### 文件组织

本 Story 需创建/修改的文件：

```
Curator/
├── Features/
│   └── MainWorkspace/                        # 新建目录
│       ├── MainWorkspaceView.swift            # 新建：Agent 工作空间主视图
│       └── AgentContentAreaPlaceholder.swift  # 新建：Agent 执行区占位
├── Features/
│   └── Settings/                              # 新建目录
│       └── SettingsPlaceholderView.swift      # 新建：设置页面最小占位
├── App/
│   └── NavigationModel.swift                  # 修改：替换占位为实际导航状态
├── ContentView.swift                          # 修改：集成 MainWorkspaceView
├── CuratorApp.swift                           # 修改：添加 Settings scene

CuratorTests/
├── Features/
│   └── MainWorkspace/                         # 新建目录
│       └── MainWorkspaceTests.swift           # 新建
```

### 技术要求

- **Swift 6 strict concurrency**：NavigationModel 用 @MainActor，所有跨线程传递用 Sendable 值类型
- **macOS 15+ API**：可使用 NavigationSplitView、@AppStorage、withAnimation、ToolbarItem 等最新 API
- **文件命名**：类型名即文件名
- **访问控制**：internal（默认）即可
- **不引入新依赖**：仅使用 SwiftUI 和已有的 View 组件
- **构建通过**：`xcodebuild build -project Curator.xcodeproj -scheme Curator -destination 'platform=macOS,arch=arm64'` 必须成功
- **无回归**：Story 1.1~1.5 的现有测试必须仍然通过
- **xcodegen 自动发现**：新增文件通过 project.yml 的 `sources: - Curator` 配置自动发现

### 测试策略

**ATDD 测试优先级：**

- **[P0] NavigationModel 侧边栏切换测试**：验证 toggleSidebar() 正确切换状态
- **[P0] NavigationModel 面板状态测试**：验证 activePanel 状态转换
- **[P1] @AppStorage 持久化测试**：验证窗口大小和侧边栏状态正确存储和恢复
- **[P1] 构建和回归测试**：全部现有测试通过

**Mock 策略**：NavigationModel 是纯状态对象，无需 Mock。

### Agent Content Area 占位设计

Agent 执行区在 MVP 阶段先显示空状态占位 [Source: ux-design-specification.md#UX-DR15]：

```swift
/// Agent 执行区占位视图 — Story 3.3/3.4 将替换为真实组件
struct AgentContentAreaPlaceholder: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Welcome to Curator")
                .font(.title2)
                .fontWeight(.medium)
            Text("Describe what you'd like to do with your photos...")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
```

底部输入区同样为占位——一个简单的 TextField 或 Text 提示，Story 3.3 将替换为 AgentInputBar。

### References

- [Source: _bmad-output/planning-artifacts/architecture.md#决策1] — 分层架构（Presentation → Application → Domain → Infrastructure）
- [Source: _bmad-output/planning-artifacts/architecture.md#决策5] — 数据持久化（UserDefaults/@AppStorage 用于轻量偏好）
- [Source: _bmad-output/planning-artifacts/architecture.md#决策6] — 状态管理（@Observable + Observation）
- [Source: _bmad-output/planning-artifacts/epics.md#Story 1.6] — 原始需求定义（UX-DR1, UX-DR16, UX-DR18）
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#Design Direction Decision] — Agent 工作空间三栏布局决策
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#Responsive Strategy] — 窗口尺寸策略
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#Navigation Patterns] — 主界面导航模式
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#Journey 3] — API Key 配置流程（Settings scene 参考）
- [Source: _bmad-output/implementation-artifacts/1-5-first-launch-onboarding.md] — Story 1.5 完成记录和 ContentView 当前结构
- [Source: _bmad-output/project-context.md#Code Patterns] — SwiftUI 视图模式（200 行限制、Preview 覆盖亮暗色）
- [Source: _bmad-output/project-context.md#Architecture Boundaries] — 目录结构映射
- [Source: CLAUDE.md#Swift Conventions] — 避免命名类型为 Task

## Dev Agent Record

### Agent Model Used

GLM-5.1

### Debug Log References

No issues encountered during implementation.

### Completion Notes List

- Implemented NavigationModel with full sidebar toggle, panel switching, and @AppStorage persistence logic (8 RED tests turned GREEN)
- Created MainWorkspaceView with NavigationSplitView two-column layout (sidebar + detail), toolbar with sidebar toggle / session history / settings buttons
- Created AgentContentAreaPlaceholder with welcome/empty state UI
- Created InputBarPlaceholder as bottom fixed input area (private struct in MainWorkspaceView)
- Created SettingsPlaceholderView as minimal Settings scene target for Cmd+, shortcut
- Modified ContentView to show MainWorkspaceView after onboarding (replacing direct PhotoGridView), added NavigationModel as @StateObject, updated minWidth to 900pt
- Modified CuratorApp to add Settings scene and default window size 1200x800
- All 173 tests pass (29 MainWorkspace tests + 144 existing tests, 2 skipped, 0 failures)
- Build succeeds with no errors

### File List

New Files:
- Curator/Features/MainWorkspace/MainWorkspaceView.swift
- Curator/Features/MainWorkspace/AgentContentAreaPlaceholder.swift
- Curator/Features/Settings/SettingsPlaceholderView.swift

Modified Files:
- Curator/App/NavigationModel.swift (replaced stubs with real implementation)
- Curator/ContentView.swift (integrated MainWorkspaceView, added NavigationModel)
- Curator/CuratorApp.swift (added Settings scene, window defaults)
