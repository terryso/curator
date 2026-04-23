import SwiftUI
import SwiftData
import OpenAgentSDK

/// Dependency injection container for the application layer.
///
/// Provides protocol-to-implementation bindings for domain services.
/// Concrete implementations are registered during app startup;
/// tests can replace them with mock implementations.
@MainActor
final class AppDependencies: ObservableObject, UndoManagerRepositoryProvider {
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

    /// Agent tool registry — nil until registered.
    var toolRegistry: AgentToolRegistry?

    /// Agent factory — nil until registered.
    var curatorAgentFactory: CuratorAgentFactory?

    /// Session manager — nil until registered.
    var sessionManager: (any SessionManagerProtocol)?

    /// Operation manager — nil until registered.
    var operationManager: (any OperationManaging)?

    /// Permission state — manages read/write permission tracking.
    var permissionState: PermissionState?

    /// Undo manager ViewModel — manages undo/redo state for batch operations.
    @Published var undoManagerViewModel: UndoManagerViewModel?

    /// Confirmation ViewModel — manages confirmation workflow for batch operations.
    @Published var confirmationViewModel: ConfirmationViewModel?

    /// Read-only mode ViewModel — manages read-only state and saved operations.
    @Published var readOnlyModeViewModel: ReadOnlyModeViewModel?

    /// Registers the local-folder-backed photo library repository (MVP).
    func registerLocalFolderRepository() {
        let bookmarkManager = FolderBookmarkManager()
        photoRepository = LocalFolderRepository(bookmarkManager: bookmarkManager)
        permissionState = PermissionState(repository: photoRepository)
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
        permissionState = PermissionState(repository: photoRepository)
    }

    /// Registers a mock repository for UI testing.
    func registerMockRepository() {
        photoRepository = MockPhotoLibraryRepository()
        permissionState = PermissionState(repository: photoRepository)
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

        // Register SessionManager with a separate ModelContext
        let sessionContext = ModelContext(manager.container)
        let sessionMgr = SessionManager(modelContext: sessionContext)
        self.sessionManager = sessionMgr

        // Register OperationManager with a separate ModelContext
        let operationContext = ModelContext(manager.container)
        let opManager = OperationManager(modelContext: operationContext)
        self.operationManager = opManager

        // Register UndoManagerViewModel with operation manager and self as repository provider
        self.undoManagerViewModel = UndoManagerViewModel(
            operationManager: opManager,
            repositoryProvider: self
        )

        // Register ConfirmationViewModel with operation manager, permission state, and repository provider
        let readOnlyVM = ReadOnlyModeViewModel(permissionState: permissionState)
        self.readOnlyModeViewModel = readOnlyVM

        self.confirmationViewModel = ConfirmationViewModel(
            operationManager: opManager,
            permissionState: permissionState,
            repositoryProvider: self,
            readOnlyModeViewModel: readOnlyVM
        )
    }

    // MARK: - UndoManagerRepositoryProvider

    /// Provides the current photo repository for undo/redo operations.
    nonisolated func getRepository() -> any PhotoLibraryRepository {
        // Must be called from MainActor context where photoRepository is set
        // This is safe because UndoManagerViewModel is @MainActor
        MainActor.assumeIsolated {
            guard let repo = self.photoRepository else {
                fatalError("UndoManagerRepositoryProvider: photoRepository not registered")
            }
            return repo
        }
    }

    /// Registers the agent infrastructure: tool registry and agent factory.
    ///
    /// Creates an AgentToolRegistry and CuratorAgentFactory using the current
    /// LLM configuration. The factory is configured with the primary provider's
    /// API key, model, and base URL from LLMConfig.
    func registerAgentInfrastructure() {
        let registry = AgentToolRegistry()
        self.toolRegistry = registry

        let config = LLMConfig.load()
        let apiKey = config?.apiKey ?? ""
        let model = config?.modelID ?? "claude-sonnet-4-6"
        let baseURL = config?.baseURL

        // Determine provider type from config
        let sdkProvider: OpenAgentSDK.LLMProvider
        switch config?.primary.providerType {
        case .openAICompatible:
            sdkProvider = .openai
        default:
            sdkProvider = .anthropic
        }

        self.curatorAgentFactory = CuratorAgentFactory(
            apiKey: apiKey,
            model: model,
            provider: sdkProvider,
            baseURL: baseURL
        )
    }
}
