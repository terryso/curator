# Deferred Work

## Deferred from: code review of 1-2-layered-architecture-skeleton.md (2026-04-18)

- `InfrastructureError.networkError(underlying: any Error)` uses existential `any Error` which is not constrained to `Sendable`. While `Error` is implicitly `Sendable` in Swift, this is a latent concurrency soundness concern. Monitor when Swift 6 evolves existential Sendable handling.
- `AppDependencies` uses `ObservableObject` instead of `@Observable` per architecture doc line 421 which says "ViewModels 使用 @Observable 类". The DI container intentionally uses `ObservableObject` for `.environmentObject()` injection; if the project migrates to `@Observable`, revisit this.
- `LoadableState.swift` file naming does not follow architecture convention for extension files (`View+Loadable.swift`). Matches story spec but violates architecture doc naming pattern.
- `ErrorMapping.toDomainError()` discards all associated values from `InfrastructureError` (provider names, retry timing, status codes, error reasons). Matches architecture doc Decision 9. Extend when Stories 2.x/3.x need richer error context for retry logic or logging.
- Protocol files `PhotoLibraryRepository.swift` and `LLMProvider.swift` placed in `Core/Models/` temporarily. Move to a dedicated `Core/Protocols/` or similar directory when Infrastructure implementations are added in later stories.

## Deferred from: code review of 1-4-photo-library-browse-grid.md (2026-04-18)

- NSCache thumbnail cache (100MB limit per AC3/architecture decision 8) not implemented. Story 1.3 returns thumbnailData as nil for performance. Thumbnail loading strategy must be decided first (Method A/B/C from spec). Defer to a dedicated thumbnail-loading story or when implementing NFR8 performance requirements.
