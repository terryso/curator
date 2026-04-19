# Story 2.3: 多供应商支持

Status: done

## Story

As a 用户，
I want 配置备用 AI 供应商以实现自动故障转移，
So that 即使主供应商不可用，我的任务也能继续执行。

## Acceptance Criteria

1. **AC1: 主供应商故障时自动回退到备用供应商（FR43, FR45）**
   **Given** 用户配置了 Anthropic（主）和 OpenAI 兼容（备用）供应商
   **When** Anthropic API 返回 5xx 错误或超时
   **Then** LLMGateway 自动回退到 OpenAICompatibleProvider 继续处理
   **And** 故障转移在 10 秒内完成（NFR21）

2. **AC2: OpenAICompatibleProvider 支持任意 OpenAI 兼容 API（FR43）**
   **Given** OpenAICompatibleProvider 已实现
   **When** 配置 DeepSeek API endpoint
   **Then** 支持任何 OpenAI 兼容的 API（自定义 base URL + API Key）
   **And** 请求格式符合 OpenAI Chat Completions API 规范

3. **AC3: API 速率限制处理（FR48）**
   **Given** API 速率限制被触发
   **When** 收到 429 响应
   **Then** LLMGateway 排队等待 retry-after 时间后重试
   **And** 超过重试上限时回退到备用供应商

4. **AC4: LLMConfig 支持多供应商配置**
   **Given** LLMConfig 需要存储多个供应商配置
   **When** 用户配置备用供应商
   **Then** 支持存储主供应商和备用供应商的独立配置（baseURL, apiKey, modelID）
   **And** 向后兼容已有的单供应商配置

## Tasks / Subtasks

- [x] Task 1: 扩展 LLMConfig 支持多供应商 (AC: #4)
  - [x] 1.1 创建 `Curator/Core/Models/LLMProviderConfig.swift` — 单个供应商配置值类型（baseURL, apiKey, modelID, providerType）
  - [x] 1.2 定义 `LLMProviderType: String, Sendable, Codable, CaseIterable` 枚举 — `.anthropic`, `.openAICompatible`
  - [x] 1.3 修改 `Curator/Core/Models/LLMConfig.swift` — 从单供应商改为多供应商支持（primary + fallback 配置）
  - [x] 1.4 保持向后兼容 — 旧格式 `LLMConfig` 能自动迁移到新格式

- [x] Task 2: 创建 OpenAICompatibleProvider (AC: #2)
  - [x] 2.1 创建 `Curator/Infrastructure/LLM/OpenAICompatibleProvider.swift` — 实现 `LLMProvider` 协议
  - [x] 2.2 实现 `analyze(images:prompt:model:)` — 构建 OpenAI Chat Completions API 请求格式
  - [x] 2.3 实现 `estimateCost(imageCount:model:)` — 使用可配置价格或默认估算
  - [x] 2.4 处理 OpenAI API 特有的错误格式（error.message 结构）
  - [x] 2.5 支持 429 速率限制响应的 retry-after 头解析

- [x] Task 3: 增强 LLMGateway 故障转移逻辑 (AC: #1, #3)
  - [x] 3.1 修改 `Curator/Infrastructure/LLM/LLMGateway.swift` — 改进速率限制处理逻辑
  - [x] 3.2 确保 429 错误在单供应商重试耗尽后触发故障转移到下一供应商
  - [x] 3.3 添加故障转移日志/指标（记录哪个供应商失败、回退到哪个供应商）

- [x] Task 4: 更新 AppDependencies 注册多供应商 (AC: #1, #4)
  - [x] 4.1 修改 `Curator/App/AppDependencies.swift` — `registerLLMGateway()` 读取多供应商配置
  - [x] 4.2 根据配置创建 AnthropicProvider（主）+ OpenAICompatibleProvider（备用，如果已配置）
  - [x] 4.3 未配置备用供应商时仍只注册主供应商（向后兼容）

- [x] Task 5: 扩展 LLMModelID 支持多供应商模型 (AC: #2)
  - [x] 5.1 修改 `Curator/Infrastructure/LLM/LLMModels.swift` — 添加 OpenAI 兼容模型的 pricing 预设
  - [x] 5.2 添加 `gpt4o`, `gpt4oMini`, `deepseekChat` 等常见 OpenAI 兼容模型 case（或使用泛化方案）

- [x] Task 6: ATDD 测试 (AC: #1, #2, #3, #4)
  - [x] 6.1 创建 `CuratorTests/Infrastructure/LLM/OpenAICompatibleProviderTests.swift`
  - [x] 6.2 [P0] 测试 OpenAI Chat Completions API 请求格式正确
  - [x] 6.3 [P0] 测试主供应商 5xx 故障 → 自动回退到备用供应商
  - [x] 6.4 [P0] 测试 429 速率限制 → 重试耗尽后回退
  - [x] 6.5 [P1] 测试 OpenAI 错误响应解析
  - [x] 6.6 [P1] 测试 LLMConfig 多供应商配置存储和读取
  - [x] 6.7 [P1] 测试 LLMConfig 旧格式向后兼容迁移
  - [x] 6.8 [P1] 测试 AppDependencies 多供应商注册（有/无备用供应商两种情况）
  - [x] 6.9 构建验证：xcodebuild build + 全部现有测试通过

## Dev Notes

### 架构约束

本 Story 实现 Infrastructure 层的 OpenAICompatibleProvider 并增强 LLMGateway 故障转移。严格遵守以下规则：

1. **分层边界**：`LLMProvider` 协议已在 `Core/Models/LLMProvider.swift`（Domain 层）定义。OpenAICompatibleProvider 实现在 `Infrastructure/LLM/`（Infrastructure 层）[Source: project-context.md#Architecture Boundaries]。
2. **三层错误映射**：OpenAI API 错误映射为 `InfrastructureError.llmProviderError` 或 `.rateLimitExceeded`，再通过已有 ErrorMapping 传播 [Source: Curator/Core/Errors/InfrastructureError.swift]。
3. **依赖注入**：通过 `AppDependencies.registerLLMGateway()` 注册多供应商，无需新增 DI 方法 [Source: Curator/App/AppDependencies.swift]。
4. **所有模型 Sendable**：`LLMProviderConfig`、`LLMProviderType` 必须符合 `Sendable` [Source: project-context.md#Swift 6 严格并发]。
5. **避免命名冲突**：不使用 `Task` 作为类型名 [Source: CLAUDE.md#Swift Conventions]。

### 前置 Story 上下文（Story 2.1 & 2.2 已完成）

**已有的相关文件（来自 Story 2.1 和 2.2）：**
- `Curator/Infrastructure/LLM/LLMGateway.swift` — actor，已有 provider 列表 + 指数退避重试 + failover 循环逻辑（116 行）
- `Curator/Infrastructure/LLM/AnthropicProvider.swift` — 完整的 Anthropic Claude API 实现（234 行）
- `Curator/Infrastructure/LLM/LLMModels.swift` — `LLMModelID` 枚举，目前只有 Anthropic 模型（42 行）
- `Curator/Core/Models/LLMProvider.swift` — `LLMProvider` 协议（11 行）
- `Curator/Core/Models/LLMConfig.swift` — 单供应商配置，存储在 UserDefaults（58 行）
- `Curator/Core/Models/LLMGatewayProtocol.swift` — `LLMGatewayProtocol` 协议（25 行）
- `Curator/Core/Models/LLMResponse.swift` — `LLMResponse` 值类型（18 行）
- `Curator/Core/Models/CostEstimate.swift` — `CostEstimate` 值类型（16 行）
- `Curator/App/AppDependencies.swift` — `registerLLMGateway()` 当前只注册 AnthropicProvider（49 行）

**Story 2.2 的实际实现与计划不同：** Story 2.2 原计划实现 KeychainManager + SecItem API，但实际提交使用了 UserDefaults + `LLMConfig` 方案（参见 commit `8c17368`）。因此：
- `LLMConfig` 已经存在于 `Core/Models/`，使用 UserDefaults 存储（非 Keychain）
- `InfrastructureError` 中没有 `keychainError` case
- `AppDependencies.registerLLMGateway()` 从 `LLMConfig.load()` 读取配置

**LLMGateway 已有的故障转移机制：**
LLMGateway 已经实现了基础的 provider failover 循环：
```swift
for provider in providers {
    do {
        return try await analyzeWithRetry(provider:provider, images:images, prompt:prompt, model:model)
    } catch {
        lastError = error
        // Move to next provider (failover)
    }
}
```
但 `analyzeWithRetry` 的错误处理不区分 429（速率限制）和其他错误。对于 429，应该在重试耗尽后 failover；对于 5xx/超时，应立即 failover 或重试后 failover。这是本 Story 需要增强的点。

### OpenAI Chat Completions API 技术要点

OpenAICompatibleProvider 必须符合 [OpenAI Chat Completions API](https://platform.openai.com/docs/api-reference/chat) 规范。该规范被多个供应商兼容（OpenAI、DeepSeek、Groq、Together AI 等）。

**请求格式（与 Anthropic 的差异）：**
```
POST {baseURL}/v1/chat/completions
Authorization: Bearer {apiKey}
Content-Type: application/json

{
  "model": "gpt-4o",
  "messages": [
    {
      "role": "user",
      "content": [
        {"type": "image_url", "image_url": {"url": "data:image/jpeg;base64,{base64}"}},
        {"type": "text", "text": "{prompt}"}
      ]
    }
  ],
  "max_tokens": 4096
}
```

**关键差异（Anthropic vs OpenAI）：**

| 维度 | Anthropic | OpenAI 兼容 |
|------|-----------|-------------|
| 认证头 | `x-api-key: {key}` | `Authorization: Bearer {key}` |
| Endpoint | `/v1/messages` | `/v1/chat/completions` |
| 图片格式 | `source.type: "base64"` | `image_url.url: "data:{mime};base64,{data}"` |
| 版本头 | `anthropic-version: 2023-06-01` | 无 |
| 响应字段 | `content[].text` | `choices[].message.content` |
| Token 使用 | `usage.input_tokens/output_tokens` | `usage.prompt_tokens/completion_tokens` |
| 错误格式 | `{error: {type, message}}` | `{error: {message, type, code}}` |

**响应格式：**
```json
{
  "id": "chatcmpl-abc123",
  "model": "gpt-4o",
  "choices": [
    {
      "index": 0,
      "message": {
        "role": "assistant",
        "content": "Analysis result text..."
      },
      "finish_reason": "stop"
    }
  ],
  "usage": {
    "prompt_tokens": 1000,
    "completion_tokens": 500,
    "total_tokens": 1500
  }
}
```

**速率限制（429 响应）：**
```
HTTP/1.1 429 Too Many Requests
Retry-After: 20

{"error": {"message": "Rate limit exceeded", "type": "rate_limit_error"}}
```

### OpenAICompatibleProvider 设计

```swift
/// OpenAI-compatible API implementation of the LLMProvider protocol.
///
/// Supports any API that follows the OpenAI Chat Completions format,
/// including OpenAI, DeepSeek, Groq, Together AI, and self-hosted models.
/// Configuration (base URL, API key, model) is injected at init time.
final class OpenAICompatibleProvider: LLMProvider, Sendable {
    let name: String  // e.g. "DeepSeek", "OpenAI", "Custom"

    private let apiKey: String
    private let baseURL: String
    private let urlSession: any URLSessionProtocol

    init(name: String, apiKey: String, baseURL: String, urlSession: (any URLSessionProtocol)? = nil)

    func analyze(images: [Data], prompt: String, model: String) async throws -> LLMResponse
    func estimateCost(imageCount: Int, model: String) -> CostEstimate
}
```

**关键设计决策：**
- `name` 参数允许用户自定义供应商显示名（如 "DeepSeek"、"Groq"），不硬编码
- `baseURL` 支持任意 API endpoint（DeepSeek: `https://api.deepseek.com`、Groq: `https://api.groq.com/openai` 等）
- 复用 `URLSessionProtocol` 抽象以便测试（与 AnthropicProvider 一致）

### LLMConfig 多供应商扩展方案

**当前 LLMConfig（单供应商）：**
```swift
struct LLMConfig: Codable, Sendable, Equatable {
    let baseURL: String
    let apiKey: String
    let modelID: String
    static let storageKey = "llm.config"
}
```

**扩展后（多供应商）：**
```swift
/// Single provider configuration.
struct LLMProviderConfig: Codable, Sendable, Equatable {
    let providerType: LLMProviderType  // .anthropic, .openAICompatible
    let baseURL: String
    let apiKey: String
    let modelID: String
    let displayName: String?  // Optional user-friendly name

    var isConfigured: Bool { ... }
}

enum LLMProviderType: String, Codable, Sendable, CaseIterable {
    case anthropic
    case openAICompatible
}

/// Multi-provider configuration stored in UserDefaults.
struct LLMConfig: Codable, Sendable, Equatable {
    let primary: LLMProviderConfig
    let fallback: LLMProviderConfig?

    // Backward compatibility: load old single-provider format
    static let storageKey = "llm.config"
}
```

**向后兼容迁移：**
旧的 `LLMConfig` 格式（`baseURL/apiKey/modelID`）在加载时自动转换为新的 `LLMProviderConfig` 格式（`providerType` 自动设为 `.anthropic`）。如果 UserDefaults 中存储的是旧格式 JSON，解码时使用 `try?` 回退到旧格式解析。

### LLMGateway 速率限制增强

当前 `analyzeWithRetry` 对所有错误一视同仁地重试。本 Story 需要区分：

1. **429 速率限制** — 遵循 `retry-after` 头等待后重试，重试耗尽后 failover
2. **5xx 服务器错误** — 快速重试（指数退避），重试耗尽后 failover
3. **4xx 客户端错误（非 429）** — 不重试，直接 failover 或报错
4. **网络超时/连接错误** — 重试后 failover

修改 `analyzeWithRetry` 以传递错误类型信息，让 `analyze` 方法决定是 failover 还是继续重试。

### 文件组织

本 Story 需创建/修改的文件：

```
Curator/
├── Core/Models/
│   ├── LLMProviderConfig.swift           # 新建：单供应商配置值类型
│   └── LLMConfig.swift                   # 修改：扩展为多供应商配置
├── Infrastructure/LLM/
│   ├── OpenAICompatibleProvider.swift     # 新建：OpenAI 兼容 API 实现
│   ├── LLMGateway.swift                  # 修改：增强速率限制处理
│   └── LLMModels.swift                   # 修改：添加 OpenAI 兼容模型
├── App/
│   └── AppDependencies.swift             # 修改：多供应商注册

CuratorTests/
├── Infrastructure/LLM/
│   ├── OpenAICompatibleProviderTests.swift  # 新建：OpenAI Provider 测试
│   └── LLMGatewayTests.swift               # 新建（如果不存在）：故障转移测试
├── Core/Models/
│   └── LLMConfigTests.swift                # 新建：多供应商配置测试
```

### 测试策略

**ATDD 测试优先级：**

- **[P0] OpenAI Chat Completions API 请求格式** — 验证请求 URL、headers、body 格式正确
- **[P0] 主供应商 5xx 故障 → 自动回退** — Mock AnthropicProvider 返回错误，验证回退到 OpenAICompatibleProvider
- **[P0] 429 速率限制 → 重试后回退** — Mock 返回 429 + retry-after，验证重试行为和最终回退
- **[P1] OpenAI 错误响应解析** — 验证各种错误格式正确映射到 InfrastructureError
- **[P1] LLMConfig 多供应商存储和读取** — 存储多供应商配置后读取返回正确数据
- **[P1] LLMConfig 旧格式向后兼容** — 存储旧格式 JSON 后加载返回正确的 LLMProviderConfig
- **[P1] AppDependencies 多供应商注册** — 有备用供应商时注册两个 provider，无备用时只注册一个

**Mock 策略：**

复用 `URLSessionProtocol` 抽象（与 AnthropicProvider 测试相同的方式）。创建 `MockURLSession` 返回预定义的 HTTP 响应。

### 不做什么（范围边界）

以下内容在本 Story 中 **不实现**，属于后续 Story：

- **供应商设置 UI**（Story 2.5）— Settings 界面中的多供应商管理 UI
- **费用预估卡片 UI**（Story 2.6）— CostEstimateCard 自定义组件
- **费用追踪面板**（Story 2.6）— 累计 API 支出展示
- **供应商健康检查/自动选择最优供应商** — 超出 MVP 范围
- **Ollama 本地模型支持** — 第三阶段功能
- **Keychain 迁移** — 当前使用 UserDefaults 存储配置，安全增强在后续迭代

### 技术要求

- **Swift 6 strict concurrency**：所有新类型必须 `Sendable`
- **macOS 15+ API**：无特殊平台 API 需求
- **文件命名**：类型名即文件名
- **复用已有抽象**：`URLSessionProtocol`、`LLMProvider`、`LLMResponse`、`CostEstimate`、`InfrastructureError`
- **不引入新第三方依赖**：仅使用 `Foundation`（URLSession + JSONSerialization）
- **构建通过**：`xcodebuild build -project Curator.xcodeproj -scheme Curator -destination 'platform=macOS,arch=arm64'` 必须成功
- **无回归**：全部现有测试（208 个）必须仍然通过
- **xcodegen 自动发现**：新增文件通过 project.yml 的 `sources: - Curator` 配置自动发现

### Project Structure Notes

- `OpenAICompatibleProvider.swift` 放在 `Infrastructure/LLM/` 目录，与 `AnthropicProvider.swift` 同级 [Source: architecture.md#目录组织]
- `LLMProviderConfig` 放在 `Core/Models/`，遵循"协议和模型在 Domain 层定义"规则 [Source: project-context.md#协议在 Domain 层定义]
- `LLMConfig` 修改保持在 `Core/Models/`，不需要移动

### References

- [Source: _bmad-output/planning-artifacts/architecture.md#决策4] — LLM 网关：Provider 协议 + 故障转移链 + 成本追踪，AnthropicProvider + OpenAICompatibleProvider
- [Source: _bmad-output/planning-artifacts/epics.md#Story 2.3] — 原始需求定义（多供应商支持）
- [Source: _bmad-output/planning-artifacts/prd.md#FR43] — 用户可以配置多个 LLM 供应商的 API Key
- [Source: _bmad-output/planning-artifacts/prd.md#FR45] — 用户可以配置备用供应商，在主供应商不可用时自动故障转移
- [Source: _bmad-output/planning-artifacts/prd.md#FR48] — 系统通过排队、重试或回退来优雅处理 API 速率限制
- [Source: _bmad-output/planning-artifacts/prd.md#NFR20] — LLM API 调用实现指数退避，最多 3 次重试后报告失败
- [Source: _bmad-output/planning-artifacts/prd.md#NFR21] — 供应商故障转移在主供应商失败后 10 秒内完成
- [Source: _bmad-output/project-context.md#Critical Implementation Rules] — Swift 6 严格并发、三层错误体系
- [Source: _bmad-output/implementation-artifacts/2-1-llm-gateway-core.md] — Story 2.1 完成记录（LLMGateway + AnthropicProvider）
- [Source: _bmad-output/implementation-artifacts/2-2-keychain-credential-mgmt.md] — Story 2.2 完成记录（实际使用 UserDefaults + LLMConfig 方案）
- [Source: Curator/Infrastructure/LLM/LLMGateway.swift] — 已有 failover 循环和指数退避重试
- [Source: Curator/Infrastructure/LLM/AnthropicProvider.swift] — 参考实现（URLSessionProtocol、错误映射）
- [Source: Curator/Core/Models/LLMConfig.swift] — 当前单供应商配置存储
- [Source: Curator/App/AppDependencies.swift] — 当前 registerLLMGateway() 实现

## Dev Agent Record

### Agent Model Used

Claude Opus 4.7 (GLM-5.1)

### Debug Log References

No blocking issues encountered during implementation.

### Completion Notes List

- Task 1: Created LLMProviderConfig value type with LLMProviderType enum (.anthropic, .openAICompatible). Restructured LLMConfig to hold primary + optional fallback LLMProviderConfig. Added backward-compatible convenience init and computed properties (baseURL, apiKey, modelID, isConfigured, messagesEndpoint) so existing callers (OnboardingViewModel, SettingsPlaceholderView) continue to compile without changes. Legacy JSON auto-migrates on load via LegacyLLMConfig decoding.
- Task 2: Created OpenAICompatibleProvider implementing LLMProvider protocol. Supports Bearer auth, /v1/chat/completions endpoint, image_url data URI encoding, choices[].message.content response parsing, prompt_tokens/completion_tokens usage mapping. Includes 429 retry-after handling with up to 3 retries.
- Task 3: Enhanced LLMGateway.analyzeWithRetry() with error-type-aware strategy: 4xx non-429 errors immediately failover (no retry), 429 rate limit errors use retry-after delay then failover, 5xx/network errors use exponential backoff then failover.
- Task 4: Updated AppDependencies.registerLLMGateway() to read multi-provider config, create AnthropicProvider for primary and OpenAICompatibleProvider for fallback when configured.
- Task 5: Added gpt4o, gpt4oMini, deepseekChat cases to LLMModelID with real-world pricing.
- Task 6: All 48 new ATDD tests pass (OpenAICompatibleProviderTests: 13 tests, LLMConfigMultiProviderTests: 14 tests, MultiProviderFailoverTests: 9 tests). Existing 208 tests remain green (256 total, 0 failures, 3 skipped for PhotoKit permission reasons).
- Build: xcodebuild build succeeded with 0 errors.
- Full test suite: 256 tests executed, 0 failures, 3 skipped.

### File List

**New Files:**
- Curator/Core/Models/LLMProviderConfig.swift
- Curator/Infrastructure/LLM/OpenAICompatibleProvider.swift

**Modified Files:**
- Curator/Core/Models/LLMConfig.swift
- Curator/Infrastructure/LLM/LLMGateway.swift
- Curator/Infrastructure/LLM/LLMModels.swift
- Curator/App/AppDependencies.swift
- CuratorTests/Infrastructure/LLM/OpenAICompatibleProviderTests.swift (removed XCTSkip)
- CuratorTests/Core/Models/LLMConfigMultiProviderTests.swift (removed XCTSkip)
- CuratorTests/Infrastructure/LLM/MultiProviderFailoverTests.swift (removed XCTSkip)
- _bmad-output/implementation-artifacts/sprint-status.yaml

## Change Log

- 2026-04-19: Story 2.3 implementation complete — multi-provider support with OpenAICompatibleProvider, error-type-aware LLMGateway failover, LLMProviderConfig/LLMProviderType, backward-compatible LLMConfig migration, OpenAI-compatible model pricing. All 256 tests pass (0 failures).
- 2026-04-19: Code review — removed duplicate retry logic from OpenAICompatibleProvider, added os_log failover logging to LLMGateway, added maxRetries guard. 3 items deferred.

### Review Findings

- [x] [Review][Defer] AppDependencies ignores primary.providerType, always creates AnthropicProvider [Curator/App/AppDependencies.swift:47-58] — deferred: primary provider type dispatch deferred to Story 2.5 when provider settings UI is added
- [x] [Review][Patch] Remove duplicate retry logic from OpenAICompatibleProvider [Curator/Infrastructure/LLM/OpenAICompatibleProvider.swift:121-154] — fixed: provider now throws immediately on 429, gateway handles retries
- [x] [Review][Patch] Add failover logging/metrics to LLMGateway [Curator/Infrastructure/LLM/LLMGateway.swift] — fixed: added os.log warning on provider failure with failover
- [x] [Review][Patch] Guard maxRetries > 0 in LLMGateway init [Curator/Infrastructure/LLM/LLMGateway.swift:42-52] — fixed: max(1, maxRetries) prevents zero-retry loop
- [x] [Review][Defer] messagesEndpoint hardcoded to /v1/messages regardless of provider type [Curator/Core/Models/LLMConfig.swift:56-59] — deferred: pre-existing design, will be addressed in Story 2.5
- [x] [Review][Defer] Duplicated code between AnthropicProvider and OpenAICompatibleProvider (detectMediaType, estimateCost, parseRetryAfter) — deferred: pre-existing pattern, not introduced by this change
