---
stepsCompleted:
  - step-01-preflight-and-context
  - step-02-generation-mode
  - step-03-test-strategy
  - step-04c-aggregate
  - step-05-validate-and-complete
lastStep: step-05-validate-and-complete
lastSaved: '2026-04-24'
storyId: '6.1'
storyKey: 6-1-content-analysis-and-naming
storyFile: _bmad-output/implementation-artifacts/6-1-content-analysis-and-naming.md
atddChecklistPath: _bmad-output/test-artifacts/atdd-checklist-6-1-content-analysis-and-naming.md
generatedTestFiles:
  - CuratorTests/Core/Models/RenameSuggestionTests.swift
  - CuratorTests/Infrastructure/Analysis/ContentAnalyzerServiceTests.swift
  - CuratorTests/Infrastructure/SDKTools/AnalyzeContentToolTests.swift
---

# ATDD Checklist: Story 6.1 -- Content Analysis and Naming

## TDD Red Phase (Current)

Red-phase test scaffolds generated. All tests use `#if false` / `#endif` guards to prevent compilation errors for not-yet-implemented types. Remove `#if false` / `#endif` guards one-by-one during implementation to activate each test.

- **Unit/Integration Tests:** 25 tests (all guarded via `#if false`, empty shells pass immediately)
- **E2E Tests:** N/A (backend project, no browser testing)
- **Total test suite:** 771 tests pass (25 new + 746 existing)

## Test Strategy

| Test Level | Tests | Purpose |
|---|---|---|
| Unit | RenameSuggestion model, file name validation, status transitions | Pure model logic, no dependencies |
| Unit | ContentAnalyzerService (with mocked LLM) | Service logic in isolation with mock LLMGatewayProtocol |
| Integration | AnalyzeContentTool (mocked analyzer + repository) | Tool wiring, JSON serialization, parameter passing |

## Acceptance Criteria Coverage

### AC1: Photo Content Analysis (FR24, FR25) -- 5 tests

| Test | Priority | File |
|---|---|---|
| `testAnalyzeContentReturnsSuggestions` | P0 | ContentAnalyzerServiceTests.swift |
| `testAnalyzeContentRespectsLanguageParameter` | P1 | ContentAnalyzerServiceTests.swift |
| `testAnalyzeContentToolReturnsValidJSON` | P0 | AnalyzeContentToolTests.swift |
| `testAnalyzeContentToolWithEmptyLibrary` | P0 | AnalyzeContentToolTests.swift |
| `testAnalyzeContentEmptyAssets` | P1 | ContentAnalyzerServiceTests.swift |

### AC2: RenameSuggestion Model Generation -- 9 tests

| Test | Priority | File |
|---|---|---|
| `testRenameSuggestionHasAllRequiredFields` | P0 | RenameSuggestionTests.swift |
| `testRenameSuggestionIsSendable` | P0 | RenameSuggestionTests.swift |
| `testRenameSuggestionIsIdentifiable` | P0 | RenameSuggestionTests.swift |
| `testRenameSuggestionStatusHasExpectedCases` | P0 | RenameSuggestionTests.swift |
| `testRenameSuggestionDefaultStatusIsPending` | P0 | RenameSuggestionTests.swift |
| `testIsValidFileNameRejectsIllegalCharacters` | P0 | RenameSuggestionTests.swift |
| `testIsValidFileNameRejectsEmptyString` | P0 | RenameSuggestionTests.swift |
| `testIsValidFileNameRejectsTooLongName` | P0 | RenameSuggestionTests.swift |
| `testIsValidFileNameAcceptsValidNames` | P1 | RenameSuggestionTests.swift |
| `testSuggestedNamePreservesExtension` | P0 | RenameSuggestionTests.swift |
| `testSuggestedNamePreservesVariousExtensions` | P1 | RenameSuggestionTests.swift |

### AC3: Error Tolerance (Partial Failure) -- 4 tests

| Test | Priority | File |
|---|---|---|
| `testAnalyzeContentHandlesPartialFailure` | P0 | ContentAnalyzerServiceTests.swift |
| `testAnalyzeContentHandlesCompleteLLMFailure` | P0 | ContentAnalyzerServiceTests.swift |
| `testAnalyzeContentSanitizesNames` | P0 | ContentAnalyzerServiceTests.swift |
| `testAnalyzeContentToolHandlesAnalyzerError` | P1 | AnalyzeContentToolTests.swift |

### AC4: Batch Analysis and Progress Reporting -- 1 test

| Test | Priority | File |
|---|---|---|
| `testAnalyzeContentReportsProgress` | P1 | ContentAnalyzerServiceTests.swift |

### AC5: Cost Estimate Integration -- 1 test

| Test | Priority | File |
|---|---|---|
| `testAnalyzeContentToolIncludesCostEstimate` | P1 | AnalyzeContentToolTests.swift |

### Tool Properties -- 2 tests

| Test | Priority | File |
|---|---|---|
| `testAnalyzeContentToolAnnotations` | P1 | AnalyzeContentToolTests.swift |
| `testAnalyzeContentToolRespectsMaxPhotos` | P1 | AnalyzeContentToolTests.swift |

## Priority Summary

| Priority | Count | Description |
|---|---|---|
| P0 | 14 | Critical happy paths and model integrity -- must pass for story completion |
| P1 | 11 | Error handling, annotations, edge cases, progress -- should pass |
| P2 | 0 | Nice-to-have edge cases |
| P3 | 0 | Performance/stress tests |

## Mock Strategy

All tests use protocol-based mocks following existing project patterns:

- `MockAnalyzerLLMGateway` (LLMGatewayProtocol) -- returns preset LLM responses, supports fail-on-call-number and fail-always modes
- `TrackingMockAnalyzerLLMGateway` (LLMGatewayProtocol) -- tracks prompt content for language parameter verification
- `MockAnalyzerTestRepository` (PhotoLibraryRepository) -- returns synthetic image data
- `MockContentAnalyzerTool` (ContentAnalyzerProtocol) -- returns preset RenameSuggestions, supports failure simulation
- `MockContentToolTestRepository` (PhotoLibraryRepository) -- returns preset PhotoAssets
- `TrackingContentToolRepository` (PhotoLibraryRepository) -- tracks fetchAssets call parameters
- `LockedValue<T>` -- thread-safe mutable wrapper for progress tracking in async tests

## Next Steps (Task-by-Task Activation)

During implementation of each task:

1. Remove `#if false` / `#endif` guards from the tests for the current task
2. Run tests: `xcodebuild test` or via Xcode
3. Verify the activated test fails first, then passes after implementation (green phase)
4. If any activated tests still fail unexpectedly:
   - Either fix implementation (feature bug)
   - Or fix test (test bug)
5. Commit passing tests

Recommended activation order (matches story tasks):

1. **Task 1 (RenameSuggestion model):** Activate all `RenameSuggestionTests` -- validates model, status, file name validation
2. **Task 2 (ContentAnalyzerService):** Activate `testAnalyzeContentReturnsSuggestions`, `testAnalyzeContentHandlesPartialFailure`, `testAnalyzeContentHandlesCompleteLLMFailure`, `testAnalyzeContentSanitizesNames`, `testAnalyzeContentTruncatesLongNames`, `testAnalyzeContentRespectsLanguageParameter`, `testAnalyzeContentEmptyAssets`, `testAnalyzeContentReportsProgress`
3. **Task 3 (AnalyzeContentTool):** Activate all `AnalyzeContentToolTests` -- validates tool wiring, JSON output, annotations, parameter passing

## Implementation Files to Create

Per story specification:

- `Curator/Core/Models/RenameSuggestion.swift` -- Task 1
- `Curator/Core/Models/ContentAnalyzerProtocol.swift` -- Task 2
- `Curator/Infrastructure/Analysis/ContentAnalyzerService.swift` -- Task 2
- `Curator/Infrastructure/SDKTools/AnalyzeContentTool.swift` -- Task 3

## Key Risks and Assumptions

1. **ContentAnalyzerProtocol two-overload pattern:** Tests assume the protocol has two `analyzeContent` overloads (with and without progressHandler), matching the story's design
2. **defineTool() signature:** Tests assume `createAnalyzeContentTool` follows the same factory function pattern as `createAnalyzeDuplicatesTool`
3. **RenameSuggestion static validation:** Tests assume `isValidFileName` is a static method on RenameSuggestion
4. **File name sanitization:** Tests expect the service to sanitize LLM output internally, removing characters in `\/:*?"<>|` and truncating to 200 chars
5. **actor isolation:** ContentAnalyzerService is expected to be an actor (per story dev notes); mocks use struct/class as appropriate
6. **Error handling in tool:** Tests assume the tool catches errors internally and returns `result.isError = true` with structured JSON, matching the AnalyzeDuplicatesTool pattern
7. **#if false guards:** Tests use `#if false` / `#endif` instead of `XCTSkipIf` because Swift requires compile-time type checking for types that don't exist yet. Remove guards during implementation to activate tests.
