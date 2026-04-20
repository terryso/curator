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

    /// SwiftData manager — nil until registered.
    var swiftDataManager: SwiftDataManager?

    /// Cost tracker — nil until registered.
    var costTracker: (any CostTrackerProtocol)?

    /// Registers the local-folder-backed photo library repository (MVP).
    func registerLocalFolderRepository() {
        let bookmarkManager = FolderBookmarkManager()
        photoRepository = LocalFolderRepository(bookmarkManager: bookmarkManager)
    }

    /// Registers a real LocalFolderRepository with a pre-set temp directory for testing.
    /// Creates sample photos so the UI has content to display.
    func registerTestRepository() {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("CuratorTestPhotos", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        createSamplePhotos(in: tempDir)

        let bookmarkManager = FolderBookmarkManager()
        photoRepository = LocalFolderRepository(
            bookmarkManager: bookmarkManager,
            initialFolderURL: tempDir
        )
    }

    /// Registers a mock repository for UI testing.
    func registerMockRepository() {
        photoRepository = MockPhotoLibraryRepository()
    }

    private func createSamplePhotos(in directory: URL) {
        let names = ["test_photo_1.jpg", "test_photo_2.png", "test_photo_3.jpg"]
        for name in names {
            let url = directory.appendingPathComponent(name)
            if FileManager.default.fileExists(atPath: url.path) { continue }

            let size = NSSize(width: 100, height: 100)
            let image = NSImage(size: size)
            image.lockFocus()
            NSColor.blue.setFill()
            NSBezierPath.fill(NSRect(origin: .zero, size: size))
            image.unlockFocus()

            guard let tiffData = image.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiffData) else { continue }

            let data: Data = if name.hasSuffix(".jpg") {
                bitmap.representation(using: .jpeg, properties: [:])!
            } else {
                bitmap.representation(using: .png, properties: [:])!
            }
            try? data.write(to: url)
        }
    }

    /// Registers the LLM Gateway using stored LLMConfig.
    func registerLLMGateway() {
        // Initialize SwiftData and CostTracker
        let manager = SwiftDataManager()
        self.swiftDataManager = manager
        let context = manager.container.mainContext
        let tracker = CostTracker(modelContext: context)
        self.costTracker = tracker

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

        let gateway = LLMGateway(providers: providers, costTracker: tracker)
        llmGateway = gateway
        llmProvider = primaryProvider
    }
}
