import XCTest
@testable import Curator

/// ATDD Tests for Story 2.3 - Multi-Provider Support (LLMConfig & LLMProviderConfig)
///
/// Tests verify:
/// - LLMProviderConfig stores individual provider configuration (providerType, baseURL, apiKey, modelID)
/// - LLMProviderType enum has .anthropic and .openAICompatible cases
/// - LLMConfig supports primary + optional fallback provider configuration
/// - LLMConfig backward compatibility: old single-provider format auto-migrates to new format
/// - LLMConfig multi-provider persistence (save/load via UserDefaults)
/// - All new types conform to Sendable and Codable
///
/// TDD RED PHASE: These tests will fail until LLMProviderConfig, LLMProviderType,
/// and updated LLMConfig are implemented.
final class LLMConfigMultiProviderTests: XCTestCase {

    // MARK: - Setup / Teardown

    override func setUp() {
        super.setUp()
        LLMConfig.clear()
    }

    override func tearDown() {
        LLMConfig.clear()
        super.tearDown()
    }

    // MARK: - AC4: LLMProviderType Enum

    /// [P1] LLMProviderType enum has anthropic and openAICompatible cases
    func testLLMProviderTypeHasRequiredCases() throws {
        let anthropic = LLMProviderType.anthropic
        let openAI = LLMProviderType.openAICompatible

        XCTAssertEqual(anthropic.rawValue, "anthropic")
        XCTAssertEqual(openAI.rawValue, "openAICompatible")
    }

    /// [P1] LLMProviderType is CaseIterable
    func testLLMProviderTypeIsCaseIterable() throws {
        let allCases = LLMProviderType.allCases
        XCTAssertEqual(allCases.count, 2,
            "Should have exactly 2 provider types")
        XCTAssertTrue(allCases.contains(.anthropic))
        XCTAssertTrue(allCases.contains(.openAICompatible))
    }

    /// [P1] LLMProviderType conforms to Sendable (compile-time check)
    func testLLMProviderTypeIsSendable() throws {
        let providerType: LLMProviderType = .anthropic
        func assertSendable<T: Sendable>(_: T) {}
        assertSendable(providerType)
    }

    // MARK: - AC4: LLMProviderConfig Value Type

    /// [P1] LLMProviderConfig stores provider configuration fields
    func testLLMProviderConfigStoresFields() throws {
        let config = LLMProviderConfig(
            providerType: .anthropic,
            baseURL: "https://api.anthropic.com",
            apiKey: "sk-ant-test",
            modelID: "claude-sonnet-4-20250514",
            displayName: "Anthropic"
        )

        XCTAssertEqual(config.providerType, .anthropic)
        XCTAssertEqual(config.baseURL, "https://api.anthropic.com")
        XCTAssertEqual(config.apiKey, "sk-ant-test")
        XCTAssertEqual(config.modelID, "claude-sonnet-4-20250514")
        XCTAssertEqual(config.displayName, "Anthropic")
    }

    /// [P1] LLMProviderConfig isConfigured when all required fields populated
    func testLLMProviderConfigIsConfiguredWhenAllFieldsPopulated() throws {
        let config = LLMProviderConfig(
            providerType: .openAICompatible,
            baseURL: "https://api.deepseek.com",
            apiKey: "ds-key",
            modelID: "deepseek-chat",
            displayName: nil
        )

        XCTAssertTrue(config.isConfigured,
            "Should be configured when all required fields are populated")
    }

    /// [P1] LLMProviderConfig isConfigured is false when baseURL empty
    func testLLMProviderConfigNotConfiguredWhenBaseURLEmpty() throws {
        let config = LLMProviderConfig(
            providerType: .anthropic,
            baseURL: "",
            apiKey: "key",
            modelID: "model",
            displayName: nil
        )

        XCTAssertFalse(config.isConfigured,
            "Should not be configured when baseURL is empty")
    }

    /// [P1] LLMProviderConfig displayName is optional
    func testLLMProviderConfigDisplayNameIsOptional() throws {
        let config = LLMProviderConfig(
            providerType: .anthropic,
            baseURL: "https://api.anthropic.com",
            apiKey: "key",
            modelID: "model",
            displayName: nil
        )

        XCTAssertNil(config.displayName,
            "displayName should be optional and nil when not provided")
    }

    /// [P1] LLMProviderConfig conforms to Codable and Equatable
    func testLLMProviderConfigCodableRoundTrip() throws {
        let config = LLMProviderConfig(
            providerType: .openAICompatible,
            baseURL: "https://api.deepseek.com",
            apiKey: "ds-key",
            modelID: "deepseek-chat",
            displayName: "DeepSeek"
        )

        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(LLMProviderConfig.self, from: data)
        XCTAssertEqual(decoded, config,
            "Codable round-trip should produce equal value")
    }

    /// [P1] LLMProviderConfig conforms to Sendable (compile-time check)
    func testLLMProviderConfigIsSendable() throws {
        let config = LLMProviderConfig(
            providerType: .anthropic,
            baseURL: "https://api.anthropic.com",
            apiKey: "key",
            modelID: "model",
            displayName: nil
        )
        func assertSendable<T: Sendable>(_: T) {}
        assertSendable(config)
    }

    // MARK: - AC4: LLMConfig Multi-Provider Storage

    /// [P1] LLMConfig stores primary and optional fallback provider configs
    func testLLMConfigStoresPrimaryAndFallback() throws {
        let primary = LLMProviderConfig(
            providerType: .anthropic,
            baseURL: "https://api.anthropic.com",
            apiKey: "sk-ant-primary",
            modelID: "claude-sonnet-4-20250514",
            displayName: "Anthropic"
        )
        let fallback = LLMProviderConfig(
            providerType: .openAICompatible,
            baseURL: "https://api.deepseek.com",
            apiKey: "ds-key",
            modelID: "deepseek-chat",
            displayName: "DeepSeek"
        )

        let config = LLMConfig(primary: primary, fallback: fallback)

        XCTAssertEqual(config.primary.providerType, .anthropic)
        XCTAssertEqual(config.primary.baseURL, "https://api.anthropic.com")
        XCTAssertNotNil(config.fallback)
        XCTAssertEqual(config.fallback?.providerType, .openAICompatible)
        XCTAssertEqual(config.fallback?.baseURL, "https://api.deepseek.com")
    }

    /// [P1] LLMConfig fallback is nil when not configured
    func testLLMConfigFallbackIsNilWhenNotConfigured() throws {
        let primary = LLMProviderConfig(
            providerType: .anthropic,
            baseURL: "https://api.anthropic.com",
            apiKey: "sk-ant-key",
            modelID: "claude-sonnet-4-20250514",
            displayName: nil
        )

        let config = LLMConfig(primary: primary, fallback: nil)

        XCTAssertNil(config.fallback,
            "Fallback should be nil when only primary is configured")
    }

    /// [P1] LLMConfig multi-provider save and load round-trip
    func testLLMConfigMultiProviderSaveAndLoad() throws {
        let primary = LLMProviderConfig(
            providerType: .anthropic,
            baseURL: "https://api.anthropic.com",
            apiKey: "sk-ant-primary",
            modelID: "claude-sonnet-4-20250514",
            displayName: "Anthropic"
        )
        let fallback = LLMProviderConfig(
            providerType: .openAICompatible,
            baseURL: "https://api.deepseek.com",
            apiKey: "ds-fallback",
            modelID: "deepseek-chat",
            displayName: "DeepSeek"
        )

        let config = LLMConfig(primary: primary, fallback: fallback)
        config.save()

        let loaded = LLMConfig.load()
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.primary.providerType, .anthropic)
        XCTAssertEqual(loaded?.primary.apiKey, "sk-ant-primary")
        XCTAssertEqual(loaded?.primary.modelID, "claude-sonnet-4-20250514")
        XCTAssertNotNil(loaded?.fallback)
        XCTAssertEqual(loaded?.fallback?.providerType, .openAICompatible)
        XCTAssertEqual(loaded?.fallback?.apiKey, "ds-fallback")
        XCTAssertEqual(loaded?.fallback?.modelID, "deepseek-chat")
    }

    /// [P1] LLMConfig save/load without fallback (backward compat)
    func testLLMConfigSaveLoadWithoutFallback() throws {
        let primary = LLMProviderConfig(
            providerType: .anthropic,
            baseURL: "https://api.anthropic.com",
            apiKey: "sk-ant-key",
            modelID: "claude-sonnet-4-20250514",
            displayName: nil
        )

        let config = LLMConfig(primary: primary, fallback: nil)
        config.save()

        let loaded = LLMConfig.load()
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.primary.apiKey, "sk-ant-key")
        XCTAssertNil(loaded?.fallback,
            "Fallback should be nil after load when not configured")
    }

    // MARK: - AC4: Backward Compatibility

    /// [P1] Old single-provider LLMConfig format auto-migrates to new format
    func testLLMConfigBackwardCompatibilityMigration() throws {
        // Simulate old format: single-provider LLMConfig stored as JSON
        let oldFormatJSON: [String: String] = [
            "baseURL": "https://api.anthropic.com",
            "apiKey": "sk-ant-old-key",
            "modelID": "claude-sonnet-4-20250514"
        ]
        let oldData = try JSONSerialization.data(withJSONObject: oldFormatJSON)
        UserDefaults.standard.set(oldData, forKey: "llm.config")

        // When loading, it should auto-migrate to the new multi-provider format
        let loaded = LLMConfig.load()
        XCTAssertNotNil(loaded, "Should load old format and auto-migrate")

        // Primary should be populated from old fields
        XCTAssertEqual(loaded?.primary.providerType, .anthropic,
            "Old format should auto-migrate to .anthropic provider type")
        XCTAssertEqual(loaded?.primary.baseURL, "https://api.anthropic.com")
        XCTAssertEqual(loaded?.primary.apiKey, "sk-ant-old-key")
        XCTAssertEqual(loaded?.primary.modelID, "claude-sonnet-4-20250514")

        // Fallback should be nil (old format had no fallback)
        XCTAssertNil(loaded?.fallback,
            "Old format should have nil fallback after migration")
    }

    // MARK: - AC4: Codable Conformance

    /// [P1] LLMConfig multi-provider Codable round-trip
    func testLLMConfigMultiProviderCodableRoundTrip() throws {
        let primary = LLMProviderConfig(
            providerType: .anthropic,
            baseURL: "https://api.anthropic.com",
            apiKey: "sk-ant-key",
            modelID: "claude-sonnet-4-20250514",
            displayName: nil
        )
        let fallback = LLMProviderConfig(
            providerType: .openAICompatible,
            baseURL: "https://api.openai.com",
            apiKey: "sk-oai-key",
            modelID: "gpt-4o",
            displayName: "OpenAI"
        )

        let config = LLMConfig(primary: primary, fallback: fallback)
        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(LLMConfig.self, from: data)
        XCTAssertEqual(decoded, config,
            "LLMConfig Codable round-trip should produce equal value")
    }

    /// [P1] LLMConfig conforms to Sendable (compile-time check)
    func testLLMConfigMultiProviderIsSendable() throws {
        let config = LLMConfig(
            primary: LLMProviderConfig(
                providerType: .anthropic,
                baseURL: "https://api.anthropic.com",
                apiKey: "key",
                modelID: "model",
                displayName: nil
            ),
            fallback: nil
        )
        func assertSendable<T: Sendable>(_: T) {}
        assertSendable(config)
    }
}
