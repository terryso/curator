# Story 5.1: 感知哈希引擎

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a 用户，
I want Curator 能在本地高效计算照片的感知哈希值，
so that 可以快速识别视觉相似的照片而不依赖网络。

## Acceptance Criteria

1. **AC1: 批量 pHash 计算性能（FR19, NFR4）**
   **Given** 系统中存在至少 100 张照片
   **When** 触发感知哈希批量计算
   **Then** 引擎在 1 分钟内完成全部 100 张照片的 pHash 计算
   **And** 计算过程在后台 Task 中执行，不阻塞主线程

2. **AC2: 单张照片 pHash 计算（FR19）**
   **Given** PerceptualHasher 已初始化
   **When** 对一张照片计算 pHash
   **Then** 利用 Apple Silicon 加速（Accelerate/vImage）完成计算
   **And** 返回固定长度的哈希值（UInt64）用于相似度比对

3. **AC3: 批量计算取消支持（FR17）**
   **Given** 用户取消正在进行的批量计算
   **When** Task.cancel() 被调用
   **Then** 后台 Task 被正确取消，已计算的结果被保留
   **And** 不导致内存泄漏或数据不一致

4. **AC4: 相似度比对**
   **Given** 两张照片的 pHash 值已计算
   **When** 计算汉明距离（Hamming Distance）
   **Then** 距离越小表示越相似，阈值为可配置参数
   **And** 返回 PairwiseSimilarity 结构，包含两张照片 ID、汉明距离、是否相似

5. **AC5: 哈希值持久化与缓存（NFR5）**
   **Given** 照片的 pHash 值已计算
   **When** 下次启动批量计算
   **Then** 已计算的 pHash 值从磁盘缓存加载，跳过重复计算
   **And** 缓存文件存储在应用沙盒目录中

6. **AC6: 错误处理与容错（NFR23）**
   **Given** 某张照片文件损坏或格式不支持
   **When** 尝试计算其 pHash
   **Then** 该照片被标记为"计算失败"并跳过
   **And** 不影响其他照片的批量计算继续进行
   **And** 错误映射为 DomainError.analysisFailed

## Tasks / Subtasks

- [ ] Task 1: 创建 PerceptualHashValue 值类型 (AC: #2, #4)
  - [ ] 1.1 创建 `Curator/Core/Models/PerceptualHashValue.swift` — `Sendable, Codable, Equatable, Hashable` struct
  - [ ] 1.2 包含字段：`assetID: AssetID`、`hash: UInt64`、`computedAt: Date`
  - [ ] 1.3 实现静态方法 `hammingDistance(_ a: UInt64, _ b: UInt64) -> Int` — 计算两个哈希值的汉明距离
  - [ ] 1.4 实现方法 `isSimilar(to other: PerceptualHashValue, threshold: Int) -> Bool`

- [ ] Task 2: 创建 PairwiseSimilarity 值类型 (AC: #4)
  - [ ] 2.1 创建 `Curator/Core/Models/PairwiseSimilarity.swift` — `Sendable, Identifiable` struct
  - [ ] 2.2 包含字段：`id: UUID`、`assetID1: AssetID`、`assetID2: AssetID`、`hammingDistance: Int`、`isSimilar: Bool`
  - [ ] 2.3 遵循 Comparable 协议（按 hammingDistance 升序排列，距离越小越相似）

- [ ] Task 3: 创建 PerceptualHasher 协议与实现 (AC: #1, #2, #3, #6)
  - [ ] 3.1 创建 `Curator/Core/Models/PerceptualHasherProtocol.swift` — Domain 层协议定义
  - [ ] 3.2 协议方法：`computeHash(for imageData: Data) async throws -> UInt64`、`computeHashes(for assets: [PhotoAsset], repository: PhotoLibraryRepository) async throws -> [PerceptualHashValue]`、`findSimilarPairs(hashes: [PerceptualHashValue], threshold: Int) -> [PairwiseSimilarity]`
  - [ ] 3.3 创建 `Curator/Infrastructure/Analysis/PerceptualHasher.swift` — 具体 actor 实现
  - [ ] 3.4 实现 `computeHash(for:)` 核心算法：
    - 使用 CGImage 从 Data 创建图像
    - 使用 Accelerate vImage 缩放至 32x32 灰度图
    - 使用 vDSP DCT-II 变换（取左上角 8x8 低频系数）
    - 计算系数中值，高于中值置 1、低于置 0，生成 64-bit 哈希
  - [ ] 3.5 实现 `computeHashes(for:repository:)` 批量计算：
    - 支持通过 `withTaskCancellationHandler` 处理取消
    - 每批处理 N 张，通过 `Task.isCancelled` 检查取消状态
    - 已计算的 PerceptualHashValue 在取消时保留并返回
  - [ ] 3.6 实现 `findSimilarPairs(hashes:threshold:)`：
    - O(n^2) 全量比较（MVP 阶段可接受，10,000 张 = 约 5000 万次比较，UInt64 汉明距离极快）
    - 返回所有 isSimilar == true 的 PairwiseSimilarity 列表，按 hammingDistance 升序
  - [ ] 3.7 错误处理：图像解码失败映射为 `DomainError.analysisFailed(reason:)`

- [ ] Task 4: 实现 pHash 磁盘缓存 (AC: #5)
  - [ ] 4.1 创建 `Curator/Infrastructure/Analysis/HashCacheManager.swift` — 管理持久化 pHash 缓存
  - [ ] 4.2 缓存格式：`[AssetID.rawValue: UInt64]` 字典，JSON 编码到沙盒 Application Support 目录
  - [ ] 4.3 缓存文件路径：`~/Library/Application Support/Curator/phash_cache.json`
  - [ ] 4.4 实现 `loadCache() -> [String: UInt64]` — 从磁盘加载已有缓存
  - [ ] 4.5 实现 `saveCache(_ hashes: [String: UInt64])` — 增量保存新计算的哈希值
  - [ ] 4.6 实现 `invalidateCache(for assetIDs: [AssetID])` — 使指定照片缓存失效
  - [ ] 4.7 实现 `clearCache()` — 清除全部缓存（配合 NFR13）

- [ ] Task 5: 注册到依赖注入容器 (AC: #1, #5)
  - [ ] 5.1 修改 `Curator/App/AppDependencies.swift` — 添加 `hasher: (any PerceptualHasherProtocol)?` 属性
  - [ ] 5.2 在适当的注册方法中创建并注册 PerceptualHasher 实例
  - [ ] 5.3 创建 HashCacheManager 并注入 PerceptualHasher

- [ ] Task 6: ATDD 测试 (AC: #1, #2, #3, #4, #5, #6)
  - [ ] 6.1 创建 `CuratorTests/Infrastructure/Analysis/PerceptualHasherTests.swift`
  - [ ] 6.2 [P0] testComputeHashReturnsUInt64 — 单张照片 pHash 计算返回 UInt64 值
  - [ ] 6.3 [P0] testIdenticalImagesProduceSameHash — 相同图像产生相同哈希值
  - [ ] 6.4 [P0] testSimilarImagesHaveLowHammingDistance — 视觉相似照片汉明距离低于阈值
  - [ ] 6.5 [P0] testDifferentImagesHaveHighHammingDistance — 视觉不同照片汉明距离高于阈值
  - [ ] 6.6 [P0] testBatchComputeHashesPerformance — 100 张照片批量计算在 60 秒内完成
  - [ ] 6.7 [P0] testBatchComputeCancellationRetainsResults — 取消批量计算时已计算结果被保留
  - [ ] 6.8 [P0] testCorruptedImageSkippedGracefully — 损坏图像被跳过，不中断批量计算
  - [ ] 6.9 [P0] testHammingDistanceCalculation — 验证汉明距离计算正确性
  - [ ] 6.10 [P1] testFindSimilarPairsReturnsCorrectPairs — findSimilarPairs 正确识别相似对
  - [ ] 6.11 [P1] testHashCachePersistAndLoad — 缓存持久化和加载正确
  - [ ] 6.12 [P1] testHashCacheInvalidation — 缓存失效正确清除指定条目
  - [ ] 6.13 [P1] testBatchSkipsCachedPhotos — 批量计算跳过已缓存的照片
  - [ ] 6.14 构建通过 + 全部现有测试通过

## Dev Notes

### 架构约束

1. **PerceptualHasher 使用 actor 隔离**：所有图像处理操作（缩放、灰度化、DCT）在 actor 内串行执行，不阻塞主线程。[Source: architecture.md#决策3, project-context.md#Architecture Boundaries]
2. **协议在 Domain 层定义**：`PerceptualHasherProtocol` 定义在 `Core/Models/`，实现 `PerceptualHasher` 在 `Infrastructure/Analysis/`。[Source: project-context.md#协议在 Domain 层定义]
3. **Sendable 值类型**：`PerceptualHashValue`、`PairwiseSimilarity` 为 `Sendable` struct。[Source: project-context.md#Code Patterns]
4. **禁止使用 `Task` 作为类型名**。[Source: CLAUDE.md]
5. **三层错误链路**：图像解码等 InfrastructureError 映射为 DomainError.analysisFailed 再向上传播。[Source: project-context.md#三层错误体系]
6. **@MainActor ViewModel**：本 Story 暂不涉及 ViewModel（仅 Infrastructure + Domain 层）。Epic 5 后续 Story（5.2-5.6）才涉及 DeduplicationViewModel。[Source: project-context.md#Critical Implementation Rules]
7. **不引入第三方依赖**：使用 Apple 原生 Accelerate/vImage/vDSP 框架，不引入 swiftimagehash 等第三方包。[Source: architecture.md#硬约束]

### 前置 Story 上下文（Epic 1-4 已完成）

**本 Story 需复用和集成的核心实现：**

- `PhotoLibraryRepository` 协议 — `fetchFullResolutionImage(for:)` 方法返回照片全分辨率 Data。[Source: Curator/Core/Models/PhotoLibraryRepository.swift]
- `PhotoAsset` 值类型 — `id: AssetID`、`metadata: AssetMetadata`、`thumbnailData: Data?`。[Source: Curator/Core/Models/PhotoAsset.swift]
- `AssetID` 值类型 — `rawValue: String`，Sendable, Hashable, Codable。[Source: Curator/Core/Models/AssetID.swift]
- `AssetMetadata` 值类型 — `fileName`、`fileSize`、`creationDate`、`imageWidth`、`imageHeight`、`fileFormat` 等。[Source: Curator/Core/Models/AssetMetadata.swift]
- `DomainError.analysisFailed(reason:)` — 已有此 case，本 Story 直接使用。[Source: Curator/Core/Errors/DomainError.swift]
- `AgentEvent` 枚举 — `stepProgress(stepID:completed:total:)` 用于后续 Story（5.2）报告 pHash 计算进度。[Source: Curator/Core/Agent/AgentEvent.swift]
- `AppDependencies` — 依赖注入容器，本 Story 需添加 hasher 属性。[Source: Curator/App/AppDependencies.swift]
- `LocalFolderRepository` (actor) — `fetchFullResolutionImage(for:)` 通过 FileManager 读取文件。[Source: Curator/Infrastructure/PhotoSource/LocalFolderRepository.swift]

### 关键设计决策

#### pHash 算法选型

采用 DCT-based perceptual hash（经典 pHash）：

1. **缩放至 32x32 灰度图** — 使用 Accelerate vImage 的 `vImageScale_ARGB8888ToGray8` 或等效 API
2. **DCT-II 变换** — 使用 vDSP 的 `vDSP_dct_md` 将 32x32 灰度矩阵变换到频域
3. **取左上角 8x8 低频系数** — 低频分量捕获图像整体结构
4. **计算中值，二值化** — 64 个系数与中值比较，生成 64-bit 哈希

**为什么不用 dHash（差值哈希）或 aHash（均值哈希）：**
- pHash 使用 DCT，对缩放、轻微旋转、亮度调整更鲁棒
- NFR4 要求 100 张/分钟的性能，DCT 在 Apple Silicon 上通过 vDSP 硬件加速可轻松达标
- 经典 pHash 在照片去重场景中准确率高于 dHash

#### Apple Silicon 加速策略

- **vImage** — 图像缩放和色彩空间转换（RGB -> 灰度），利用 GPU/DSP 硬件加速
- **vDSP** — DCT-II 变换，Apple Silicon 上极快的向量运算
- **CGImage / CGDataProvider** — 从原始 Data 创建图像，支持 JPEG/PNG/HEIC/TIFF
- **ImageIO** — 支持 RAW 格式解码（CGImageSource）

#### 汉明距离阈值

- 默认阈值：**10**（64-bit 哈希中最多允许 10 位不同）
- 阈值范围 0-64，0 = 完全相同，64 = 完全不同
- 可配置参数，后续 Story 5.2 通过 DeduplicationViewModel 调整
- 典型值：完全相同 = 0-2，缩放/裁剪 = 3-8，相似但不同 = 9-15，完全不同 = 20+

#### 批量计算策略

```
computeHashes(for: assets, repository: repo)
  1. 加载磁盘缓存 -> cachedHashes
  2. 过滤已缓存资产 -> uncachedAssets
  3. 分批处理（每批 20 张）：
     a. 检查 Task.isCancelled
     b. 调用 repo.fetchFullResolutionImage(for:)
     c. 调用 computeHash(for:)
     d. 保存到缓存
  4. 合并缓存 + 新计算结果
  5. 返回完整 [PerceptualHashValue]
```

#### 缓存设计

- 格式：JSON 文件 `[assetPath: UInt64]`
- 路径：`Application Support/Curator/phash_cache.json`
- 增量更新：每次批量计算后将新哈希合并到现有缓存
- 失效触发：文件变更（ETag/大小/修改时间），由 Epic 7 FileSystemWatcher 驱动
- MVP 阶段：不实现自动失效，仅支持手动清除和全量重算

### 与现有代码的集成点

**新建的文件：**

1. `Curator/Core/Models/PerceptualHashValue.swift` — pHash 值类型
2. `Curator/Core/Models/PairwiseSimilarity.swift` — 相似度比对结果
3. `Curator/Core/Models/PerceptualHasherProtocol.swift` — 协议定义
4. `Curator/Infrastructure/Analysis/PerceptualHasher.swift` — 核心 pHash 实现（actor）
5. `Curator/Infrastructure/Analysis/HashCacheManager.swift` — 缓存管理
6. `CuratorTests/Infrastructure/Analysis/PerceptualHasherTests.swift` — ATDD 测试

**修改的文件：**

1. `Curator/App/AppDependencies.swift` — 添加 hasher 和 hashCacheManager 属性

**不修改的文件：**

- 不修改 AgentEvent — 本 Story 不涉及 Agent 事件（5.2 才需要）
- 不修改任何 ViewModel — 本 Story 纯 Infrastructure + Domain 层
- 不修改 PhotoLibraryRepository 协议 — 直接使用现有 fetchFullResolutionImage

### 不做什么（范围边界）

以下内容在本 Story 中 **不实现**：

- **DuplicateGroup 模型** — 在 Story 5.2（图像分析管线）中创建，本 Story 仅输出 PairwiseSimilarity 列表
- **LLM 确认阶段** — Story 5.2 的职责（pHash 是第一阶段的本地筛选）
- **DeduplicationViewModel** — Story 5.2-5.4 的 UI 层
- **去重 SDK 工具** — Story 5.3 注册 ScanLibraryTool、AnalyzeDuplicatesTool
- **pHash 索引文件（二进制格式）** — MVP 使用 JSON 缓存，性能优化在 Epic 7（两级缓存管理）
- **自动缓存失效** — Epic 7 Story 7.1（FileSystemWatcher）驱动
- **ThumbnailGenerator** — Story 5.2 中实现
- **图片聚类优化（BK-Tree 等）** — MVP 使用全量 O(n^2) 比较，后续优化

### 技术要求

- **Swift 6 strict concurrency**：所有新增类型标注 `Sendable`。PerceptualHasher 使用 actor 隔离。[Source: project-context.md#Critical Implementation Rules]
- **不引入第三方依赖**：仅使用 Accelerate/vImage/vDSP + Foundation + CoreGraphics + ImageIO。[Source: architecture.md]
- **构建通过**：`xcodebuild build` 必须成功
- **无回归**：全部现有测试必须仍然通过
- **xcodegen 自动发现**：新增文件通过 project.yml 的 `sources: - Curator` 配置自动发现
- **macOS 15+ API**：可使用 vImage/vDSP 最新 API，无需兼容旧版本

### NFR 关注点

- **NFR4（100 张/分钟）**：Apple Silicon vDSP DCT + vImage 缩放可轻松达标。实测预期 200-500 张/分钟。
- **NFR6（500MB 内存）**：批量计算每次只处理 20 张全分辨率图像数据，用完即释放。单张 32x32 灰度图仅 1KB。
- **NFR15（零文件损坏）**：pHash 计算是纯只读操作，不修改任何文件。
- **NFR23（容错）**：损坏/不支持格式文件被跳过，不影响批量计算。

### 性能预估

| 操作 | 单张耗时（Apple Silicon M1/M2/M3） |
|------|-------------------------------------|
| 图像解码（JPEG -> CGImage） | 1-3ms |
| 缩放至 32x32（vImage） | <1ms |
| 灰度转换（vImage） | <1ms |
| 32x32 DCT-II（vDSP） | <1ms |
| 中值计算 + 二值化 | <1ms |
| **合计** | **3-6ms/张** |
| **100 张** | **300-600ms** |
| **10,000 张** | **30-60s** |

NFR4 要求 100 张/分钟（600ms/张），预估性能远超要求。

### 项目结构说明

本 Story 新增的文件：

```
Curator/
├── Core/Models/
│   ├── PerceptualHashValue.swift              # 新建：pHash 值类型
│   ├── PairwiseSimilarity.swift               # 新建：相似度比对结果
│   └── PerceptualHasherProtocol.swift          # 新建：pHash 协议
├── Infrastructure/Analysis/                    # 新建目录
│   ├── PerceptualHasher.swift                  # 新建：pHash 核心 actor 实现
│   └── HashCacheManager.swift                  # 新建：缓存管理
```

修改的文件：

```
Curator/
├── App/AppDependencies.swift                   # 修改：添加 hasher 属性
```

测试文件：

```
CuratorTests/
├── Infrastructure/Analysis/                    # 新建目录
│   └── PerceptualHasherTests.swift             # 新建：ATDD 测试
```

### 与后续 Story 的关系

**本 Story（5.1）完成后：**

- **Story 5.2（图像分析管线）** — 将使用 PerceptualHasher.computeHashes() 作为第一阶段，再用 LLM 确认候选重复组。会创建 DuplicateGroup 模型、ImageAnalysisPipeline、ThumbnailGenerator。
- **Story 5.3（去重 SDK 工具）** — 注册 AnalyzeDuplicatesTool，内部调用 ImageAnalysisPipeline（Story 5.2）。
- **Story 5.4（去重审核界面）** — DeduplicationViewModel 展示 DuplicateGroup（Story 5.2），使用 PairwiseSimilarity（本 Story）的相似度分数排序。

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 5.1] — 原始需求定义（感知哈希引擎）
- [Source: _bmad-output/planning-artifacts/architecture.md#Infrastructure/Analysis] — 图像分析目录结构
- [Source: _bmad-output/planning-artifacts/architecture.md#决策5] — 数据持久化（pHash 索引文件）
- [Source: _bmad-output/planning-artifacts/architecture.md#决策8] — 缓存策略（pHash 值：二进制索引文件，图库变更时重建）
- [Source: _bmad-output/planning-artifacts/prd.md#FR19] — 本地感知哈希算法检测视觉相似照片
- [Source: _bmad-output/planning-artifacts/prd.md#NFR4] — 100 张/分钟 pHash 性能
- [Source: _bmad-output/planning-artifacts/prd.md#NFR5] — 10,000 张照片 60 秒扫描
- [Source: _bmad-output/planning-artifacts/prd.md#NFR6] — 500MB 内存上限
- [Source: _bmad-output/planning-artifacts/prd.md#NFR15] — 零文件损坏
- [Source: _bmad-output/planning-artifacts/prd.md#NFR23] — 部分不可访问时保持功能
- [Source: _bmad-output/project-context.md#Critical Implementation Rules] — Swift 6 严格并发、actor 隔离、Sendable
- [Source: _bmad-output/project-context.md#Architecture Boundaries] — Core/Models/ 和 Infrastructure/Analysis/ 目录映射
- [Source: _bmad-output/project-context.md#Testing Rules] — ATDD 风格、Mock 模式
- [Source: Curator/Core/Models/PhotoLibraryRepository.swift] — fetchFullResolutionImage(for:) 方法
- [Source: Curator/Core/Models/PhotoAsset.swift] — PhotoAsset 值类型
- [Source: Curator/Core/Models/AssetID.swift] — AssetID 值类型
- [Source: Curator/Core/Errors/DomainError.swift] — DomainError.analysisFailed
- [Source: Curator/App/AppDependencies.swift] — 依赖注入容器
- [Apple vImage Documentation](https://developer.apple.com/documentation/accelerate/vimage-library) — vImage 高性能图像处理
- [Apple Grayscale Conversion](https://developer.apple.com/documentation/Accelerate/converting-color-images-to-grayscale) — RGB 灰度转换
- [Apple vImage Performance](https://developer.apple.com/documentation/accelerate/optimizing-image-processing-performance) — vImage 性能优化

## Dev Agent Record

### Agent Model Used

{{agent_model_name_version}}

### Debug Log References

### Completion Notes List

### File List
