# Story 1.3: PhotoKit 读取服务

Status: review

## Story

As a 用户，
I want 授予应用照片图库读取权限并浏览我的照片，
So that 我可以在 Curator 中查看所有照片和相册。

## Acceptance Criteria

1. **AC1: 读取权限请求**
   **Given** 应用首次启动且未获得照片权限（FR1）
   **When** 请求读取权限
   **Then** 系统弹出权限对话框，用户授权后 PhotoKitRepository 可读取图库
   **And** 用户拒绝时返回友好的错误提示，引导至系统设置

2. **AC2: 照片资产获取与映射**
   **Given** PhotoKitRepository 已获得读取权限（FR2, FR3）
   **When** 调用 fetchAssets()
   **Then** 返回照片列表，包含缩略图和元数据（日期、标题、描述、关键词、位置）
   **And** PHAssetMapper 正确将 PHAsset 映射为领域模型 PhotoAsset

3. **AC3: 分页查询**
   **Given** 图库中有大量照片（10,000+）（FR5）
   **When** 使用分页参数调用 fetchAssets(pageSize: 100)
   **Then** 返回 AssetPage 包含当前页照片和下一页游标
   **And** 所有 PhotoKit 操作在 actor 内执行，不阻塞主线程

4. **AC4: 全分辨率图像访问**
   **Given** 需要访问照片全分辨率图像（FR7）
   **When** 调用 fetchFullResolutionImage(for: assetID)
   **Then** 返回该照片的全分辨率 Data，用于后续 AI 分析

## Tasks / Subtasks

- [x] Task 1: 实现 PHAssetMapper (AC: #2)
  - [x] 1.1 创建 `Curator/Infrastructure/PhotoKit/PHAssetMapper.swift` — PHAsset → PhotoAsset 映射器
  - [x] 1.2 映射 PHAsset.localIdentifier → AssetID
  - [x] 1.3 映射 PHAsset 属性 → AssetMetadata（creationDate、title、description、keywords、location）
  - [x] 1.4 实现缩略图数据获取（PHImageManager，目标尺寸 200x200）

- [x] Task 2: 实现 PhotoPermissionManager (AC: #1)
  - [x] 2.1 创建 `Curator/Infrastructure/PhotoKit/PhotoPermissionManager.swift`
  - [x] 2.2 实现 requestReadAccess() — 调用 PHPhotoLibrary.requestAuthorization(for: .readWrite)
  - [x] 2.3 处理授权状态：.notDetermined → 弹对话框，.denied/.restricted → 返回错误+引导信息，.authorized/.limited → 返回成功
  - [x] 2.4 实现 checkCurrentStatus() — 查询当前权限状态

- [x] Task 3: 实现 PhotoKitRepository actor (AC: #2, #3, #4)
  - [x] 3.1 创建 `Curator/Infrastructure/PhotoKit/PhotoKitRepository.swift` — actor 隔离的实现
  - [x] 3.2 实现 `requestReadAccess()` — 委托给 PhotoPermissionManager
  - [x] 3.3 实现 `requestWriteAccess()` — 占位，返回 false（Story 4.1 实现写入）
  - [x] 3.4 实现 `fetchAssets(predicate:pageSize:)` — PHAsset.fetchAssets(with:options:) + 分页
  - [x] 3.5 实现 `fetchFullResolutionImage(for:)` — PHImageManager 全尺寸请求
  - [x] 3.6 所有 PHImageManager 请求使用异步包装（PHImageManager 的 completion handler → async/await）

- [x] Task 4: 扩展 PhotoPredicate 和 AssetPage 支持分页 (AC: #3)
  - [x] 4.1 更新 `Curator/Core/Models/PhotoPredicate.swift` — 扩展过滤条件（日期范围、媒体类型等）
  - [x] 4.2 更新 `Curator/Core/Models/AssetPage.swift` — 添加分页游标信息（fetchOffset）

- [x] Task 5: 注册 PhotoKitRepository 到 AppDependencies (AC: #1, #2)
  - [x] 5.1 更新 `Curator/App/AppDependencies.swift` — 添加 registerPhotoKitRepository() 方法
  - [x] 5.2 在 App 启动时调用注册方法

- [x] Task 6: ATDD 测试和验证 (AC: #1, #2, #3, #4)
  - [x] 6.1 创建 `CuratorTests/Infrastructure/PhotoKit/PHAssetMapperTests.swift`
  - [x] 6.2 创建 `CuratorTests/Infrastructure/PhotoKit/PhotoPermissionManagerTests.swift`
  - [x] 6.3 创建 `CuratorTests/Infrastructure/PhotoKit/PhotoKitRepositoryTests.swift`（含 Mock 数据）
  - [x] 6.4 完整构建验证：`xcodebuild build` 成功
  - [x] 6.5 运行全部测试确认无回归

## Dev Notes

### 架构约束

本 Story 实现 Infrastructure 层的 PhotoKit 集成。严格遵守以下规则：

1. **分层边界**：PhotoKitRepository 实现已在 Story 1.2 中定义的 `PhotoLibraryRepository` 协议。协议在 Domain 层（`Core/Models/PhotoLibraryRepository.swift`），实现在 Infrastructure 层（`Infrastructure/PhotoKit/PhotoKitRepository.swift`）。
2. **Actor 隔离**：PhotoKitRepository 必须是 `actor`，所有 PhotoKit 操作串行化执行，确保线程安全 [Source: architecture.md#决策3]。
3. **Swift 6 strict concurrency**：所有跨并发域传递的类型必须 `Sendable`。使用值类型（struct）传递数据。
4. **错误映射**：PhotoKit 错误必须映射为 `InfrastructureError`，再通过 `.toDomainError()` 映射为 `DomainError` 向上传播 [Source: architecture.md#决策9]。
5. **避免命名冲突**：不使用 `Task` 作为类型名 [Source: CLAUDE.md#Swift Conventions]。

### Story 1.2 遗留上下文

Story 1.2 已完成以下工作（文件已存在）：
- `Curator/Core/Models/PhotoLibraryRepository.swift` — 协议已定义，本 Story 实现它
- `Curator/Core/Models/PhotoAsset.swift` — 照片资产值类型（Sendable）
- `Curator/Core/Models/AssetMetadata.swift` — 元数据值类型（Sendable）+ LocationData
- `Curator/Core/Models/AssetID.swift` — PHAsset.localIdentifier 的类型安全封装
- `Curator/Core/Models/PhotoPredicate.swift` — 当前为占位类型（rawValue: String），需扩展
- `Curator/Core/Models/AssetPage.swift` — 分页模型，当前仅含 assets + hasMore
- `Curator/Core/Models/LoadingState.swift` — 泛型加载状态枚举
- `Curator/Core/Errors/InfrastructureError.swift` — 已含 `.photoKitAccessDenied` 和 `.photoKitFetchFailed`
- `Curator/Core/Errors/DomainError.swift` — 已含 `.insufficientPermission` 和 `.assetNotFound`
- `Curator/Core/Errors/ErrorMapping.swift` — 已实现 InfrastructureError → DomainError → UserFacingError 映射
- `Curator/App/AppDependencies.swift` — DI 容器，含 `@Published var photoRepository: (any PhotoLibraryRepository)?`
- `Curator/Infrastructure/PhotoKit/.gitkeep` — 空目录占位（实现后删除）
- 项目使用 xcodegen（project.yml）管理配置，新文件自动发现

**Story 1.2 关键教训**：
- xcodegen 会覆盖 entitlements 设置
- 测试 target 需要独立的 entitlements 文件（`CuratorTestsHost.entitlements`，无沙盒）
- Swift 6 strict concurrency 要求泛型关联值也满足 Sendable 约束
- XCTUnwrap autoclosure 不支持 async 调用，需要先 let 绑定

### PhotoKit API 要点

**权限请求：**
```swift
import Photos

// PHPhotoLibrary.authorizationStatus(for: .readWrite)
// PHPhotoLibrary.requestAuthorization(for: .readWrite)
// 状态：.notDetermined, .restricted, .denied, .authorized, .limited
```

**注意**：macOS 沙盒应用需要 entitlements 中声明 `com.apple.security.personal-information.photos`（已配置）。

**PHAsset 获取：**
```swift
let fetchOptions = PHFetchOptions()
fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
fetchOptions.fetchLimit = pageSize
// fetchOffset 用于分页
let fetchResult = PHAsset.fetchAssets(with: .image, options: fetchOptions)
```

**PHImageManager 缩略图获取：**
```swift
let options = PHImageRequestOptions()
options.deliveryMode = .opportunistic
options.isSynchronous = false
options.resizeMode = .fast
// 目标尺寸：CGSize(width: 200, height: 200) 用于缩略图
PHImageManager.default().requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFill, options: options) { image, _ in ... }
```

**全分辨率图像获取：**
```swift
let options = PHImageRequestOptions()
options.deliveryMode = .highQualityFormat
options.isSynchronous = false
options.resizeMode = .none
PHImageManager.default().requestImageDataAndOrientation(for: asset, options: options) { data, _, _, _, _ in ... }
```

**关键注意**：
- PHImageManager 的 completion handler 在任意线程回调，需要正确处理线程安全
- 在 actor 内部使用时，需要将 completion handler 包装为 async/await（使用 withCheckedThrowingContinuation 或 withUnsafeContinuation）
- PHFetchResult 的 index 访问是线程安全的，但需要确保在正确的上下文中使用
- iCloud 照片可能返回 nil（尚未下载），需要优雅处理（NFR23）

### PHAssetMapper 设计

```swift
/// Maps PHAsset from PhotoKit to domain model PhotoAsset.
struct PHAssetMapper: Sendable {
    /// Maps a PHAsset to a PhotoAsset with optional thumbnail data.
    static func map(_ phAsset: PHAsset, thumbnailData: Data?) -> PhotoAsset

    /// Maps PHAsset properties to AssetMetadata.
    static func mapMetadata(_ phAsset: PHAsset) -> AssetMetadata

    /// Maps PHAsset.location to LocationData.
    static func mapLocation(_ phAsset: PHAsset) -> LocationData?
}
```

**映射关系：**
- `PHAsset.localIdentifier` → `AssetID(rawValue:)`
- `PHAsset.creationDate` → `AssetMetadata.creationDate`
- `PHAsset.title`（通过 `.localizedTitle` 或 PHAsset 的高亮信息）→ `AssetMetadata.title`（注意：标准 PHAsset 没有 title 属性，需要通过 `PHAssetResource.assetResources(for:)` 获取原始文件名）
- `PHAsset.description` → `AssetMetadata.description`（通过 `PHAsset.mediaSubtypes` 等信息无法直接获取描述，需要查看是否有相关 API）
- `PHAsset.keywords` → `AssetMetadata.keywords`（通过 `PHAsset.fetchAssets(withLocalIdentifiers:options:)` + PHFetchOptions 的 properties）
- `PHAsset.location` → `LocationData(latitude:, longitude:)`

**重要**：PHAsset 不直接提供 `title`、`description`、`keywords` 字段。这些元数据需要通过 `PHAssetChangeRequest` 或 `PHAssetCreationRequest` 的 API 来读取。在 macOS 上可以通过 `PHAsset` 的 `assetProperties` (macOS 14+) 或间接方法获取。如果 API 不支持直接读取，在 PhotoPredicate 和元数据映射中可先用可选值（nil），并在 Dev Notes 中注明限制，留待后续 Story 完善。

### PhotoKitRepository actor 设计

```swift
import Photos

/// Concrete implementation of PhotoLibraryRepository using PhotoKit.
///
/// All PhotoKit operations are serialized within this actor to ensure
/// thread safety. Infrastructure errors are mapped to DomainError
/// before propagating to the Domain layer.
actor PhotoKitRepository: PhotoLibraryRepository {
    private let permissionManager: PhotoPermissionManager

    init(permissionManager: PhotoPermissionManager = PhotoPermissionManager()) {
        self.permissionManager = permissionManager
    }

    func requestReadAccess() async throws -> Bool { ... }
    func requestWriteAccess() async throws -> Bool { ... }
    func fetchAssets(predicate: PhotoPredicate, pageSize: Int) async throws -> AssetPage { ... }
    func fetchFullResolutionImage(for assetID: AssetID) async throws -> Data { ... }
}
```

**分页实现策略：**
- `AssetPage` 需要扩展以支持分页游标。当前 `AssetPage` 仅有 `assets` 和 `hasMore`
- 分页通过 `PHFetchOptions.fetchOffset` 和 `fetchLimit` 实现
- 需要在 `AssetPage` 中添加 `nextOffset: Int?` 或类似字段来传递分页状态
- 或者使用 `PHFetchResult` 的 index 作为分页游标

**PHImageManager 异步包装：**
```swift
/// Wraps PHImageManager image request in async/await.
private func requestThumbnail(for asset: PHAsset, size: CGSize) async throws -> Data? {
    try await withCheckedThrowingContinuation { continuation in
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.isSynchronous = false
        options.resizeMode = .fast

        PHImageManager.default().requestImage(
            for: asset,
            targetSize: size,
            contentMode: .aspectFill,
            options: options
        ) { image, _ in
            if let image = image {
                continuation.resume(returning: image.pngData())
            } else {
                continuation.resume(returning: nil)
            }
        }
    }
}
```

**注意**：`withCheckedThrowingContinuation` 要求 resume 仅调用一次。PHImageManager 的 completion handler 可能被调用多次（progressive delivery）。需要使用 `isNetworkAccessAllowed = false` + `deliveryMode = .opportunistic` 来避免重复回调，或使用标志位确保只 resume 一次。更安全的做法是使用 `deliveryMode = .highQualityFormat` 或使用 `withUnsafeContinuation`。

### PhotoPermissionManager 设计

```swift
import Photos

/// Manages PhotoKit authorization status and permission requests.
///
/// Provides read/write permission checking and request methods.
/// Errors are mapped to InfrastructureError for consistent error handling.
struct PhotoPermissionManager: Sendable {
    /// Current authorization status for photo library access.
    var currentStatus: PHAuthorizationStatus {
        PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }

    /// Requests read access to the photo library.
    /// Returns true if granted, throws InfrastructureError.photoKitAccessDenied if denied.
    func requestReadAccess() async throws -> Bool { ... }
}
```

### 文件组织

本 Story 需创建/修改的文件：

```
Curator/
├── Infrastructure/
│   └── PhotoKit/
│       ├── PhotoKitRepository.swift      # 新建：actor 实现 PhotoLibraryRepository 协议
│       ├── PhotoPermissionManager.swift   # 新建：权限管理
│       ├── PHAssetMapper.swift           # 新建：PHAsset → 领域模型映射
│       └── .gitkeep                      # 删除
├── Core/
│   └── Models/
│       ├── PhotoPredicate.swift          # 修改：扩展过滤条件
│       └── AssetPage.swift               # 修改：添加分页游标
├── App/
│   └── AppDependencies.swift             # 修改：注册 PhotoKitRepository

CuratorTests/
├── Infrastructure/
│   └── PhotoKit/
│       ├── PHAssetMapperTests.swift      # 新建
│       ├── PhotoPermissionManagerTests.swift  # 新建
│       └── PhotoKitRepositoryTests.swift      # 新建
```

### 技术要求

- **Swift 6 strict concurrency**：所有值类型标记 `Sendable`，PhotoKitRepository 用 `actor`
- **文件命名**：类型名即文件名
- **访问控制**：internal（默认）即可
- **不引入新依赖**：仅使用 Photos 框架（系统框架）
- **构建通过**：`xcodebuild build -scheme Curator -destination 'platform=macOS,arch=arm64'` 必须成功
- **无回归**：Story 1.1 和 1.2 的现有测试必须仍然通过（当前 48 个测试）
- **import Photos**：PhotoKit 代码需要 `import Photos`，确保 project.yml 无需额外配置（系统框架自动链接）

### 关于 import Photos 和构建系统

`import Photos` 是 macOS SDK 的系统框架，xcodegen 会自动链接。project.yml 的 sources 配置已设置递归发现（`sources: - Curator`），新文件无需手动添加。

### 测试策略

**ATDD 测试优先级：**

- **[P0] 权限请求测试**：验证授权状态映射、拒绝时抛出正确错误
- **[P0] PHAssetMapper 测试**：验证 PHAsset → PhotoAsset 映射的完整性（使用 Mock PHAsset）
- **[P1] 分页测试**：验证 AssetPage 分页逻辑
- **[P1] 全分辨率图像获取测试**：验证图像数据获取和错误处理

**Mock 策略注意**：PHAsset、PHFetchResult、PHImageManager 是系统类，不易 mock。测试策略：
- PHAssetMapper：可以创建测试辅助方法测试映射逻辑
- PhotoKitRepository：使用协议级别的 mock（`MockPhotoLibraryRepository`）测试上层交互
- 集成测试依赖真实 PhotoKit 环境，在 ATDD 中使用 mock 替代
- 测试权限状态映射逻辑（不需要真实权限对话框）

### Project Structure Notes

- 目录结构严格遵循架构文档的 Feature-based 组织 [Source: architecture.md#完整项目目录结构]
- Infrastructure/PhotoKit/ 已有 .gitkeep 占位，实现后删除
- 新增文件通过 xcodegen 自动发现（project.yml 的 `sources: - Curator` 已配置递归发现）
- 测试 target 镜像源码结构：CuratorTests/Infrastructure/PhotoKit/
- CuratorTests 使用独立 entitlements（无沙盒），避免测试运行器权限问题

### References

- [Source: _bmad-output/planning-artifacts/architecture.md#决策3] — PhotoKit 服务层设计（Repository 模式 + Actor 隔离）
- [Source: _bmad-output/planning-artifacts/architecture.md#决策9] — 错误处理模式（分层错误传播）
- [Source: _bmad-output/planning-artifacts/architecture.md#基础设施层] — Infrastructure/PhotoKit/ 目录结构
- [Source: _bmad-output/planning-artifacts/epics.md#Story 1.3] — 原始需求定义（FR1, FR2, FR3, FR5, FR7）
- [Source: _bmad-output/planning-artifacts/prd.md#照片图库访问] — FR1-FR7 功能需求
- [Source: _bmad-output/planning-artifacts/prd.md#性能] — NFR5（60 秒索引 10000 张）、NFR6（500MB 内存）、NFR7（UI 响应）
- [Source: _bmad-output/planning-artifacts/prd.md#集成质量] — NFR19（权限变更处理）、NFR23（部分结果处理）
- [Source: _bmad-output/planning-artifacts/prd.md#PhotoKit API 约束] — 默认只读、元数据限制、大规模分页、沙盒边界
- [Source: _bmad-output/implementation-artifacts/1-2-layered-architecture-skeleton.md] — Story 1.2 完成记录和教训
- [Source: _bmad-output/project-context.md#Architecture Boundaries] — 目录结构映射和测试目录镜像
- [Source: CLAUDE.md#Swift Conventions] — 避免命名类型为 Task

### ATDD Artifacts

- Checklist: `_bmad-output/test-artifacts/atdd-checklist-1-3-photokit-read-service.md`
- API tests: `CuratorTests/Infrastructure/PhotoKit/PHAssetMapperTests.swift`
- API tests: `CuratorTests/Infrastructure/PhotoKit/PhotoPermissionManagerTests.swift`
- API tests: `CuratorTests/Infrastructure/PhotoKit/PhotoKitRepositoryTests.swift`

## Dev Agent Record

### Agent Model Used

Claude GLM-5.1

### Debug Log References

- Build fix: AssetPage Equatable conformance removed (PhotoAsset contains Data? which isn't Equatable)
- Build fix: PHAsset.fetchAssets(with: nil) -> PHAsset.fetchAssets(with: options) for .all mediaType
- Build fix: requestImageDataAndOrientation callback has 4 params not 5
- Info.plist: Added NSPhotoLibraryUsageDescription for PhotoKit access (required by macOS)
- Test environment: requestReadAccess() tests work in sandbox — authorized in test runner
- 2 tests skipped (iCloud-related) — expected in test environment without photo library access

### Completion Notes List

- Task 1: Implemented PHAssetMapper as Sendable struct with static map/mapMetadata/mapLocation methods. PHAsset.title and PHAsset.description not directly available via PHAsset API — left as nil per Dev Notes guidance.
- Task 2: Implemented PhotoPermissionManager as Sendable struct. requestReadAccess() uses PHPhotoLibrary.requestAuthorization(for: .readWrite). Handles all authorization states (.authorized/.limited -> true, .denied/.restricted/.notDetermined -> throw photoKitAccessDenied).
- Task 3: Implemented PhotoKitRepository as actor conforming to PhotoLibraryRepository. fetchAssets uses PHFetchOptions with fetchLimit for pagination. fetchFullResolutionImage uses async wrapper with NSLock to ensure single continuation resume. requestWriteAccess returns false (placeholder for Story 4.1).
- Task 4: Extended PhotoPredicate with dateRange, MediaType filter, and factory methods. Extended AssetPage with nextOffset cursor for pagination.
- Task 5: Added registerPhotoKitRepository() method to AppDependencies.
- Task 6: All 30 ATDD tests activated (XCTSkip removed). 90 total tests pass (48 existing + 42 new), 2 skipped (iCloud-related, expected). Build succeeds.

### File List

- Curator/Infrastructure/PhotoKit/PHAssetMapper.swift (new)
- Curator/Infrastructure/PhotoKit/PhotoPermissionManager.swift (new)
- Curator/Infrastructure/PhotoKit/PhotoKitRepository.swift (new)
- Curator/Core/Models/PhotoPredicate.swift (modified — added DateRange, MediaType, filter methods)
- Curator/Core/Models/AssetPage.swift (modified — added nextOffset, custom init)
- Curator/App/AppDependencies.swift (modified — added registerPhotoKitRepository())
- Curator/Info.plist (modified — added NSPhotoLibraryUsageDescription)
- CuratorTests/Infrastructure/PhotoKit/PHAssetMapperTests.swift (modified — activated tests)
- CuratorTests/Infrastructure/PhotoKit/PhotoPermissionManagerTests.swift (modified — activated tests)
- CuratorTests/Infrastructure/PhotoKit/PhotoKitRepositoryTests.swift (modified — activated tests)
