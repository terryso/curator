import SwiftUI

/// Dependency injection container for the application layer.
///
/// Provides protocol-to-implementation bindings for domain services.
/// Concrete implementations are registered during app startup;
/// tests can replace them with mock implementations.
@MainActor
final class AppDependencies: ObservableObject {
    /// Photo library repository — nil until registered.
    @Published var photoRepository: (any PhotoLibraryRepository)?

    /// LLM provider — nil until registered.
    /// - Note: Retained for backward compatibility. Prefer `llmGateway` for new code.
    @Published var llmProvider: (any LLMProvider)?

    /// LLM Gateway — nil until registered.
    @Published var llmGateway: (any LLMGatewayProtocol)?

    /// Registers the local-folder-backed photo library repository (MVP).
    func registerLocalFolderRepository() {
        // Story 1.3 will create LocalFolderRepository and register it here.
        // For now, leave nil — mock registration is available for testing.
    }

    /// Registers a mock repository for UI testing.
    func registerMockRepository() {
        photoRepository = MockPhotoLibraryRepository()
    }

    /// Registers the LLM Gateway using stored LLMConfig.
    func registerLLMGateway() {
        let config = LLMConfig.load()

        let apiKey = config?.apiKey ?? ""
        let baseURL = config?.baseURL ?? ""
        let primaryProvider = AnthropicProvider(apiKey: apiKey, baseURL: baseURL)

        var providers: [any LLMProvider] = [primaryProvider]

        if let fallbackConfig = config?.fallback, fallbackConfig.isConfigured {
            let fallbackProvider = OpenAICompatibleProvider(
                name: fallbackConfig.displayName ?? "Fallback",
                apiKey: fallbackConfig.apiKey,
                baseURL: fallbackConfig.baseURL
            )
            providers.append(fallbackProvider)
        }

        let gateway = LLMGateway(providers: providers)
        llmGateway = gateway
        llmProvider = primaryProvider
    }
}
