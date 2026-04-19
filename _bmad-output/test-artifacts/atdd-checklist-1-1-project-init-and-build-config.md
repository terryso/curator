---
stepsCompleted:
  - 'step-01-preflight-and-context'
  - 'step-02-generation-mode'
  - 'step-03-test-strategy'
  - 'step-04c-aggregate'
  - 'step-05-validate-and-complete'
lastStep: 'step-05-validate-and-complete'
lastSaved: '2026-04-18'
storyId: '1.1'
storyKey: '1-1-project-init-and-build-config'
storyFile: '_bmad-output/implementation-artifacts/1-1-project-init-and-build-config.md'
atddChecklistPath: '_bmad-output/test-artifacts/atdd-checklist-1-1-project-init-and-build-config.md'
generatedTestFiles:
  - 'CuratorTests/BuildConfigurationTests.swift'
  - 'CuratorTests/SPMDependencyTests.swift'
  - 'CuratorTests/EntitlementsTests.swift'
  - 'CuratorTests/DirectoryStructureTests.swift'
inputDocuments:
  - '_bmad-output/implementation-artifacts/1-1-project-init-and-build-config.md'
  - '_bmad-output/planning-artifacts/architecture.md'
  - '_bmad/tea/config.yaml'
  - '.claude/skills/bmad-testarch-atdd/resources/knowledge/data-factories.md'
  - '.claude/skills/bmad-testarch-atdd/resources/knowledge/component-tdd.md'
  - '.claude/skills/bmad-testarch-atdd/resources/knowledge/test-quality.md'
  - '.claude/skills/bmad-testarch-atdd/resources/knowledge/test-healing-patterns.md'
  - '.claude/skills/bmad-testarch-atdd/resources/knowledge/test-levels-framework.md'
  - '.claude/skills/bmad-testarch-atdd/resources/knowledge/test-priorities-matrix.md'
---

# ATDD Checklist - Epic 1, Story 1.1: 项目初始化与构建配置

**Date:** 2026-04-18
**Author:** Nick
**Primary Test Level:** Integration / Build Verification

---

## Story Summary

本 Story 覆盖 Curator 项目的初始创建，包括 Xcode 项目配置、SPM 依赖（OpenAgentSDKSwift 和 Sparkle 2）、Feature-based 目录结构以及 Entitlements 权限声明。

**As a** 开发者
**I want** 创建 Xcode 项目并配置所有必要的依赖和权限
**So that** 项目可以成功构建并运行在 macOS 15+ Apple Silicon 上

---

## Acceptance Criteria

1. **AC1: 项目成功构建** — 执行 `xcodebuild build` 项目成功编译无错误，目标平台 macOS 15.0，架构 arm64
2. **AC2: SPM 依赖正确配置** — OpenAgentSDKSwift 和 Sparkle 2 依赖已正确添加，Feature-based 目录结构已创建
3. **AC3: Entitlements 文件配置正确** — 包含 app-sandbox、personal-information.photos、network.client、keychain 权限声明

---

## Story Integration Metadata

- **Story ID:** `1.1`
- **Story Key:** `1-1-project-init-and-build-config`
- **Story File:** `_bmad-output/implementation-artifacts/1-1-project-init-and-build-config.md`
- **Checklist Path:** `_bmad-output/test-artifacts/atdd-checklist-1-1-project-init-and-build-config.md`
- **Generated Test Files:**
  - `CuratorTests/BuildConfigurationTests.swift`
  - `CuratorTests/SPMDependencyTests.swift`
  - `CuratorTests/EntitlementsTests.swift`
  - `CuratorTests/DirectoryStructureTests.swift`

---

## Red-Phase Test Scaffolds Created

### Integration / Build Verification Tests (4 tests)

**File:** `CuratorTests/BuildConfigurationTests.swift`

- **Test:** `testXcodeProjectBuildsSuccessfully`
  - **Status:** RED - 项目尚未创建
  - **Verifies:** AC1 — `xcodebuild build` 成功编译无错误

**File:** `CuratorTests/SPMDependencyTests.swift`

- **Test:** `testOpenAgentSDKSwiftDependencyResolved`
  - **Status:** RED - SPM 依赖未配置
  - **Verifies:** AC2 — OpenAgentSDKSwift 依赖已正确解析

- **Test:** `testSparkleDependencyResolved`
  - **Status:** RED - SPM 依赖未配置
  - **Verifies:** AC2 — Sparkle 2 依赖已正确解析

**File:** `CuratorTests/EntitlementsTests.swift`

- **Test:** `testEntitlementsFileContainsRequiredKeys`
  - **Status:** RED - Entitlements 文件不存在
  - **Verifies:** AC3 — 所有必需权限声明存在

**File:** `CuratorTests/DirectoryStructureTests.swift`

- **Test:** `testFeatureBasedDirectoryStructureExists`
  - **Status:** RED - 目录结构未创建
  - **Verifies:** AC2 — Feature-based 目录结构完整

---

## Data Factories Created

N/A — 本 Story 为基础设施初始化，不涉及数据工厂。

---

## Fixtures Created

N/A — 本 Story 为构建配置验证，使用文件系统断言，无需 Playwright/Cypress 风格的 fixtures。

---

## Mock Requirements

N/A — 本 Story 为本地构建验证，无外部服务需要 mock。

---

## Required data-testid Attributes

N/A — 本 Story 不涉及 UI 组件。

---

## Implementation Checklist

### Test: `testXcodeProjectBuildsSuccessfully`

**File:** `CuratorTests/BuildConfigurationTests.swift`

**Tasks to make this test pass:**

- [ ] 创建 Xcode 项目 (macOS App, SwiftUI Lifecycle, Swift 6, arm64)
- [ ] 设置部署目标为 macOS 15.0
- [ ] 创建 `CuratorApp.swift` SwiftUI App 入口点（最小化占位实现）
- [ ] 验证 `xcodebuild build -scheme Curator -destination 'platform=macOS,arch=arm64'` 成功
- [ ] 运行测试: `xcodebuild test -scheme Curator -destination 'platform=macOS,arch=arm64' -only-testing:CuratorTests/BuildConfigurationTests`
- [ ] Test passes (green phase)

**Estimated Effort:** 2 hours

---

### Test: `testOpenAgentSDKSwiftDependencyResolved`

**File:** `CuratorTests/SPMDependencyTests.swift`

**Tasks to make this test pass:**

- [ ] 添加 OpenAgentSDKSwift SPM 依赖：`https://github.com/terryso/open-agent-sdk-swift`，branch: main
- [ ] 在项目 target 中链接依赖
- [ ] 验证 Package.resolved 正确生成
- [ ] 运行测试: `xcodebuild test -scheme Curator -destination 'platform=macOS,arch=arm64' -only-testing:CuratorTests/SPMDependencyTests`
- [ ] Test passes (green phase)

**Estimated Effort:** 0.5 hours

---

### Test: `testSparkleDependencyResolved`

**File:** `CuratorTests/SPMDependencyTests.swift`

**Tasks to make this test pass:**

- [ ] 添加 Sparkle 2 SPM 依赖：`https://github.com/sparkle-project/Sparkle`，版本 `2.0.0..<3.0.0`
- [ ] 在项目 target 中链接依赖
- [ ] 验证 Package.resolved 正确生成
- [ ] 运行测试: `xcodebuild test -scheme Curator -destination 'platform=macOS,arch=arm64' -only-testing:CuratorTests/SPMDependencyTests`
- [ ] Test passes (green phase)

**Estimated Effort:** 0.5 hours

---

### Test: `testEntitlementsFileContainsRequiredKeys`

**File:** `CuratorTests/EntitlementsTests.swift`

**Tasks to make this test pass:**

- [ ] 创建 `Curator.entitlements` 文件
- [ ] 添加 `com.apple.security.app-sandbox`（YES）
- [ ] 添加 `com.apple.security.files.user-selected.read-write`（YES）
- [ ] 添加 `com.apple.security.network.client`（YES）
- [ ] 添加 `com.apple.security.keychain`（YES）
- [ ] 在 Build Settings 中配置 Code Signing Entitlements
- [ ] 运行测试: `xcodebuild test -scheme Curator -destination 'platform=macOS,arch=arm64' -only-testing:CuratorTests/EntitlementsTests`
- [ ] Test passes (green phase)

**Estimated Effort:** 1 hour

---

### Test: `testFeatureBasedDirectoryStructureExists`

**File:** `CuratorTests/DirectoryStructureTests.swift`

**Tasks to make this test pass:**

- [ ] 创建 `Curator/App/` 目录
- [ ] 创建 `Curator/Core/` 及子目录 (Agent/, Operations/, Models/, Errors/, Extensions/)
- [ ] 创建 `Curator/Features/` 目录
- [ ] 创建 `Curator/Infrastructure/` 及子目录 (PhotoSource/, LLM/, Analysis/, Storage/, SDKTools/, Update/)
- [ ] 创建 `Curator/Resources/` 目录
- [ ] 创建 `CuratorTests/` 和 `CuratorUITests/` 测试 target 目录
- [ ] 每个子目录添加 `.gitkeep` 或占位文件
- [ ] 运行测试: `xcodebuild test -scheme Curator -destination 'platform=macOS,arch=arm64' -only-testing:CuratorTests/DirectoryStructureTests`
- [ ] Test passes (green phase)

**Estimated Effort:** 1 hour

---

## Running Tests

```bash
# Run all acceptance tests for this story
xcodebuild test -scheme Curator \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:CuratorTests/BuildConfigurationTests \
  -only-testing:CuratorTests/SPMDependencyTests \
  -only-testing:CuratorTests/EntitlementsTests \
  -only-testing:CuratorTests/DirectoryStructureTests

# Run specific test suite
xcodebuild test -scheme Curator \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:CuratorTests/EntitlementsTests

# Run a single test
xcodebuild test -scheme Curator \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:CuratorTests/SPMDependencyTests/testOpenAgentSDKSwiftDependencyResolved

# Build without running tests (verify compilation)
xcodebuild build -scheme Curator \
  -destination 'platform=macOS,arch=arm64'
```

---

## Red-Green-Refactor Workflow

### RED Phase (Complete)

**TEA Agent Responsibilities:**

- All tests written as red-phase scaffolds with `XCTSkip` markers
- Implementation checklist created
- Mock requirements documented (N/A for this story)

**Verification:**

- All generated tests are present and marked with `XCTSkip`
- Activation guidance is clear and actionable
- Any activated test fails due to missing implementation, not test bugs

---

### GREEN Phase (DEV Team - Next Steps)

**DEV Agent Responsibilities:**

1. **Pick one scaffolded test** from implementation checklist (start with highest priority)
2. **Remove `XCTSkip`** for that test and confirm it fails first
3. **Read the test** to understand expected behavior
4. **Implement minimal code** to make that specific test pass
5. **Run the test** to verify it now passes (green)
6. **Check off the task** in implementation checklist
7. **Move to next test** and repeat

**Key Principles:**

- One test at a time (don't try to fix all at once)
- Minimal implementation (don't over-engineer)
- Run tests frequently (immediate feedback)
- Use implementation checklist as roadmap

---

### REFACTOR Phase (DEV Team - After All Tests Pass)

**DEV Agent Responsibilities:**

1. **Verify all tests pass** (green phase complete)
2. **Review code for quality** (readability, maintainability, performance)
3. **Extract duplications** (DRY principle)
4. **Ensure tests still pass** after each refactor
5. **Update documentation** (if API contracts change)

---

## Next Steps

1. **Review this checklist** with team in standup or planning
2. **Begin implementation** using implementation checklist as guide
3. **Activate one scaffold at a time** by removing `XCTSkip` for the current task, then confirm it fails before implementing
4. **Work one activated test at a time** (red -> green for each)
5. **When all activated tests pass**, refactor code for quality
6. **When refactoring complete**, update story status to 'done' in sprint-status.yaml

---

## Knowledge Base References Applied

This ATDD workflow consulted the following knowledge fragments:

- **data-factories.md** - Factory patterns (adapted for Swift test data)
- **component-tdd.md** - Red-green-refactor TDD cycle (applied to XCTest)
- **test-quality.md** - Test design principles (determinism, isolation, explicit assertions)
- **test-levels-framework.md** - Test level selection (integration/build verification for infra story)
- **test-priorities-matrix.md** - Priority assignment (P1: core user journey, project foundation)

See `tea-index.csv` for complete knowledge fragment mapping.

---

## Test Execution Evidence

### Initial Scaffold Review / RED Verification

**Command:** `xcodebuild test -scheme Curator -destination 'platform=macOS,arch=arm64' -only-testing:CuratorTests`

**Expected Results:**

- Total tests: 5
- Skipped: 5 (all have XCTSkip markers)
- Passing: 0 (expected before activation)
- Status: Red-phase scaffolds verified

**Expected Failure Messages:**

- `testXcodeProjectBuildsSuccessfully`: XCTSkip — "项目尚未创建，等待 Story 1.1 实现"
- `testOpenAgentSDKSwiftDependencyResolved`: XCTSkip — "SPM 依赖未配置，等待 Task 2 实现"
- `testSparkleDependencyResolved`: XCTSkip — "SPM 依赖未配置，等待 Task 2 实现"
- `testEntitlementsFileContainsRequiredKeys`: XCTSkip — "Entitlements 文件不存在，等待 Task 4 实现"
- `testFeatureBasedDirectoryStructureExists`: XCTSkip — "目录结构未创建，等待 Task 3 实现"

---

## Notes

- 本 Story 为基础设施初始化，测试主要验证文件系统状态和构建配置，不涉及 UI 或网络 mock
- 测试使用 `Bundle.main.bundleURL` 和 `FileManager` 验证项目结构
- Entitlements 验证通过解析 plist XML 实现
- SPM 依赖验证通过检查 `Bundle` 中 linked frameworks 实现
- 所有测试均为 `XCTSkip` 标记的红阶段脚手架

---

**Generated by BMad TEA Agent** - 2026-04-18
