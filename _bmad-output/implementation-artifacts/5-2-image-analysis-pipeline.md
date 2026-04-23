# Story 5.2: 图像分析管线

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a 用户，
I want 系统自动执行两阶段分析来精准识别重复照片，
so that 不会出现误报。

## Acceptance Criteria

1. **AC1: 两阶段分析流程（FR20）**
   **Given** 图库中存在视觉相似的重复照片组
   **When** ImageAnalysisPipeline 执行分析流程
   **Then** 第一阶段通过本地 pHash 计算筛选出候选重复组
   **And** 第二阶段将候选组发送至 LLM 进行语义确认
   **And** 生成 DuplicateGroup 模型，包含相似度分数和组内照片引用

2. **AC2: 缩略图生成（FR21）**
   **Given** 分析管线正在处理大量照片
   **When** 需要展示重复组供用户审核
   **Then** ThumbnailGenerator 为每组照片生成缩略图用于快速预览
   **And** DuplicateGroup 包含足够信息以支持后续审核操作

3. **AC3: LLM 匹配原因说明（FR20, FR21）**
   **Given** 两阶段分析已完成
   **When** 生成分析结果
   **Then** 每组重复照片附带 LLM 提供的匹配原因说明
   **And** 相似度分数可用于排序展示优先级最高的重复组

4. **AC4: 取消支持（FR17）**
   **Given** 分析管线正在执行
   **When** 用户取消操作
   **Then** 已完成的分析结果被保留
   **And** 不导致内存泄漏或数据不一致

5. **AC5: 错误处理与容错（NFR23）**
   **Given** LLM 调用失败或某组照片处理异常
   **When** 分析管线继续执行
   **Then** 失败的组被标记为"分析失败"并跳过
   **And** 不影响其他候选组的分析继续进行

6. **AC6: 内存控制（NFR6）**
   **Given** 分析管线处理 10,000+ 张照片
   **When** 执行两阶段分析
   **Then** 内存使用保持在 500MB 以下
   **And** 照片数据按需加载和处理，用完即释放

## Tasks / Subtasks

- [x] Task 1: 创建 DuplicateGroup 值类型 (AC: #1, #3)
  - [x] 1.1 创建 `Curator/Core/Models/DuplicateGroup.swift` — `Sendable, Identifiable` struct
  - [x] 1.2 包含字段：`id: UUID`、`assets: [PhotoAsset]`、`similarityScore: Double`、`reason: String?`（LLM 匹配说明）、`thumbnails: [AssetID: Data]`、`status: DuplicateGroupStatus`
  - [x] 1.3 定义 `DuplicateGroupStatus` 枚举：`.pending`、`.confirmed`、`.rejected`、`.analysisFailed`
  - [x] 1.4 实现排序能力（按 similarityScore 降序）

- [x] Task 2: 创建 ThumbnailGenerator (AC: #2)
  - [x] 2.1 创建 `Curator/Core/Models/ThumbnailGeneratorProtocol.swift` — Domain 层协议定义
  - [x] 2.2 协议方法：`func generateThumbnail(for assetID: AssetID, repository: PhotoLibraryRepository, targetSize: CGSize) async throws -> Data`、`func generateThumbnails(for assets: [PhotoAsset], repository: PhotoLibraryRepository, targetSize: CGSize) async -> [AssetID: Data]`
  - [x] 2.3 创建 `Curator/Infrastructure/Analysis/ThumbnailGenerator.swift` — actor 实现
  - [x] 2.4 使用 CoreGraphics 缩放图像至指定尺寸（默认 200x200）
  - [x] 2.5 返回 JPEG 压缩数据（质量 0.7），控制缩略图体积
  - [x] 2.6 错误处理：图像解码失败映射为 `DomainError.analysisFailed`

- [x] Task 3: 创建 ImageAnalysisPipelineProtocol (AC: #1, #4, #5, #6)
  - [x] 3.1 创建 `Curator/Core/Models/ImageAnalysisPipelineProtocol.swift` — Domain 层协议
  - [x] 3.2 协议方法：`func analyze(assets: [PhotoAsset], repository: PhotoLibraryRepository) async throws -> [DuplicateGroup]`、`func analyze(assets: [PhotoAsset], repository: PhotoLibraryRepository, progressHandler: ((AnalysisProgress) -> Void)?) async throws -> [DuplicateGroup]`
  - [x] 3.3 定义 `AnalysisProgress` 值类型：`stage: AnalysisStage`、`completed: Int`、`total: Int`
  - [x] 3.4 定义 `AnalysisStage` 枚举：`.hashing`、`.pairComparison`、`.llmConfirmation`、`.thumbnailGeneration`、`.completed`

- [x] Task 4: 创建 ImageAnalysisPipeline 实现 (AC: #1, #3, #4, #5, #6)
  - [x] 4.1 创建 `Curator/Infrastructure/Analysis/ImageAnalysisPipeline.swift` — actor 实现
  - [x] 4.2 注入依赖：`PerceptualHasherProtocol`、`LLMGatewayProtocol`、`ThumbnailGeneratorProtocol`
  - [x] 4.3 实现 `analyze()` 方法：
    ```
    第一阶段（本地 pHash）：
      1. 调用 hasher.computeHashes(for:repository:) 获取所有 pHash 值
      2. 调用 hasher.findSimilarPairs(hashes:threshold:) 获取候选相似对
      3. 将相似对按连通分量聚类为候选重复组

    第二阶段（LLM 确认）：
      4. 对每个候选组：
         a. 加载组内照片的全分辨率图像
         b. 构造 LLM prompt（包含图片，要求判断是否为真正重复并说明原因）
         c. 调用 llmGateway.analyze(images:prompt:model:)
         d. 解析 LLM 响应提取：是否重复（boolean）、匹配原因（string）
      5. 生成 DuplicateGroup（仅保留 LLM 确认为重复的组）

    第三阶段（缩略图生成）：
      6. 调用 thumbnailGenerator 为每组照片生成缩略图
      7. 组装最终 DuplicateGroup 列表
    ```
  - [x] 4.4 实现连通分量聚类算法：将 PairwiseSimilarity 列表按 assetID 关系聚合为独立组
  - [x] 4.5 构造 LLM prompt：包含所有组内照片，要求 JSON 格式输出 `{ "isDuplicate": bool, "reason": string, "confidence": double }`
  - [x] 4.6 解析 LLM 响应：从 LLMResponse.text 提取 JSON 或结构化文本
  - [x] 4.7 进度回调：每个阶段更新 AnalysisProgress
  - [x] 4.8 取消支持：在阶段转换和批次处理中检查 Task.isCancelled
  - [x] 4.9 内存管理：LLM 确认阶段逐组处理，照片数据用完释放

- [x] Task 5: 注册到依赖注入容器 (AC: #1)
  - [x] 5.1 修改 `Curator/App/AppDependencies.swift` — 添加 `imageAnalysisPipeline: (any ImageAnalysisPipelineProtocol)?` 属性
  - [x] 5.2 修改 `registerHashEngine()` 方法：同时创建 ThumbnailGenerator 和 ImageAnalysisPipeline 实例
  - [x] 5.3 将方法重命名为 `registerAnalysisInfrastructure()` 以反映更广的职责

- [x] Task 6: ATDD 测试 (AC: #1, #2, #3, #4, #5, #6)
  - [x] 6.1 创建 `CuratorTests/Infrastructure/Analysis/ImageAnalysisPipelineTests.swift`
  - [x] 6.2 创建 `CuratorTests/Infrastructure/Analysis/ThumbnailGeneratorTests.swift`
  - [x] 6.3 [P0] testTwoStageAnalysisProducesDuplicateGroups — 两阶段分析生成 DuplicateGroup
  - [x] 6.4 [P0] testLLMConfirmationFiltersFalsePositives — LLM 确认过滤掉非真正重复
  - [x] 6.5 [P0] testDuplicateGroupContainsReason — 每组包含 LLM 提供的匹配原因说明
  - [x] 6.6 [P0] testAnalysisCancellationRetainsResults — 取消时已分析结果被保留
  - [x] 6.7 [P0] testLLMFailureSkipsGroupGracefully — LLM 调用失败时组被跳过
  - [x] 6.8 [P0] testThumbnailGenerationForDuplicateGroups — 缩略图正确生成
  - [x] 6.9 [P1] testProgressHandlerReportsStages — 进度回调报告各阶段
  - [x] 6.10 [P1] testSimilarityScoreOrdering — 结果按相似度分数降序排列
  - [x] 6.11 [P1] testThumbnailGenerationHandlesCorruptImage — 损坏图像缩略图生成不崩溃
  - [x] 6.12 [P1] testConnectedComponentClustering — 相似对正确聚类为连通组
  - [x] 6.13 构建通过 + 全部现有测试通过

## Dev Notes

### 架构约束

1. **ImageAnalysisPipeline 使用 actor 隔离**：所有分析操作（pHash 计算、LLM 调用、缩略图生成）在 actor 内串行执行，不阻塞主线程。[Source: project-context.md#Critical Implementation Rules, architecture.md#决策3]
2. **协议在 Domain 层定义**：`ImageAnalysisPipelineProtocol`、`ThumbnailGeneratorProtocol` 定义在 `Core/Models/`，实现在 `Infrastructure/Analysis/`。[Source: project-context.md#协议在 Domain 层定义]
3. **Sendable 值类型**：`DuplicateGroup`、`AnalysisProgress`、`AnalysisStage` 为 `Sendable` struct/enum。[Source: project-context.md#Code Patterns]
4. **禁止使用 `Task` 作为类型名**。[Source: CLAUDE.md]
5. **三层错误链路**：LLM 调用失败映射为 DomainError.analysisFailed 再向上传播。[Source: project-context.md#三层错误体系]
6. **API 调用必须通过 LLMGateway**：不直接调用供应商 API。[Source: project-context.md#Critical Implementation Rules]
7. **不引入第三方依赖**：缩略图生成使用 CoreGraphics，LLM 解析使用 Foundation JSONDecoder。[Source: architecture.md#硬约束]

### 前置 Story 5.1 的实现

**必须复用的已有实现：**

- `PerceptualHasherProtocol` — `computeHash(for:)` 返回 UInt64、`computeHashes(for:repository:)` 批量计算、`findSimilarPairs(hashes:threshold:)` 返回 `[PairwiseSimilarity]`。[Source: Curator/Core/Models/PerceptualHasherProtocol.swift]
- `PerceptualHasher` (actor) — 具体 pHash 实现，已注册到 AppDependencies.hasher。[Source: Curator/Infrastructure/Analysis/PerceptualHasher.swift]
- `PerceptualHashValue` — `assetID: AssetID`、`hash: UInt64`、`computedAt: Date`。[Source: Curator/Core/Models/PerceptualHashValue.swift]
- `PairwiseSimilarity` — `id: UUID`、`assetID1: AssetID`、`assetID2: AssetID`、`hammingDistance: Int`、`isSimilar: Bool`。[Source: Curator/Core/Models/PairwiseSimilarity.swift]
- `HashCacheManager` — pHash 磁盘缓存，已注册到 AppDependencies.hashCacheManager。[Source: Curator/Infrastructure/Analysis/HashCacheManager.swift]
- `AppDependencies.hasher` 和 `AppDependencies.hashCacheManager` — 已通过 `registerHashEngine()` 注册。[Source: Curator/App/AppDependencies.swift]

### 前置 Epic 的已有实现

- `LLMGatewayProtocol` — `analyze(images:prompt:model:) async throws -> LLMResponse`、`estimateCost(imageCount:model:) async -> CostEstimate`。[Source: Curator/Core/Models/LLMGatewayProtocol.swift]
- `LLMGateway` (actor) — 已实现重试/故障转移，已注册到 AppDependencies.llmGateway。[Source: Curator/Infrastructure/LLM/LLMGateway.swift]
- `LLMResponse` — `text: String`、`modelID: String`、`providerName: String`、`inputTokens: Int`、`outputTokens: Int`。[Source: Curator/Core/Models/LLMResponse.swift]
- `PhotoLibraryRepository` — `fetchFullResolutionImage(for:) async throws -> Data`、`fetchAssets(predicate:pageSize:pageOffset:)`。[Source: Curator/Core/Models/PhotoLibraryRepository.swift]
- `PhotoAsset` — `id: AssetID`、`metadata: AssetMetadata`、`thumbnailData: Data?`。[Source: Curator/Core/Models/PhotoAsset.swift]
- `AssetID` — `rawValue: String`，Sendable, Hashable, Codable。[Source: Curator/Core/Models/AssetID.swift]
- `DomainError.analysisFailed(reason:)` — 已有此 case，本 Story 直接使用。[Source: Curator/Core/Errors/DomainError.swift]
- `CostEstimate` — 已有模型，本 Story 用于费用预估。[Source: Curator/Core/Models/CostEstimate.swift]

### 关键设计决策

#### 两阶段分析策略

**为什么两阶段？**
- pHash 快速但仅捕获视觉相似性（缩放、裁剪、压缩后的副本），可能产生误报（如连拍照片、相似构图）
- LLM 语义确认能区分真正重复（同一场景的副本）和视觉相似但内容不同（连拍中不同表情）
- 先用 pHash 全量筛选（O(n^2) 但极快），再用 LLM 精确确认（有 API 成本），最大化效率、最小化费用

**第一阶段（本地 pHash 筛选）：**
1. 调用 `hasher.computeHashes(for: assets, repository: repo)` — 获取全部照片 pHash
2. 调用 `hasher.findSimilarPairs(hashes: hashes, threshold: 10)` — 获取候选相似对
3. 将 PairwiseSimilarity 列表通过**连通分量算法**聚合为独立的候选组
   - 例如 A-B 相似、B-C 相似 → A、B、C 归为同一组
   - 使用 Union-Find 或 DFS/BFS 实现

**第二阶段（LLM 语义确认）：**
4. 对每个候选组，加载照片全分辨率图像
5. 构造 LLM prompt 要求判断是否真正重复
6. 调用 `llmGateway.analyze(images: photos, prompt: prompt, model: model)`
7. 解析 LLM 响应，仅保留确认的重复组

#### LLM Prompt 设计

```
你是照片去重专家。请判断以下 {n} 张照片是否为重复照片（即同一场景的不同版本、副本、裁剪或压缩版本）。

规则：
- 连拍照片（同一场景但不同瞬间）**不是**重复
- 同一场景的不同曝光/焦距版本**是**重复
- 完全相同或仅经过缩放/压缩的**是**重复

请以 JSON 格式回复：
{
  "isDuplicate": true/false,
  "reason": "简要说明判断原因",
  "confidence": 0.0-1.0
}
```

#### 缩略图生成策略

- 尺寸：200x200（满足审核界面预览需求）
- 格式：JPEG，质量 0.7（平衡清晰度和体积）
- 使用 CoreGraphics `CGContext` 缩放，不依赖 NSImage（避免主线程依赖）
- 批量生成时逐张处理，检查取消状态
- 失败的缩略图用占位符 Data 替代，不阻塞流程

#### 连通分量聚类

将 PairwiseSimilarity 列表转换为互不重叠的候选重复组：

```
输入：[PairwiseSimilarity(A,B), PairwiseSimilarity(B,C), PairwiseSimilarity(D,E)]
输出：[[A,B,C], [D,E]]

算法：
1. 构建 adjacency map：assetID → Set<AssetID>
2. 对每个未访问节点执行 DFS/BFS
3. 收集连通分量作为候选组
```

#### 内存管理

- pHash 阶段：每批 20 张全分辨率图像，用完释放（继承自 Story 5.1）
- LLM 确认阶段：逐组处理，每组加载 2-5 张图像，确认后释放
- 缩略图阶段：200x200 JPEG 约 10-20KB/张，10,000 张约 100-200MB
- 总内存预估：pHash 缓存 + 当前组图像 + 缩略图 < 400MB（500MB 预算内）

### 与现有代码的集成点

**新建的文件：**

1. `Curator/Core/Models/DuplicateGroup.swift` — 重复分组值类型
2. `Curator/Core/Models/AnalysisProgress.swift` — 分析进度值类型
3. `Curator/Core/Models/ImageAnalysisPipelineProtocol.swift` — 分析管线协议
4. `Curator/Core/Models/ThumbnailGeneratorProtocol.swift` — 缩略图生成协议
5. `Curator/Infrastructure/Analysis/ImageAnalysisPipeline.swift` — 分析管线实现（actor）
6. `Curator/Infrastructure/Analysis/ThumbnailGenerator.swift` — 缩略图生成实现（actor）
7. `CuratorTests/Infrastructure/Analysis/ImageAnalysisPipelineTests.swift` — ATDD 测试
8. `CuratorTests/Infrastructure/Analysis/ThumbnailGeneratorTests.swift` — ATDD 测试

**修改的文件：**

1. `Curator/App/AppDependencies.swift` — 添加 `imageAnalysisPipeline`、`thumbnailGenerator` 属性，将 `registerHashEngine()` 扩展为注册全部分析组件

**不修改的文件：**

- 不修改 PerceptualHasher 或其协议 — 直接复用
- 不修改 LLMGateway 或其协议 — 通过依赖注入获取
- 不修改 AgentEvent — 本 Story 不涉及 Agent 事件（Story 5.3 SDK 工具才需要）
- 不修改 DeduplicationViewModel — Story 5.4 的 UI 层

### 不做什么（范围边界）

以下内容在本 Story 中 **不实现**：

- **去重 SDK 工具** — Story 5.3 职责（ScanLibraryTool、AnalyzeDuplicatesTool）
- **DeduplicationViewModel** — Story 5.4 的 UI 层
- **PhotoComparisonCard / DuplicateReviewView** — Story 5.4 的审核界面
- **批量审批和执行** — Story 5.5
- **去重结果摘要** — Story 5.6
- **OperationManager 集成** — 删除操作在 Story 5.5 中通过 SDK 工具集成
- **LLM 响应缓存** — Epic 7（两级缓存管理）中考虑
- **费用预估集成** — Story 5.3 SDK 工具中通过 EstimateCostTool 实现

### NFR 关注点

- **NFR4（100 张/分钟 pHash）**：第一阶段复用 Story 5.1 的 PerceptualHasher，已验证达标。
- **NFR6（500MB 内存）**：LLM 确认阶段逐组处理，照片数据用完释放。缩略图控制在 200x200 JPEG。
- **NFR10（TLS 传输）**：LLM 调用通过 LLMGateway（URLSession HTTPS），自动满足。
- **NFR15（零文件损坏）**：分析管线为纯只读操作（pHash + LLM 分析 + 缩略图生成），不修改任何原始文件。
- **NFR20（LLM 重试）**：LLMGateway 已实现指数退避重试和故障转移，本 Story 直接复用。
- **NFR23（容错）**：LLM 调用失败或图像解码失败的组被跳过，不影响其他组。

### 项目结构说明

本 Story 新增的文件：

```
Curator/
├── Core/Models/
│   ├── DuplicateGroup.swift                        # 新建：重复分组值类型
│   ├── AnalysisProgress.swift                      # 新建：分析进度值类型
│   ├── ImageAnalysisPipelineProtocol.swift          # 新建：分析管线协议
│   └── ThumbnailGeneratorProtocol.swift             # 新建：缩略图生成协议
├── Infrastructure/Analysis/
│   ├── ImageAnalysisPipeline.swift                  # 新建：分析管线 actor 实现
│   └── ThumbnailGenerator.swift                     # 新建：缩略图生成 actor 实现
```

修改的文件：

```
Curator/
├── App/AppDependencies.swift                        # 修改：添加分析管线和缩略图生成器
```

测试文件：

```
CuratorTests/
├── Infrastructure/Analysis/
│   ├── ImageAnalysisPipelineTests.swift             # 新建：ATDD 测试
│   └── ThumbnailGeneratorTests.swift                # 新建：ATDD 测试
```

### 与后续 Story 的关系

**本 Story（5.2）完成后：**

- **Story 5.3（去重 SDK 工具）** — 注册 AnalyzeDuplicatesTool，内部调用 ImageAnalysisPipeline.analyze()。将创建 ScanLibraryTool、AnalyzeDuplicatesTool、EstimateCostTool 并注册到 AgentToolRegistry。
- **Story 5.4（去重审核界面）** — DeduplicationViewModel 展示 DuplicateGroup 列表，使用本 Story 创建的 DuplicateGroup 模型和 ThumbnailGenerator 生成的缩略图。
- **Story 5.5（批量审批与执行）** — 通过 OperationManager 执行用户确认的删除操作。
- **Story 5.6（去重结果摘要）** — 展示 AgentResultSummary。

### Mock 策略

测试中需要 Mock 三个依赖：

```swift
// Mock PerceptualHasher — 返回预设的 pHash 值和相似对
private struct MockPerceptualHasher: PerceptualHasherProtocol { ... }

// Mock LLMGateway — 返回预设的 LLM 响应（JSON 格式的重复判断）
private struct MockLLMGateway: LLMGatewayProtocol { ... }

// Mock ThumbnailGenerator — 返回预设的缩略图数据
private struct MockThumbnailGenerator: ThumbnailGeneratorProtocol { ... }
```

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 5.2] — 原始需求定义（图像分析管线）
- [Source: _bmad-output/planning-artifacts/architecture.md#Infrastructure/Analysis] — 图像分析目录结构
- [Source: _bmad-output/planning-artifacts/architecture.md#决策2] — Agent 执行引擎（AsyncStream 流式管道）
- [Source: _bmad-output/planning-artifacts/architecture.md#决策4] — LLM 网关（Provider 协议 + 故障转移）
- [Source: _bmad-output/planning-artifacts/prd.md#FR18] — 请求重复照片检测
- [Source: _bmad-output/planning-artifacts/prd.md#FR19] — 本地感知哈希算法
- [Source: _bmad-output/planning-artifacts/prd.md#FR20] — LLM 确认视觉相似照片是否为真正重复
- [Source: _bmad-output/planning-artifacts/prd.md#FR21] — 审核重复分组（并排对比 + AI 说明）
- [Source: _bmad-output/planning-artifacts/prd.md#NFR6] — 500MB 内存上限
- [Source: _bmad-output/planning-artifacts/prd.md#NFR10] — HTTPS/TLS 传输
- [Source: _bmad-output/planning-artifacts/prd.md#NFR15] — 零文件损坏
- [Source: _bmad-output/planning-artifacts/prd.md#NFR20] — LLM 指数退避重试
- [Source: _bmad-output/planning-artifacts/prd.md#NFR23] — 部分不可访问时保持功能
- [Source: _bmad-output/project-context.md#Critical Implementation Rules] — Swift 6 严格并发、actor 隔离、Sendable
- [Source: _bmad-output/project-context.md#Architecture Boundaries] — Core/Models/ 和 Infrastructure/Analysis/ 目录映射
- [Source: _bmad-output/project-context.md#Testing Rules] — ATDD 风格、Mock 模式
- [Source: _bmad-output/implementation-artifacts/5-1-perceptual-hash-engine.md] — Story 5.1 实现（pHash 引擎）
- [Source: Curator/Core/Models/PerceptualHasherProtocol.swift] — pHash 协议（复用）
- [Source: Curator/Core/Models/PairwiseSimilarity.swift] — 相似度比对结果（复用）
- [Source: Curator/Core/Models/LLMGatewayProtocol.swift] — LLM 网关协议（复用）
- [Source: Curator/Core/Models/LLMResponse.swift] — LLM 响应模型（复用）
- [Source: Curator/Core/Models/PhotoLibraryRepository.swift] — 照片来源协议（复用）
- [Source: Curator/Core/Errors/DomainError.swift] — DomainError.analysisFailed
- [Source: Curator/App/AppDependencies.swift] — 依赖注入容器

## Dev Agent Record

### Agent Model Used

GLM-5.1

### Debug Log References

- Fixed Xcode project file (pbxproj) to properly include new source files in Swift compilation
- Fixed `@Sendable` requirement on progress handler closure for actor isolation
- Fixed `UTType` import for ThumbnailGenerator JPEG output
- Fixed `CostEstimate` init parameters in mock (estimatedTokens vs tokenCount)
- Fixed test assertion for false positive filtering (BFS traversal order is non-deterministic)

### Completion Notes List

- Task 1: Created `DuplicateGroup` value type with `Sendable, Identifiable, Comparable` conformance. Includes `DuplicateGroupStatus` enum with `.pending`, `.confirmed`, `.rejected`, `.analysisFailed` cases. Sorting by similarityScore descending.
- Task 2: Created `ThumbnailGeneratorProtocol` in Domain layer and `ThumbnailGenerator` actor in Infrastructure layer. Uses CoreGraphics for image scaling, JPEG compression at 0.7 quality. Batch mode skips corrupt images gracefully.
- Task 3: Created `ImageAnalysisPipelineProtocol` with `analyze()` methods (with/without progress handler). Defined `AnalysisProgress` and `AnalysisStage` value types. Progress handler uses `@Sendable` closure for actor isolation.
- Task 4: Created `ImageAnalysisPipeline` actor implementing three-stage analysis: (1) pHash local filtering via PerceptualHasher, (2) LLM semantic confirmation via LLMGateway with JSON response parsing, (3) thumbnail generation. BFS-based connected component clustering for grouping similar pairs. Supports cancellation via Task.checkCancellation(). LLM failures skip groups gracefully.
- Task 5: Added `thumbnailGenerator` and `imageAnalysisPipeline` properties to AppDependencies. Renamed `registerHashEngine()` to `registerAnalysisInfrastructure()`.
- Task 6: All 18 ATDD tests pass (13 pipeline + 5 thumbnail). Full test suite: 682 tests, 0 failures.

### File List

**New Files:**
- `Curator/Core/Models/DuplicateGroup.swift`
- `Curator/Core/Models/AnalysisProgress.swift`
- `Curator/Core/Models/ImageAnalysisPipelineProtocol.swift`
- `Curator/Core/Models/ThumbnailGeneratorProtocol.swift`
- `Curator/Infrastructure/Analysis/ImageAnalysisPipeline.swift`
- `Curator/Infrastructure/Analysis/ThumbnailGenerator.swift`
- `CuratorTests/Infrastructure/Analysis/ImageAnalysisPipelineTests.swift`
- `CuratorTests/Infrastructure/Analysis/ThumbnailGeneratorTests.swift`

**Modified Files:**
- `Curator/App/AppDependencies.swift`
- `Curator.xcodeproj/project.pbxproj`

### Review Findings

- [x] [Review][Patch] Fragile JSON extraction from LLM response [ImageAnalysisPipeline.swift:260-276] — Fixed: replaced greedy first/last brace matching with proper brace-counting parser that handles nested JSON, markdown code fences, and string escaping.
- [x] [Review][Patch] Double PerceptualHasher instance in AppDependencies [AppDependencies.swift:224-239] — Fixed: reused the same hasherInstance for both `self.hasher` and the pipeline.
- [x] [Review][Patch] ThumbnailGenerator fallback returns full-resolution image [ThumbnailGenerator.swift:109-139] — Fixed: `scaleCGImage` now throws `DomainError.analysisFailed` on failure instead of returning the original full-res image.
- [x] [Review][Patch] AC5: Failed groups silently skipped, never marked `.analysisFailed` [ImageAnalysisPipeline.swift:96-114] — Fixed: failed groups are now collected and emitted as `DuplicateGroup(status: .analysisFailed)`. Test updated to verify.
- [x] [Review][Patch] Unbounded image loading per group — memory risk [ImageAnalysisPipeline.swift:212-222] — Fixed: added `maxGroupSize` (default: 10) parameter; oversized connected components are split into chunks.
- [x] [Review][Defer] O(n) queue.removeFirst() in BFS [ImageAnalysisPipeline.swift:188] — deferred, pre-existing performance concern at scale
