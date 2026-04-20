---
title: 'Story 1.3: 本地文件夹读取服务'
type: 'feature'
created: '2026-04-20'
status: 'review-complete'
context:
  - '_bmad-output/implementation-artifacts/epic-1-context.md'
  - '_bmad-output/implementation-artifacts/1-3-local-folder-read-service.md'
baseline_commit: '57723c7'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** PhotoLibraryRepository 协议和 FolderBookmarkManaging 协议已由 Story 1.2 定义，但尚无具体的基础设施层实现。应用无法访问文件系统、扫描照片或读取元数据。

**Approach:** 实现三个基础设施组件：FolderBookmarkManager（security-scoped bookmark 持久化）、ExifMetadataReader（ImageIO EXIF 读取）、LocalFolderRepository（actor，文件系统扫描），并将它们注册到 AppDependencies。

## Boundaries & Constraints

**Always:**
- LocalFolderRepository 必须是 actor，所有文件 I/O 在 actor 内串行执行
- 所有跨并发域类型必须 Sendable
- 文件系统错误映射为 InfrastructureError → DomainError → UserFacingError
- 不命名任何类型为 Task
- import ImageIO 用于 EXIF 读取，import AppKit 用于 NSOpenPanel/NSImage
- ExifMetadataReader 使用静态方法（无状态 struct）

**Ask First:**
- 如需修改 PhotoLibraryRepository 或 FolderBookmarkManaging 协议签名
- 如需引入新的第三方依赖

**Never:**
- 不实现写入操作（deleteAssets/moveAssets/updateAsset 留空，Story 4.1 实现）
- 不实现 observeSourceChanges（返回空流，Story 7.1 实现）
- 不使用 PhotoKit
- 不在 Infrastructure 层直接 import SwiftUI

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| 首次选择文件夹 | 无 bookmark 存在 | NSOpenPanel 弹出，用户选择后创建 bookmark 并持久化 | 用户取消返回 nil |
| 恢复已有 bookmark | bookmark data 在 UserDefaults | 反序列化 URL，startAccessingSecurityScopedResource | bookmark stale 时重新请求选择 |
| 扫描空文件夹 | 文件夹内无图片 | 返回空 AssetPage（assets=[], hasMore=false） | N/A |
| 扫描含混合文件的文件夹 | 文件夹含 jpg/png/heic/tiff/raw + 非图片 | 仅返回 supportedExtensions 中的文件 | 非图片文件静默跳过 |
| 分页请求 | pageSize=100, pageOffset=200 | 返回第 201-300 个资产 | 超出范围返回空页 |
| 读取无 EXIF 的图片 | 纯 PNG 截图 | 返回文件属性作为回退（fileName/fileSize/creationDate/fileFormat） | 缺失字段为 nil |
| 访问不存在的文件 | assetID 指向已删除文件 | 抛出 DomainError.assetNotFound | InfrastructureError.fileNotFound 映射链 |
| 生成缩略图 | 任意支持格式的文件 | 返回指定尺寸的 PNG Data | 损坏文件返回 nil |

</frozen-after-approval>

## Code Map

- `Curator/Core/Models/PhotoLibraryRepository.swift` -- 协议定义（已存在，实现它）
- `Curator/Core/Models/FolderBookmarkManaging.swift` -- bookmark 协议（已存在，实现它）
- `Curator/Core/Models/AssetMetadata.swift` -- 元数据模型（已存在，ExifMetadataReader 产出它）
- `Curator/Core/Models/FileFormat.swift` -- 文件格式枚举 + supportedExtensions（已存在）
- `Curator/Core/Models/PhotoAsset.swift` -- 照片资产模型（已存在）
- `Curator/Core/Models/AssetPage.swift` -- 分页模型（已存在）
- `Curator/Core/Models/PhotoPredicate.swift` -- 过滤条件（已存在）
- `Curator/Core/Errors/InfrastructureError.swift` -- 文件系统错误变体（已存在）
- `Curator/Core/Errors/ErrorMapping.swift` -- 错误映射链（已存在）
- `Curator/App/AppDependencies.swift` -- DI 容器（已存在，填充 registerLocalFolderRepository）
- `Curator/Infrastructure/PhotoSource/.gitkeep` -- 占位文件（实现后删除）
- `Curator/Infrastructure/Mock/MockPhotoLibraryRepository.swift` -- Mock 实现（已存在，不修改）

## Tasks & Acceptance

**Execution:**
- [x] `Curator/Infrastructure/PhotoSource/FolderBookmarkManager.swift` -- 实现 FolderBookmarkManaging 协议：selectAndBookmarkFolder（NSOpenPanel + bookmark data 持久化到 UserDefaults）、loadBookmark（恢复 URL）、accessBookmark/releaseBookmark（security-scoped resource 生命周期） -- AC1
- [x] `Curator/Infrastructure/PhotoSource/ExifMetadataReader.swift` -- 实现 EXIF 读取：readMetadata（CGImageSource → AssetMetadata，EXIF 日期解析，GPS 提取，文件属性回退）、generateThumbnail（CGImageSourceCreateThumbnailAtIndex → PNG Data） -- AC2
- [x] `Curator/Infrastructure/PhotoSource/LocalFolderRepository.swift` -- actor 实现 PhotoLibraryRepository：requestReadAccess（委托 FolderBookmarkManager）、fetchAssets（FileManager 递归扫描 + FileFormat 过滤 + 分页切片）、fetchFullResolutionImage（FileHandle.readData）、fetchThumbnail（委托 ExifMetadataReader）、requestWriteAccess 返回 false、observeSourceChanges 返回空流 -- AC1-4
- [x] `Curator/App/AppDependencies.swift` -- 填充 registerLocalFolderRepository() 方法，创建 FolderBookmarkManager 和 LocalFolderRepository 实例并赋值 photoRepository -- AC1
- [x] `Curator/Infrastructure/PhotoSource/.gitkeep` -- 删除占位文件
- [x] `CuratorTests/Infrastructure/PhotoSource/FolderBookmarkManagerTests.swift` -- 书签管理测试：协议一致性、bookmark 创建/加载/持久化、security-scoped 访问生命周期 -- AC1
- [x] `CuratorTests/Infrastructure/PhotoSource/ExifMetadataReaderTests.swift` -- EXIF 读取测试：元数据字段映射、缺失 EXIF 回退、缩略图生成、损坏文件处理 -- AC2
- [x] `CuratorTests/Infrastructure/PhotoSource/LocalFolderRepositoryTests.swift` -- Repository 测试：actor 类型、协议一致性、递归扫描、分页、过滤、全分辨率读取、错误路径 -- AC1-4

**Acceptance Criteria:**
- Given 应用首次启动, when 引导选择照片文件夹, then NSOpenPanel 选择目录并持久化 bookmark，重启后无需重新选择
- Given LocalFolderRepository 已获得权限, when 调用 fetchAssets(), then 递归扫描照片文件返回含缩略图和 EXIF 元数据的列表
- Given 文件夹有大量照片, when 使用分页参数, then 返回 AssetPage 含当前页和下一页游标，所有 I/O 在 actor 内执行
- Given 需要全分辨率图像, when 调用 fetchFullResolutionImage, then 返回文件原始 Data

## Spec Change Log

## Design Notes

**EXIF 日期格式：** EXIF DateTimeOriginal 格式为 "yyyy:MM:dd HH:mm:ss"，需要自定义 DateFormatter：
```swift
let formatter = DateFormatter()
formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
```

**缩略图生成策略：** 使用 CGImageSourceCreateThumbnailAtIndex 而非先解码全图再缩放，避免大文件的内存峰值。选项 kCGImageSourceCreateThumbnailFromImageAlways 确保即使文件无嵌入缩略图也能生成。

**文件扫描缓存：** 首次扫描时将所有匹配文件路径缓存到内存数组，后续分页请求直接从缓存切片。每次 fetchAssets 带相同 predicate 时不重新扫描。这意味着外部新增文件需要重新请求扫描（未来 Story 7.1 的 FileSystemWatcher 会触发缓存失效）。

**Bookmark 存储：** 使用 UserDefaults 而非 Keychain，因为 bookmark data 不是敏感凭证，且单文件夹场景下 key-value 存储足够。

## Verification

**Commands:**
- `xcodebuild build -scheme Curator -destination 'platform=macOS,arch=arm64'` -- expected: BUILD SUCCEEDED
- `xcodebuild test -scheme Curator -destination 'platform=macOS,arch=arm64'` -- expected: all tests pass, 0 failures
