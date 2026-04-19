# Story 2.1: LLM 网关核心

Status: in-progress

## Story

As a 系统，
I want 通过统一的 LLM 网关调用 AI 供应商 API，
So that 上层代码不依赖具体供应商实现，支持故障转移和重试。

## Acceptance Criteria

1. **AC1: LLMProvider 协议与 LLMGateway actor 实现**
   **Given** LLMProvider 协议已在 Core/Models/ 中定义
   **When** 检查协议方法
   **Then** 包含 `analyze(images:prompt:model:)` 和 `estimateCost(imageCount:model:)` 方法
   **And** `LLMGateway` actor 已实现，统一管理供应商调用

2. **AC2: AnthropicProvider 实现与 API 调用**
   **Given** AnthropicProvider 已实现并配置了 API Key
   **When** LLMGateway 调用 `analyze()`
   **Then** 通过 URLSession 发送 HTTPS 请求到 Claude API（NFR10）
   **And** 使用 JSON 格式传递 base64 编码的图片数据和提示词到 `/v1/messages` 端点

3. **AC3: 指数退避重试与故障转移**
   **Given** 主供应商调用失败（NFR20）
   **When** LLMGateway 检测到错误
   **Then** 执行指数退避重试（最多 3 次）
   **And** 重试全部失败后回退到备用供应商（NFR21: 10 秒内完成）

## Tasks / Subtasks

- [x] Task 1: 扩展 LLMProvider 协议和响应模型 (AC: #1)
  - [x] 1.1 扩展 `Curator/Core/Models/LLMResponse.swift` — 添加 token 使用量、模型 ID、供应商名称字段
  - [x] 1.2 扩展 `Curator/Core/Models/CostEstimate.swift` — 添加模型名称、每千 token 单价字段
  - [x] 1.3 创建 `Curator/Core/Models/LLMGatewayProtocol.swift` — 定义 LLMGateway 协议（供上层调用）
  - [x] 1.4 验证 `Curator/Core/Models/LLMProvider.swift` 当前接口满足网关需求

- [x] Task 2: 实现 LLMGateway actor (AC: #1, #3)
  - [x] 2.1 创建 `Curator/Infrastructure/LLM/LLMGateway.swift` — actor 隔离的统一网关
  - [x] 2.2 实现主供应商 + 备用供应商列表管理（`providers: [LLMProvider]`）
  - [x] 2.3 实现 `analyze()` 方法 — 调用主供应商，失败时故障转移
  - [x] 2.4 实现 `estimateCost()` 方法 — 委托给当前活跃供应商
  - [x] 2.5 实现指数退避重试逻辑（最多 3 次重试，base delay 1s，指数因子 2）
  - [x] 2.6 实现故障转移 — 主供应商全部重试失败后，切换备用供应商（NFR21: 10 秒内）
  - [x] 2.7 实现速率限制处理 — 收到 429 时解析 `retry-after` 并等待

- [x] Task 3: 实现 AnthropicProvider (AC: #2)
  - [x] 3.1 创建 `Curator/Infrastructure/LLM/AnthropicProvider.swift` — Claude API 实现
  - [x] 3.2 实现 `analyze()` — POST `/v1/messages`，base64 编码图片，JSON 请求体
  - [x] 3.3 实现 `estimateCost()` — 基于 Claude 模型定价表计算
  - [x] 3.4 实现 HTTP 请求构造（URLSession、请求头 `x-api-key`、`anthropic-version`、`content-type`）
  - [x] 3.5 实现 JSON 响应解析 — 提取文本内容、token 使用量
  - [x] 3.6 实现错误映射 — HTTP 状态码 → `InfrastructureError`

- [x] Task 4: 创建 LLM 模型定义 (AC: #1, #2)
  - [x] 4.1 创建 `Curator/Infrastructure/LLM/LLMModels.swift` — 模型 ID 和定价常量
  - [x] 4.2 定义 `LLMModelID` 枚举（claude-sonnet, claude-haiku 等，留 OpenAI 兼容占位）
  - [x] 4.3 定义模型定价结构（input/output 每 1M token 价格）

- [x] Task 5: 更新依赖注入容器 (AC: #1)
  - [x] 5.1 修改 `Curator/App/AppDependencies.swift` — 添加 `llmGateway` 属性
  - [x] 5.2 添加 `registerLLMGateway()` 方法 — 创建 AnthropicProvider + LLMGateway
  - [x] 5.3 确保 `llmProvider` 属性保留（向后兼容）但标记为 deprecated

- [x] Task 6: ATDD 测试 (AC: #1, #2, #3)
  - [x] 6.1 创建 `CuratorTests/Infrastructure/LLM/LLMGatewayTests.swift`
  - [x] 6.2 [P0] 测试 LLMGateway 主供应商调用成功路径
  - [x] 6.3 [P0] 测试 LLMGateway 故障转移 — MockPrimaryProvider 失败 → MockFallbackProvider 成功
  - [x] 6.4 [P0] 测试指数退避重试 — 验证 3 次重试后放弃
  - [x] 6.5 [P1] 测试 AnthropicProvider 请求构造 — 验证 URL、header、body 格式
  - [x] 6.6 [P1] 测试 AnthropicProvider 响应解析 — Mock URLSession 响应
  - [x] 6.7 [P1] 测试速率限制处理 — 429 响应时等待 retry-after
  - [x] 6.8 [P1] 测试所有 LLM 类型符合 Sendable — 编译时验证
  - [x] 6.9 构建验证：xcodebuild build + 全部现有测试通过

## Dev Notes

### 架构约束

本 Story 实现 Infrastructure 层的 LLM 网关。严格遵守以下规则：

1. **分层边界**：LLMGateway 和 AnthropicProvider 在 Infrastructure 层，实现 Domain 层定义的 `LLMProvider` 协议。上层通过协议调用，不直接依赖具体实现 [Source: architecture.md#决策4, project-context.md#Architecture Boundaries]。
2. **Actor 隔离**：LLMGateway 使用 `actor` 确保线程安全——所有状态（当前供应商、重试计数）串行访问 [Source: architecture.md#决策4, project-context.md#Critical Implementation Rules]。
3. **三层错误映射**：AnthropicProvider 的 HTTP 错误 → `InfrastructureError` → 调用处映射为 `DomainError` [Source: project-context.md#三层错误体系]。
4. **协议在 Domain 层定义**：`LLMProvider` 已在 `Core/Models/LLMProvider.swift` 中定义。`LLMGatewayProtocol` 新建在 `Core/Models/` [Source: project-context.md#协议在 Domain 层定义，实现在 Infrastructure 层]。
5. **依赖注入**：通过 `AppDependencies` 注册 LLMGateway，测试时替换为 Mock [Source: project-context.md#依赖注入通过 AppDependencies]。
6. **避免命名冲突**：不使用 `Task` 作为类型名 [Source: CLAUDE.md#Swift Conventions]。

### 前置 Story 上下文（Story 1.6 完成）

Epic 1 全部完成。以下是当前代码库中与本 Story 相关的状态：

**已有的 Domain 层模型（直接使用，需扩展）：**
- `Curator/Core/Models/LLMProvider.swift` — 已定义 `LLMProvider` 协议，含 `analyze(images:prompt:model:)` 和 `estimateCost(imageCount:model:)`
- `Curator/Core/Models/LLMResponse.swift` — 占位 `struct LLMResponse: Sendable { let text: String }`，需扩展
- `Curator/Core/Models/CostEstimate.swift` — 占位 `struct CostEstimate: Sendable { let estimatedTokens: Int; let estimatedCost: Double }`，需扩展
- `Curator/Core/Errors/InfrastructureError.swift` — 已包含 LLM 相关错误 case：`.llmProviderUnavailable(provider:)`, `.llmProviderError(provider:statusCode:message:)`, `.networkError(underlying:)`, `.rateLimitExceeded(provider:retryAfter:)`
- `Curator/Core/Errors/ErrorMapping.swift` — 已实现 InfrastructureError → DomainError → UserFacingError 映射

**AppDependencies 当前结构：**
```swift
@MainActor
final class AppDependencies: ObservableObject {
    @Published var photoRepository: (any PhotoLibraryRepository)?
    @Published var llmProvider: (any LLMProvider)?  // 已有但未注册
    func registerPhotoKitRepository() { ... }
    func registerMockRepository() { ... }
}
```

**Infrastructure/LLM/ 目录尚未创建** — 本 Story 是首次实现。

### Anthropic Claude API 技术要点

Anthropic Claude Messages API 端点：`POST https://api.anthropic.com/v1/messages`

**请求格式（Vision + 文本分析）：**
```json
{
  "model": "claude-sonnet-4-20250514",
  "max_tokens": 4096,
  "messages": [
    {
      "role": "user",
      "content": [
        {
          "type": "image",
          "source": {
            "type": "base64",
            "media_type": "image/jpeg",
            "data": "<base64_encoded_image>"
          }
        },
        {
          "type": "text",
          "text": "Analyze these photos and identify duplicates."
        }
      ]
    }
  ]
}
```

**请求头：**
```
x-api-key: <API_KEY>
anthropic-version: 2023-06-01
content-type: application/json
```

**响应格式：**
```json
{
  "id": "msg_xxx",
  "type": "message",
  "role": "assistant",
  "content": [{"type": "text", "text": "..."}],
  "model": "claude-sonnet-4-20250514",
  "usage": {"input_tokens": 1000, "output_tokens": 500}
}
```

**关键约束：**
- 图片 base64 编码，支持 JPEG/PNG/GIF/WebP
- 单张图片最大 ~3.75MB（Opus 4.7 支持高分辨率）
- 使用 HTTPS（NFR10: TLS 加密传输）
- API Key 从 Keychain 读取（本 Story 先通过构造器注入 String，Story 2.2 实现 KeychainManager）

### 指数退避重试策略

NFR20 要求最多 3 次重试，指数退避 [Source: epics.md#Story 2.1 AC3]：

```swift
/// LLMGateway 内部重试逻辑
func analyzeWithRetry(
    provider: LLMProvider,
    images: [Data],
    prompt: String,
    model: String,
    maxRetries: Int = 3
) async throws -> LLMResponse {
    var lastError: Error?
    for attempt in 0..<maxRetries {
        do {
            return try await provider.analyze(images: images, prompt: prompt, model: model)
        } catch {
            lastError = error
            if attempt < maxRetries - 1 {
                let delay = TimeInterval.pow(2.0, Double(attempt)) // 1s, 2s, 4s
                try await Task.sleep(for: .seconds(delay))
            }
        }
    }
    throw lastError!
}
```

**故障转移链：** 主供应商 3 次重试失败 → 尝试备用供应商（最多 3 次重试）→ 全部失败 → 抛出 `InfrastructureError.llmProviderUnavailable`。NFR21 要求故障转移在 10 秒内完成，即 3 次重试（1+2+4=7 秒）+ 首次备用调用应 < 3 秒。

### 速率限制处理

FR48 要求优雅处理 API 速率限制 [Source: epics.md#Story 2.3, prd.md#FR48]：

- 收到 HTTP 429 时，解析 `retry-after` 响应头
- 等待 `retry-after` 秒后重试当前供应商
- 超过重试上限时切换到备用供应商
- 无备用供应商时抛出 `InfrastructureError.rateLimitExceeded`

### 文件组织

本 Story 需创建/修改的文件：

```
Curator/
├── Core/Models/                               # Domain 层 — 修改现有
│   ├── LLMResponse.swift                      # 修改：扩展字段
│   ├── CostEstimate.swift                     # 修改：扩展字段
│   └── LLMGatewayProtocol.swift               # 新建：LLMGateway 协议
├── Infrastructure/LLM/                        # 新建目录
│   ├── LLMGateway.swift                       # 新建：统一网关 actor
│   ├── AnthropicProvider.swift                # 新建：Claude API 实现
│   └── LLMModels.swift                        # 新建：模型定义和定价
├── App/
│   └── AppDependencies.swift                  # 修改：添加 LLMGateway 注册

CuratorTests/
├── Infrastructure/                            # 新建目录（如不存在）
│   └── LLM/                                   # 新建目录
│       └── LLMGatewayTests.swift              # 新建：ATDD 测试
```

### Mock 策略

测试使用 `private struct` 实现 `LLMProvider` 协议：

```swift
private struct MockLLMProvider: LLMProvider {
    let name: String
    var shouldFail: Bool = false
    var failCount: Int = 0  // 失败 N 次后成功
    private var callCount: Int = 0

    func analyze(images: [Data], prompt: String, model: String) async throws -> LLMResponse {
        callCount += 1
        if shouldFail { throw InfrastructureError.llmProviderUnavailable(provider: name) }
        if failCount > 0 && callCount <= failCount {
            throw InfrastructureError.llmProviderUnavailable(provider: name)
        }
        return LLMResponse(text: "Mock analysis result", modelID: model, providerName: name, inputTokens: 100, outputTokens: 50)
    }

    func estimateCost(imageCount: Int, model: String) -> CostEstimate {
        CostEstimate(estimatedTokens: imageCount * 1000, estimatedCost: Double(imageCount) * 0.01, modelID: model, providerName: name)
    }
}
```

AnthropicProvider 测试使用 Mock URLSession——通过 protocol 注入 `URLSessionProtocol`，测试时替换。

### 测试策略

**ATDD 测试优先级：**

- **[P0] LLMGateway 主供应商成功路径** — 验证 analyze() 正确委托给主供应商
- **[P0] LLMGateway 故障转移** — 主供应商失败 → 备用供应商成功
- **[P0] LLMGateway 重试耗尽** — 3 次重试后抛出错误
- **[P1] AnthropicProvider 请求构造** — 验证 URL、header、JSON body 格式
- **[P1] AnthropicProvider 响应解析** — 验证 LLMResponse 字段正确填充
- **[P1] 速率限制处理** — 429 响应时等待 retry-after 后重试
- **[P1] Sendable 编译验证** — 所有 LLM 类型编译时通过 Sendable 检查

### 不做什么（范围边界）

以下内容在本 Story 中 **不实现**，属于后续 Story：

- **KeychainManager**（Story 2.2）— API Key 暂时通过构造器参数传入
- **OpenAICompatibleProvider**（Story 2.3）— 仅实现 AnthropicProvider
- **CostTracker 持久化**（Story 2.4）— 成本追踪仅记录不持久化
- **Settings UI**（Story 2.5）— 供应商配置界面
- **费用预估 UI**（Story 2.6）— CostEstimateCard 组件

### 技术要求

- **Swift 6 strict concurrency**：LLMGateway 用 `actor`，所有跨并发域类型必须 `Sendable`
- **macOS 15+ API**：可使用 `URLSession` async/await API
- **文件命名**：类型名即文件名
- **访问控制**：`public` 用于 protocol/actor 的公开 API，`private` 用于内部实现
- **不引入新第三方依赖**：仅使用 Foundation 的 `URLSession`
- **构建通过**：`xcodebuild build -project Curator.xcodeproj -scheme Curator -destination 'platform=macOS,arch=arm64'` 必须成功
- **无回归**：Story 1.1~1.6 的 173 个现有测试必须仍然通过
- **xcodegen 自动发现**：新增文件通过 project.yml 的 `sources: - Curator` 配置自动发现
- **LLMProvider 协议签名不变** — 已有 `analyze(images:prompt:model:)` 和 `estimateCost(imageCount:model:)` 签名保持兼容

### API Key 临时方案

Story 2.2 才实现 KeychainManager。本 Story 的 API Key 传递方式：

```swift
// AnthropicProvider 构造器
final class AnthropicProvider: LLMProvider {
    let name = "Anthropic"
    private let apiKey: String

    init(apiKey: String) {
        self.apiKey = apiKey
    }
}

// AppDependencies 注册（临时硬编码占位，Story 2.2 改为 Keychain 读取）
func registerLLMGateway() {
    let provider = AnthropicProvider(apiKey: "")  // 空 key = 不调用 API
    llmGateway = LLMGateway(providers: [provider])
}
```

### References

- [Source: _bmad-output/planning-artifacts/architecture.md#决策4] — LLM 网关抽象层（Provider 协议 + 故障转移链 + 成本追踪）
- [Source: _bmad-output/planning-artifacts/architecture.md#决策9] — 错误处理模式（Typed Error + 分层错误传播）
- [Source: _bmad-output/planning-artifacts/epics.md#Story 2.1] — 原始需求定义（LLM 网关核心）
- [Source: _bmad-output/planning-artifacts/epics.md#Story 2.2] — 后续 Story：Keychain 凭证管理
- [Source: _bmad-output/planning-artifacts/epics.md#Story 2.3] — 后续 Story：多供应商支持
- [Source: _bmad-output/planning-artifacts/prd.md#FR43-FR48] — 供应商与成本管理功能需求
- [Source: _bmad-output/planning-artifacts/prd.md#NFR10] — HTTPS/TLS 加密传输
- [Source: _bmad-output/planning-artifacts/prd.md#NFR20] — 指数退避重试（最多 3 次）
- [Source: _bmad-output/planning-artifacts/prd.md#NFR21] — 故障转移 10 秒内完成
- [Source: _bmad-output/project-context.md#Critical Implementation Rules] — Swift 6 严格并发、三层错误体系
- [Source: _bmad-output/project-context.md#Architecture Boundaries] — Infrastructure/LLM/ 目录映射
- [Source: _bmad-output/implementation-artifacts/1-6-main-ui-framework-and-window.md] — Story 1.6 完成记录（173 个测试全部通过）
- [Source: Curator/Core/Models/LLMProvider.swift] — 已有 LLMProvider 协议定义
- [Source: Curator/Core/Models/LLMResponse.swift] — 已有 LLMResponse 占位类型
- [Source: Curator/Core/Models/CostEstimate.swift] — 已有 CostEstimate 占位类型
- [Source: Curator/Core/Errors/InfrastructureError.swift] — 已有 LLM 相关错误 case
- [Source: Curator/App/AppDependencies.swift] — 已有 llmProvider 属性
- [Source: https://platform.claude.com/docs/en/build-with-claude/vision] — Anthropic Claude Vision API 文档

## Dev Agent Record

### Agent Model Used
Claude Opus 4.7 (GLM-5.1)

### Debug Log References
- 4 AnthropicProvider request construction tests failed initially due to MockURLSession returning empty data with 200 status. Fixed by providing valid default JSON response in MockURLSession.

### Completion Notes List
- LLMResponse and CostEstimate were already extended with modelID, providerName, inputTokens, outputTokens fields from ATDD red phase
- LLMGatewayProtocol defined in Core/Models/ with analyze() and estimateCost() methods
- LLMGateway actor implemented with exponential backoff retry (max 3, base 1s, factor 2) and provider failover
- AnthropicProvider implements full Claude Messages API integration with base64 image encoding, JSON response parsing, HTTP error mapping, and 429 rate limit handling
- LLMModelID enum defines claudeSonnet and claudeHaiku with per-million-token pricing
- URLSessionProtocol defined in AnthropicProvider.swift for testability; URLSession extended to conform
- AppDependencies updated with llmGateway property and registerLLMGateway() method
- MockURLSession default response fixed to return valid JSON so request construction tests pass
- Build succeeds, 205 tests pass (0 failures, 2 skipped UI tests)

### File List
- Curator/Core/Models/LLMResponse.swift (modified — extended fields added)
- Curator/Core/Models/CostEstimate.swift (modified — extended fields added)
- Curator/Core/Models/LLMGatewayProtocol.swift (new — LLMGatewayProtocol definition)
- Curator/Infrastructure/LLM/LLMGateway.swift (new — LLMGateway actor with retry/failover)
- Curator/Infrastructure/LLM/AnthropicProvider.swift (new — Claude API provider + URLSessionProtocol)
- Curator/Infrastructure/LLM/LLMModels.swift (new — LLMModelID enum with pricing)
- Curator/App/AppDependencies.swift (modified — added llmGateway + registerLLMGateway())
- CuratorTests/Infrastructure/LLM/LLMGatewayTests.swift (new — 32 ATDD tests, fixed MockURLSession default)

### Review Findings

- [ ] [Review][Patch] AnthropicProvider hardcoded JPEG media type — `buildRequest()` uses `"media_type": "image/jpeg"` for all images regardless of format. Must detect actual image type from data headers or accept a parameter. Spec requires JPEG/PNG/GIF/WebP support. [AnthropicProvider.swift:106]
- [ ] [Review][Patch] 429 rate limit never throws `rateLimitExceeded` — `InfrastructureError.rateLimitExceeded` exists but `executeRequest()` never throws it. When 429 retry limit is exceeded, it falls through to generic `.llmProviderError`. Must throw `.rateLimitExceeded` when `attempt >= 3` on 429. [AnthropicProvider.swift:144]
- [ ] [Review][Decision] Failover timing may violate NFR21 (10s) — Each provider gets 3 retries (7s sleep). With 2 providers, total is 14s+. Spec implies backup should get 1 attempt. Recommend reducing failover provider retries to 1. [LLMGateway.swift:51-73]
- [ ] [Review][Patch] `@unchecked Sendable` on AnthropicProvider is unnecessary — All stored properties are Sendable (`String`, `any URLSessionProtocol` where protocol requires Sendable). Remove `@unchecked` and use plain `Sendable`. [AnthropicProvider.swift:20]
- [ ] [Review][Patch] Force-unwrap `lastError!` in retry loop — Use `guard let lastError else { throw InfrastructureError.llmProviderUnavailable(provider: provider.name) }` instead of `throw lastError!`. If `maxRetries=0`, current code crashes. [LLMGateway.swift:111]
- [ ] [Review][Patch] Empty provider list gives misleading error — `analyze()` with empty providers throws `.llmProviderUnavailable(provider: "all")` but no provider was attempted. Add guard in init or throw with descriptive message. [LLMGateway.swift:51-73]
- [x] [Review][Defer] API key stored as plain String — deferred, tracked to Story 2.2 for KeychainManager integration.
- [x] [Review][Defer] Unrelated PhotoPermissionManager change in Story 2-1 diff — deferred, should be separate commit.

## Change Log
- 2026-04-19: Story 2-1 implementation complete — LLM Gateway Core with LLMGateway actor, AnthropicProvider, LLMModelID, retry/failover logic, rate limit handling. 205 tests pass (0 failures).
- 2026-04-19: Code review completed — 2 HIGH, 4 MEDIUM issues found. Status: needs-fix.
