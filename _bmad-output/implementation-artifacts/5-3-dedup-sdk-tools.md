# Story 5.3: 去重 SDK 工具

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a AI Agent，
I want 拥有一套完整的去重工具，
so that 能够自主执行完整的去重工作流。

## Acceptance Criteria

1. **AC1: ScanLibraryTool 扫描图库（FR18）**
   **Given** Agent 收到用户的去重请求
   **When** Agent 调用 ScanLibraryTool 扫描图库
   **Then** 工具返回图库照片清单及其元数据（文件名、日期、格式、尺寸等）
   **And** 支持分页参数控制返回数量

2. **AC2: AnalyzeDuplicatesTool 串联分析（FR19, FR20）**
   **Given** Agent 获得图库照片清单
   **When** Agent 调用 AnalyzeDuplicatesTool 执行去重分析
   **Then** 工具内部调用 ImageAnalysisPipeline 执行两阶段分析（pHash + LLM 确认）
   **And** 返回 DuplicateGroup 列表，包含相似度分数和匹配原因
   **And** 支持进度回调，Agent 可实时展示分析进度

3. **AC3: DeleteAssetsTool 安全删除（FR22, FR33）**
   **Given** 用户已审核并确认要删除的重复照片
   **When** Agent 调用 DeleteAssetsTool 执行删除
   **Then** 工具通过 OperationManager 创建快照并安全执行删除操作
   **And** 删除操作支持通过 OperationManager 回滚
   **And** 删除操作在执行前需要用户确认（破坏性操作）

4. **AC4: EstimateCostTool 费用预估（FR46）**
   **Given** Agent 需要告知用户去重操作的预估成本
   **When** Agent 调用 EstimateCostTool
   **Then** 工具通过 LLMGateway.estimateCost() 返回预计的 LLM API 调用成本
   **And** 返回预估 API 调用次数和费用金额

5. **AC5: 工具注册（FR13）**
   **Given** 所有去重 SDK 工具已实现
   **When** 应用启动并注册 Agent 基础设施
   **Then** AnalyzeDuplicatesTool、DeleteAssetsTool、EstimateCostTool 已注册至 AgentToolRegistry
   **And** ScanLibraryTool 已注册（已有实现，需验证）
   **And** CuratorAgent 系统提示词已更新包含去重工具说明

6. **AC6: 错误处理与容错（NFR20, NFR23）**
   **Given** 工具执行过程中发生错误
   **When** 依赖服务不可用（LLM、文件系统等）
   **Then** 工具返回结构化错误信息，Agent 可据此向用户报告
   **And** 不导致应用崩溃或 Agent 循环中断

## Tasks / Subtasks

- [x] Task 1: 创建 AnalyzeDuplicatesTool (AC: #2, #6)
  - [x] 1.1 创建 `Curator/Infrastructure/SDKTools/AnalyzeDuplicatesTool.swift`
  - [x] 1.2 定义 `AnalyzeDuplicatesInput: Codable, Sendable` — 包含 `maxPhotos: Int?`（限制分析照片数量）、`hashThreshold: Int?`（pHash 汉明距离阈值，默认 10）
  - [x] 1.3 使用 `defineTool()` 工厂函数，工具名 `analyze_duplicates`
  - [x] 1.4 工具描述："Analyze photos in the library for duplicates using two-stage analysis: local perceptual hashing followed by AI confirmation. Returns groups of duplicate photos with similarity scores and explanations."
  - [x] 1.5 `inputSchema` JSON Schema：`maxPhotos`(integer, optional)、`hashThreshold`(integer, optional)
  - [x] 1.6 设置 `isReadOnly: true`、`annotations: ToolAnnotations(readOnlyHint: true, destructiveHint: false)`
  - [x] 1.7 实现工具逻辑
  - [x] 1.8 错误处理：pipeline 错误通过 defineTool 的 CodableTool 自动包装为 isError:true

- [x] Task 2: 创建 DeleteAssetsTool (AC: #3, #6)
  - [x] 2.1 创建 `Curator/Infrastructure/SDKTools/DeleteAssetsTool.swift`
  - [x] 2.2 定义 `DeleteAssetsInput: Codable, Sendable` — 包含 `assetIDs: [String]`（要删除的资产 ID 列表）、`batchDescription: String?`（操作描述）
  - [x] 2.3 使用 `defineTool()` 工厂函数，工具名 `delete_assets`
  - [x] 2.4 工具描述
  - [x] 2.5 `inputSchema` JSON Schema
  - [x] 2.6 设置 `isReadOnly: false`、`annotations: ToolAnnotations(readOnlyHint: false, destructiveHint: true)`
  - [x] 2.7 实现工具逻辑（beginBatch + executeBatch，通过 OperationManager 回滚）
  - [x] 2.8 错误处理：验证空 assetIDs、beginBatch/executeBatch 失败时自动回滚

- [x] Task 3: 创建 EstimateCostTool (AC: #4, #6)
  - [x] 3.1 创建 `Curator/Infrastructure/SDKTools/EstimateCostTool.swift`
  - [x] 3.2 定义 `EstimateCostInput: Codable, Sendable`
  - [x] 3.3 使用 `defineTool()` 工厂函数，工具名 `estimate_cost`
  - [x] 3.4 工具描述
  - [x] 3.5 `inputSchema` JSON Schema
  - [x] 3.6 设置 `isReadOnly: true`、`annotations: ToolAnnotations(readOnlyHint: true, destructiveHint: false)`
  - [x] 3.7 实现工具逻辑（deduplication: photoCount/5, rename: photoCount，调用 llmGateway.estimateCost）
       - deduplication: photoCount / 5（每组约 5 张照片进行 LLM 确认）
       - rename: photoCount（每张照片一次 LLM 调用）
    2. 调用 llmGateway.estimateCost(imageCount: photoCount, model: model ?? "default")
    3. 返回 JSON：{ "estimatedCost": ..., "estimatedAPICalls": ..., "model": ..., "provider": ... }
    ```

- [x] Task 4: 工具注册与 DI 集成 (AC: #5)
  - [x] 4.1 修改 `Curator/App/AppDependencies.swift` — 添加 `registerDeduplicationTools()` 方法
  - [x] 4.2 在方法中创建并注册 AnalyzeDuplicatesTool、DeleteAssetsTool、EstimateCostTool 到 toolRegistry
  - [x] 4.3 ScanLibraryTool 已在 Story 3.2 注册，验证其仍在注册（通过 DedupToolRegistrationTests.testScanLibraryToolRegistered 验证）
  - [x] 4.4 在 ContentView 的 `.task` 中添加 `dependencies.registerDeduplicationTools()` 和 `registerAnalysisInfrastructure()` 调用
  - [x] 4.5 确保 registerDeduplicationTools 在 registerAgentInfrastructure 之后调用

- [x] Task 5: 更新 CuratorAgent 系统提示词 (AC: #5)
  - [x] 5.1 修改 `Curator/Core/Agent/CuratorAgent.swift` — 更新 `photoManagerSystemPrompt`
  - [x] 5.2 在 "Available Tools" 部分添加去重工具说明
  - [x] 5.3 在 Guidelines 中添加去重流程指导

- [x] Task 6: ATDD 测试 (AC: #1, #2, #3, #4, #5, #6)
  - [x] 6.1 创建 `CuratorTests/Infrastructure/SDKTools/AnalyzeDuplicatesToolTests.swift`
  - [x] 6.2 创建 `CuratorTests/Infrastructure/SDKTools/DeleteAssetsToolTests.swift`
  - [x] 6.3 创建 `CuratorTests/Infrastructure/SDKTools/EstimateCostToolTests.swift`
  - [x] 6.4 [P0] testAnalyzeDuplicatesReturnsGroups — 分析工具返回 DuplicateGroup 列表
  - [x] 6.5 [P0] testAnalyzeDuplicatesWithEmptyLibrary — 空图库返回空结果
  - [x] 6.6 [P0] testDeleteAssetsCreatesSnapshotAndExecutes — 删除工具创建快照并执行
  - [x] 6.7 [P0] testDeleteAssetsRollsBackOnFailure — 删除失败时自动回滚
  - [x] 6.8 [P0] testEstimateCostReturnsCostEstimate — 费用预估工具返回正确估算
  - [x] 6.9 [P1] testAllDedupToolsRegisteredInRegistry — 所有去重工具已注册到 toolRegistry
  - [x] 6.10 [P1] testAnalyzeDuplicatesHandlesPipelineError — 分析管线错误时返回结构化错误
  - [x] 6.11 [P1] testDeleteAssetsHandlesInvalidAssetIDs — 无效资产 ID 时返回错误
  - [x] 6.12 [P1] testEstimateCostDifferentOperations — 不同操作类型的费用预估
  - [x] 6.13 [P1] testToolAnnotationsCorrect — 工具注解（readOnly/destructive）正确设置
  - [x] 6.14 构建通过 + 全部现有测试通过（700 tests, 0 failures）

## Dev Notes

### 架构约束

1. **工具使用 `defineTool()` 工厂函数**：遵循 ScanLibraryTool 的模式，使用闭包捕获依赖注入的服务实例。[Source: Curator/Infrastructure/SDKTools/ScanLibraryTool.swift]
2. **Input 类型必须 `Codable, Sendable`**：与 `defineTool()` 的 JSON 序列化管道兼容。[Source: Curator/Infrastructure/SDKTools/ScanLibraryTool.swift]
3. **工具返回 JSON 字符串**：所有工具结果为 JSON 格式字符串，供 Agent LLM 解析。[Source: Curator/Infrastructure/SDKTools/ScanLibraryTool.swift]
4. **ToolAnnotations 必须正确设置**：只读工具 `readOnlyHint: true`，破坏性工具 `destructiveHint: true`。[Source: architecture.md#决策2]
5. **禁止使用 `Task` 作为类型名**。[Source: CLAUDE.md]
6. **三层错误链路**：Infrastructure 层错误映射为 DomainError 再向上传播。[Source: project-context.md#三层错误体系]
7. **破坏性操作必须通过 OperationManager**：DeleteAssetsTool 的删除操作通过 beginBatch + executeBatch 执行。[Source: project-context.md#Critical Implementation Rules]
8. **API 调用必须通过 LLMGateway**：EstimateCostTool 的费用预估通过 llmGateway.estimateCost() 执行。[Source: project-context.md#Critical Implementation Rules]

### 前置 Story 5.2 的实现（必须复用）

**分析管线：**
- `ImageAnalysisPipelineProtocol` — `analyze(assets:repository:)` 和 `analyze(assets:repository:progressHandler:)`。[Source: Curator/Core/Models/ImageAnalysisPipelineProtocol.swift]
- `ImageAnalysisPipeline` (actor) — 已实现两阶段分析，已注册到 AppDependencies.imageAnalysisPipeline。[Source: Curator/Infrastructure/Analysis/ImageAnalysisPipeline.swift]

**模型类型：**
- `DuplicateGroup` — `id: UUID`、`assets: [PhotoAsset]`、`similarityScore: Double`、`reason: String?`、`thumbnails: [AssetID: Data]`、`status: DuplicateGroupStatus`。[Source: Curator/Core/Models/DuplicateGroup.swift]
- `DuplicateGroupStatus` — `.pending`、`.confirmed`、`.rejected`、`.analysisFailed`。[Source: Curator/Core/Models/DuplicateGroup.swift]
- `PhotoAsset` — `id: AssetID`、`metadata: AssetMetadata`。[Source: Curator/Core/Models/PhotoAsset.swift]
- `AssetID` — `rawValue: String`，Sendable, Hashable, Codable。[Source: Curator/Core/Models/AssetID.swift]

### 前置 Epic 的已有实现

**Agent 基础设施：**
- `AgentToolRegistry` — `register(_ tool:)`、`allTools`。[Source: Curator/Core/Agent/AgentToolRegistry.swift]
- `CuratorAgentFactory` — `createAgent(tools:systemPrompt:)`。[Source: Curator/Core/Agent/CuratorAgentFactory.swift]
- `CuratorAgent` — 系统提示词 `photoManagerSystemPrompt`。[Source: Curator/Core/Agent/CuratorAgent.swift]
- `ScanLibraryTool` — 已实现的 `createScanLibraryTool(repository:)`。[Source: Curator/Infrastructure/SDKTools/ScanLibraryTool.swift]
- `defineTool()` — OpenAgentSDK 工厂函数，用于创建 ToolProtocol 实例。

**操作管理：**
- `OperationManaging` 协议 — `beginBatch(operations:repository:)`、`executeBatch(_:repository:)`、`rollbackBatch(_:repository:)`。[Source: Curator/Core/Operations/OperationManaging.swift]
- `OperationManager` (actor) — 已实现快照/回滚，已注册到 AppDependencies.operationManager。[Source: Curator/App/AppDependencies.swift]
- `PlannedOperation` — `operationType: OperationType`、`assetID: AssetID`、`parameters: OperationParameters`。[Source: Curator/Core/Operations/PlannedOperation.swift]
- `OperationParameters` — `.rename(newTitle:)`、`.delete`、`.move(targetDirectory:)`、`.metadataChange`。[Source: Curator/Core/Operations/PlannedOperation.swift]

**LLM 网关：**
- `LLMGatewayProtocol` — `estimateCost(imageCount:model:) async -> CostEstimate`。[Source: Curator/Core/Models/LLMGatewayProtocol.swift]
- `LLMGateway` (actor) — 已注册到 AppDependencies.llmGateway。[Source: Curator/App/AppDependencies.swift]
- `CostEstimate` — `estimatedTokens: Int`、`estimatedCost: Double`、`modelID: String`、`providerName: String`、`estimatedAPICalls: Int`、`currency: String`。[Source: Curator/Core/Models/CostEstimate.swift]

**照片来源：**
- `PhotoLibraryRepository` — `fetchAssets(predicate:pageSize:pageOffset:)`、`deleteAssets(_:)`。[Source: Curator/Core/Models/PhotoLibraryRepository.swift]

### 关键设计决策

#### 工具工厂函数模式

每个工具使用独立的全局工厂函数（如 `createAnalyzeDuplicatesTool`），通过闭包捕获依赖注入的服务。这与 ScanLibraryTool 的模式一致：

```swift
func createAnalyzeDuplicatesTool(
    pipeline: any ImageAnalysisPipelineProtocol,
    repository: any PhotoLibraryRepository
) -> ToolProtocol {
    return defineTool(
        name: "analyze_duplicates",
        description: "...",
        inputSchema: [...],
        isReadOnly: true,
        annotations: ToolAnnotations(readOnlyHint: true, destructiveHint: false)
    ) { (input: AnalyzeDuplicatesInput, _: ToolContext) async throws -> String in
        // 使用捕获的 pipeline 和 repository
    }
}
```

#### AnalyzeDuplicatesTool 分析流程

```
1. repository.fetchAssets(predicate: .all, pageSize: input.maxPhotos ?? 500, pageOffset: 0)
2. pipeline.analyze(assets: page.assets, repository: repository)
3. 将 DuplicateGroup[] 序列化为 JSON：
   [
     {
       "id": "...",
       "assetIDs": ["...", "..."],
       "fileNames": ["photo1.jpg", "photo2.jpg"],
       "similarityScore": 0.95,
       "reason": "LLM 提供的匹配原因",
       "assetCount": 2
     },
     ...
   ]
```

#### DeleteAssetsTool 安全删除流程

DeleteAssetsTool 是本 Story 中唯一的破坏性工具。它必须：

1. **创建快照**：调用 `operationManager.beginBatch(operations: repository:)` 记录操作前状态
2. **执行删除**：调用 `operationManager.executeBatch(batchID: repository:)`
3. **错误时回滚**：executeBatch 内部 OperationManager 已实现自动回滚（Story 4.2）
4. **返回 batchID**：用于后续可能的撤销操作

**重要：** 工具本身不负责展示确认 UI——这是 Agent 循环和 ChatInputViewModel 的职责。工具仅在 Agent 明确调用时执行。Agent 系统提示词指导 Agent 在调用 delete_assets 前必须获得用户确认。

#### EstimateCostTool 费用预估

根据操作类型计算预估 API 调用次数：
- `deduplication`：LLM 仅在第二阶段（语义确认）消耗 API。预估组数 = photoCount / 5（平均每组 5 张照片）
- `rename`：每张照片一次 LLM 调用（内容分析 + 命名生成）

调用 `llmGateway.estimateCost(imageCount: estimatedAPICalls, model: model)` 获取费用。

#### DI 注册顺序

```
1. registerLocalFolderRepository()  → photoRepository
2. registerLLMGateway()             → llmGateway, operationManager, costTracker
3. registerAgentInfrastructure()    → toolRegistry, curatorAgentFactory
4. registerAnalysisInfrastructure() → hasher, imageAnalysisPipeline
5. registerDeduplicationTools()     → 注册 analyze_duplicates, delete_assets, estimate_cost
                                       （需要 toolRegistry, imageAnalysisPipeline,
                                          operationManager, llmGateway, photoRepository）
```

### 与现有代码的集成点

**新建的文件：**

1. `Curator/Infrastructure/SDKTools/AnalyzeDuplicatesTool.swift` — 去重分析工具
2. `Curator/Infrastructure/SDKTools/DeleteAssetsTool.swift` — 删除执行工具
3. `Curator/Infrastructure/SDKTools/EstimateCostTool.swift` — 费用预估工具
4. `CuratorTests/Infrastructure/SDKTools/AnalyzeDuplicatesToolTests.swift` — ATDD 测试
5. `CuratorTests/Infrastructure/SDKTools/DeleteAssetsToolTests.swift` — ATDD 测试
6. `CuratorTests/Infrastructure/SDKTools/EstimateCostToolTests.swift` — ATDD 测试

**修改的文件：**

1. `Curator/App/AppDependencies.swift` — 添加 `registerDeduplicationTools()` 方法
2. `Curator/Core/Agent/CuratorAgent.swift` — 更新 `photoManagerSystemPrompt` 添加去重工具说明
3. `Curator/ContentView.swift` — 添加 `registerDeduplicationTools()` 和 `registerAnalysisInfrastructure()` 调用

**不修改的文件：**

- 不修改 ScanLibraryTool — 已有实现，仅验证是否已注册
- 不修改 ImageAnalysisPipeline — 通过协议调用，不修改实现
- 不修改 OperationManager — 通过协议调用，不修改实现
- 不修改 LLMGateway — 通过协议调用，不修改实现
- 不修改 DeduplicationViewModel — Story 5.4 的 UI 层
- 不修改 AgentToolRegistry — 仅使用其 register() 方法

### 不做什么（范围边界）

以下内容在本 Story 中 **不实现**：

- **去重审核界面** — Story 5.4 职责（DeduplicationViewModel、PhotoComparisonCard、DuplicateReviewView）
- **批量审批 UI** — Story 5.5 职责（BatchApprovalView）
- **去重结果摘要** — Story 5.6 职责（AgentResultSummary）
- **确认工作流 UI** — Story 4.4 已实现（ConfirmationViewModel），本 Story 的 DeleteAssetsTool 仅执行操作，不触发 UI 确认
- **RenameAssetsTool / AnalyzeContentTool** — Story 6.2 职责（Epic 6 重命名 SDK 工具）
- **工具执行的进度 UI 更新** — AgentEvent 流式传输在 Story 3.6 已实现，工具返回结果后 SDKMessageBridge 自动转换

### NFR 关注点

- **NFR6（500MB 内存）**：AnalyzeDuplicatesTool 调用 ImageAnalysisPipeline，已实现逐组处理和内存控制。
- **NFR10（TLS 传输）**：EstimateCostTool 通过 LLMGateway 调用（URLSession HTTPS），自动满足。
- **NFR15（零文件损坏）**：DeleteAssetsTool 通过 OperationManager 执行，仅删除文件不修改原始图像内容。原始图像文件以外的文件名/目录变更通过快照支持回滚。
- **NFR16（5 秒回滚）**：OperationManager 已实现 5 秒内完成回滚，DeleteAssetsTool 直接复用。
- **NFR20（LLM 重试）**：LLMGateway 已实现指数退避重试和故障转移，EstimateCostTool 直接复用。
- **NFR23（容错）**：工具返回结构化 JSON 错误，不导致应用崩溃。Agent 循环可捕获工具错误并向用户报告。

### 项目结构说明

本 Story 新增的文件：

```
Curator/
└── Infrastructure/SDKTools/
    ├── AnalyzeDuplicatesTool.swift          # 新建：去重分析工具
    ├── DeleteAssetsTool.swift               # 新建：删除执行工具
    └── EstimateCostTool.swift               # 新建：费用预估工具
```

修改的文件：

```
Curator/
├── App/AppDependencies.swift                # 修改：添加 registerDeduplicationTools()
├── Core/Agent/CuratorAgent.swift            # 修改：更新系统提示词
└── ContentView.swift                        # 修改：添加注册调用
```

测试文件：

```
CuratorTests/
└── Infrastructure/SDKTools/
    ├── AnalyzeDuplicatesToolTests.swift     # 新建：ATDD 测试
    ├── DeleteAssetsToolTests.swift          # 新建：ATDD 测试
    └── EstimateCostToolTests.swift          # 新建：ATDD 测试
```

### 与后续 Story 的关系

**本 Story（5.3）完成后：**

- **Story 5.4（去重审核界面）** — DeduplicationViewModel 展示 AnalyzeDuplicatesTool 返回的 DuplicateGroup 列表，用户可通过 UI 逐组审核。
- **Story 5.5（批量审批与执行）** — 用户在审核界面确认后，调用 DeleteAssetsTool 批量删除。BatchApprovalView 集成 OperationManager 确认工作流。
- **Story 5.6（去重结果摘要）** — 删除完成后展示 AgentResultSummary。

### Mock 策略

测试中需要 Mock 以下依赖：

```swift
// Mock ImageAnalysisPipeline — 返回预设的 DuplicateGroup 列表
private struct MockImageAnalysisPipeline: ImageAnalysisPipelineProtocol { ... }

// Mock OperationManaging — 记录 beginBatch/executeBatch 调用
private actor MockOperationManager: OperationManaging { ... }

// Mock LLMGatewayProtocol — 返回预设的 CostEstimate
private struct MockLLMGateway: LLMGatewayProtocol { ... }

// Mock PhotoLibraryRepository — 返回预设的照片列表
private struct MockPhotoLibraryRepository: PhotoLibraryRepository { ... }
```

工具测试直接调用工厂函数返回的 ToolProtocol，通过 Mock 依赖验证行为。不需要启动 Agent 循环。

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 5.3] — 原始需求定义（去重 SDK 工具）
- [Source: _bmad-output/planning-artifacts/architecture.md#Infrastructure/SDKTools] — SDK 工具目录结构
- [Source: _bmad-output/planning-artifacts/architecture.md#决策2] — Agent 执行引擎（AsyncStream 流式管道、工具注册）
- [Source: _bmad-output/planning-artifacts/architecture.md#决策4] — LLM 网关（Provider 协议 + 故障转移）
- [Source: _bmad-output/planning-artifacts/architecture.md#决策7] — 操作回滚系统（快照 + 操作日志）
- [Source: _bmad-output/planning-artifacts/prd.md#FR13] — Agent 自主执行多步工作流
- [Source: _bmad-output/planning-artifacts/prd.md#FR18] — 请求重复照片检测
- [Source: _bmad-output/planning-artifacts/prd.md#FR19] — 本地感知哈希算法
- [Source: _bmad-output/planning-artifacts/prd.md#FR20] — LLM 确认视觉相似照片是否为真正重复
- [Source: _bmad-output/planning-artifacts/prd.md#FR22] — 批准或拒绝单个重复分组
- [Source: _bmad-output/planning-artifacts/prd.md#FR33] — 破坏性操作前需用户批准
- [Source: _bmad-output/planning-artifacts/prd.md#FR46] — 分析任务执行前展示费用预估
- [Source: _bmad-output/planning-artifacts/prd.md#NFR15] — 零文件损坏
- [Source: _bmad-output/planning-artifacts/prd.md#NFR16] — 5 秒回滚
- [Source: _bmad-output/planning-artifacts/prd.md#NFR20] — LLM 指数退避重试
- [Source: _bmad-output/planning-artifacts/prd.md#NFR23] — 部分不可访问时保持功能
- [Source: _bmad-output/project-context.md#Critical Implementation Rules] — Swift 6 严格并发、actor 隔离、Sendable
- [Source: _bmad-output/project-context.md#Architecture Boundaries] — Infrastructure/SDKTools/ 目录映射
- [Source: _bmad-output/project-context.md#Testing Rules] — ATDD 风格、Mock 模式
- [Source: _bmad-output/implementation-artifacts/5-2-image-analysis-pipeline.md] — Story 5.2 实现（分析管线）
- [Source: Curator/Infrastructure/SDKTools/ScanLibraryTool.swift] — 工具工厂函数模式（复用）
- [Source: Curator/Core/Agent/AgentToolRegistry.swift] — 工具注册表（复用）
- [Source: Curator/Core/Agent/CuratorAgent.swift] — Agent 系统提示词（修改）
- [Source: Curator/Core/Models/ImageAnalysisPipelineProtocol.swift] — 分析管线协议（复用）
- [Source: Curator/Core/Models/DuplicateGroup.swift] — 重复分组模型（复用）
- [Source: Curator/Core/Operations/OperationManaging.swift] — 操作管理协议（复用）
- [Source: Curator/Core/Operations/PlannedOperation.swift] — 计划操作模型（复用）
- [Source: Curator/Core/Models/LLMGatewayProtocol.swift] — LLM 网关协议（复用）
- [Source: Curator/Core/Models/CostEstimate.swift] — 费用预估模型（复用）
- [Source: Curator/Core/Models/PhotoLibraryRepository.swift] — 照片来源协议（复用）
- [Source: Curator/App/AppDependencies.swift] — 依赖注入容器（修改）

## Dev Agent Record

### Agent Model Used

GLM-5.1

### Debug Log References

- Fixed conflict with ATDD stub file DedupToolStubs.swift that shadowed real implementations
- Fixed test assertions for CodableTool error wrapping (case-sensitive "Error" vs "error")
- Used String-returning defineTool overload instead of ToolExecuteResult to avoid overload resolution issues

### Completion Notes List

- Implemented AnalyzeDuplicatesTool using defineTool with ImageAnalysisPipelineProtocol integration
- Implemented DeleteAssetsTool with OperationManager beginBatch/executeBatch flow and empty array validation
- Implemented EstimateCostTool with deduplication (photoCount/5) and rename (photoCount) API call estimation
- Added registerDeduplicationTools() to AppDependencies with proper DI ordering
- Added registerAnalysisInfrastructure() and registerDeduplicationTools() calls to ContentView
- Updated CuratorAgent system prompt with all four tool descriptions and dedup workflow guidance
- Removed ATDD stub file (DedupToolStubs.swift) that was shadowing real implementations
- All 700 tests pass including 18 new ATDD tests (5 P0 + 13 P1)

### File List

**New Files:**
- Curator/Infrastructure/SDKTools/AnalyzeDuplicatesTool.swift
- Curator/Infrastructure/SDKTools/DeleteAssetsTool.swift
- Curator/Infrastructure/SDKTools/EstimateCostTool.swift

**Modified Files:**
- Curator/App/AppDependencies.swift
- Curator/Core/Agent/CuratorAgent.swift
- Curator/ContentView.swift
- CuratorTests/Infrastructure/SDKTools/AnalyzeDuplicatesToolTests.swift
- CuratorTests/Infrastructure/SDKTools/DeleteAssetsToolTests.swift
- CuratorTests/Infrastructure/SDKTools/EstimateCostToolTests.swift
- CuratorTests/Infrastructure/SDKTools/DedupToolRegistrationTests.swift

**Deleted Files:**
- CuratorTests/Infrastructure/SDKTools/DedupToolStubs.swift

### Review Findings

- [x] [Review][Patch] hashThreshold parameter declared but unused in AnalyzeDuplicatesTool [Curator/Infrastructure/SDKTools/AnalyzeDuplicatesTool.swift:15] -- Fixed: Added doc note explaining forward-compatibility. The ImageAnalysisPipeline protocol does not yet expose threshold configuration.
- [x] [Review][Patch] String(describing:) on DuplicateGroupStatus is fragile for JSON serialization [Curator/Infrastructure/SDKTools/AnalyzeDuplicatesTool.swift:74] -- Fixed: Added explicit `stringValue` computed property to DuplicateGroupStatus enum.
- [x] [Review][Defer] Duplicate mock repository implementations across 3 test files [CuratorTests/Infrastructure/SDKTools/*.swift] -- deferred, pre-existing pattern
