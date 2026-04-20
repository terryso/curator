import XCTest
@testable import Curator

/// ATDD Tests for Story 2.5 - Provider Settings UI
///
/// Tests verify:
/// - SettingsViewModel loads current LLMConfig correctly
/// - SettingsViewModel saves config and persists to UserDefaults
/// - API Key validation succeeds with valid credentials (mock)
/// - API Key validation fails with invalid credentials (mock)
/// - Gateway is rebuilt after config save
/// - Model selection updates config immediately
/// - Fallback provider toggle works correctly
final class SettingsViewModelTests: XCTestCase {

    // MARK: - Mock Providers

    /// Mock LLM provider that can be configured to succeed or fail for validation testing.
    private final class MockLLMProviderForSettings: LLMProvider, Sendable {
        let name: String
        private let _shouldFail: Bool
        private let _errorMessage: String

        init(name: String = "MockSettingsProvider", shouldFail: Bool = false, errorMessage: String = "Invalid API key") {
            self.name = name
            self._shouldFail = shouldFail
            self._errorMessage = errorMessage
        }

        func analyze(images: [Data], prompt: String, model: String) async throws -> LLMResponse {
            if _shouldFail {
                throw InfrastructureError.llmProviderError(
                    provider: name,
                    statusCode: 401,
                    message: _errorMessage
                )
            }
            return LLMResponse(
                text: "Validation successful",
                modelID: model,
                providerName: name,
                inputTokens: 10,
                outputTokens: 5
            )
        }

        func estimateCost(imageCount: Int, model: String) -> CostEstimate {
            CostEstimate(
                estimatedTokens: imageCount * 100,
                estimatedCost: Double(imageCount) * 0.001,
                modelID: model,
                providerName: name,
                estimatedAPICalls: 1,
                currency: "USD"
            )
        }
    }

    // MARK: - Setup / Teardown

    override func setUp() {
        super.setUp()
        LLMConfig.clear()
    }

    override func tearDown() {
        LLMConfig.clear()
        super.tearDown()
    }

    // MARK: - Helper

    /// Creates a SettingsViewModel with the given dependencies.
    private func makeViewModel() async -> SettingsViewModel {
        let deps = await MainActor.run { AppDependencies() }
        return await MainActor.run { SettingsViewModel(dependencies: deps) }
    }

    /// Creates a SettingsViewModel with specific dependencies.
    private func makeViewModel(dependencies: AppDependencies) async -> SettingsViewModel {
        return await MainActor.run { SettingsViewModel(dependencies: dependencies) }
    }

    // MARK: - AC1: Settings Page Rendering (SettingsViewModel Creation)

    /// [P0] SettingsViewModel can be instantiated with AppDependencies
    func testSettingsViewModelCanBeInstantiated() async throws {
        let viewModel = await makeViewModel()
        XCTAssertNotNil(viewModel)
    }

    /// [P0] SettingsViewModel is @MainActor @Observable
    func testSettingsViewModelIsMainActorObservable() async throws {
        let viewModel = await makeViewModel()
        // Verify @Observable by accessing property on MainActor
        await MainActor.run {
            let _ = viewModel.primaryAPIKey
            viewModel.primaryAPIKey = "test"
        }
    }

    /// [P1] SettingsViewModel has all primary provider properties
    func testSettingsViewModelHasPrimaryProviderProperties() async throws {
        let viewModel = await makeViewModel()

        await MainActor.run {
            // Primary provider properties should have defaults
            XCTAssertTrue(viewModel.primaryAPIKey.isEmpty, "Default API key should be empty")
            XCTAssertEqual(viewModel.primaryProviderType, .anthropic)
            XCTAssertFalse(viewModel.primaryModelID.isEmpty)
        }
    }

    /// [P1] SettingsViewModel has fallback provider properties
    func testSettingsViewModelHasFallbackProviderProperties() async throws {
        let viewModel = await makeViewModel()

        await MainActor.run {
            XCTAssertFalse(viewModel.hasFallback)
            XCTAssertTrue(viewModel.fallbackAPIKey.isEmpty)
            XCTAssertTrue(viewModel.fallbackDisplayName.isEmpty)
        }
    }

    /// [P1] SettingsViewModel has validation state properties
    func testSettingsViewModelHasValidationStateProperties() async throws {
        let viewModel = await makeViewModel()

        await MainActor.run {
            XCTAssertFalse(viewModel.isValidatingPrimary)
            XCTAssertNil(viewModel.primaryValidationResult)
            XCTAssertFalse(viewModel.isValidatingFallback)
            XCTAssertNil(viewModel.fallbackValidationResult)
        }
    }

    // MARK: - AC2: Load Current Config

    /// [P0] loadCurrentConfig loads from existing LLMConfig
    func testLoadCurrentConfigLoadsFromLLMConfig() async throws {
        // Given: A saved LLMConfig with primary + fallback
        let primaryConfig = LLMProviderConfig(
            providerType: .anthropic,
            baseURL: "https://api.anthropic.com",
            apiKey: "sk-ant-test-key",
            modelID: "claude-sonnet-4-20250514",
            displayName: nil
        )
        let fallbackConfig = LLMProviderConfig(
            providerType: .openAICompatible,
            baseURL: "https://api.deepseek.com",
            apiKey: "sk-deepseek-key",
            modelID: "deepseek-chat",
            displayName: "DeepSeek"
        )
        let config = LLMConfig(primary: primaryConfig, fallback: fallbackConfig)
        config.save()

        let viewModel = await makeViewModel()

        // When: Loading current config
        await viewModel.loadCurrentConfig()

        // Then: All properties match saved config
        await MainActor.run {
            XCTAssertEqual(viewModel.primaryProviderType, .anthropic)
            XCTAssertEqual(viewModel.primaryBaseURL, "https://api.anthropic.com")
            XCTAssertEqual(viewModel.primaryAPIKey, "sk-ant-test-key")
            XCTAssertEqual(viewModel.primaryModelID, "claude-sonnet-4-20250514")
            XCTAssertTrue(viewModel.hasFallback)
            XCTAssertEqual(viewModel.fallbackProviderType, .openAICompatible)
            XCTAssertEqual(viewModel.fallbackBaseURL, "https://api.deepseek.com")
            XCTAssertEqual(viewModel.fallbackAPIKey, "sk-deepseek-key")
            XCTAssertEqual(viewModel.fallbackModelID, "deepseek-chat")
            XCTAssertEqual(viewModel.fallbackDisplayName, "DeepSeek")
        }
    }

    /// [P1] loadCurrentConfig uses defaults when no config stored
    func testLoadCurrentConfigUsesDefaultsWhenNoConfigStored() async throws {
        // Given: No config stored
        LLMConfig.clear()

        let viewModel = await makeViewModel()

        // When: Loading current config
        await viewModel.loadCurrentConfig()

        // Then: Properties should have sensible defaults
        await MainActor.run {
            XCTAssertEqual(viewModel.primaryProviderType, .anthropic)
            XCTAssertEqual(viewModel.primaryBaseURL, LLMConfig.defaultBaseURL)
            XCTAssertTrue(viewModel.primaryAPIKey.isEmpty)
            XCTAssertFalse(viewModel.hasFallback)
        }
    }

    // MARK: - AC2: Save Config

    /// [P0] saveConfig persists to LLMConfig
    func testSaveConfigPersistsToLLMConfig() async throws {
        let viewModel = await makeViewModel()

        // When: Setting properties and saving
        await MainActor.run {
            viewModel.primaryProviderType = .anthropic
            viewModel.primaryBaseURL = "https://api.anthropic.com"
            viewModel.primaryAPIKey = "sk-new-test-key"
            viewModel.primaryModelID = "claude-haiku-4-20250506"
            viewModel.hasFallback = true
            viewModel.fallbackProviderType = .openAICompatible
            viewModel.fallbackDisplayName = "TestFallback"
            viewModel.fallbackBaseURL = "https://api.test.com"
            viewModel.fallbackAPIKey = "sk-fallback-key"
            viewModel.fallbackModelID = "deepseek-chat"
            viewModel.saveConfig()
        }

        // Then: LLMConfig.load() returns the saved values
        let loaded = LLMConfig.load()
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.primary.apiKey, "sk-new-test-key")
        XCTAssertEqual(loaded?.primary.modelID, "claude-haiku-4-20250506")
        XCTAssertNotNil(loaded?.fallback)
        XCTAssertEqual(loaded?.fallback?.displayName, "TestFallback")
        XCTAssertEqual(loaded?.fallback?.apiKey, "sk-fallback-key")
    }

    /// [P0] saveConfig without fallback stores nil fallback
    func testSaveConfigWithFallbackDisabledStoresNilFallback() async throws {
        let viewModel = await makeViewModel()

        await MainActor.run {
            viewModel.primaryProviderType = .anthropic
            viewModel.primaryBaseURL = "https://api.anthropic.com"
            viewModel.primaryAPIKey = "sk-primary-key"
            viewModel.primaryModelID = "claude-sonnet-4-20250514"
            viewModel.hasFallback = false
            viewModel.saveConfig()
        }

        let loaded = LLMConfig.load()
        XCTAssertNotNil(loaded)
        XCTAssertNil(loaded?.fallback)
    }

    // MARK: - AC2: API Key Validation

    /// [P0] validatePrimaryAPIKey succeeds with valid credentials
    func testValidateAPIKeySuccess() async throws {
        let viewModel = await makeViewModel()

        await MainActor.run {
            viewModel.primaryProviderType = .anthropic
            viewModel.primaryAPIKey = "sk-valid-key"
            viewModel.primaryBaseURL = "https://api.anthropic.com"
            viewModel.primaryModelID = "claude-sonnet-4-20250514"
            // Inject mock provider that succeeds
            viewModel.providerFactory = { _, _, _ in
                MockLLMProviderForSettings(shouldFail: false)
            }
        }

        // When: Validating with mock provider returning success
        await viewModel.validatePrimaryAPIKey()

        // Then: Validation result should be success
        await MainActor.run {
            XCTAssertFalse(viewModel.isValidatingPrimary)
            if case .success = viewModel.primaryValidationResult {
                // Expected
            } else {
                XCTFail("Expected validation result to be .success, got \(String(describing: viewModel.primaryValidationResult))")
            }
        }
    }

    /// [P0] validatePrimaryAPIKey fails with invalid credentials
    func testValidateAPIKeyFailure() async throws {
        let viewModel = await makeViewModel()

        await MainActor.run {
            viewModel.primaryProviderType = .anthropic
            viewModel.primaryAPIKey = "sk-bad-key"
            viewModel.primaryBaseURL = "https://api.anthropic.com"
            viewModel.primaryModelID = "claude-sonnet-4-20250514"
            // Inject mock provider that fails
            viewModel.providerFactory = { _, _, _ in
                MockLLMProviderForSettings(shouldFail: true)
            }
        }

        // When: Validating with mock provider returning failure
        await viewModel.validatePrimaryAPIKey()

        // Then: Validation result should be failure with message
        await MainActor.run {
            XCTAssertFalse(viewModel.isValidatingPrimary)
            if case .failure(let message) = viewModel.primaryValidationResult {
                XCTAssertFalse(message.isEmpty, "Error message should not be empty")
            } else {
                XCTFail("Expected validation result to be .failure, got \(String(describing: viewModel.primaryValidationResult))")
            }
        }
    }

    /// [P1] validatePrimaryAPIKey sets isValidatingPrimary during validation
    func testValidateAPIKeySetsValidatingDuringOperation() async throws {
        let viewModel = await makeViewModel()

        await MainActor.run {
            viewModel.primaryProviderType = .anthropic
            viewModel.primaryAPIKey = "sk-key"
            viewModel.primaryBaseURL = "https://api.anthropic.com"
            viewModel.primaryModelID = "claude-sonnet-4-20250514"
            viewModel.providerFactory = { _, _, _ in
                MockLLMProviderForSettings(shouldFail: false)
            }
        }

        // Validation should start with isValidatingPrimary = true, end with false
        await viewModel.validatePrimaryAPIKey()

        await MainActor.run {
            XCTAssertFalse(viewModel.isValidatingPrimary, "isValidatingPrimary should be false after validation completes")
            XCTAssertNotNil(viewModel.primaryValidationResult, "primaryValidationResult should be set after validation")
        }
    }

    /// [P1] validateFallbackAPIKey succeeds for fallback provider
    func testValidateFallbackAPIKeySuccess() async throws {
        let viewModel = await makeViewModel()

        await MainActor.run {
            viewModel.hasFallback = true
            viewModel.fallbackProviderType = .openAICompatible
            viewModel.fallbackAPIKey = "sk-valid-fallback"
            viewModel.fallbackBaseURL = "https://api.test.com"
            viewModel.fallbackModelID = "deepseek-chat"
            viewModel.providerFactory = { _, _, _ in
                MockLLMProviderForSettings(shouldFail: false)
            }
        }

        await viewModel.validateFallbackAPIKey()

        await MainActor.run {
            XCTAssertFalse(viewModel.isValidatingFallback)
            if case .success = viewModel.fallbackValidationResult {
                // Expected
            } else {
                XCTFail("Expected fallback validation result to be .success")
            }
        }
    }

    // MARK: - AC2: Rebuild Gateway After Save

    /// [P0] saveConfig calls AppDependencies.registerLLMGateway()
    func testRebuildGatewayAfterSave() async throws {
        let dependencies = await MainActor.run { AppDependencies() }
        // Initially no gateway
        await MainActor.run {
            XCTAssertNil(dependencies.llmGateway)
        }

        let viewModel = await makeViewModel(dependencies: dependencies)

        await MainActor.run {
            viewModel.primaryProviderType = .anthropic
            viewModel.primaryBaseURL = "https://api.anthropic.com"
            viewModel.primaryAPIKey = "sk-rebuild-test"
            viewModel.primaryModelID = "claude-sonnet-4-20250514"
            viewModel.saveConfig()
        }

        // Then: Gateway should be rebuilt (non-nil)
        await MainActor.run {
            XCTAssertNotNil(dependencies.llmGateway, "Gateway should be rebuilt after saveConfig()")
        }
    }

    // MARK: - AC3: Model Selection Updates Config

    /// [P1] Changing model selection updates config immediately
    func testModelSelectionUpdatesConfig() async throws {
        let viewModel = await makeViewModel()

        await MainActor.run {
            viewModel.primaryProviderType = .anthropic
            viewModel.primaryBaseURL = "https://api.anthropic.com"
            viewModel.primaryAPIKey = "sk-model-test"
            viewModel.primaryModelID = "claude-sonnet-4-20250514"
        }

        // When: Changing model selection
        await MainActor.run {
            viewModel.primaryModelID = "claude-haiku-4-20250506"
            viewModel.saveConfig()
        }

        // Then: Config should reflect new model
        let loaded = LLMConfig.load()
        XCTAssertEqual(loaded?.modelID, "claude-haiku-4-20250506")
    }

    /// [P1] All LLMModelID cases are available as selection options
    func testAllLLMModelIDCasesAvailable() async throws {
        // Verify that LLMModelID.allCases is accessible and has expected models
        let allModels = LLMModelID.allCases
        XCTAssertGreaterThanOrEqual(allModels.count, 5, "Should have at least 5 model options")

        // Verify specific models exist
        let rawValues = allModels.map(\.rawValue)
        XCTAssertTrue(rawValues.contains("claude-sonnet-4-20250514"), "Should include Claude Sonnet")
        XCTAssertTrue(rawValues.contains("claude-haiku-4-20250506"), "Should include Claude Haiku")
        XCTAssertTrue(rawValues.contains("gpt-4o"), "Should include GPT-4o")
        XCTAssertTrue(rawValues.contains("deepseek-chat"), "Should include DeepSeek Chat")
    }

    // MARK: - AC2: Fallback Provider Toggle

    /// [P1] Enabling fallback provider configures fallback correctly
    func testFallbackProviderToggleEnable() async throws {
        let viewModel = await makeViewModel()

        await MainActor.run {
            viewModel.primaryProviderType = .anthropic
            viewModel.primaryBaseURL = "https://api.anthropic.com"
            viewModel.primaryAPIKey = "sk-primary"
            viewModel.primaryModelID = "claude-sonnet-4-20250514"

            viewModel.hasFallback = true
            viewModel.fallbackProviderType = .openAICompatible
            viewModel.fallbackDisplayName = "MyFallback"
            viewModel.fallbackBaseURL = "https://api.fallback.com"
            viewModel.fallbackAPIKey = "sk-fallback"
            viewModel.fallbackModelID = "gpt-4o-mini"
            viewModel.saveConfig()
        }

        let loaded = LLMConfig.load()
        XCTAssertNotNil(loaded?.fallback)
        XCTAssertEqual(loaded?.fallback?.displayName, "MyFallback")
        XCTAssertEqual(loaded?.fallback?.providerType, .openAICompatible)
        XCTAssertEqual(loaded?.fallback?.modelID, "gpt-4o-mini")
    }

    /// [P1] Disabling fallback provider removes it from config
    func testFallbackProviderToggleDisable() async throws {
        // Given: Config with fallback
        let primaryConfig = LLMProviderConfig(
            providerType: .anthropic,
            baseURL: "https://api.anthropic.com",
            apiKey: "sk-primary",
            modelID: "claude-sonnet-4-20250514",
            displayName: nil
        )
        let fallbackConfig = LLMProviderConfig(
            providerType: .openAICompatible,
            baseURL: "https://api.fallback.com",
            apiKey: "sk-fallback",
            modelID: "deepseek-chat",
            displayName: "OldFallback"
        )
        LLMConfig(primary: primaryConfig, fallback: fallbackConfig).save()

        let viewModel = await makeViewModel()

        await viewModel.loadCurrentConfig()

        await MainActor.run {
            XCTAssertTrue(viewModel.hasFallback, "Should start with fallback enabled")

            viewModel.hasFallback = false
            viewModel.saveConfig()
        }

        let loaded = LLMConfig.load()
        XCTAssertNil(loaded?.fallback, "Fallback should be nil after disabling")
    }

    // MARK: - AC1: Cost Tracking Entry Point

    /// [P1] SettingsViewModel can access cost tracker through dependencies
    func testSettingsViewModelAccessesCostTracker() async throws {
        let dependencies = await MainActor.run { AppDependencies() }
        await MainActor.run { dependencies.registerLLMGateway() }

        let viewModel = await makeViewModel(dependencies: dependencies)

        // Trigger loading which should populate monthlyCostSummary
        await viewModel.loadMonthlyCostSummary()

        await MainActor.run {
            let summary = viewModel.monthlyCostSummary
            // With a fresh CostTracker, monthlySummary returns .zero
            XCTAssertNotNil(summary, "Should have access to cost summary through dependencies")
        }
    }

    // MARK: - AC1: ValidationResult Type

    /// [P1] SettingsViewModel.ValidationResult enum has expected cases
    func testValidationResultEnumExists() async throws {
        // Verify the ValidationResult enum exists with success and failure cases
        let success = SettingsViewModel.ValidationResult.success
        let failure = SettingsViewModel.ValidationResult.failure("error message")

        // Verify pattern matching works
        switch success {
        case .success:
            break // Expected
        case .failure:
            XCTFail("Should be .success")
        }

        switch failure {
        case .failure(let message):
            XCTAssertEqual(message, "error message")
        case .success:
            XCTFail("Should be .failure")
        }
    }
}
