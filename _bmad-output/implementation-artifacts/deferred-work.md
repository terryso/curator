# Deferred Work

## Deferred from: code review of 1-2-layered-architecture-skeleton.md (2026-04-18)

- `InfrastructureError.networkError(underlying: any Error)` uses existential `any Error` which is not constrained to `Sendable`. While `Error` is implicitly `Sendable` in Swift, this is a latent concurrency soundness concern. Monitor when Swift 6 evolves existential Sendable handling.
- `AppDependencies` uses `ObservableObject` instead of `@Observable` per architecture doc line 421 which says "ViewModels 使用 @Observable 类". The DI container intentionally uses `ObservableObject` for `.environmentObject()` injection; if the project migrates to `@Observable`, revisit this.
- `LoadableState.swift` file naming does not follow architecture convention for extension files (`View+Loadable.swift`). Matches story spec but violates architecture doc naming pattern.
- `ErrorMapping.toDomainError()` discards all associated values from `InfrastructureError` (provider names, retry timing, status codes, error reasons). Matches architecture doc Decision 9. Extend when Stories 2.x/3.x need richer error context for retry logic or logging.
- Protocol files `PhotoLibraryRepository.swift` and `LLMProvider.swift` placed in `Core/Models/` temporarily. Move to a dedicated `Core/Protocols/` or similar directory when Infrastructure implementations are added in later stories.

## Deferred from: code review of 1-4-photo-library-browse-grid.md (2026-04-18)

- NSCache thumbnail cache (100MB limit per AC3/architecture decision 8) not implemented. Story 1.3 returns thumbnailData as nil for performance. Thumbnail loading strategy must be decided first (Method A/B/C from spec). Defer to a dedicated thumbnail-loading story or when implementing NFR8 performance requirements.

## Deferred from: macOS HIG compliance review of Epic 1 UI (2026-04-19)

Epic 1 UI 基础架构正确（NavigationSplitView 三栏、Toolbar、Sidebar），以下为增量合规项，可在后续 Epic 或专项 HIG 清理 Story 中补齐：

- 照片网格缺少右键 Context Menu（应含复制、删除、收藏、分享等操作）
- Toolbar 按钮缺少键盘快捷键（如 Cmd+Ctrl+S 切换 Sidebar）
- 缺少 Space 键 Quick Look 预览照片支持
- 照片网格缺少多选支持（Cmd+Click 非连续选、Shift+Click 范围选）
- Onboarding 动画未检查 `@Environment(\.accessibilityReduceMotion)` 设置
- 未注册菜单栏命令（App 菜单、自定义菜单项）

## Deferred from: code review of 2-1-llm-gateway-core.md (2026-04-19)

- API key stored as plain `String` in `AnthropicProvider`. Swift `String` values are interned and may persist in memory. No zeroing after use. Acceptable for now — Story 2.2 will introduce KeychainManager for secure key storage.
- Unrelated `PhotoPermissionManager` change (early return on already-authorized status) included in Story 2-1 diff. Should be a separate commit for clean git history.

## Deferred from: code review of 1-2-layered-architecture-skeleton.md (2026-04-20, rewrite review)

- `registerLocalFolderRepository()` 空实现 — 设计如此，Story 1.3 填充具体绑定
- `ErrorMapping.toDomainError()` 丢弃关联值（reason/provider/retryAfter）— 设计选择，完整错误链在基础设施层可用
- Mock 从 actor 改为 struct — 有意为之，解决 AsyncStream Sendable 隔离问题
- `AsyncStream` 无背压控制 — 架构决策，大量文件变化时可能导致内存增长，后续考虑
- `AssetID` 无路径规范化，同一文件可产生多个 ID — Story 1.3 实现细节
- `FileFormat` 缺少 WebP/GIF — 未来增强
- `SourceChange` 空数组未校验 — 实现层处理
- `AssetMetadata` 值域校验缺失（fileSize≤0, width/height≤0, fileName 空）— 后续优化
- `DateRange` 反向范围未校验 — 实现层处理
- `supportedExtensions` 仅小写，调用方需注意 `.lowercased()` — 文档层面
- `deleteAssets`/`moveAssets` 空数组行为未定义 — 实现层处理
- `LocationData` 纬度/经度无范围校验 — 后续优化
- UI 测试 `testClickPhotoOpensDetailSheet` 失败 — 环境相关，非本 Story 范围
- `FolderBookmarkManaging` accessBookmark/releaseBookmark 非异步 — API 设计由实现层关注

## Deferred from: code review of 2-6-cost-estimate-and-tracking.md (2026-04-20)

- `allTimeSummary()` fetches all CostRecordEntity records without limit — unbounded memory if many records exist. Pattern is consistent with pre-existing `monthlySummary()` and `sessionSummary()`. A future story should add pagination or streaming to all summary methods.
- Silent error swallowing in `SettingsViewModel.loadAllTimeSummary()`, `refreshCostData()`, `loadRecentRecords()` — sets properties to nil/empty on error with no logging. Consistent with pre-existing `loadMonthlyCostSummary()` pattern from Story 2.5. A future story should add proper error logging and/or user-facing error states.

## Deferred from: code review of 3-3-agent-input-bar (2026-04-21)

- Tests use `Task.sleep(for: .milliseconds(100))` to wait for AgentJob state transitions — fragile under CI load. Pattern pre-exists from Story 3.1/3.2. A future story should introduce a proper async expectation or EventBus pattern for deterministic state transition testing.

## Deferred from: code review of 3-4-agent-execution-panel (2026-04-22)

- `formattedDuration` 仅展示整数秒 (`Int(summary.duration)`)，丢弃亚秒精度。执行时间在 0.5-0.9 秒的任务会显示 "0s"。低优先级设计选择。
- UI 文本硬编码英文（"Starting execution...", "Waiting", "Running" 等）而非中文。可能是有意的产品决策，与中文用户故事不一致。

## Deferred from: code review of 3-6-agent-streaming-comm.md (2026-04-22)

- Pre-tool partialMessage reasoning (arriving before any toolUse event) falls through to `AgentJob.reasoningMessages` array which is not rendered in any view. The messages are silently dropped from the UI. This is a pre-existing limitation of the `stepIDMap.latestValue ?? UUID()` fallback pattern -- pre-existing
- No explicit `withAnimation(.easeInOut(duration: 0.2))` for streaming text append in ReasoningBubbleView (AC5 spec says "smooth append"). SwiftUI @Observable implicit animation may handle this. Verify visually during QA -- deferred, verify visually

## Deferred from: code review of 4-5-read-only-mode-safety.md (2026-04-23)

- `isWriteOperation` heuristic in `AgentStep` uses keyword matching ("rename", "move", "delete", "remove", "organize") which can false-positive on analysis steps ("organize") and is English-centric. Acceptable for MVP as false-positive direction (showing lock badge on analysis step) is safe. Revisit in Epic 5/6 when SDK tools provide actual operation type metadata. [AgentStep.swift:36-40]
- `ReadOnlyNoOpRepository` is a near-exact copy of `ConfirmationNoOpRepository` in ConfirmationViewModel.swift. Both are private safety-net types. Could consolidate into a shared test helper in a future refactor pass. [ReadOnlyModeViewModel.swift:130-151]

## Deferred from: code review of 5-3-dedup-sdk-tools.md (2026-04-24)

- Duplicate mock `PhotoLibraryRepository` implementations across 3 test files (AnalyzeDuplicatesToolTests, DeleteAssetsToolTests, DedupToolRegistrationTests). Pattern pre-exists from Story 3.2 (ScanLibraryTool tests). Could consolidate into a shared test helper in `CuratorTests/Infrastructure/SDKTools/TestHelpers.swift`.
