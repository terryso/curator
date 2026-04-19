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
    /// Replace with mock for testing.
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

    /// Registers the LLM Gateway with an Anthropic provider.
    ///
    /// Creates an AnthropicProvider with the given API key and wraps it
    /// in an LLMGateway. The API key is currently passed as a parameter;
    /// Story 2.2 will replace this with KeychainManager retrieval.
    func registerLLMGateway(apiKey: String = "") {
        let provider = AnthropicProvider(apiKey: apiKey)
        let gateway = LLMGateway(providers: [provider])
        llmGateway = gateway
        llmProvider = provider
    }
}
