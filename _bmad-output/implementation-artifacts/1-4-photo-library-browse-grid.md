# Story 1.4: 照片网格浏览

Status: done

<!-- 重写说明：MVP 照片来源策略从 PhotoKit 切换为本地文件夹。
     本 Story 的 Presentation 层代码通过 PhotoLibraryRepository 协议与数据层交互，
     不直接依赖 PhotoKit 或文件系统组件，因此实现代码无需修改。
     主要变更体现在 Dev Notes 中：
     - Story 1.3 遗留上下文从 PhotoKit 组件更新为本地文件夹组件
     - AssetMetadata 字段更新（fileName, fileSize, cameraModel, imageWidth, imageHeight, gpsLocation, fileFormat）
     - PhotoDetailSheet 元数据展示字段更新（文件名、日期、相机、尺寸、文件大小、位置）
     - 缩略图加载使用 fetchThumbnail(for:size:) 协议方法
     - ContentView 集成方式更新（registerLocalFolderRepository）
     AC 保持不变，因为它们通过协议定义而非具体实现。 -->

## Story

As a 用户，
I want 在网格视图中浏览照片缩略图，
So that 我可以快速浏览和管理我的照片库。

## Acceptance Criteria

1. **AC1: 自适应网格布局**
   **Given** PhotoLibraryViewModel 已加载照片数据
   **When** 渲染 PhotoGridView
   **Then** 照片以自适应列数的网格展示（UX-DR13：最小列宽 120pt，间距 4pt）
   **And** 窗口宽度变化时列数自动调整

2. **AC2: 分页无限滚动**
   **Given** 用户滚动照片网格（FR5）
   **When** 滚动到当前页末尾
   **Then** 自动加载下一页（200ms 内加载，NFR8）
   **And** 滚动流畅，达到 60fps（NFR2）

3. **AC3: 照片详情查看**
   **Given** 点击某张照片
   **When** 打开照片详情
   **Then** PhotoDetailSheet 展示完整元数据（文件名、日期、相机型号、尺寸、文件大小、GPS 位置）
   **And** 缩略图通过 fetchThumbnail(for:size:) 按需加载

## Tasks / Subtasks

- [x] Task 1: 创建 PhotoLibraryViewModel (AC: #1, #2)
  - [x] 1.1 创建 `Curator/Features/PhotoLibrary/PhotoLibraryViewModel.swift` — @MainActor ViewModel
  - [x] 1.2 实现 loadInitialPage() — 调用 photoRepository.fetchAssets 加载第一页
  - [x] 1.3 实现 loadNextPage() — 基于 AssetPage.nextOffset 加载后续页，追加到现有资产列表
  - [x] 1.4 管理 photos: [PhotoAsset] 状态和 LoadingState<[PhotoAsset]> 整体加载状态
  - [x] 1.5 通过 init 注入 PhotoLibraryRepository 协议（支持 nil 降级）
  - [x] 1.6 实现 updateRepository() — 运行时更新仓库引用（用于注册后回调）
  - [x] 1.7 实现 loadThumbnail(for:) 和 loadPreview(for:) — 通过 fetchThumbnail 协议方法按需加载
  - [x] 1.8 实现 paginationError 非阻塞分页错误（网格保持可见）

- [x] Task 2: 创建 PhotoGridView (AC: #1, #2)
  - [x] 2.1 创建 `Curator/Features/PhotoLibrary/PhotoGridView.swift` — 自适应网格视图
  - [x] 2.2 使用 LazyVGrid + ScrollView 实现虚拟化网格，最小列宽 120pt，间距 4pt
  - [x] 2.3 使用 GridColumnCalculator（独立可测试工具）计算列数
  - [x] 2.4 实现无限滚动检测：最后一项 onAppear 触发 loadNextPage()
  - [x] 2.5 实现状态视图：idle / loading / loaded / empty / error（UX-DR15）
  - [x] 2.6 实现分页错误横幅（非阻塞，网格保持可见）
  - [x] 2.7 实现 .sheet 绑定照片详情弹窗

- [x] Task 3: 创建 PhotoThumbnailView (AC: #1)
  - [x] 3.1 创建 `Curator/Features/PhotoLibrary/PhotoThumbnailView.swift` — 缩略图子视图
  - [x] 3.2 展示 120x120 缩略图，nil 数据时使用 systemName "photo" 占位符
  - [x] 3.3 使用 .task(id:) 触发缩略图按需加载
  - [x] 3.4 添加点击手势 → 触发选中状态 → 打开 PhotoDetailSheet
  - [x] 3.5 添加 accessibilityLabel — "photo, taken on {日期}"

- [x] Task 4: 创建 PhotoDetailSheet (AC: #3)
  - [x] 4.1 创建 `Curator/Features/PhotoLibrary/PhotoDetailSheet.swift` — 照片详情弹窗
  - [x] 4.2 展示放大预览图（通过 loadPreview 加载 400x400 图像）
  - [x] 4.3 展示元数据行：文件名、创建日期、相机型号、尺寸、文件大小、GPS 位置
  - [x] 4.4 使用 Sheet 弹出 + 工具栏关闭按钮（Esc 快捷键）
  - [x] 4.5 缺失元数据优雅降级 — 空字段显示 "-"
  - [x] 4.6 使用静态 DateFormatter 和 ByteCountFormatter 避免重复创建

- [x] Task 5: 创建 GridColumnCalculator (AC: #1)
  - [x] 5.1 创建 `Curator/Features/PhotoLibrary/GridColumnCalculator.swift` — 纯函数工具
  - [x] 5.2 实现 columnCount(for:) 和 gridItems(for:) 静态方法
  - [x] 5.3 常量：minColumnWidth = 120, spacing = 4

- [x] Task 6: ATDD 测试和验证 (AC: #1, #2, #3)
  - [x] 6.1 创建 `CuratorTests/Features/PhotoLibrary/PhotoLibraryViewModelTests.swift`
  - [x] 6.2 创建 `CuratorTests/Features/PhotoLibrary/GridColumnCalculatorTests.swift`
  - [x] 6.3 完整构建验证：xcodebuild build 成功
  - [x] 6.4 运行全部测试确认无回归

## Dev Notes

### 架构约束

本 Story 实现 Presentation 层的照片图库浏览功能。严格遵守以下规则：

1. **分层边界**：PhotoLibraryViewModel 通过注入的 PhotoLibraryRepository 协议获取数据，不直接调用 LocalFolderRepository 或任何 Infrastructure 层代码 [Source: architecture.md#架构边界]。
2. **@MainActor ViewModel**：PhotoLibraryViewModel 标记 @MainActor，所有 UI 状态更新在主线程 [Source: project-context.md#Critical Implementation Rules]。
3. **Sendable 值类型**：PhotoAsset、AssetMetadata、AssetPage 等跨层传递类型已实现 Sendable，无需修改 [Source: Curator/Core/Models/]。
4. **LoadingState**：使用已有的 LoadingState<T> 枚举管理加载状态 [Source: Curator/Core/Models/LoadingState.swift]。
5. **错误处理**：PhotoLibraryRepository 抛出的 DomainError 通过 LoadingState.failed 展示给用户；分页错误通过 paginationError 非阻塞展示，网格保持可见 [Source: architecture.md#决策9]。
6. **避免命名冲突**：不使用 `Task` 作为类型名 [Source: CLAUDE.md#Swift Conventions]。

### Story 1.3 遗留上下文

Story 1.3 已完成以下工作（文件已存在且可用）：

**Infrastructure 层（通过协议调用，不直接引用）：**
- `Curator/Infrastructure/PhotoSource/LocalFolderRepository.swift` — actor 实现 PhotoLibraryRepository 协议
- `Curator/Infrastructure/PhotoSource/FolderBookmarkManager.swift` — security-scoped bookmark 管理
- `Curator/Infrastructure/PhotoSource/ExifMetadataReader.swift` — ImageIO EXIF 读取 + 缩略图生成

**Domain 模型（直接使用，无需修改）：**
- `Curator/Core/Models/PhotoAsset.swift` — `PhotoAsset: Sendable, Identifiable`，含 id、metadata、thumbnailData?
- `Curator/Core/Models/AssetID.swift` — 文件路径的类型安全封装
- `Curator/Core/Models/AssetMetadata.swift` — 含 fileName、fileSize、creationDate、cameraModel、imageWidth、imageHeight、gpsLocation、fileFormat
- `Curator/Core/Models/AssetPage.swift` — `AssetPage: Sendable`，含 assets、hasMore、nextOffset?
- `Curator/Core/Models/PhotoPredicate.swift` — 支持过滤（`.all`、日期范围、文件格式）
- `Curator/Core/Models/LoadingState.swift` — `LoadingState<T: Sendable>: Sendable`（idle/loading/loaded/failed）
- `Curator/Core/Models/PhotoLibraryRepository.swift` — 协议，含 requestReadAccess()、fetchAssets(predicate:pageSize:pageOffset:)、fetchThumbnail(for:size:)、fetchFullResolutionImage(for:)

**DI 容器：**
- `Curator/App/AppDependencies.swift` — @MainActor ObservableObject，@Published var photoRepository: (any PhotoLibraryRepository)?，registerLocalFolderRepository()

**关键上下文：**
- fetchAssets 默认不加载缩略图（thumbnailData: nil），网格通过 .task(id:) 按需调用 fetchThumbnail 加载
- 分页使用 pageOffset + pageSize 模式，nextOffset 由 AssetPage 返回
- LocalFolderRepository 是 actor，所有调用天然异步
- requestReadAccess() 内部通过 FolderBookmarkManager 加载或选择文件夹

### ContentView 集成

当前 `ContentView.swift` 使用以下结构集成 PhotoLibraryViewModel：

```swift
@StateObject private var dependencies = AppDependencies()
@StateObject private var viewModel: PhotoLibraryViewModel
@StateObject private var onboardingViewModel: OnboardingViewModel

init() {
    let deps = AppDependencies()
    _dependencies = StateObject(wrappedValue: deps)
    _viewModel = StateObject(wrappedValue: PhotoLibraryViewModel(repository: deps.photoRepository))
    _onboardingViewModel = StateObject(wrappedValue: OnboardingViewModel(repository: deps.photoRepository))
}
```

- `.task` 中调用 `dependencies.registerLocalFolderRepository()` 注册仓库
- `.onChange(of: dependencies.photoRepository != nil)` 监听仓库就绪后调用 `viewModel.updateRepository(repo)`
- 引导完成后通过 MainWorkspaceView 展示 PhotoGridView
- 支持 `--uitest-mock-photos` 参数使用 MockPhotoLibraryRepository

### SwiftUI LazyVGrid 性能要点

**关键性能要求（NFR2: 60fps 滚动，NFR8: 200ms 加载）：**

```swift
// 自适应列数网格（GridColumnCalculator）
private let minColumnWidth: CGFloat = 120
private let spacing: CGFloat = 4

static func columnCount(for availableWidth: CGFloat) -> Int {
    let totalUnitWidth = minColumnWidth + spacing
    return max(1, Int(availableWidth / totalUnitWidth))
}
```

**性能关键点：**
1. **必须使用 LazyVGrid**（不是 Grid）— 仅渲染可见项，支持大量照片
2. **缩略图按需加载** — .task(id:) 触发，120x120 用于网格，400x400 用于详情预览
3. **避免在行内进行图片解码** — 使用已解码的 Data 或缓存的 NSImage
4. **onAppear 触发分页** — 在最后一项出现时调用 loadNextPage()
5. **非阻塞分页错误** — paginationError 横幅展示在网格底部，网格保持可滚动

### 缩略图加载策略

当前实现使用协议方法按需加载缩略图：

- **PhotoLibraryViewModel.loadThumbnail(for:)** — 调用 `repository.fetchThumbnail(for: photo.id, size: CGSize(width: 120, height: 120))`
- **PhotoLibraryViewModel.loadPreview(for:)** — 调用 `repository.fetchThumbnail(for: photo.id, size: CGSize(width: 400, height: 400))`
- **PhotoThumbnailView** — 通过 `.task(id: photo.id)` 触发缩略图加载
- **PhotoDetailSheet** — 通过 `.task` 触发预览图加载

LocalFolderRepository 内部委托 ExifMetadataReader.generateThumbnail(from:targetSize:) 使用 CGImageSource 生成缩略图。

### 无限滚动实现

```swift
// 在 LazyVGrid 的最后一项 onAppear 中检测
PhotoThumbnailView(photo: photo, onTap: {
    viewModel.selectPhoto(photo)
}, viewModel: viewModel)
.onAppear {
    if photo.id == viewModel.photos.last?.id && viewModel.hasMorePages {
        Task {
            await viewModel.loadNextPage()
        }
    }
}
```

### 文件组织

本 Story 创建/修改的文件：

```
Curator/
├── Features/
│   └── PhotoLibrary/
│       ├── PhotoLibraryViewModel.swift      # @MainActor ViewModel
│       ├── PhotoGridView.swift              # LazyVGrid 网格视图
│       ├── PhotoThumbnailView.swift         # 缩略图子视图
│       ├── PhotoDetailSheet.swift           # 照片详情 Sheet
│       └── GridColumnCalculator.swift       # 网格列数计算工具

CuratorTests/
├── Features/
│   └── PhotoLibrary/
│       ├── PhotoLibraryViewModelTests.swift
│       └── GridColumnCalculatorTests.swift
```

### 技术要求

- **Swift 6 strict concurrency**：ViewModel 用 @MainActor，所有跨线程传递用 Sendable 值类型
- **macOS 15+ API**：可使用 LazyVGrid、GridItem、.sheet() 等最新 API
- **文件命名**：类型名即文件名
- **访问控制**：internal（默认）即可
- **不引入新依赖**：仅使用 SwiftUI 和已有的 Domain 模型
- **构建通过**：`xcodebuild build -scheme Curator -destination 'platform=macOS,arch=arm64'` 必须成功
- **无回归**：Story 1.1、1.2、1.3 的现有测试必须仍然通过

### UX 设计规格要求

本 Story 需满足以下 UX 设计规格 [Source: _bmad-output/planning-artifacts/ux-design-specification.md]：

1. **UX-DR13: 照片网格自适应列数** — 最小列宽 120pt，列间距 4pt，根据窗口宽度自动计算
2. **UX-DR15: 空状态处理** — 无照片友好提示 + 替代操作建议
3. **WCAG AA 无障碍** — 缩略图 VoiceOver 标签、键盘导航支持
4. **macOS 原生视觉语言** — 使用系统背景色、自适应亮色/暗色模式
5. **按钮层级** — 遵循 UX-DR17（如有按钮）

### 测试策略

**ATDD 测试优先级：**

- **[P0] ViewModel 测试**：验证分页逻辑、加载状态管理、错误处理（使用 MockPhotoLibraryRepository）
- **[P0] 网格列数计算**：验证自适应列数逻辑（120pt 最小列宽 + 4pt 间距）
- **[P1] 无限滚动测试**：验证 loadNextPage 触发条件和状态更新
- **[P1] 空状态测试**：验证无照片时的 LoadingState 处理
- **[P1] 缩略图加载测试**：验证按需加载逻辑

**Mock 策略**：使用 MockPhotoLibraryRepository（实现 PhotoLibraryRepository 协议），支持多页、错误、延迟配置。

```swift
private struct MockPhotoLibraryRepository: PhotoLibraryRepository {
    func requestReadAccess() async throws -> Bool { true }
    func requestWriteAccess() async throws -> Bool { false }
    func fetchAssets(predicate: PhotoPredicate, pageSize: Int, pageOffset: Int) async throws -> AssetPage { ... }
    func fetchFullResolutionImage(for assetID: AssetID) async throws -> Data { Data() }
    func fetchThumbnail(for assetID: AssetID, size: CGSize) async throws -> Data { Data() }
    func updateAsset(_ assetID: AssetID, title: String?) async throws {}
    func deleteAssets(_ assetIDs: [AssetID]) async throws {}
    func moveAssets(_ assetIDs: [AssetID], to directory: String) async throws {}
    func observeSourceChanges() -> AsyncStream<SourceChange> { AsyncStream { _ in } }
}
```

### Project Structure Notes

- Features/PhotoLibrary/ 目录包含所有照片浏览相关文件
- 新增文件通过 xcodegen 自动发现（project.yml 的 `sources: - Curator` 已配置递归发现）
- ContentView.swift 已正确集成 PhotoLibraryViewModel 和 AppDependencies

### References

- [Source: _bmad-output/planning-artifacts/architecture.md#决策1] — 分层架构（Presentation → Application → Domain → Infrastructure）
- [Source: _bmad-output/planning-artifacts/architecture.md#决策3] — 照片来源服务层（Repository 模式 + Actor 隔离 + 本地文件夹）
- [Source: _bmad-output/planning-artifacts/architecture.md#决策6] — 状态管理（@Observable + Observation 框架）
- [Source: _bmad-output/planning-artifacts/architecture.md#决策8] — 缓存策略（两级缓存，缩略图 NSCache 100MB）
- [Source: _bmad-output/planning-artifacts/architecture.md#决策9] — 错误处理模式（Typed Error + 分层错误传播）
- [Source: _bmad-output/planning-artifacts/epics.md#Story 1.4] — 原始需求定义（FR5, NFR2, NFR8, UX-DR13）
- [Source: _bmad-output/planning-artifacts/prd.md#照片图库访问] — FR2, FR3, FR5 功能需求
- [Source: _bmad-output/planning-artifacts/prd.md#性能] — NFR2（60fps 滚动）、NFR6（500MB 内存）、NFR8（200ms 加载）
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#Component Strategy] — LazyVGrid 用于照片网格
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#Responsive Strategy] — 照片网格自适应列数计算公式
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#Accessibility Strategy] — WCAG AA 合规要求
- [Source: _bmad-output/implementation-artifacts/1-3-local-folder-read-service.md] — Story 1.3 本地文件夹读取服务
- [Source: _bmad-output/project-context.md#Code Patterns] — SwiftUI 视图模式（200 行限制、Preview 覆盖亮暗色）
- [Source: _bmad-output/project-context.md#Architecture Boundaries] — 目录结构映射
- [Source: CLAUDE.md#Swift Conventions] — 避免命名类型为 Task

### ATDD Artifacts

- Checklist: `_bmad-output/test-artifacts/atdd-checklist-1-4-photo-library-browse-grid.md`
- API tests: `CuratorTests/Features/PhotoLibrary/PhotoLibraryViewModelTests.swift`
- API tests: `CuratorTests/Features/PhotoLibrary/GridColumnCalculatorTests.swift`

## Dev Agent Record

### Agent Model Used

GLM-5.1 (Claude Code)

### Debug Log References

No blocking issues encountered during implementation.

### Completion Notes List

- Task 1: Created PhotoLibraryViewModel with @MainActor, ObservableObject. Implements loadInitialPage(), loadNextPage() with pagination state tracking, concurrent load prevention. Repository injection via init parameter. Handles nil repository gracefully with failed state. Added updateRepository() for runtime repository registration. Implements loadThumbnail(for:) and loadPreview(for:) using fetchThumbnail protocol method. paginationError for non-blocking page failures.
- Task 2: Created PhotoGridView with LazyVGrid + ScrollView + GeometryReader. GridColumnCalculator extracted as testable utility (UX-DR13: min 120pt, 4pt spacing). Infinite scroll detection via onAppear on last item. Empty/loading/error/idle state views implemented (UX-DR15). Non-blocking pagination error banner. Sheet binding for photo detail.
- Task 3: Created PhotoThumbnailView with 120x120 frame, NSImage rendering, placeholder for nil thumbnailData. .task(id:) triggers on-demand thumbnail loading via ViewModel. Tap gesture for selection. VoiceOver accessibility label with date formatting.
- Task 4: Created PhotoDetailSheet displaying enlarged preview (400x400 via loadPreview), metadata rows (fileName, creationDate, cameraModel, dimensions, fileSize, gpsLocation). Missing fields show "-" placeholder. Static DateFormatter and ByteCountFormatter for reuse. Uses SwiftUI .sheet() modifier with toolbar close button.
- Task 5: Created GridColumnCalculator as pure static utility (columnCount, gridItems, minColumnWidth, spacing).
- Task 6: All ATDD tests passing. MockPhotoLibraryRepository supports multi-page, errors, delays. Build succeeds.

### File List

- Curator/Features/PhotoLibrary/PhotoLibraryViewModel.swift (new)
- Curator/Features/PhotoLibrary/PhotoGridView.swift (new)
- Curator/Features/PhotoLibrary/PhotoThumbnailView.swift (new)
- Curator/Features/PhotoLibrary/PhotoDetailSheet.swift (new)
- Curator/Features/PhotoLibrary/GridColumnCalculator.swift (new)
- Curator/ContentView.swift (modified)

### Change Log

- 2026-04-18: Story 1.4 implementation complete — Photo library browse grid with ViewModel, GridView, ThumbnailView, DetailSheet, GridColumnCalculator. All ATDD tests passing.
- 2026-04-18: Code review — 5 patches applied, 1 deferred. All tests still pass.
- 2026-04-20: Story 1.4 规格重写——MVP 照片来源从 PhotoKit 切换为本地文件夹。Presentation 层代码通过协议抽象无需修改。更新 Dev Notes 以反映本地文件夹架构（LocalFolderRepository、FolderBookmarkManager、ExifMetadataReader）。AssetMetadata 字段和 PhotoDetailSheet 展示内容更新。缩略图加载策略更新为使用 fetchThumbnail(for:size:) 协议方法。ContentView 集成方式更新。

### Review Findings

- [x] [Review][Patch] errorView displayed DomainError.localizedDescription directly — violated 3-layer error rule; fixed to use toUserFacingError() [PhotoGridView.swift]
- [x] [Review][Patch] loadNextPage error replaces entire loaded state losing photos — added comment clarifying preservation; same behavior but documented [PhotoLibraryViewModel.swift]
- [x] [Review][Patch] DateFormatter created per-view-body — extracted to static let for reuse [PhotoThumbnailView.swift, PhotoDetailSheet.swift]
- [x] [Review][Patch] updateRepository race: multiple loadInitialPage Tasks could spawn — now transitions to .loading immediately before Task [PhotoLibraryViewModel.swift]
- [x] [Review][Patch] ContentView double-creates AppDependencies — added convenience init for explicit dependency injection [ContentView.swift]
- [x] [Review][Defer] NSCache thumbnail cache (100MB) not implemented — deferred, depends on thumbnail loading strategy decision [AC3]
