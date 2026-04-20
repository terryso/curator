# Story 1.3: 本地文件夹读取服务

Status: todo

<!-- 重写说明：MVP 照片来源策略从 PhotoKit 切换为本地文件夹。
     原始实现基于 PhotoKit（PHAssetMapper、PhotoPermissionManager、PhotoKitRepository），
     已在 Story 1.2 重写时被移除。本 Story 实现基于文件系统的替代方案：
     LocalFolderRepository（actor）、FolderBookmarkManager、ExifMetadataReader。
     协议和领域模型已在 Story 1.2 中更新完毕，本 Story 实现具体基础设施层代码。 -->

## Story

As a 用户，
I want 选择照片文件夹并浏览其中的照片，
So that 我可以在 Curator 中查看所有照片。

## Acceptance Criteria

1. **AC1: 文件夹选择与访问持久化**
   **Given** 应用首次启动（FR1）
   **When** 引导用户选择照片文件夹
   **Then** 通过 NSOpenPanel 让用户选择目录，访问权限通过 security-scoped bookmark 持久化
   **And** 应用重启后无需重新选择文件夹

2. **AC2: 照片文件扫描与元数据读取**
   **Given** LocalFolderRepository 已获得文件夹访问权限（FR2, FR3）
   **When** 调用 fetchAssets()
   **Then** 递归扫描文件夹中的照片文件（JPEG、PNG、HEIC、TIFF、RAW），返回照片列表
   **And** 包含缩略图和 EXIF 元数据（日期、相机型号、尺寸、GPS 位置）

3. **AC3: 分页查询**
   **Given** 文件夹中有大量照片（10,000+）（FR5）
   **When** 使用分页参数调用 fetchAssets(predicate:pageSize:pageOffset:)
   **Then** 返回 AssetPage 包含当前页照片和下一页游标
   **And** 所有文件系统操作在 actor 内执行，不阻塞主线程

4. **AC4: 全分辨率图像访问**
   **Given** 需要访问照片全分辨率图像（FR7）
   **When** 调用 fetchFullResolutionImage(for: assetID)
   **Then** 返回该照片的全分辨率 Data，用于后续 AI 分析

## Tasks / Subtasks

- [ ] Task 1: 实现 FolderBookmarkManager (AC: #1)
  - [ ] 1.1 创建 `Curator/Infrastructure/PhotoSource/FolderBookmarkManager.swift` — 实现 FolderBookmarkManaging 协议
  - [ ] 1.2 实现 `selectAndBookmarkFolder()` — 通过 NSOpenPanel 选择目录，创建 security-scoped bookmark 并持久化到 UserDefaults
  - [ ] 1.3 实现 `loadBookmark()` — 从 UserDefaults 加载 bookmark data，恢复 security-scoped URL
  - [ ] 1.4 实现 `accessBookmark(_:)` / `releaseBookmark(_:)` — 调用 URL.startAccessingSecurityScopedResource() / stopAccessingSecurityScopedResource()
  - [ ] 1.5 实现 `hasValidBookmark` 和 `currentFolderURL` 属性

- [ ] Task 2: 实现 ExifMetadataReader (AC: #2)
  - [ ] 2.1 创建 `Curator/Infrastructure/PhotoSource/ExifMetadataReader.swift` — 使用 ImageIO 框架读取 EXIF
  - [ ] 2.2 实现 `readMetadata(from: URL) -> AssetMetadata` — 读取文件属性 + EXIF 元数据
  - [ ] 2.3 映射 CGImageProperties → AssetMetadata 字段（kCGImagePropertyEXIFCameraModel、kCGImagePropertyEXIFDateTimeOriginal、kCGImagePropertyGPSDictionary 等）
  - [ ] 2.4 实现 `generateThumbnail(from: URL, size: CGSize) -> Data?` — 使用 CGImageSourceCreateThumbnailAtIndex 生成缩略图
  - [ ] 2.5 处理缺失 EXIF 数据的降级（使用文件属性作为回退：fileSize、creationDate、fileName）

- [ ] Task 3: 实现 LocalFolderRepository actor (AC: #1, #2, #3, #4)
  - [ ] 3.1 创建 `Curator/Infrastructure/PhotoSource/LocalFolderRepository.swift` — actor 隔离的实现
  - [ ] 3.2 实现 `requestReadAccess()` — 通过 FolderBookmarkManager 加载或选择文件夹
  - [ ] 3.3 实现 `requestWriteAccess()` — 当前返回 false（Story 4.1 实现写入权限升级）
  - [ ] 3.4 实现 `fetchAssets(predicate:pageSize:pageOffset:)` — 递归扫描 + 过滤 + 分页
  - [ ] 3.5 实现 `fetchFullResolutionImage(for:)` — 从文件系统读取原始文件 Data
  - [ ] 3.6 实现 `fetchThumbnail(for:size:)` — 委托给 ExifMetadataReader 生成缩略图
  - [ ] 3.7 实现 `observeSourceChanges()` — 当前返回空 AsyncStream（Story 7.1 实现 DispatchSourceFileSystemObject）

- [ ] Task 4: 注册 LocalFolderRepository 到 AppDependencies (AC: #1, #2)
  - [ ] 4.1 更新 `Curator/App/AppDependencies.swift` — 填充 registerLocalFolderRepository() 方法

- [ ] Task 5: ATDD 测试和验证 (AC: #1, #2, #3, #4)
  - [ ] 5.1 创建 `CuratorTests/Infrastructure/PhotoSource/FolderBookmarkManagerTests.swift`
  - [ ] 5.2 创建 `CuratorTests/Infrastructure/PhotoSource/ExifMetadataReaderTests.swift`
  - [ ] 5.3 创建 `CuratorTests/Infrastructure/PhotoSource/LocalFolderRepositoryTests.swift`
  - [ ] 5.4 完整构建验证：`xcodebuild build` 成功
  - [ ] 5.5 运行全部测试确认无回归

## Dev Notes

### 架构约束

本 Story 实现 Infrastructure 层的本地文件夹集成。严格遵守以下规则：

1. **分层边界**：LocalFolderRepository 实现已在 Story 1.2 中定义的 `PhotoLibraryRepository` 协议。协议在 Domain 层（`Core/Models/PhotoLibraryRepository.swift`），实现在 Infrastructure 层（`Infrastructure/PhotoSource/LocalFolderRepository.swift`）。
2. **Actor 隔离**：LocalFolderRepository 必须是 `actor`，所有文件系统操作串行化执行，确保线程安全 [Source: architecture.md#决策3]。
3. **Swift 6 strict concurrency**：所有跨并发域传递的类型必须 `Sendable`。使用值类型（struct）传递数据。
4. **错误映射**：文件系统错误必须映射为 `InfrastructureError`，再通过 `.toDomainError()` 映射为 `DomainError` 向上传播 [Source: architecture.md#决策9]。
5. **避免命名冲突**：不使用 `Task` 作为类型名 [Source: CLAUDE.md#Swift Conventions]。

### Story 1.2 遗留上下文

Story 1.2 已完成以下工作（文件已存在）：
- `Curator/Core/Models/PhotoLibraryRepository.swift` — 协议已定义，含 requestReadAccess/requestWriteAccess/fetchAssets/fetchFullResolutionImage/fetchThumbnail/updateAsset/deleteAssets/moveAssets/observeSourceChanges
- `Curator/Core/Models/FolderBookmarkManaging.swift` — 书签管理协议已定义，本 Story 实现它
- `Curator/Core/Models/PhotoAsset.swift` — 照片资产值类型（Sendable）
- `Curator/Core/Models/AssetMetadata.swift` — EXIF 元数据值类型（Sendable）+ LocationData
- `Curator/Core/Models/AssetID.swift` — 文件路径的类型安全封装
- `Curator/Core/Models/FileFormat.swift` — 支持的照片文件格式枚举 + supportedExtensions
- `Curator/Core/Models/PhotoPredicate.swift` — 过滤条件（DateRange、FileFormatFilter）
- `Curator/Core/Models/AssetPage.swift` — 分页模型（assets + hasMore + nextOffset）
- `Curator/Core/Models/SourceChange.swift` — 来源变更事件枚举
- `Curator/Core/Models/LoadingState.swift` — 泛型加载状态枚举
- `Curator/Core/Errors/InfrastructureError.swift` — 已含 folderAccessDenied/folderScanFailed/fileNotFound/fileWriteFailed/bookmarkAccessFailed
- `Curator/Core/Errors/DomainError.swift` — 已含 insufficientPermission/assetNotFound/invalidState
- `Curator/Core/Errors/ErrorMapping.swift` — 已实现 InfrastructureError → DomainError → UserFacingError 映射
- `Curator/App/AppDependencies.swift` — DI 容器，含 `@Published var photoRepository: (any PhotoLibraryRepository)?` 和空的 `registerLocalFolderRepository()` 方法
- `Curator/Infrastructure/PhotoSource/.gitkeep` — 空目录占位（实现后删除）
- 项目使用 xcodegen（project.yml）管理配置，新文件自动发现
- `Curator/Infrastructure/Mock/MockPhotoLibraryRepository.swift` — 已实现所有协议方法的 Mock
- `Curator/Infrastructure/Mock/MockPhotoData.swift` — 测试用的 Mock 照片数据

**Story 1.2 关键教训**：
- xcodegen 会覆盖 entitlements 设置
- 测试 target 需要独立的 entitlements 文件（`CuratorTestsHost.entitlements`，无沙盒）
- Swift 6 strict concurrency 要求泛型关联值也满足 Sendable 约束
- XCTUnwrap autoclosure 不支持 async 调用，需要先 let 绑定

### Security-Scoped Bookmark API 要点

**创建书签：**
```swift
import AppKit

// NSOpenPanel 选择目录
let panel = NSOpenPanel()
panel.canChooseDirectories = true
panel.canChooseFiles = false
panel.allowsMultipleSelection = false
let response = await panel.beginSheetModal(for: window)

// 创建 security-scoped bookmark
let bookmarkData = try url.bookmarkData(
    options: .withSecurityScope,
    includingResourceValuesForKeys: nil,
    relativeTo: nil
)
// 持久化到 UserDefaults
UserDefaults.standard.set(bookmarkData, forKey: "folderBookmark")
```

**恢复书签访问：**
```swift
var isStale = false
let url = try URL(
    resolvingBookmarkData: bookmarkData,
    options: .withSecurityScope,
    relativeTo: nil,
    bookmarkDataIsStale: &isStale
)
// 开始访问
url.startAccessingSecurityScopedResource()
// ... 使用 url 进行文件操作 ...
// 结束访问
url.stopAccessingSecurityScopedResource()
```

**重要**：
- macOS 沙盒应用需要 entitlements 中声明 `com.apple.security.files.user-selected.read-write`（已配置）
- Security-scoped bookmark 在应用重启后仍然有效
- `startAccessingSecurityScopedResource()` 和 `stopAccessingSecurityScopedResource()` 必须成对调用
- 书签可能变 stale，需要检查 `bookmarkDataIsStale` 并在必要时重新创建

### ImageIO EXIF 读取 API 要点

**读取元数据：**
```swift
import ImageIO

guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any]

// EXIF 字典
let exif = properties?[kCGImagePropertyEXIFDictionary as String] as? [String: Any]
let cameraModel = properties?[kCGImagePropertyEXIFCameraModel as String] as? String  // 注意：实际在 TIFF 字典中
let dateTime = exif?[kCGImagePropertyEXIFDateTimeOriginal as String] as? String
let width = properties?[kCGImagePropertyPixelWidth as String] as? Int
let height = properties?[kCGImagePropertyPixelHeight as String] as? Int

// TIFF 字典（相机型号在这里）
let tiff = properties?[kCGImagePropertyTIFFDictionary as String] as? [String: Any]
let camera = tiff?[kCGImagePropertyTIFFModel as String] as? String

// GPS 字典
let gps = properties?[kCGImagePropertyGPSDictionary as String] as? [String: Any]
let latitude = gps?[kCGImagePropertyGPSLatitude as String] as? Double
let longitude = gps?[kCGImagePropertyGPSLongitude as String] as? Double
```

**生成缩略图：**
```swift
let options: [CFString: Any] = [
    kCGImageSourceThumbnailMaxPixelSize: max(size.width, size.height),
    kCGImageSourceCreateThumbnailFromImageAlways: true,
    kCGImageSourceShouldCacheImmediately: true
]
guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
let nsImage = NSImage(cgImage: thumbnail, size: size)
// 转换为 Data (PNG 或 JPEG)
guard let tiffData = nsImage.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiffData),
      let pngData = bitmap.representation(using: .png, properties: [:]) else { return nil }
return pngData
```

**重要**：
- CGImageSource 支持 JPEG、PNG、HEIC、TIFF，部分 RAW 格式可能需要系统编解码器
- EXIF 日期格式为 "yyyy:MM:dd HH:mm:ss"，需要自定义 DateFormatter 解析
- 并非所有照片都有 EXIF 数据，需要优雅降级到文件属性
- RAW 文件的元数据读取可能受限，需要测试具体格式支持

### FolderBookmarkManager 设计

```swift
import AppKit
import Foundation

/// Manages security-scoped folder bookmarks for photo library access.
///
/// Handles folder selection via NSOpenPanel, bookmark persistence,
/// and security-scoped resource access lifecycle.
struct FolderBookmarkManager: FolderBookmarkManaging, @unchecked Sendable {
    private let bookmarkKey = "folderBookmark"

    var hasValidBookmark: Bool { get async { ... } }
    var currentFolderURL: URL? { get async { ... } }
    func selectAndBookmarkFolder() async throws -> URL { ... }
    func loadBookmark() async throws -> URL? { ... }
    func accessBookmark(_ url: URL) throws -> Bool { ... }
    func releaseBookmark(_ url: URL) { ... }
}
```

**设计决策**：
- 使用 `struct` + `@unchecked Sendable`（因为内部状态通过 UserDefaults 和 URL 访问都是线程安全的）
- `selectAndBookmarkFolder()` 需要在 `@MainActor` 上执行（NSOpenPanel 需要 UI 线程）
- Bookmark 数据存储在 UserDefaults（简单的 key-value 存储，适合单个文件夹）
- 如果未来需要支持多个文件夹，可以改用 Keychain 或文件存储

### ExifMetadataReader 设计

```swift
import Foundation
import ImageIO
import AppKit

/// Reads EXIF metadata and generates thumbnails from photo files using ImageIO.
struct ExifMetadataReader: Sendable {
    /// Reads file system and EXIF metadata from a photo file.
    static func readMetadata(from url: URL) -> AssetMetadata { ... }

    /// Generates a thumbnail image at the specified size.
    static func generateThumbnail(from url: URL, targetSize: CGSize) -> Data? { ... }
}
```

**映射关系：**
- `URL.lastPathComponent` → `AssetMetadata.fileName`
- `FileManager.attributesOfItem(atPath:)` → `fileSize`, `creationDate`（回退值）
- `CGImageSourceCopyPropertiesAtIndex` → `cameraModel`, `imageWidth`, `imageHeight`
- `kCGImagePropertyGPSDictionary` → `LocationData`
- `FileFormat.from(pathExtension:)` → `fileFormat`

### LocalFolderRepository actor 设计

```swift
import Foundation

/// Concrete implementation of PhotoLibraryRepository using local folder file system.
///
/// All file system operations are serialized within this actor to ensure
/// thread safety. Infrastructure errors are mapped to DomainError
/// before propagating to the Domain layer.
actor LocalFolderRepository: PhotoLibraryRepository {
    private let bookmarkManager: FolderBookmarkManaging
    private let metadataReader: ExifMetadataReader.Type
    private var folderURL: URL?
    private var isAccessing: Bool = false

    init(bookmarkManager: FolderBookmarkManaging = FolderBookmarkManager()) {
        self.bookmarkManager = bookmarkManager
        self.metadataReader = ExifMetadataReader.self
    }

    func requestReadAccess() async throws -> Bool { ... }
    func requestWriteAccess() async throws -> Bool { ... }
    func fetchAssets(predicate: PhotoPredicate, pageSize: Int, pageOffset: Int) async throws -> AssetPage { ... }
    func fetchFullResolutionImage(for assetID: AssetID) async throws -> Data { ... }
    func fetchThumbnail(for assetID: AssetID, size: CGSize) async throws -> Data { ... }
    func observeSourceChanges() -> AsyncStream<SourceChange> { ... }
}
```

**文件扫描策略：**
- 使用 `FileManager.enumerator(at:includingPropertiesForKeys:options:)` 递归扫描
- 过滤条件：仅包含 `FileFormat.supportedExtensions` 中的文件扩展名
- 排序：按文件创建日期降序（最新的照片排在前面）
- 分页：使用内存中的文件列表 + offset/limit 切片
- 首次扫描后缓存文件列表，后续请求直接从缓存分页

**性能考量（NFR5, NFR6）**：
- 10,000 张照片的元数据扫描应在 60 秒内完成
- 内存使用保持在 500MB 以下
- 分页加载避免一次性加载所有照片到内存
- 缩略图按需生成，不预先生成所有缩略图

### 文件组织

本 Story 需创建/修改的文件：

```
Curator/
├── Infrastructure/
│   └── PhotoSource/
│       ├── LocalFolderRepository.swift   # 新建：actor 实现 PhotoLibraryRepository 协议
│       ├── FolderBookmarkManager.swift   # 新建：security-scoped bookmark 管理
│       ├── ExifMetadataReader.swift      # 新建：ImageIO EXIF 读取 + 缩略图生成
│       └── .gitkeep                      # 删除
├── App/
│   └── AppDependencies.swift             # 修改：填充 registerLocalFolderRepository()

CuratorTests/
├── Infrastructure/
│   └── PhotoSource/
│       ├── FolderBookmarkManagerTests.swift      # 新建
│       ├── ExifMetadataReaderTests.swift         # 新建
│       └── LocalFolderRepositoryTests.swift      # 新建
```

### 技术要求

- **Swift 6 strict concurrency**：所有值类型标记 `Sendable`，LocalFolderRepository 用 `actor`
- **文件命名**：类型名即文件名
- **访问控制**：internal（默认）即可
- **不引入新依赖**：仅使用 Foundation、ImageIO、AppKit（系统框架）
- **构建通过**：`xcodebuild build -scheme Curator -destination 'platform=macOS,arch=arm64'` 必须成功
- **无回归**：Story 1.1 和 1.2 的现有测试必须仍然通过
- **import 语句**：FolderBookmarkManager 需要 `import AppKit`（NSOpenPanel），ExifMetadataReader 需要 `import ImageIO` 和 `import AppKit`

### 关于 import 和构建系统

`import ImageIO` 和 `import AppKit` 是 macOS SDK 的系统框架，xcodegen 会自动链接。project.yml 的 sources 配置已设置递归发现（`sources: - Curator`），新文件无需手动添加。

### 测试策略

**ATDD 测试优先级：**

- **[P0] 书签管理测试**：验证书签创建、加载、stale 处理、访问生命周期
- **[P0] EXIF 元数据读取测试**：验证 AssetMetadata 映射的完整性（使用临时文件）
- **[P0] LocalFolderRepository 测试**：验证协议一致性、分页、错误处理
- **[P1] 缩略图生成测试**：验证缩略图尺寸和格式
- **[P1] 分页测试**：验证 AssetPage 分页逻辑和边界条件

**Mock 策略**：
- FolderBookmarkManager：可以创建 MockFolderBookmarkManager 用于 LocalFolderRepository 测试
- ExifMetadataReader：使用静态方法，可直接测试
- 文件系统操作：使用临时目录（`FileManager.default.temporaryDirectory`）创建测试文件

### Project Structure Notes

- 目录结构严格遵循架构文档的 Feature-based 组织 [Source: architecture.md#完整项目目录结构]
- Infrastructure/PhotoSource/ 已有 .gitkeep 占位，实现后删除
- 新增文件通过 xcodegen 自动发现（project.yml 的 `sources: - Curator` 已配置递归发现）
- 测试 target 镜像源码结构：CuratorTests/Infrastructure/PhotoSource/
- CuratorTests 使用独立 entitlements（无沙盒），避免测试运行器权限问题

### References

- [Source: _bmad-output/planning-artifacts/architecture.md#决策1] — 分层架构 + 依赖注入
- [Source: _bmad-output/planning-artifacts/architecture.md#决策3] — 照片来源服务层（Repository 模式 + Actor 隔离 + 可插拔来源）
- [Source: _bmad-output/planning-artifacts/architecture.md#决策9] — 错误处理模式（分层错误传播）
- [Source: _bmad-output/planning-artifacts/architecture.md#基础设施层] — Infrastructure/PhotoSource/ 目录结构
- [Source: _bmad-output/planning-artifacts/epics.md#Story 1.3] — 原始需求定义（FR1, FR2, FR3, FR5, FR7）
- [Source: _bmad-output/planning-artifacts/prd.md#照片图库访问] — FR1-FR7 功能需求
- [Source: _bmad-output/planning-artifacts/prd.md#性能] — NFR5（60 秒索引 10000 张）、NFR6（500MB 内存）、NFR7（UI 响应）
- [Source: _bmad-output/planning-artifacts/prd.md#集成质量] — NFR19（权限变更处理）、NFR23（部分结果处理）
- [Source: _bmad-output/implementation-artifacts/1-2-layered-architecture-skeleton.md] — Story 1.2 完成记录和教训
- [Source: _bmad-output/project-context.md#Architecture Boundaries] — 目录结构映射和测试目录镜像
- [Source: CLAUDE.md#Swift Conventions] — 避免命名类型为 Task

### ATDD Artifacts

- Checklist: `_bmad-output/test-artifacts/atdd-checklist-1-3-local-folder-read-service.md`
- API tests: `CuratorTests/Infrastructure/PhotoSource/FolderBookmarkManagerTests.swift`
- API tests: `CuratorTests/Infrastructure/PhotoSource/ExifMetadataReaderTests.swift`
- API tests: `CuratorTests/Infrastructure/PhotoSource/LocalFolderRepositoryTests.swift`

## Change Log

- 2026-04-18: Story 1.3 原始实现完成（基于 PhotoKit）
- 2026-04-20: Story 1.3 重写规格——MVP 照片来源从 PhotoKit 切换为本地文件夹。所有 PhotoKit 相关组件（PHAssetMapper、PhotoPermissionManager、PhotoKitRepository）替换为文件系统组件（ExifMetadataReader、FolderBookmarkManager、LocalFolderRepository）。协议和领域模型已在 Story 1.2 中更新完毕，本 Story 仅实现基础设施层代码。

## Dev Agent Record

### Agent Model Used

(待实现时填写)

### Debug Log References

(待实现时填写)

### Completion Notes List

(待实现时填写)

### File List

(待实现时填写)
