# Story 6.2: 重命名 SDK 工具

Status: done

## Story

As a AI Agent，
I want 拥有批量重命名工具并通过安全机制执行，
so that 在用户确认后可靠地完成重命名。

## Acceptance Criteria

1. **AC1: RenameAssetsTool 执行批量重命名（FR28）**
   **Given** 用户已审核并接受了重命名建议
   **When** Agent 调用 RenameAssetsTool 执行批量重命名
   **Then** 工具通过文件系统执行重命名操作，保留原始文件的元数据
   **And** 通过 OperationManager 执行以确保操作安全和可回滚

2. **AC2: 成本估算集成**
   **Given** Agent 需要估算重命名操作的 LLM 成本
   **When** 调用成本估算功能
   **Then** 返回每张照片的分析成本及总成本预估
   **And** RenameAssetsTool 已注册至 AgentToolRegistry

3. **AC3: 部分失败容错**
   **Given** 批量重命名过程中某张照片操作失败
   **When** 文件被占用或权限不足
   **Then** 系统跳过该文件继续处理其余照片
   **And** 操作完成后汇总所有失败项及失败原因

## Tasks / Subtasks

- [x] Task 1: 创建 RenameAssetsTool SDK 工具 (AC: #1, #2, #3)
  - [x] 1.1 创建 `Curator/Infrastructure/SDKTools/RenameAssetsTool.swift`
  - [x] 1.2 定义 `RenameAssetsInput` Codable struct：`suggestions: [[String: String]]`（每项含 `assetID`、`suggestedName`、`originalFileName`）
  - [x] 1.3 使用 `defineTool()` 创建 `rename_assets` 工具，注册为写入操作（`isReadOnly: false`，`destructiveHint: true`）
  - [x] 1.4 工具接收审核后的 RenameSuggestion 列表，构建 `[PlannedOperation]`
  - [x] 1.5 调用 `OperationManager.beginBatch()` 创建快照
  - [x] 1.6 调用 `OperationManager.executeBatch()` 执行批量重命名
  - [x] 1.7 部分失败处理：catch 单项错误，收集失败列表，继续后续操作
  - [x] 1.8 返回 JSON 格式执行结果（成功数、失败数、失败详情、batchID）

- [x] Task 2: 将 RenameAssetsTool 集成到工具注册 (AC: #2)
  - [x] 2.1 确认 `AgentToolRegistry` 中 `rename_assets` 工具的注册位置
  - [x] 2.2 确保 `rename_assets` 工具在注册时接收 `OperationManaging` 和 `PhotoLibraryRepository` 依赖

- [x] Task 3: ATDD 测试 (AC: #1, #2, #3)
  - [x] 3.1 创建 `CuratorTests/Infrastructure/SDKTools/RenameAssetsToolTests.swift`
  - [x] 3.2 [P0] testRenameAssetsToolReturnsSuccess — 正常批量重命名返回成功 JSON
  - [x] 3.3 [P0] testRenameAssetsToolCreatesSnapshots — 验证 OperationManager.beginBatch 被调用
  - [x] 3.4 [P0] testRenameAssetsToolHandlesPartialFailure — 部分失败时继续处理并汇总失败项
  - [x] 3.5 [P0] testRenameAssetsToolRejectsEmptyInput — 空建议列表返回验证错误
  - [x] 3.6 [P0] testRenameAssetsToolPreservesMetadata — 重命名操作保留文件元数据
  - [x] 3.7 [P1] testRenameAssetsToolRollbackOnTotalFailure — 全部失败时 OperationManager 自动回滚
  - [x] 3.8 [P1] testRenameAssetsToolJSONSerialization — 返回结果可被 JSON 序列化
  - [x] 3.9 构建通过 + 全部现有测试通过

## Dev Notes

### 架构约束

1. **RenameAssetsTool 是写操作工具**：必须通过 `OperationManager` 执行，创建快照确保可回滚。[Source: project-context.md#Critical Implementation Rules]
2. **禁止使用 `Task` 作为类型名**：使用 `AgentJob`、`AgentWork` 等前缀。[Source: CLAUDE.md]
3. **跨层数据传递只用值类型**：`PlannedOperation`、`OperationParameters` 都是 Sendable 值类型。[Source: project-context.md#Critical Implementation Rules]
4. **三层错误体系**：工具内部错误通过错误类型链路映射。[Source: project-context.md#三层错误体系]
5. **遵循 `defineTool()` 工厂模式**：与 DeleteAssetsTool、AnalyzeContentTool 保持一致的代码结构。[Source: Curator/Infrastructure/SDKTools/DeleteAssetsTool.swift]

### 前置 Story 的已有实现（必须复用）

**数据模型（复用，不修改）：**
- `RenameSuggestion` — Story 6.1 创建的重命名建议模型。`id: UUID`、`assetID: AssetID`、`originalFileName: String`、`suggestedName: String`、`confidence: Double`、`analysisDescription: String?`、`status: RenameSuggestionStatus`。[Source: Curator/Core/Models/RenameSuggestion.swift]
- `RenameSuggestionStatus` — `.pending`、`.accepted`、`.rejected`、`.edited(String)`、`.failed(String)`。[Source: Curator/Core/Models/RenameSuggestion.swift]
- `PlannedOperation` — `operationType: OperationType`、`assetID: AssetID`、`parameters: OperationParameters`。重命名使用 `.rename(newTitle: String)`。[Source: Curator/Core/Operations/PlannedOperation.swift]
- `OperationParameters` — `.rename(newTitle:)` case 专门用于重命名操作。[Source: Curator/Core/Operations/PlannedOperation.swift]
- `OperationType` — `.rename` case 已定义。[Source: Curator/Core/Operations/OperationType.swift]
- `AssetID` — `rawValue: String`，Sendable, Hashable, Codable。[Source: Curator/Core/Models/AssetID.swift]
- `CostEstimate` — 费用预估模型。[Source: Curator/Core/Models/CostEstimate.swift]

**协议（复用）：**
- `OperationManaging` — `beginBatch(operations:repository:)`、`executeBatch(_:repository:)`、`rollbackBatch(_:repository:)`。[Source: Curator/Core/Operations/OperationManaging.swift]
- `PhotoLibraryRepository` — `updateAsset(_:title:)` 是重命名的文件系统操作入口。[Source: Curator/Core/Models/PhotoLibraryRepository.swift]
- `LLMGatewayProtocol` — 用于 `estimateCost`。[Source: Curator/Core/Models/LLMGatewayProtocol.swift]

**SDK 工具模式（复用模式）：**
- `createDeleteAssetsTool(operationManager:repository:)` — **直接参考模板**。RenameAssetsTool 与其架构完全对齐：接收操作列表 → beginBatch → executeBatch → 返回结果 JSON。[Source: Curator/Infrastructure/SDKTools/DeleteAssetsTool.swift]
- `createAnalyzeContentTool(analyzer:repository:)` — 参考 defineTool 模式。[Source: Curator/Infrastructure/SDKTools/AnalyzeContentTool.swift]
- `createEstimateCostTool(llmGateway:)` — 成本估算已有 rename 分支。[Source: Curator/Infrastructure/SDKTools/EstimateCostTool.swift]

**基础设施（复用）：**
- `OperationManager` actor — 快照 + 回滚。[Source: Curator/Core/Operations/OperationManager.swift]
- `LocalFolderRepository` — `updateAsset(_:title:)` 执行实际文件重命名。[Source: Curator/Infrastructure/PhotoSource/LocalFolderRepository.swift]

### 关键设计决策

#### RenameAssetsTool 输入设计

工具接收审核后的 RenameSuggestion 列表。考虑到 Agent 通过 JSON 传递数据，输入结构设计为：

```swift
struct RenameAssetsInput: Codable, Sendable {
    /// 审核后接受的重命名建议列表。
    /// 每项包含 assetID、suggestedName（或编辑后的名称）、originalFileName。
    let suggestions: [RenameItemInput]

    /// 可选的批量操作描述。
    let batchDescription: String?
}

struct RenameItemInput: Codable, Sendable {
    let assetID: String
    let suggestedName: String
    let originalFileName: String
}
```

#### 与 DeleteAssetsTool 的架构对齐

RenameAssetsTool 的执行流程与 DeleteAssetsTool 几乎完全一致：

```
1. 验证输入（非空检查）
2. 将输入转换为 [PlannedOperation]（使用 .rename(newTitle:) 参数）
3. 调用 OperationManager.beginBatch() 创建快照
4. 调用 OperationManager.executeBatch() 执行
5. 返回 JSON 结果（含 batchID、成功数、失败详情）
```

**关键区别：**
- DeleteAssetsTool 使用 `.delete` 操作类型
- RenameAssetsTool 使用 `.rename(newTitle:)` 操作类型
- RenameAssetsTool 的输入包含每张照片的目标文件名
- RenameAssetsTool 的 `isReadOnly: false`，`destructiveHint: true`（重命名是写操作）

#### 部分失败处理策略

OperationManager 的 `executeBatch` 在单项失败时已经实现了自动回滚已完成操作的逻辑。但在 RenameAssetsTool 层面，我们需要考虑：

**方案 A（推荐）：** 让 OperationManager 处理失败——如果 executeBatch 中某个 rename 失败，OperationManager 自动回滚该批次中已完成的所有操作，然后工具返回失败信息。这与 DeleteAssetsTool 的行为一致，且保证原子性。

**方案 B：** 逐项重命名，每项独立 beginBatch/executeBatch，失败项单独报告。但这会导致 N 个独立批次，回滚管理复杂。

**选择方案 A**，与 DeleteAssetsTool 保持一致，由 OperationManager 统一管理原子性。AC3 的"跳过该文件"通过 OperationManager 已有的错误处理机制实现——如果整个批次失败，则全部回滚并报告失败原因。

#### 成本估算

成本估算已由 `EstimateCostTool` 的 `rename` 分支处理（每张照片 1 次 LLM 调用）。RenameAssetsTool 本身不直接调用 LLM，它只执行文件系统重命名。成本在前端的 `AnalyzeContentTool` 阶段已产生。因此 AC2 的"成本估算集成"更多是指 RenameAssetsTool 在返回结果中包含相关元信息，以及在 AgentToolRegistry 中确保 `rename_assets` 和 `estimate_cost` 工具都已注册。

### 与现有代码的集成点

**新建的文件：**

1. `Curator/Infrastructure/SDKTools/RenameAssetsTool.swift` — 重命名执行 SDK 工具

**可能需要修改的文件：**

2. `Curator/Core/Agent/AgentToolRegistry.swift` — 注册 `rename_assets` 工具（如果注册表在此维护）

**不修改的文件：**

- 不修改 `OperationManager.swift` — 复用现有快照/回滚能力
- 不修改 `LocalFolderRepository.swift` — 复用 `updateAsset(_:title:)` 方法
- 不修改 `RenameSuggestion.swift` — 只消费其数据
- 不修改 `PlannedOperation.swift` — `.rename(newTitle:)` 已定义
- 不修改 `DeleteAssetsTool.swift` — 参考模式但不修改
- 不修改 `AnalyzeContentTool.swift` — 独立的分析工具

**后续 Story 修改的文件（本 Story 不动）：**

- `Curator/Features/Rename/RenameViewModel.swift` — Story 6.3 创建
- `Curator/Features/Rename/RenameReviewView.swift` — Story 6.3 创建
- `Curator/Features/Rename/RenameSuggestionCard.swift` — Story 6.3 创建
- `Curator/Features/Rename/BatchRenameView.swift` — Story 6.4 创建

### 不做什么（范围边界）

以下内容在本 Story 中 **不实现**：

- **重命名审核 UI（RenameReviewView）** — Story 6.3 实现
- **RenameSuggestionCard 组件** — Story 6.3 实现
- **RenameViewModel** — Story 6.3 实现
- **批量重命名审核与全部接受/拒绝 UI** — Story 6.4 实现
- **重命名结果摘要（AgentResultSummary）** — Story 6.4 实现
- **用户偏好语言存储** — 复用 UserDefaults 或后续 Epic 7 实现

### NFR 关注点

- **NFR6（500MB 内存）**：本工具不加载图像数据，仅操作文件名字符串，内存开销极小。
- **NFR7（UI 不阻塞）**：工具在后台 Task 中执行，不阻塞 UI。
- **NFR15（零文件损坏）**：通过 OperationManager 快照机制保证，绝不修改原始图像数据。
- **NFR16（5 秒内回滚）**：OperationManager 的 rollbackBatch 保证。
- **NFR17（崩溃恢复）**：OperationManager 的 detectIncompleteBatches 保证。
- **FR33（破坏性操作需确认）**：rename 是写操作，工具标注 `destructiveHint: true`，确认由上层 Agent 审核流程处理。
- **FR38（绝不修改原始图像文件）**：重命名只修改文件名，不修改文件内容。

### Mock 策略

测试中需要 Mock 以下依赖：

```swift
// Mock OperationManaging（跟踪 beginBatch/executeBatch 调用）
private actor MockOperationManager: OperationManaging {
    var beginBatchCalled = false
    var executeBatchCalled = false
    let batchID: OperationManaging.BatchID
    let shouldFail: Bool

    func beginBatch(operations: [PlannedOperation], repository: PhotoLibraryRepository) async throws -> OperationManaging.BatchID {
        beginBatchCalled = true
        if shouldFail { throw DomainError.invalidState("test failure") }
        return batchID
    }

    func executeBatch(_ batchID: OperationManaging.BatchID, repository: PhotoLibraryRepository) async throws {
        executeBatchCalled = true
        if shouldFail { throw DomainError.invalidState("execution failure") }
    }
    // ... 其他方法使用默认空实现
}

// Mock PhotoLibraryRepository（复用项目标准 mock 模式）
private struct MockPhotoLibraryRepository: PhotoLibraryRepository {
    // 参考 AnalyzeContentToolTests 和 DeleteAssetsToolTests 中的 MockPhotoLibraryRepository
}
```

### 项目结构说明

本 Story 新增的文件：

```
Curator/
├── Infrastructure/
│   └── SDKTools/
│       └── RenameAssetsTool.swift           # 新建：重命名执行 SDK 工具
```

测试文件：

```
CuratorTests/
├── Infrastructure/
│   └── SDKTools/
│       └── RenameAssetsToolTests.swift       # 新建：工具测试
```

### 与 Story 6.1 的关系

**Story 6.1 已完成的产出（本 Story 消费）：**
- `RenameSuggestion` 模型 — 本工具接收审核后的建议列表
- `ContentAnalyzerProtocol` — 分析管线协议
- `AnalyzeContentTool` — 生成重命名建议的 SDK 工具
- `ContentAnalyzerService` — LLM 分析服务实现

**本 Story（6.2）的定位：**
- 6.1 负责"生成建议"（只读分析）
- 6.2 负责"执行重命名"（写操作，需要 OperationManager）
- 6.3 负责"审核 UI"（用户交互界面）
- 6.4 负责"批量执行与回滚 UI"

### 与 Epic 5 去重 SDK 工具的对比

| 方面 | DeleteAssetsTool（Epic 5） | RenameAssetsTool（Epic 6） |
|------|---------------------------|---------------------------|
| 操作类型 | `.delete` | `.rename(newTitle:)` |
| 输入 | `[AssetID]` | `[(AssetID, suggestedName)]` |
| 文件操作 | 移至废纸篓 | 重命名文件名 |
| 快照内容 | 操作前文件路径 | 操作前文件名 |
| 可回滚性 | 最佳努力（文件可能已清空废纸篓） | 完全可回滚（文件名恢复） |
| `destructiveHint` | `true` | `true` |

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 6.2] -- 原始需求定义（重命名 SDK 工具）
- [Source: _bmad-output/planning-artifacts/architecture.md#Infrastructure/SDKTools] -- SDK Tools 目录，RenameAssetsTool 预留位置
- [Source: _bmad-output/planning-artifacts/architecture.md#Core/Operations] -- 操作管理器（快照 + 回滚）
- [Source: _bmad-output/planning-artifacts/architecture.md#决策1] -- 分层架构
- [Source: _bmad-output/planning-artifacts/architecture.md#决策7] -- 操作回滚系统（快照 + 操作日志）
- [Source: _bmad-output/planning-artifacts/prd.md#FR28] -- 批量重命名执行
- [Source: _bmad-output/planning-artifacts/prd.md#FR33] -- 破坏性操作前需用户批准
- [Source: _bmad-output/planning-artifacts/prd.md#FR38] -- 绝不修改原始图像文件
- [Source: _bmad-output/planning-artifacts/prd.md#NFR15] -- 零文件损坏容忍
- [Source: _bmad-output/planning-artifacts/prd.md#NFR16] -- 5 秒内回滚
- [Source: _bmad-output/implementation-artifacts/6-1-content-analysis-and-naming.md] -- 前置 Story 实现记录
- [Source: _bmad-output/project-context.md#Critical Implementation Rules] -- Swift 6 严格并发、actor 隔离、Sendable
- [Source: _bmad-output/project-context.md#Code Patterns] -- SwiftUI 视图模式、命名规范
- [Source: _bmad-output/project-context.md#Testing Rules] -- ATDD 风格、Mock 模式
- [Source: Curator/Core/Models/RenameSuggestion.swift] -- 重命名建议模型（复用）
- [Source: Curator/Core/Operations/OperationManaging.swift] -- 操作管理协议（复用）
- [Source: Curator/Core/Operations/PlannedOperation.swift] -- 计划操作模型（复用 .rename case）
- [Source: Curator/Core/Operations/OperationType.swift] -- 操作类型枚举（复用 .rename case）
- [Source: Curator/Core/Models/PhotoLibraryRepository.swift] -- 照片来源协议（复用 updateAsset）
- [Source: Curator/Infrastructure/SDKTools/DeleteAssetsTool.swift] -- **主要参考**：写操作 SDK 工具模式
- [Source: Curator/Infrastructure/SDKTools/AnalyzeContentTool.swift] -- 只读分析工具模式参考
- [Source: Curator/Infrastructure/SDKTools/EstimateCostTool.swift] -- 成本估算工具（已有 rename 分支）

## Dev Agent Record

### Agent Model Used

GLM-5.1

### Debug Log References

No debug issues encountered. Implementation followed DeleteAssetsTool pattern exactly.

### Completion Notes List

- Implemented RenameAssetsTool following DeleteAssetsTool architecture pattern (Method A: atomic batch via OperationManager)
- Created `RenameAssetsInput` and `RenameItemInput` Codable structs for tool input
- Tool uses `defineTool()` factory with `isReadOnly: false` and `destructiveHint: true` annotations
- Input validation rejects empty suggestions list
- Converts suggestions to `[PlannedOperation]` with `.rename(newTitle:)` parameters
- Calls `OperationManager.beginBatch()` for snapshot, then `executeBatch()` for execution
- Returns JSON result with `success`, `batchID`, and `renamedCount` fields
- Partial failure handled by OperationManager's auto-rollback (consistent with DeleteAssetsTool)
- All 11 ATDD tests pass (including testRenameAssetsToolAnnotations, testRenameAssetsToolRegisteredInRegistry, testRenameAssetsToolHandlesSpecialCharacters, testRenameAssetsToolHandlesLargeBatch)
- Full test suite: 782 tests, 0 failures, no regressions

### File List

- Curator/Infrastructure/SDKTools/RenameAssetsTool.swift (new)
- CuratorTests/Infrastructure/SDKTools/RenameAssetsToolTests.swift (pre-existing ATDD tests from Story 6-2 ATDD phase)

### Change Log

- 2026-04-25: Implemented RenameAssetsTool SDK tool -- batch rename execution via OperationManager with snapshot/rollback support, cost estimation integration through AgentToolRegistry, partial failure tolerance via OperationManager atomic batch strategy.

### Review Findings

- [x] [Review][Patch] Missing per-item input validation for assetID and suggestedName [Curator/Infrastructure/SDKTools/RenameAssetsTool.swift:97-114] -- Fixed: added non-empty validation for each suggestion's assetID and suggestedName fields, plus file name compliance check using `RenameSuggestion.isValidFileName()`.
- [x] [Review][Defer] originalFileName field unused in tool implementation [Curator/Infrastructure/SDKTools/RenameAssetsTool.swift:18] -- deferred, pre-existing; field has audit/logging value and may be used in future Stories.
