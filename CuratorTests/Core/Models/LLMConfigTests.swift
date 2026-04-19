import XCTest
@testable import Curator

/// Tests for LLMConfig persistence and validation.
final class LLMConfigTests: XCTestCase {

    override func setUp() {
        super.setUp()
        LLMConfig.clear()
    }

    override func tearDown() {
        LLMConfig.clear()
        super.tearDown()
    }

    // MARK: - Validation

    func testIsConfiguredWhenAllFieldsPopulated() {
        let config = LLMConfig(baseURL: "https://api.anthropic.com", apiKey: "sk-test", modelID: "claude-sonnet-4-20250514")
        XCTAssertTrue(config.isConfigured)
    }

    func testIsNotConfiguredWhenBaseURLEmpty() {
        let config = LLMConfig(baseURL: "", apiKey: "sk-test", modelID: "claude-sonnet-4-20250514")
        XCTAssertFalse(config.isConfigured)
    }

    func testIsNotConfiguredWhenAPIKeyEmpty() {
        let config = LLMConfig(baseURL: "https://api.anthropic.com", apiKey: "", modelID: "claude-sonnet-4-20250514")
        XCTAssertFalse(config.isConfigured)
    }

    func testIsNotConfiguredWhenModelIDEmpty() {
        let config = LLMConfig(baseURL: "https://api.anthropic.com", apiKey: "sk-test", modelID: "")
        XCTAssertFalse(config.isConfigured)
    }

    func testIsNotConfiguredWhenFieldsAreWhitespace() {
        let config = LLMConfig(baseURL: "  ", apiKey: "  ", modelID: "  ")
        XCTAssertFalse(config.isConfigured)
    }

    // MARK: - Endpoint

    func testMessagesEndpointAppendsPath() {
        let config = LLMConfig(baseURL: "https://api.anthropic.com", apiKey: "key", modelID: "model")
        XCTAssertEqual(config.messagesEndpoint, "https://api.anthropic.com/v1/messages")
    }

    func testMessagesEndpointHandlesTrailingSlash() {
        let config = LLMConfig(baseURL: "https://api.anthropic.com/", apiKey: "key", modelID: "model")
        XCTAssertEqual(config.messagesEndpoint, "https://api.anthropic.com/v1/messages")
    }

    // MARK: - Persistence

    func testSaveAndLoad() {
        let config = LLMConfig(baseURL: "https://custom.api.com", apiKey: "sk-test-key", modelID: "custom-model")
        config.save()

        let loaded = LLMConfig.load()
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.baseURL, "https://custom.api.com")
        XCTAssertEqual(loaded?.apiKey, "sk-test-key")
        XCTAssertEqual(loaded?.modelID, "custom-model")
    }

    func testLoadReturnsNilWhenNotStored() {
        XCTAssertNil(LLMConfig.load())
    }

    func testClearRemovesStoredConfig() {
        let config = LLMConfig(baseURL: "https://api.test", apiKey: "key", modelID: "model")
        config.save()
        XCTAssertTrue(LLMConfig.isStored)

        LLMConfig.clear()
        XCTAssertFalse(LLMConfig.isStored)
        XCTAssertNil(LLMConfig.load())
    }

    // MARK: - Sendable & Codable

    func testCodableRoundTrip() throws {
        let config = LLMConfig(baseURL: "https://api.anthropic.com", apiKey: "sk-ant-key", modelID: "claude-haiku-4-20250506")
        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(LLMConfig.self, from: data)
        XCTAssertEqual(decoded, config)
    }
}
