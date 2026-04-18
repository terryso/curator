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
    @Published var llmProvider: (any LLMProvider)?
}
