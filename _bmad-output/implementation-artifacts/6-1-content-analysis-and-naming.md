# Story 6.1: 内容分析与命名生成

Status: review

## Story

As a 用户，
I want AI 能分析照片内容并生成描述性标题，
so that 为无意义的文件名赋予有意义的名称。

## Acceptance Criteria

1. **AC1: 照片内容分析（FR24, FR25）**
   **Given** 用户选择了需要重命名的照片
   **When** AnalyzeContentTool 分析照片内容
   **Then** 工具通过 LLM 识别照片中的场景、人物、地点等关键元素
   **And** 在用户偏好语言下生成描述性标题

2. **AC2: RenameSuggestion 模型生成**
   **Given** LLM 已完成对照片的内容分析
   **When** 生成 RenameSuggestion 模型
   **Then** 包含原始文件名、建议的新名称、分析置信度
   **And** 建议名称符合文件系统命名规范（无非法字符、长度合理）

3. **AC3: 错误容错（部分失败不影响整体）**
   **Given** 分析过程中 LLM 不可用或某张照片返回错误
   **When** 命名生成失败
   **Then** 该照片被标记为"未能生成建议"并跳过
   **And** 不影响其他照片的分析流程继续进行

4. **AC4: 批量分析与进度报告**
   **Given** 用户请求对多张照片进行重命名分析
   **When** 批量分析执行中
   **Then** 系统通过 AsyncStream 报告已分析/总数进度
   **And** 分析在后台 Task 中执行，不阻塞 UI（NFR7）

5. **AC5: 费用预估集成**
   **Given** 用户即将执行大规模重命名分析
   **When** 系统计算费用预估
   **Then** 基于照片数量和所选模型返回 CostEstimate
   **And** 预估展示在执行确认前（FR46）

## Tasks / Subtasks

- [x] Task 1: 创建 RenameSuggestion 领域模型 (AC: #2)
  - [x] 1.1 创建 `Curator/Core/Models/RenameSuggestion.swift`
  - [x] 1.2 定义 `RenameSuggestion` Sendable struct：`id: UUID`、`assetID: AssetID`、`originalFileName: String`、`suggestedName: String`、`confidence: Double`、`analysisDescription: String?`、`status: RenameSuggestionStatus`
  - [x] 1.3 定义 `RenameSuggestionStatus` enum：`.pending`、`.accepted`、`.rejected`、`.edited(String)`、`.failed(String)`
  - [x] 1.4 添加文件系统名称合规验证方法 `isValidFileName(_:) -> Bool`（过滤非法字符、控制长度）

- [x] Task 2: 创建 ContentAnalyzerService (AC: #1, #2, #3)
  - [x] 2.1 创建 `Curator/Core/Models/ContentAnalyzerProtocol.swift` 协议定义
  - [x] 2.2 创建 `Curator/Infrastructure/Analysis/ContentAnalyzerService.swift` actor 实现
  - [x] 2.3 实现 `analyzeContent(assets:repository:language:) async throws -> [RenameSuggestion]` 核心方法
  - [x] 2.4 构建 LLM prompt：要求识别场景、人物、地点、活动等关键元素并生成描述性标题
  - [x] 2.5 解析 LLM 响应为 RenameSuggestion 数组（JSON 格式）
  - [x] 2.6 实现单张照片失败容错：catch 单项错误，标记为 `.failed`，继续后续照片
  - [x] 2.7 实现文件名合规化：移除/替换非法字符，截断超长名称，保留文件扩展名

- [x] Task 3: 创建 AnalyzeContentTool SDK 工具 (AC: #1, #4, #5)
  - [x] 3.1 创建 `Curator/Infrastructure/SDKTools/AnalyzeContentTool.swift`
  - [x] 3.2 定义 `AnalyzeContentInput` Codable struct：`maxPhotos: Int?`、`language: String?`
  - [x] 3.3 使用 `defineTool()` 创建 `analyze_content` 工具，注册为只读（readOnlyHint: true）
  - [x] 3.4 工具从 repository 获取资产，调用 ContentAnalyzerProtocol 执行分析
  - [x] 3.5 返回 JSON 格式的 RenameSuggestion 列表

- [x] Task 4: ATDD 测试 (AC: #1, #2, #3, #4)
  - [x] 4.1 创建 `CuratorTests/Core/Models/RenameSuggestionTests.swift`
  - [x] 4.2 [P0] testRenameSuggestionStatusTransitions — 验证状态枚举值
  - [x] 4.3 [P0] testIsValidFileName — 合规文件名验证（非法字符、空串、超长）
  - [x] 4.4 [P0] testSuggestedNamePreservesExtension — 建议名称保留原始扩展名
  - [x] 4.5 创建 `CuratorTests/Infrastructure/Analysis/ContentAnalyzerServiceTests.swift`
  - [x] 4.6 [P0] testAnalyzeContentReturnsSuggestions — Mock LLM 返回有效响应时生成正确 RenameSuggestion
  - [x] 4.7 [P0] testAnalyzeContentHandlesPartialFailure — 部分照片 LLM 返回错误时标记为 .failed 不中断
  - [x] 4.8 [P0] testAnalyzeContentSanitizesNames — 非法字符被清理，超长名称被截断
  - [x] 4.9 [P1] testAnalyzeContentEmptyAssets — 空输入返回空数组
  - [x] 4.10 创建 `CuratorTests/Infrastructure/SDKTools/AnalyzeContentToolTests.swift`
  - [x] 4.11 [P0] testAnalyzeContentToolReturnsValidJSON — 工具返回可解析的 JSON 结果
  - [x] 4.12 [P1] testAnalyzeContentToolRespectsMaxPhotos — maxPhotos 参数限制分析数量
  - [x] 4.13 构建通过 + 全部现有测试通过

## Dev Notes

### 架构约束

1. **ContentAnalyzerService 用 `actor` 隔离**：LLM 调用是 I/O 操作，必须在 actor 内执行。[Source: project-context.md#Critical Implementation Rules]
2. **禁止使用 `Task` 作为类型名**：使用 `AgentJob`、`AgentWork` 等前缀。[Source: CLAUDE.md]
3. **跨层数据传递只用值类型**：RenameSuggestion 必须是 Sendable struct。[Source: project-context.md#Critical Implementation Rules]
4. **协议在 Domain 层定义，实现在 Infrastructure 层**：ContentAnalyzerProtocol 在 Core/Models/，ContentAnalyzerService 在 Infrastructure/Analysis/。[Source: project-context.md#协议在 Domain 层定义]
5. **三层错误体系**：LLM 错误通过 InfrastructureError -> DomainError -> UserFacingError 映射。[Source: project-context.md#三层错误体系]
6. **LLM 调用通过 LLMGatewayProtocol**：不直接调用供应商 API，通过 gateway 获取故障转移和重试。[Source: project-context.md#API 调用必须通过 LLMGateway]

### 前置 Story 的已有实现（必须复用）

**数据模型（复用，不修改）：**
- `PhotoAsset` — `id: AssetID`、`metadata: AssetMetadata`、`thumbnailData: Data?`。[Source: Curator/Core/Models/PhotoAsset.swift]
- `AssetMetadata` — `fileName: String`、`fileSize: Int64?`、`creationDate`、`cameraModel`、`imageWidth`、`imageHeight`、`gpsLocation`、`fileFormat`。[Source: Curator/Core/Models/AssetMetadata.swift]
- `AssetID` — `rawValue: String`，Sendable, Hashable, Codable。[Source: Curator/Core/Models/AssetID.swift]
- `LLMResponse` — `text: String`、`modelID: String`、`providerName: String`、`inputTokens: Int`、`outputTokens: Int`。[Source: Curator/Core/Models/LLMResponse.swift]
- `CostEstimate` — 费用预估模型。[Source: Curator/Core/Models/CostEstimate.swift]

**协议（复用）：**
- `LLMGatewayProtocol` — `analyze(images:prompt:model:) async throws -> LLMResponse`、`estimateCost(imageCount:model:) async -> CostEstimate`。[Source: Curator/Core/Models/LLMGatewayProtocol.swift]
- `PhotoLibraryRepository` — `fetchAssets(predicate:pageSize:pageOffset:)`、`fetchFullResolutionImage(for:)`。[Source: Curator/Core/Models/PhotoLibraryRepository.swift]
- `ImageAnalysisPipelineProtocol` — 去重管线协议，重命名不复用此协议但参考其模式。[Source: Curator/Core/Models/ImageAnalysisPipelineProtocol.swift]

**SDK 工具模式（复用模式）：**
- `createAnalyzeDuplicatesTool(pipeline:repository:)` — 参考其 `defineTool()` 模式、JSON 序列化方式、只读注解。[Source: Curator/Infrastructure/SDKTools/AnalyzeDuplicatesTool.swift]
- `createScanLibraryTool(repository:)` — 参考其 `defineTool()` 模式。[Source: Curator/Infrastructure/SDKTools/ScanLibraryTool.swift]

**基础设施（复用）：**
- `LLMGateway` actor — 统一 LLM 调用入口，已实现重试和故障转移。[Source: Curator/Infrastructure/LLM/LLMGateway.swift]
- `ThumbnailGenerator` — 已实现缩略图生成，可复用于重命名的预览展示。[Source: Curator/Infrastructure/Analysis/ThumbnailGenerator.swift]

### 关键设计决策

#### ContentAnalyzerProtocol 设计

参考 ImageAnalysisPipelineProtocol 的模式，在 Domain 层定义协议：

```swift
// Curator/Core/Models/ContentAnalyzerProtocol.swift
protocol ContentAnalyzerProtocol: Sendable {
    func analyzeContent(
        assets: [PhotoAsset],
        repository: PhotoLibraryRepository,
        language: String
    ) async throws -> [RenameSuggestion]

    func analyzeContent(
        assets: [PhotoAsset],
        repository: PhotoLibraryRepository,
        language: String,
        progressHandler: (@Sendable (Int, Int) -> Void)?
    ) async throws -> [RenameSuggestion]
}
```

#### LLM Prompt 策略

为每张照片（或批量）构建 prompt，要求 LLM 以结构化 JSON 返回：

```
分析这张照片的内容，生成一个描述性的文件名标题。

要求：
1. 识别照片中的关键元素：场景、人物（不识别人名）、地点、活动、时间特征
2. 生成简洁的描述性标题（5-15 个词）
3. 标题用 {language} 生成
4. 返回 JSON 格式：{"title": "描述性标题", "description": "详细描述", "confidence": 0.85}

文件名规则：
- 不含特殊字符（\ / : * ? " < > |）
- 不以点号开头或结尾
- 最大 200 字符
```

#### 批量分析策略

采用逐张或小批量（3-5 张）发送给 LLM 的方式：
- 每次发送 1 张照片的图像数据 + EXIF 元数据上下文（日期、相机型号）
- 逐张处理便于错误隔离和进度追踪
- LLM 返回的 title 经过文件名合规化处理后生成 RenameSuggestion

#### 文件名合规化

```swift
func sanitizeFileName(_ name: String, extension ext: String) -> String {
    var sanitized = name
    // 移除非法字符
    let illegalChars = CharacterSet(charactersIn: "\\/:*?\"<>|")
    sanitized = sanitized.components(separatedBy: illegalChars).joined()
    // 移除首尾空格和点号
    sanitized = sanitized.trimmingCharacters(in: .whitespacesAndNewlines)
    sanitized = sanitized.trimmingCharacters(in: CharacterSet(charactersIn: "."))
    // 截断至合理长度（保留扩展名空间）
    let maxLength = 200
    if sanitized.count > maxLength {
        sanitized = String(sanitized.prefix(maxLength))
    }
    return sanitized.isEmpty ? "unnamed" : sanitized
}
```

#### 与 AnalyzeContentTool 的关系

AnalyzeContentTool 是 SDK 层的入口，负责：
1. 接收 Agent 的分析请求
2. 从 repository 获取照片资产
3. 调用 ContentAnalyzerProtocol.analyzeContent()
4. 序列化结果为 JSON 返回给 Agent

ContentAnalyzerService 是 Infrastructure 层的实现，负责：
1. 逐张照片构建 LLM prompt
2. 调用 LLMGateway.analyze()
3. 解析 LLM 响应
4. 生成 RenameSuggestion

### 与现有代码的集成点

**新建的文件：**

1. `Curator/Core/Models/RenameSuggestion.swift` — 重命名建议领域模型
2. `Curator/Core/Models/ContentAnalyzerProtocol.swift` — 内容分析协议（Domain 层）
3. `Curator/Infrastructure/Analysis/ContentAnalyzerService.swift` — 内容分析服务实现（Infrastructure 层）
4. `Curator/Infrastructure/SDKTools/AnalyzeContentTool.swift` — SDK 工具
5. `CuratorTests/Core/Models/RenameSuggestionTests.swift` — 模型测试
6. `CuratorTests/Infrastructure/Analysis/ContentAnalyzerServiceTests.swift` — 服务测试
7. `CuratorTests/Infrastructure/SDKTools/AnalyzeContentToolTests.swift` — 工具测试

**不修改的文件：**

- 不修改 `ImageAnalysisPipeline.swift` — 去重管线独立，重命名不复用
- 不修改 `LLMGateway.swift` — 复用现有 LLM 调用能力
- 不修改 `PhotoLibraryRepository.swift` — 复用现有协议
- 不修改 `AnalyzeDuplicatesTool.swift` — 独立的去重工具

**后续 Story 修改的文件（本 Story 不动）：**

- `Curator/Infrastructure/SDKTools/RenameAssetsTool.swift` — Story 6.2 创建
- `Curator/Features/Rename/RenameViewModel.swift` — Story 6.3 创建
- `Curator/Features/Rename/RenameReviewView.swift` — Story 6.3 创建
- `Curator/Features/Rename/RenameSuggestionCard.swift` — Story 6.3 创建
- `Curator/App/AppDependencies.swift` — 后续 Story 中注册 RenameViewModel

### 不做什么（范围边界）

以下内容在本 Story 中 **不实现**：

- **重命名审核 UI（RenameReviewView）** — Story 6.3 实现
- **RenameSuggestionCard 组件** — Story 6.3 实现
- **RenameViewModel** — Story 6.3 实现
- **RenameAssetsTool 执行工具** — Story 6.2 实现
- **批量重命名执行与回滚** — Story 6.2 和 6.4 实现
- **重命名结果摘要** — Story 6.4 实现
- **用户偏好语言存储** — 复用 UserDefaults 或后续 Epic 7 实现
- **缩略图在重命名建议中的展示** — Story 6.3 UI 层处理

### NFR 关注点

- **NFR4（pHash 100 张/分钟）**：本 Story 不涉及 pHash，但 ContentAnalyzerService 的 LLM 调用速率需合理。
- **NFR6（500MB 内存）**：逐张处理照片，不在内存中累积全分辨率图像数据。
- **NFR7（UI 不阻塞）**：分析在 actor 内执行，SDK 工具在后台 Task 中运行。
- **NFR10（HTTPS/TLS）**：LLM 调用通过 LLMGateway 已确保 TLS。
- **NFR20（指数退避重试）**：LLMGateway 已实现重试，ContentAnalyzerService 复用。
- **FR25（用户偏好语言）**：language 参数传递给 LLM prompt，生成对应语言的标题。
- **FR38（绝不修改原始图像文件）**：本 Story 仅分析内容生成建议，不执行任何文件操作。

### Mock 策略

测试中需要 Mock 以下依赖：

```swift
// Mock LLMGatewayProtocol（返回预设的 LLM 响应 JSON）
private struct MockLLMGateway: LLMGatewayProtocol {
    let response: LLMResponse
    func analyze(images: [Data], prompt: String, model: String) async throws -> LLMResponse {
        return response
    }
    func estimateCost(imageCount: Int, model: String) async -> CostEstimate {
        return CostEstimate(estimatedCalls: imageCount, estimatedCost: Double(imageCount) * 0.003, currency: "USD", modelID: model)
    }
}

// Mock PhotoLibraryRepository（返回预设照片资产）
// 参考 Story 5.3 AnalyzeDuplicatesToolTests 中的 MockPhotoLibraryRepository

// Mock ContentAnalyzerProtocol（用于 SDK 工具测试）
private struct MockContentAnalyzer: ContentAnalyzerProtocol {
    let suggestions: [RenameSuggestion]
    func analyzeContent(assets: [PhotoAsset], repository: PhotoLibraryRepository, language: String) async throws -> [RenameSuggestion] {
        return suggestions
    }
    func analyzeContent(assets: [PhotoAsset], repository: any PhotoLibraryRepository, language: String, progressHandler: (@Sendable (Int, Int) -> Void)?) async throws -> [RenameSuggestion] {
        return suggestions
    }
}
```

### LLM 响应解析策略

LLM 返回的 text 字段需解析为结构化数据。采用 JSON-in-text 方式：

```swift
// 预期 LLM 响应格式
{
    "title": "海滩日落风景",
    "description": "照片显示一个海滩上的日落场景，有棕榈树和海浪",
    "confidence": 0.85
}

// 解析逻辑
func parseLLMResponse(_ text: String) -> (title: String, description: String, confidence: Double)? {
    // 尝试直接解析 JSON
    if let data = text.data(using: .utf8),
       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
       let title = json["title"] as? String {
        let desc = json["description"] as? String
        let conf = json["confidence"] as? Double ?? 0.5
        return (title, desc ?? "", conf)
    }
    // 回退：提取文本中引号内的标题
    // ...
    return nil
}
```

### 项目结构说明

本 Story 新增的文件：

```
Curator/
├── Core/
│   └── Models/
│       ├── RenameSuggestion.swift              # 新建：重命名建议领域模型
│       └── ContentAnalyzerProtocol.swift       # 新建：内容分析协议
├── Infrastructure/
│   ├── Analysis/
│   │   └── ContentAnalyzerService.swift        # 新建：内容分析服务实现
│   └── SDKTools/
│       └── AnalyzeContentTool.swift             # 新建：SDK 工具
```

测试文件：

```
CuratorTests/
├── Core/
│   └── Models/
│       └── RenameSuggestionTests.swift          # 新建：模型测试
├── Infrastructure/
│   ├── Analysis/
│   │   └── ContentAnalyzerServiceTests.swift    # 新建：服务测试
│   └── SDKTools/
│       └── AnalyzeContentToolTests.swift         # 新建：工具测试
```

### 与后续 Story 的关系

**本 Story（6.1）完成后：**

- **Story 6.2（重命名 SDK 工具）** — 创建 RenameAssetsTool，使用 OperationManager 执行重命名
- **Story 6.3（重命名审核 UI）** — 创建 RenameViewModel、RenameReviewView、RenameSuggestionCard，消费 RenameSuggestion 数据
- **Story 6.4（批量重命名执行）** — 复用 BatchApprovalView 模式和 AgentResultSummary

### 与 Epic 5 去重实现的对比

重命名与去重是并列的两大分析功能，但架构模式不同：

| 方面 | 去重（Epic 5） | 重命名（Epic 6） |
|------|---------------|-----------------|
| 分析管线 | 两阶段（pHash + LLM） | 单阶段（LLM 直接分析） |
| 输入 | 多张照片比较 | 单张照片独立分析 |
| 输出 | DuplicateGroup（多张关联） | RenameSuggestion（单张独立） |
| 本地预筛选 | 需要 pHash | 不需要 |
| SDK 工具 | analyze_duplicates | analyze_content |
| 审核模式 | 照片对比 | 名称预览+内联编辑 |

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 6.1] -- 原始需求定义（内容分析与命名生成）
- [Source: _bmad-output/planning-artifacts/architecture.md#Infrastructure/Analysis] -- Analysis 目录结构
- [Source: _bmad-output/planning-artifacts/architecture.md#Infrastructure/SDKTools] -- SDK Tools 目录，AnalyzeContentTool 预留位置
- [Source: _bmad-output/planning-artifacts/architecture.md#Core/Models] -- RenameSuggestion 模型预留位置
- [Source: _bmad-output/planning-artifacts/architecture.md#决策1] -- 分层架构
- [Source: _bmad-output/planning-artifacts/architecture.md#决策4] -- LLM 网关抽象层
- [Source: _bmad-output/planning-artifacts/prd.md#FR24] -- 请求 AI 驱动重命名
- [Source: _bmad-output/planning-artifacts/prd.md#FR25] -- 分析照片内容生成描述性标题
- [Source: _bmad-output/planning-artifacts/prd.md#FR38] -- 绝不修改原始图像文件
- [Source: _bmad-output/planning-artifacts/prd.md#NFR6] -- 500MB 内存上限
- [Source: _bmad-output/planning-artifacts/prd.md#NFR20] -- 指数退避重试
- [Source: _bmad-output/project-context.md#Critical Implementation Rules] -- Swift 6 严格并发、actor 隔离、Sendable
- [Source: _bmad-output/project-context.md#Code Patterns] -- SwiftUI 视图模式、命名规范
- [Source: _bmad-output/project-context.md#Testing Rules] -- ATDD 风格、Mock 模式
- [Source: Curator/Core/Models/LLMGatewayProtocol.swift] -- LLM 调用协议（复用）
- [Source: Curator/Core/Models/PhotoLibraryRepository.swift] -- 照片来源协议（复用）
- [Source: Curator/Core/Models/ImageAnalysisPipelineProtocol.swift] -- 去重管线协议（参考模式）
- [Source: Curator/Infrastructure/SDKTools/AnalyzeDuplicatesTool.swift] -- 去重 SDK 工具（参考 defineTool 模式）
- [Source: Curator/Infrastructure/SDKTools/ScanLibraryTool.swift] -- 扫描工具（参考模式）
- [Source: Curator/Infrastructure/Analysis/ImageAnalysisPipeline.swift] -- 分析管线实现（参考 actor 模式）

## Dev Agent Record

### Agent Model Used

GLM-5.1

### Debug Log References

- No debug issues encountered during implementation.

### Completion Notes List

- Implemented RenameSuggestion Sendable struct with all required fields (id, assetID, originalFileName, suggestedName, confidence, analysisDescription, status).
- Implemented RenameSuggestionStatus enum with 5 cases: .pending, .accepted, .rejected, .edited(String), .failed(String).
- Added isValidFileName() static method for file system name validation (illegal chars, length, empty check).
- Added sanitizeFileName() static method for cleaning LLM-generated titles into safe file names.
- Created ContentAnalyzerProtocol in Domain layer (Core/Models/) with two variants: basic and with progress handler.
- Implemented ContentAnalyzerService as an actor in Infrastructure layer (Analysis/).
- Service processes photos individually for error isolation; catches per-photo LLM failures and marks as .failed.
- LLM prompt includes language parameter, EXIF context (camera, date, resolution), and requests structured JSON output.
- JSON parsing handles LLM response wrapping (markdown code fences, prose) via brace-counting extraction.
- Created AnalyzeContentTool SDK tool following AnalyzeDuplicatesTool pattern: defineTool(), read-only, JSON serialization.
- Tool accepts maxPhotos and language parameters; chains ContentAnalyzerProtocol and PhotoLibraryRepository.
- All 25 new ATDD tests pass (11 RenameSuggestion + 8 ContentAnalyzerService + 6 AnalyzeContentTool).
- Full regression suite passes: 771 tests, 0 failures.

### File List

**New files:**
- Curator/Core/Models/RenameSuggestion.swift
- Curator/Core/Models/ContentAnalyzerProtocol.swift
- Curator/Infrastructure/Analysis/ContentAnalyzerService.swift
- Curator/Infrastructure/SDKTools/AnalyzeContentTool.swift

**Modified files (ATDD test activation -- removed #if false guards):**
- CuratorTests/Core/Models/RenameSuggestionTests.swift
- CuratorTests/Infrastructure/Analysis/ContentAnalyzerServiceTests.swift
- CuratorTests/Infrastructure/SDKTools/AnalyzeContentToolTests.swift

## Change Log

- 2026-04-25: Story 6.1 implementation complete -- all 4 tasks, 25 ATDD tests passing, 771 total tests green.
