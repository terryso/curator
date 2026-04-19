---
stepsCompleted:
  - step-01-preflight-and-context
  - step-02-generation-mode
  - step-03-test-strategy
  - step-04c-aggregate
  - step-05-validate-and-complete
lastStep: step-05-validate-and-complete
lastSaved: '2026-04-19'
storyId: '2.2'
storyKey: 2-2-keychain-credential-mgmt
storyFile: _bmad-output/implementation-artifacts/2-2-keychain-credential-mgmt.md
atddChecklistPath: _bmad-output/test-artifacts/atdd-checklist-2-2-keychain-credential-mgmt.md
generatedTestFiles:
  - CuratorTests/Infrastructure/Storage/KeychainManagerTests.swift
  - CuratorTests/Core/Models/ProviderCredentialTests.swift
  - CuratorTests/App/KeychainIntegrationTests.swift
inputDocuments:
  - _bmad-output/implementation-artifacts/2-2-keychain-credential-mgmt.md
  - _bmad/tea/config.yaml
  - Curator/Core/Errors/InfrastructureError.swift
  - Curator/Core/Errors/ErrorMapping.swift
  - Curator/App/AppDependencies.swift
  - CuratorTests/Infrastructure/LLM/LLMGatewayTests.swift
  - CuratorTests/DependencyInjectionTests.swift
---

# ATDD Checklist: Story 2.2 - Keychain 凭证管理

## TDD Red Phase (Current)

Red-phase test scaffolds generated. All tests assert EXPECTED behavior against types/APIs that do not yet exist. Activated tests will FAIL until the feature is implemented.

## Test Strategy

- **Stack:** backend (Swift/XCTest)
- **Generation Mode:** AI Generation (no browser recording needed)
- **Test Levels:** Unit (model types, protocol conformance), Integration (KeychainManager against macOS Keychain), DI (AppDependencies integration)

## Acceptance Criteria Coverage

| AC # | Description | Test Scenarios | Priority | Level |
|------|-------------|----------------|----------|-------|
| AC1 | KeychainManager 使用 Security 框架安全存储 API Key | save + load 往返, save 使用 SecItemAdd | P0 | Integration |
| AC2 | 应用启动时从 Keychain 读取 API Key | load 返回已存储数据, load 不存在返回 nil | P0 | Integration |
| AC3 | 用户可以在设置中删除 API Key | delete 后 load 返回 nil, delete 不存在 key 不报错 | P0 | Integration |
| AC4 | 集成 KeychainManager 到 LLMGateway 注册流程 | AppDependencies 集成, registerLLMGateway 从 Keychain 读取 | P1 | Integration/DI |
| AC5 | 所有 Keychain 错误正确映射到三层错误体系 | SecItem 错误映射, 三层映射链验证 | P1 | Unit |

## Generated Test Files

### 1. `CuratorTests/Infrastructure/Storage/KeychainManagerTests.swift`
- **Level:** Integration (直接使用 macOS Keychain)
- **Tests:** 14 个测试
- **覆盖:** AC1, AC2, AC3, AC5
- **优先级:** P0 (6), P1 (8)

### 2. `CuratorTests/Core/Models/ProviderCredentialTests.swift`
- **Level:** Unit (编译时验证)
- **Tests:** 5 个测试
- **覆盖:** AC1 (Sendable 合规)
- **优先级:** P1 (5)

### 3. `CuratorTests/App/KeychainIntegrationTests.swift`
- **Level:** DI (依赖注入集成)
- **Tests:** 6 个测试
- **覆盖:** AC4
- **优先级:** P1 (6)

## Summary Statistics

- **Total Tests:** 25
- **P0 Tests:** 6
- **P1 Tests:** 19
- **All tests skipped:** Yes (TDD RED PHASE)
- **Expected to fail:** Yes (types/APIs not yet implemented)
- **Knowledge fragments used:** data-factories, test-quality, test-healing-patterns

## Implementation Guidance

### Types to Create

1. `Curator/Core/Models/KeychainManagerProtocol.swift` -- Domain 层协议
2. `Curator/Core/Models/ProviderCredential.swift` -- CredentialKey, LLMProviderID, ProviderCredential
3. `Curator/Infrastructure/Storage/KeychainManager.swift` -- SecItem API 实现

### Types to Modify

4. `Curator/App/AppDependencies.swift` -- 添加 keychainManager 属性, 修改 registerLLMGateway()

## Next Steps (Task-by-Task Activation)

During implementation of each task:

1. Remove `try XCTSkip()` from the current test file or test method
2. Run tests: `xcodebuild test -project Curator.xcodeproj -scheme Curator -destination 'platform=macOS,arch=arm64'`
3. Verify the activated test fails first, then passes after implementation (green phase)
4. If any activated tests still fail unexpectedly:
   - Either fix implementation (feature bug)
   - Or fix test (test bug)
5. Commit passing tests

## Key Risks and Assumptions

1. **Keychain Access in Test Environment:** Tests run against real macOS Keychain. Tests use unique `kSecAttrAccount` prefixes to avoid collisions. `tearDown` cleans up all test entries.
2. **SecItem Mock Strategy:** The story explicitly states NOT to mock SecItem. Tests are integration tests against the real Keychain.
3. **Test Isolation:** Each test generates unique keys using UUID to prevent cross-test interference.
4. **No New Third-Party Dependencies:** Only `Security` framework is used.

## Handoff for dev-story

- **Checklist:** `_bmad-output/test-artifacts/atdd-checklist-2-2-keychain-credential-mgmt.md`
- **Test files:**
  - `CuratorTests/Infrastructure/Storage/KeychainManagerTests.swift`
  - `CuratorTests/Core/Models/ProviderCredentialTests.swift`
  - `CuratorTests/App/KeychainIntegrationTests.swift`
- **Story file:** `_bmad-output/implementation-artifacts/2-2-keychain-credential-mgmt.md`
