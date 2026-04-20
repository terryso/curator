# Epic 1 Context: "Hello Curator" — 首次启动与照片文件夹访问

<!-- Compiled from planning artifacts. Edit freely. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Establish the complete foundation for Curator: scaffold the Xcode project with all dependencies and entitlements, implement a layered architecture skeleton with domain models and error types, build the local-folder photo source service with security-scoped bookmarks, create the photo grid browser with paged loading, deliver the first-launch onboarding flow, and set up the main Agent workspace window layout. This epic gives users a native macOS experience for browsing their photo library and provides the architectural foundation every subsequent epic builds on.

## Stories

- Story 1.1: 项目初始化与构建配置
- Story 1.2: 分层架构骨架
- Story 1.3: 本地文件夹读取服务
- Story 1.4: 照片网格浏览
- Story 1.5: 首次启动引导流程
- Story 1.6: 主界面框架与窗口管理

## Requirements & Constraints

**Photo source access (MVP = local folders only):**
- Users select a photo folder via NSOpenPanel; access persists across restarts via security-scoped bookmarks.
- Recursive scanning of supported image formats: JPEG, PNG, HEIC, TIFF, RAW.
- EXIF metadata read via ImageIO framework (date, camera model, dimensions, GPS).
- Full-resolution image data must be accessible for future AI analysis.
- Paged browsing at 100 items per page, never blocking the UI.
- File system changes detected externally (handled in Epic 7, but the Repository interface must support change observation).

**Performance targets:**
- App launches to interactive state within 3 seconds on Apple Silicon.
- Photo grid scrolls at 60fps; next page loads within 200ms.
- 10,000-photo folder completes initial metadata indexing within 60 seconds.
- Memory stays under 500MB during photo processing.

**Security and sandboxing:**
- App must run sandboxed. Entitlements required: app-sandbox, files.user-selected.read-write, network.client, keychain.
- API keys stored in macOS Keychain (not in config files or logs).
- Distribution: DMG with Apple Developer ID signing and notarization (not App Store).

**Platform constraints:**
- macOS 15+ (Sequoia), Apple Silicon (arm64) only. No iOS/iPadOS.
- Swift 6 strict concurrency (Sendable types, actor isolation).
- All I/O and compute-intensive work on background threads/actors; UI thread only for view updates.

**Trust and privacy from first launch:**
- App starts in read-only mode by default; write permission requested only when needed.
- Onboarding includes a privacy statement explaining what data is sent to LLM APIs and why.
- App must remain functional (with limited features) if the user skips folder selection.

## Technical Decisions

**Architecture: Layered (Presentation -> Application -> Domain -> Infrastructure) + dependency injection.**
- Protocols defined in Domain layer; concrete implementations in Infrastructure.
- `AppDependencies` provides protocol-to-implementation bindings, swappable for tests.
- ViewModels are `@Observable` classes injected via `@Environment`; no TCA.

**Project setup:**
- Xcode project with SPM. Two external dependencies: OpenAgentSDKSwift (Agent infrastructure) and Sparkle 2 (auto-update).
- Feature-based directory structure: `App/`, `Core/`, `Features/`, `Infrastructure/`, `Resources/`.
- Key Epic 1 files: `CuratorApp.swift`, `AppDependencies.swift`, `Curator.entitlements`.

**Photo source: Repository pattern + Actor isolation.**
- `PhotoLibraryRepository` protocol defines the abstraction; `LocalFolderRepository` (actor) is the MVP implementation.
- `FolderBookmarkManager` handles security-scoped bookmark creation, storage, and restoration.
- `ExifMetadataReader` wraps ImageIO for EXIF extraction.
- `AssetPage` model for paginated results with cursor-based navigation.

**Domain models (value types, Sendable):**
- `PhotoAsset` — represents a photo with ID, filename, path, metadata reference.
- `AssetMetadata` — EXIF fields: date, camera model, dimensions, GPS coordinates.
- `LoadingState<T>` — enum with idle / loading / loaded(T) / failed(DomainError) cases.

**Error handling: Typed errors with layered propagation.**
- `DomainError` — business-level failures (assetNotFound, insufficientPermission, analysisFailed).
- `InfrastructureError` — low-level failures (networkError, rateLimitExceeded).
- Infrastructure errors must be mappable to Domain errors before propagating upward.
- User-facing messages never expose technical internals.

**State management:**
- `@Observable` + Observation framework (Swift native). No Combine, no TCA.
- `@AppStorage` for persistent user preferences and window state.
- SwiftData for metadata caching and persistence (schema initialized in this epic).

**Naming convention:**
- Avoid naming any type `Task` — conflicts with Swift Concurrency. Use project-specific names like `AgentJob`.
- Types: UpperCamelCase. Functions/variables: lowerCamelCase. Booleans: is/has/should prefix.
- One type per file; protocol + small implementation in the same file if under 300 lines.

## UX & Interaction Patterns

**Onboarding flow (max 3 screens):**
1. Product introduction — what Curator does.
2. Privacy statement — photos analyzed in-session only, sent to LLM API for understanding.
3. Folder selection — NSOpenPanel; user can skip, app stays usable without photos.

After folder selection, show a photo count summary (e.g., "Found 15,320 photos"). On first entry to the main view, the input bar placeholder shows a sample command.

**Photo grid:**
- Adaptive column count: minimum column width 120pt, 4pt gap, columns = floor(available width / (120 + 4)).
- Automatic next-page loading when scrolling near the end of the current page.
- Clicking a photo opens a detail sheet with full metadata (filename, date, EXIF, file size).
- Thumbnail cache (NSCache, 100MB cap) prevents redundant loading.

**Main window layout (Agent Workspace):**
- `NavigationSplitView` three-column layout: collapsible photo library panel + Agent execution area + fixed bottom input area.
- Minimum window width: 900pt. Recommended: 1200pt+.
- Toolbar contains: photo library toggle, settings entry, session history button.
- Keyboard shortcuts: Cmd+N for new session, Cmd+, for settings.
- Window size and panel collapse state persisted via `@AppStorage`.

**Design system: macOS native.**
- 100% SwiftUI system controls. Custom components only for Agent-specific UI.
- System accent color, automatic light/dark mode, SF Pro fonts with semantic SwiftUI modifiers.
- Agent-generated content uses indigo-tinted card backgrounds to distinguish from system UI.

## Cross-Story Dependencies

- **1.1 -> 1.2:** Project must be scaffolded and building before architecture types can be added.
- **1.2 -> 1.3:** Domain models (`PhotoAsset`, `AssetMetadata`) and the `PhotoLibraryRepository` protocol must exist before `LocalFolderRepository` can implement them.
- **1.3 -> 1.4:** The photo source service must be functional before the grid view can display real data.
- **1.3 -> 1.5:** Folder selection and bookmark persistence are needed for the onboarding flow to complete successfully.
- **1.4, 1.5, 1.6 -> Epic 3:** The Agent workspace layout (1.6) and photo grid (1.4) are prerequisites for the Agent execution panel and input bar in Epic 3.
- **1.2 -> Epic 2:** `AppDependencies` and the DI container pattern established here are used by LLM providers in Epic 2.
- **1.3 -> Epic 5, 6:** The `PhotoLibraryRepository` protocol and `LocalFolderRepository` are used by deduplication and rename tools.
