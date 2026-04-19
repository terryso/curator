import SwiftUI

/// Dependency injection container for the application layer.
///
/// Provides protocol-to-implementation bindings for domain services.
/// Concrete implementations are registered during app startup;
/// tests can replace them with mock implementations.
///
/// Marked @MainActor for safe use with SwiftUI views that observe it.
@MainActor
final class AppDependencies: ObservableObject {
    /// Photo library repository — nil until registered.
    /// Replace with mock for testing.
    @Published var photoRepository: (any PhotoLibraryRepository)?

    /// LLM provider — nil until registered.
    /// - Note: Retained for backward compatibility. Prefer `llmGateway` for new code.
    @Published var llmProvider: (any LLMProvider)?

    /// LLM Gateway — nil until registered.
    /// Provides unified access to LLM providers with retry and failover.
    @Published var llmGateway: (any LLMGatewayProtocol)?

    /// Registers the PhotoKit-backed photo library repository.
    func registerPhotoKitRepository() {
        photoRepository = PhotoKitRepository()
    }

    /// Registers a mock repository for UI testing.
    func registerMockRepository() {
        photoRepository = MockPhotoLibraryRepository()
    }

    /// Registers the LLM Gateway using stored LLMConfig.
    ///
    /// Reads baseURL, apiKey, and modelID from UserDefaults via LLMConfig.
    /// If no config is stored, creates the gateway with empty credentials
    /// (the user will be prompted to configure via onboarding or settings).
    func registerLLMGateway() {
        let config = LLMConfig.load()
        let apiKey = config?.apiKey ?? ""
        let baseURL = config?.baseURL ?? ""

        let provider = AnthropicProvider(apiKey: apiKey, baseURL: baseURL)
        let gateway = LLMGateway(providers: [provider])
        llmGateway = gateway
        llmProvider = provider
    }
}
