import Foundation

/// ViewModel for the Settings window, managing LLM provider configuration.
///
/// Loads/saves LLMConfig and triggers gateway rebuild when config changes.
/// Validates API keys by sending a lightweight test request through an LLMProvider.
@MainActor
@Observable
final class SettingsViewModel {

    // MARK: - Primary Provider

    var primaryProviderType: LLMProviderType = .anthropic
    var primaryBaseURL: String = ""
    var primaryAPIKey: String = ""
    var primaryModelID: String = LLMModelID.claudeSonnet.rawValue

    // MARK: - Fallback Provider

    var hasFallback: Bool = false
    var fallbackProviderType: LLMProviderType = .openAICompatible
    var fallbackDisplayName: String = ""
    var fallbackBaseURL: String = ""
    var fallbackAPIKey: String = ""
    var fallbackModelID: String = LLMModelID.gpt4oMini.rawValue

    // MARK: - Validation State

    var isValidatingPrimary: Bool = false
    var primaryValidationResult: ValidationResult?
    var isValidatingFallback: Bool = false
    var fallbackValidationResult: ValidationResult?

    enum ValidationResult: Sendable {
        case success
        case failure(String)
    }

    // MARK: - Cost Tracking

    /// Monthly cost summary accessed through dependencies.
    var monthlyCostSummary: CostSummary?

    // MARK: - Dependencies

    private let dependencies: AppDependencies

    /// Provider factory for creating validation providers. Internal setter for testing injection.
    internal(set) var providerFactory: (LLMProviderType, String, String) -> any LLMProvider = { providerType, apiKey, baseURL in
        switch providerType {
        case .anthropic:
            return AnthropicProvider(apiKey: apiKey, baseURL: baseURL)
        case .openAICompatible:
            return OpenAICompatibleProvider(name: "Validation", apiKey: apiKey, baseURL: baseURL)
        }
    }

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
    }

    // MARK: - Config Management

    /// Loads the current LLMConfig from UserDefaults into view properties.
    func loadCurrentConfig() async {
        if let config = LLMConfig.load() {
            primaryProviderType = config.primary.providerType
            primaryBaseURL = config.primary.baseURL
            primaryAPIKey = config.primary.apiKey
            primaryModelID = config.primary.modelID

            if let fallback = config.fallback {
                hasFallback = true
                fallbackProviderType = fallback.providerType
                fallbackDisplayName = fallback.displayName ?? ""
                fallbackBaseURL = fallback.baseURL
                fallbackAPIKey = fallback.apiKey
                fallbackModelID = fallback.modelID
            } else {
                hasFallback = false
            }
        } else {
            // Set defaults when no config stored
            primaryProviderType = .anthropic
            primaryBaseURL = LLMConfig.defaultBaseURL
            primaryAPIKey = ""
            primaryModelID = LLMModelID.claudeSonnet.rawValue
            hasFallback = false
        }

        // Load monthly cost summary if cost tracker is available
        await loadMonthlyCostSummary()
    }

    /// Saves the current view properties to LLMConfig and rebuilds the gateway.
    func saveConfig() {
        let primary = LLMProviderConfig(
            providerType: primaryProviderType,
            baseURL: primaryBaseURL,
            apiKey: primaryAPIKey,
            modelID: primaryModelID,
            displayName: nil
        )

        let fallback: LLMProviderConfig? = hasFallback
            ? LLMProviderConfig(
                providerType: fallbackProviderType,
                baseURL: fallbackBaseURL,
                apiKey: fallbackAPIKey,
                modelID: fallbackModelID,
                displayName: fallbackDisplayName.isEmpty ? nil : fallbackDisplayName
            )
            : nil

        let config = LLMConfig(primary: primary, fallback: fallback)
        config.save()

        // Rebuild gateway so config takes effect immediately
        rebuildGateway()
    }

    /// Rebuilds the LLM gateway using the updated config.
    func rebuildGateway() {
        dependencies.registerLLMGateway()
    }

    // MARK: - API Key Validation

    /// Validates the primary provider API key by sending a test request.
    func validatePrimaryAPIKey() async {
        isValidatingPrimary = true
        primaryValidationResult = nil

        let provider = providerFactory(primaryProviderType, primaryAPIKey, primaryBaseURL)

        do {
            _ = try await provider.analyze(
                images: [],
                prompt: "Hello",
                model: primaryModelID
            )
            primaryValidationResult = .success
        } catch {
            primaryValidationResult = .failure(error.localizedDescription)
        }
        isValidatingPrimary = false
    }

    /// Validates the fallback provider API key by sending a test request.
    func validateFallbackAPIKey() async {
        isValidatingFallback = true
        fallbackValidationResult = nil

        let provider = providerFactory(fallbackProviderType, fallbackAPIKey, fallbackBaseURL)

        do {
            _ = try await provider.analyze(
                images: [],
                prompt: "Hello",
                model: fallbackModelID
            )
            fallbackValidationResult = .success
        } catch {
            fallbackValidationResult = .failure(error.localizedDescription)
        }
        isValidatingFallback = false
    }

    // MARK: - Cost Summary

    /// Loads the monthly cost summary from the cost tracker.
    func loadMonthlyCostSummary() async {
        guard let tracker = dependencies.costTracker else {
            monthlyCostSummary = nil
            return
        }

        do {
            monthlyCostSummary = try await tracker.monthlySummary()
        } catch {
            monthlyCostSummary = nil
        }
    }
}
