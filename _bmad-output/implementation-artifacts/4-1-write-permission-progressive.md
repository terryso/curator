# Story 4.1: 写入权限渐进授权

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a 用户，
I want 应用以只读模式启动，仅在需要写入时请求权限，
So that 我对应用的操作权限有完全控制。

## Acceptance Criteria

1. **AC1: 只读默认启动（FR37）**
   **Given** 应用默认以只读权限启动
   **When** 应用首次打开
   **Then** 仅请求文件夹读取权限
   **And** 不主动请求写入权限

2. **AC2: 按需写入权限升级（FR6）**
   **Given** Agent 需要执行写操作
   **When** 触发重命名、移动或元数据修改
   **Then** FolderBookmarkManager 请求写入权限（升级 security-scoped bookmark 为 read-write）
   **And** 用户授权后操作继续执行

3. **AC3: 权限拒绝降级处理（UX-DR9）**
   **Given** 用户拒绝写入权限
   **When** Agent 尝试写操作
   **Then** 展示引导至系统设置的说明
   **And** 操作结果被保存，用户授权后可重新执行

4. **AC4: 写操作实现（FR38, NFR15）**
   **Given** LocalFolderRepository 已获得写入权限
   **When** 执行 updateAsset/deleteAssets/moveAssets
   **Then** 操作仅修改文件名、目录结构和元数据
   **And** 原始图像文件像素数据绝不被修改（NFR15 零文件损坏）

5. **AC5: 权限状态 UI 指示（FR37）**
   **Given** 应用处于只读模式
   **When** 用户执行任何分析操作（去重检测、重命名建议）
   **Then** 分析正常执行，结果正常展示
   **And** 界面明确指示当前为只读模式

## Tasks / Subtasks

- [x] Task 1: FolderBookmarkManager 写入权限升级 (AC: #1, #2)
  - [x] 1.1 在 `FolderBookmarkManaging` 协议添加 `hasWriteAccess`、`grantWriteAccess()`、`revokeWriteAccess()`、`requestWriteConsent()` 方法
  - [x] 1.2 在 `FolderBookmarkManager` 实现写入权限管理 — 使用 UserDefaults 持久化写入权限状态
  - [x] 1.3 采用方案 A（简化版）— 避免二次 NSOpenPanel，通过 entitlements + 应用层标记管理权限
  - [x] 1.4 `selectAndBookmarkFolder()` 不需要修改 — bookmark 已包含 read-write 权限
  - [x] 1.5 添加 `hasWriteAccess` 计算属性 — 检查 UserDefaults 中的写入权限标记

- [x] Task 2: LocalFolderRepository 写操作实现 (AC: #2, #4)
  - [x] 2.1 实现 `requestWriteAccess()` — 调用 FolderBookmarkManager 的 requestWriteConsent()，返回是否获得权限
  - [x] 2.2 实现 `updateAsset(_:title:)` — 使用 FileManager.default.moveItem 重命名文件（仅修改文件名，不修改图像数据）
  - [x] 2.3 实现 `deleteAssets(_:)` — 移动文件到垃圾桶（FileManager.default.trashItem），而非永久删除
  - [x] 2.4 实现 `moveAssets(_:to:)` — 在源目录内创建子目录并移动文件
  - [x] 2.5 每个写操作前验证 `hasWriteAccess`，无权限时抛出 `DomainError.insufficientPermission(required: .write)`
  - [x] 2.6 移除现有 `nonisolated` 标记 — 写操作需要在 actor 隔离内执行

- [x] Task 3: 权限状态管理 (AC: #1, #3, #5)
  - [x] 3.1 创建 `Curator/Core/Models/PermissionState.swift` — `@Observable @MainActor` 类，管理读写权限状态
  - [x] 3.2 添加 `isReadOnly: Bool` 计算属性 — 基于 _writeAccessGranted 内部状态
  - [x] 3.3 添加 `requestWritePermission() async throws -> Bool` — 触发权限升级流程
  - [x] 3.4 在 `AppDependencies` 注册 `PermissionState`

- [x] Task 4: 权限拒绝降级与引导 (AC: #3)
  - [x] 4.1 修改 `ErrorMapping.swift` — `DomainError.insufficientPermission(required: .write)` 映射到更具体的用户提示
  - [x] 4.2 在 `UserFacingError` 添加 `writePermissionRequired` case — 包含引导至系统设置的说明文案
  - [x] 4.3 更新 `DomainError.toUserFacingError()` — 区分 read 和 write 权限不足的不同提示

- [x] Task 5: 只读模式 UI 指示 (AC: #5)
  - [x] 5.1 在 `MainWorkspaceView` 添加只读模式指示器 — 工具栏区域显示"只读模式"徽章
  - [x] 5.2 创建 `Curator/Features/Permission/WritePermissionPromptView.swift` — 权限请求提示组件
  - [x] 5.3 当 Agent 尝试写操作且无权限时，展示权限升级提示（内联 Sheet 或 Alert）

- [x] Task 6: ATDD 测试 (AC: #1, #2, #3, #4, #5)
  - [x] 6.1 创建 `CuratorTests/Infrastructure/PhotoSource/WritePermissionTests.swift`
  - [x] 6.2 [P0] testRequestWriteAccessUpgradesBookmark — 验证权限升级流程
  - [x] 6.3 [P0] testWriteOperationWithoutPermissionThrows — 无写权限时写操作抛出 insufficientPermission
  - [x] 6.4 [P0] testUpdateAssetRenamesFile — 重命名文件正确执行
  - [x] 6.5 [P0] testDeleteAssetsMovesToTrash — 删除操作移到垃圾桶而非永久删除
  - [x] 6.6 [P0] testMoveAssetsCreatesDirectoryAndMoves — 移动操作正确执行
  - [x] 6.7 [P1] testWritePermissionRefusedReturnsGracefully — 用户拒绝写入权限时优雅降级
  - [x] 6.8 [P1] testReadOnlyModeIndicatorVisible — 通过 PermissionState 单元测试验证
  - [x] 6.9 更新 `CuratorTests/Core/Errors/ErrorTypeTests.swift` — 添加 write 权限错误映射测试
  - [x] 6.10 构建通过 + 全部现有测试通过 (571 tests, 0 failures)

## Dev Notes

### 架构约束

1. **分层边界严格**：FolderBookmarkManaging 协议在 Core/Models，实现在 Infrastructure/PhotoSource。PermissionState 在 Core/Models。UI 提示在 Features/Permission。[Source: architecture.md#分层架构]
2. **@MainActor ViewModel**：PermissionState 标记 `@Observable @MainActor`。[Source: project-context.md#Critical Implementation Rules]
3. **Sendable 类型**：PermissionLevel 已是 Sendable enum。新增 PermissionState 为 @Observable class（@MainActor 隔离）。[Source: project-context.md#Code Patterns]
4. **禁止使用 `Task` 作为类型名**。[Source: CLAUDE.md]
5. **SwiftUI 视图不超过 200 行**。[Source: project-context.md#SwiftUI 视图模式]
6. **Actor 隔离**：LocalFolderRepository 是 actor，写操作必须在 actor 内执行（移除 nonisolated）。[Source: architecture.md#决策3]
7. **三层错误链路**：InfrastructureError → DomainError → UserFacingError，不可跳层。[Source: project-context.md#三层错误体系]

### 前置 Story 上下文

**Epic 1-3 已完成的核心类型（本 Story 需复用）：**

- `FolderBookmarkManager` — 当前仅支持 read-only bookmark。本 Story 需添加 read-write bookmark 支持
- `FolderBookmarkManaging` 协议 — 当前方法：hasValidBookmark, currentFolderURL, selectAndBookmarkFolder, loadBookmark, accessBookmark, releaseBookmark。本 Story 需扩展
- `LocalFolderRepository` (actor) — 当前 `requestWriteAccess()` 返回 false，updateAsset/deleteAssets/moveAssets 为空实现（标记为 "Story 4.1 implementation"）。本 Story 实现这些方法
- `PhotoLibraryRepository` 协议 — 已定义 requestWriteAccess, updateAsset, deleteAssets, moveAssets
- `PermissionLevel` enum — 已有 .read 和 .write case
- `DomainError.insufficientPermission(required: PermissionLevel)` — 已定义
- `AppDependencies` — 依赖注入容器，本 Story 需注册 PermissionState
- `MockPhotoLibraryRepository` — requestWriteAccess 返回 true，写操作为 no-op。无需修改

### Security-Scoped Bookmark 写入权限机制

**macOS 沙盒应用的写入权限关键规则：**

1. **Entitlements 已配置**：`Curator.entitlements` 已包含 `com.apple.security.files.user-selected.read-write`，允许应用请求用户选择的文件夹的读写权限。[Source: Curator/Curator.entitlements]

2. **Bookmark 创建方式决定权限**：`URL.bookmarkData(options: .withSecurityScope, ...)` 创建的 bookmark 继承了用户在 NSOpenPanel 中授予的权限。关键点：**bookmark 的读写权限取决于创建时 URL 的访问范围**。

3. **渐进授权方案**：
   - 首次启动：`selectAndBookmarkFolder()` 以只读模式选择文件夹
   - 按需升级：当 Agent 需要写操作时，再次弹出 NSOpenPanel 让用户选择同一文件夹，这次应用将获得读写权限
   - 替代方案（更优）：首次就创建 read-write bookmark，但在应用层维护一个 `isWritePermissionGranted` 状态标记，默认 false。只有当用户明确触发写操作时才将此标记设为 true。这样避免重复弹出 NSOpenPanel

4. **推荐方案（避免二次 NSOpenPanel）**：
   - **首次选择文件夹时就创建 read-write bookmark**（因为 entitlements 已经声明了 read-write）
   - **应用层维护 PermissionState** — 只读/读写状态标记
   - **写操作前检查 PermissionState** — 无权限时展示升级提示
   - **用户确认升级后设置 PermissionState 为读写模式** — 无需重新选择文件夹
   - 这种方案用户体验更好，因为不需要两次选择同一文件夹

5. **trashItem 而非 removeItem**：`FileManager.default.trashItem(at:resultingItemURL:)` 将文件移到垃圾桶，支持用户通过 Finder 恢复。这比永久删除更安全，符合 NFR15（零文件损坏）精神。[Source: Apple FileManager documentation]

### FolderBookmarkManager 修改方案

**方案 A（推荐 — 简化版，避免二次 NSOpenPanel）：**

由于 `com.apple.security.files.user-selected.read-write` entitlement 已配置，首次 `selectAndBookmarkFolder()` 创建的 bookmark 已经包含读写权限。macOS 的 security-scoped bookmark 权限由 entitlements 决定，而非创建时的选项。

因此实际需要的修改：
1. `FolderBookmarkManager` 添加 `private var writeAccessGranted: Bool = false` 状态标记
2. 添加 `grantWriteAccess()` / `revokeWriteAccess()` 方法
3. 添加 `hasWriteAccess: Bool` 计算属性
4. `LocalFolderRepository.requestWriteAccess()` 调用 `grantWriteAccess()` 并返回结果
5. 写操作前验证 `hasWriteAccess`

**方案 B（保守版，二次 NSOpenPanel）：**

如果测试发现 entitlements 不自动授予写权限，则需要：
1. 再次弹出 NSOpenPanel 让用户选择同一文件夹
2. 创建新的 read-write bookmark 替换旧的 read-only bookmark

**建议：先验证方案 A 是否可行（entitlements 是否已授予写权限），如果可行则采用方案 A。**

### LocalFolderRepository 写操作实现细节

**updateAsset(_:title:) — 重命名：**
```swift
func updateAsset(_ assetID: AssetID, title: String?) async throws {
    guard hasWriteAccess else {
        throw DomainError.insufficientPermission(required: .write)
    }
    let sourceURL = URL(fileURLWithPath: assetID.rawValue)
    guard let newTitle = title,
          !newTitle.isEmpty else { return }
    let directory = sourceURL.deletingLastPathComponent()
    let ext = sourceURL.pathExtension
    let destURL = directory.appendingPathComponent("\(newTitle).\(ext)")
    try FileManager.default.moveItem(at: sourceURL, to: destURL)
    // 使缓存失效
    cachedFileURLs = nil
}
```

**deleteAssets(_:) — 移到垃圾桶：**
```swift
func deleteAssets(_ assetIDs: [AssetID]) async throws {
    guard hasWriteAccess else {
        throw DomainError.insufficientPermission(required: .write)
    }
    for assetID in assetIDs {
        let url = URL(fileURLWithPath: assetID.rawValue)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw InfrastructureError.fileNotFound(path: assetID.rawValue).toDomainError()
        }
        var resultURL: NSURL?
        try FileManager.default.trashItem(at: url, resultingItemURL: &resultURL)
    }
    cachedFileURLs = nil
}
```

**moveAssets(_:to:) — 移动到子目录：**
```swift
func moveAssets(_ assetIDs: [AssetID], to directory: String) async throws {
    guard hasWriteAccess else {
        throw DomainError.insufficientPermission(required: .write)
    }
    guard let baseFolder = folderURL else {
        throw InfrastructureError.folderAccessDenied(reason: "未选择照片文件夹").toDomainError()
    }
    let destDir = baseFolder.appendingPathComponent(directory, isDirectory: true)
    try FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)
    for assetID in assetIDs {
        let sourceURL = URL(fileURLWithPath: assetID.rawValue)
        let destURL = destDir.appendingPathComponent(sourceURL.lastPathComponent)
        try FileManager.default.moveItem(at: sourceURL, to: destURL)
    }
    cachedFileURLs = nil
}
```

### 错误映射更新

当前 `DomainError.insufficientPermission` 统一映射为 `UserFacingError.permissionRequired`，不区分读写。本 Story 需要区分：

```swift
// ErrorMapping.swift 更新
case .insufficientPermission(let level):
    switch level {
    case .read:
        return .permissionRequired(
            title: "需要访问权限",
            action: "请选择照片文件夹以授予访问权限"
        )
    case .write:
        return .writePermissionRequired(
            title: "需要写入权限",
            message: "此操作需要写入权限才能执行。请在弹出的对话框中确认，或在系统设置中授予权限。",
            action: "授权写入"
        )
    }
```

需要在 `UserFacingError` 中添加新 case：
```swift
case writePermissionRequired(title: String, message: String, action: String)
```

### 只读模式 UI 指示

**工具栏徽章方案：**

在 MainWorkspaceView 的工具栏区域添加只读模式指示器：
- 只读模式：显示灰色锁图标 + "只读"文字
- 读写模式：显示绿色解锁图标（或隐藏指示器）
- 点击指示器：展示权限说明 popover

**权限升级提示方案：**

当 Agent 尝试写操作且无权限时，在 AgentExecutionPanel 中展示内联提示：
- 标题："需要写入权限"
- 说明："重命名操作需要写入权限。授权后将立即执行。"
- 按钮：[授权写入]（主要）[取消]（次要）
- 授权后触发 PermissionState.requestWritePermission()

### 不做什么（范围边界）

以下内容在本 Story 中 **不实现**：

- **OperationManager（Story 4.2）** — 快照/回滚系统是独立 Story
- **操作确认工作流 UI（Story 4.4）** — 破坏性操作的二次确认
- **批量回滚（Story 4.3）** — 撤销/回滚机制
- **只读模式分析保障（Story 4.5）** — 更深层的只读模式验证
- **SDK Tools 写操作集成** — WritePermissionTool 等（Epic 5/6 时集成）
- **FileSystemWatcher 集成（Story 7.1）** — 文件变更监控
- **Keychain 凭证管理（Story 7.0）** — API Key 安全存储

### 技术要求

- **Swift 6 strict concurrency**：所有新增类型标注 `Sendable`。PermissionState 为 `@MainActor @Observable`
- **不引入新第三方依赖** — 仅使用 SwiftUI + Foundation + AppKit
- **构建通过**：`xcodebuild build` 必须成功
- **无回归**：全部现有测试必须仍然通过
- **xcodegen 自动发现**：新增文件通过 project.yml 的 `sources: - Curator` 配置自动发现

### 项目结构说明

本 Story 新增的文件：

```
Curator/
├── Core/Models/
│   └── PermissionState.swift                      # 新建：权限状态管理
├── Features/Permission/
│   └── WritePermissionPromptView.swift            # 新建：权限升级提示组件
```

修改的文件：

```
Curator/
├── Core/Models/FolderBookmarkManaging.swift       # 修改：添加写入权限方法
├── Core/Errors/UserFacingError.swift              # 修改：添加 writePermissionRequired case
├── Core/Errors/ErrorMapping.swift                 # 修改：区分读写权限错误映射
├── Infrastructure/PhotoSource/FolderBookmarkManager.swift  # 修改：实现写入权限管理
├── Infrastructure/PhotoSource/LocalFolderRepository.swift  # 修改：实现写操作
├── Infrastructure/Mock/MockPhotoLibraryRepository.swift    # 无需修改（已实现）
├── App/AppDependencies.swift                      # 修改：注册 PermissionState
├── Features/MainWorkspace/MainWorkspaceView.swift # 修改：添加只读模式指示器
```

测试文件：

```
CuratorTests/
├── Infrastructure/PhotoSource/WritePermissionTests.swift   # 新建：写权限和写操作测试
├── Core/Errors/ErrorTypeTests.swift                        # 更新：添加 write 权限错误映射测试
├── Infrastructure/PhotoSource/FolderBookmarkManagerTests.swift  # 更新：添加写入权限测试
```

### NFR 关注点

- **NFR15（零文件损坏）**：updateAsset 使用 moveItem（重命名）不修改文件内容；deleteAssets 使用 trashItem（移到垃圾桶）而非永久删除。绝不用 write() 覆盖图像文件
- **NFR9（Keychain 存储）**：本 Story 不涉及凭证存储
- **NFR19（权限变更处理）**：写操作前检查 FolderBookmarkManager.hasWriteAccess，bookmark 失效时引导用户重新选择文件夹
- **NFR7（UI 不阻塞）**：权限升级流程（NSOpenPanel）是 @MainActor 操作但仅限用户交互，不阻塞后续操作

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 4.1] — 原始需求定义（写入权限渐进授权）
- [Source: _bmad-output/planning-artifacts/architecture.md#决策3] — Repository 模式 + Actor 隔离
- [Source: _bmad-output/planning-artifacts/architecture.md#决策7] — 操作回滚系统（本 Story 仅准备基础，不实现回滚）
- [Source: _bmad-output/planning-artifacts/architecture.md#决策9] — 错误处理模式（三层错误链路）
- [Source: _bmad-output/planning-artifacts/architecture.md#跨切关注点] — 权限管理贯穿文件系统服务、Agent 工具、UI 层
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#权限渐进授权] — UX-DR9 渐进授权设计
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#Agent-Specific Patterns] — 操作确认分级模式
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#Experience Principles] — 渐进承诺原则
- [Source: _bmad-output/planning-artifacts/prd.md#FR6] — 授予写入权限
- [Source: _bmad-output/planning-artifacts/prd.md#FR33] — 破坏性操作需用户批准
- [Source: _bmad-output/planning-artifacts/prd.md#FR37] — 只读分析模式
- [Source: _bmad-output/planning-artifacts/prd.md#FR38] — 绝不修改原始图像文件
- [Source: _bmad-output/planning-artifacts/prd.md#NFR15] — 零文件损坏容忍
- [Source: _bmad-output/planning-artifacts/prd.md#NFR19] — 权限变更时提示重新授权
- [Source: _bmad-output/project-context.md#Critical Implementation Rules] — Swift 6 严格并发、@MainActor ViewModel、Sendable 类型、三层错误体系
- [Source: _bmad-output/project-context.md#Architecture Boundaries] — Core/ 和 Features/ 和 Infrastructure/ 目录映射
- [Source: _bmad-output/project-context.md#Testing Rules] — ATDD 风格、Mock 模式
- [Source: Curator/Infrastructure/PhotoSource/FolderBookmarkManager.swift] — 当前 bookmark 实现
- [Source: Curator/Infrastructure/PhotoSource/LocalFolderRepository.swift] — 当前写操作为空实现（标记 "Story 4.1 implementation"）
- [Source: Curator/Core/Models/FolderBookmarkManaging.swift] — 当前协议定义
- [Source: Curator/Core/Models/PhotoLibraryRepository.swift] — Repository 协议（含写操作方法签名）
- [Source: Curator/Core/Errors/DomainError.swift] — insufficientPermission(required: PermissionLevel)
- [Source: Curator/Core/Errors/PermissionLevel.swift] — .read / .write
- [Source: Curator/Core/Errors/UserFacingError.swift] — 当前仅 .readOnly/.retryable/.permissionRequired
- [Source: Curator/Core/Errors/ErrorMapping.swift] — 当前 insufficientPermission 统一映射
- [Source: Curator/Curator.entitlements] — 已含 files.user-selected.read-write
- [Source: _bmad-output/implementation-artifacts/3-6-agent-streaming-comm.md] — 前一 Story 的经验

### 与后续 Story 的关系

**本 Story（4.1）是 Epic 4 的第一个 Story：**

- **Story 4.2（操作管理器核心）** — 将在本 Story 的写操作基础上添加快照创建。updateAsset/deleteAssets/moveAssets 的实际调用将在 OperationManager 的包装下执行
- **Story 4.3（批量回滚与撤销）** — ⌘Z 撤销将依赖 Story 4.2 的快照 + 本 Story 的写操作能力
- **Story 4.4（操作确认工作流 UI）** — 将使用本 Story 的 PermissionState 和 WritePermissionPromptView 扩展为完整的确认流程
- **Story 4.5（只读模式保障）** — 将深化本 Story 的只读指示器，添加更全面的只读模式保障
- **Epic 5（去重）** — DeleteAssetsTool 将通过本 Story 实现的 deleteAssets 执行删除
- **Epic 6（重命名）** — RenameAssetsTool 将通过本 Story 实现的 updateAsset 执行重命名

## Dev Agent Record

### Agent Model Used

GLM-5.1

### Debug Log References

No blocking issues encountered during implementation.

### Completion Notes List

- Adopted Plan A (simplified approach) — entitlements already grant read-write, no need for second NSOpenPanel. Write access tracked via UserDefaults flag.
- FolderBookmarkManaging protocol extended with `hasWriteAccess`, `grantWriteAccess()`, `revokeWriteAccess()`, `requestWriteConsent()`.
- FolderBookmarkManager uses UserDefaults for write access persistence (thread-safe without locks in async context).
- LocalFolderRepository write operations (`updateAsset`, `deleteAssets`, `moveAssets`) now fully implemented with permission guards.
- Write operations removed `nonisolated` to enable actor isolation for `hasWriteAccess` checks.
- `deleteAssets` uses `trashItem` (NFR15 safe — recoverable via Finder).
- `UserFacingError.writePermissionRequired` added for distinct write permission error messaging.
- `PermissionState` created as `@Observable @MainActor` class for SwiftUI integration.
- `WritePermissionPromptView` created as standalone SwiftUI component.
- `MainWorkspaceView` toolbar includes read-only mode indicator badge.
- TestBookmarkManager changed from struct to class to support mutable state in non-mutating protocol methods.
- All 571 tests pass (0 failures), including 19 new/activated WritePermissionTests.

### File List

**New files:**
- Curator/Core/Models/PermissionState.swift
- Curator/Features/Permission/WritePermissionPromptView.swift

**Modified files:**
- Curator/Core/Models/FolderBookmarkManaging.swift — Added hasWriteAccess, grantWriteAccess, revokeWriteAccess, requestWriteConsent
- Curator/Core/Errors/UserFacingError.swift — Added writePermissionRequired case
- Curator/Core/Errors/ErrorMapping.swift — Distinguish read vs write permission errors
- Curator/Infrastructure/PhotoSource/FolderBookmarkManager.swift — Implemented write access tracking via UserDefaults
- Curator/Infrastructure/PhotoSource/LocalFolderRepository.swift — Implemented requestWriteAccess, updateAsset, deleteAssets, moveAssets
- Curator/App/AppDependencies.swift — Registered PermissionState
- Curator/Features/MainWorkspace/MainWorkspaceView.swift — Added read-only indicator and write permission sheet
- Curator/Features/PhotoLibrary/PhotoGridView.swift — Handle new writePermissionRequired case in switches
- CuratorTests/Infrastructure/PhotoSource/WritePermissionTests.swift — Activated all 19 ATDD tests
- CuratorTests/Infrastructure/PhotoSource/LocalFolderRepositoryTests.swift — Updated TestBookmarkManager to class, added protocol conformance
- CuratorTests/Core/Errors/ErrorTypeTests.swift — Added writePermissionRequired case handling
- CuratorTests/Core/Models/CoreModelsTests.swift — Updated mock for new protocol methods
