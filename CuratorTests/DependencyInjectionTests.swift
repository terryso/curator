import XCTest
@testable import Curator

/// ATDD Tests for Story 1.2 - AC3: 依赖注入容器
///
/// Tests verify:
/// - AppDependencies exists as @MainActor ObservableObject
/// - PhotoLibraryRepository protocol exists (Sendable) with full method set
/// - LLMProvider protocol exists (Sendable)
/// - AppDependencies provides protocol-to-implementation binding
/// - Test-time mock replacement is supported
final class DependencyInjectionTests: XCTestCase {

    // MARK: - AC3: AppDependencies Container

    /// [P0] AppDependencies exists and can be instantiated on MainActor
    func testAppDependenciesCanBeInstantiated() async throws {
        let dependencies = await MainActor.run {
            AppDependencies()
        }
        XCTAssertNotNil(dependencies)
    }

    /// [P0] AppDependencies is a MainActor ObservableObject
    func testAppDependenciesIsObservableObject() async throws {
        let dependencies = await MainActor.run {
            AppDependencies()
        }
        let _ = dependencies.objectWillChange
    }

    /// [P0] AppDependencies has photoRepository property (optional protocol)
    func testAppDependenciesHasPhotoRepositoryProperty() async throws {
        await MainActor.run {
            let dependencies = AppDependencies()
            XCTAssertNil(dependencies.photoRepository)
        }
    }

    /// [P0] AppDependencies has llmProvider property (optional protocol)
    func testAppDependenciesHasLLMProviderProperty() async throws {
        await MainActor.run {
            let dependencies = AppDependencies()
            XCTAssertNil(dependencies.llmProvider)
        }
    }

    /// [P0] registerLLMGateway() creates gateway without stored config
    func testRegisterLLMGatewayCreatesGatewayWithoutConfig() async throws {
        await MainActor.run {
            let dependencies = AppDependencies()
            dependencies.registerLLMGateway()
            XCTAssertNotNil(dependencies.llmGateway)
        }
    }

    /// [P0] registerLocalFolderRepository() method creates a repository
    func testRegisterLocalFolderRepositoryMethodExists() async throws {
        await MainActor.run {
            let dependencies = AppDependencies()
            dependencies.registerLocalFolderRepository()
            XCTAssertNotNil(dependencies.photoRepository,
                "registerLocalFolderRepository() should register a LocalFolderRepository")
        }
    }

    // MARK: - AC3: Protocol Definitions

    /// [P0] PhotoLibraryRepository protocol exists with Sendable conformance
    func testPhotoLibraryRepositoryProtocolExists() async throws {
        let mock = DITestMockPhotoLibraryRepository()
        XCTAssertNotNil(mock as PhotoLibraryRepository)
    }

    /// [P1] PhotoLibraryRepository has requestReadAccess()
    func testPhotoLibraryRepositoryHasRequestReadAccess() async throws {
        let mock = DITestMockPhotoLibraryRepository()
        let result = try await mock.requestReadAccess()
        XCTAssertTrue(result)
    }

    /// [P1] PhotoLibraryRepository has requestWriteAccess()
    func testPhotoLibraryRepositoryHasRequestWriteAccess() async throws {
        let mock = DITestMockPhotoLibraryRepository()
        let result = try await mock.requestWriteAccess()
        XCTAssertTrue(result)
    }

    /// [P0] PhotoLibraryRepository has write operations
    func testPhotoLibraryRepositoryHasWriteOperations() async throws {
        let mock = DITestMockPhotoLibraryRepository()
        // These should compile and not throw in mock
        try await mock.updateAsset(AssetID(rawValue: "/t"), title: "test")
        try await mock.deleteAssets([AssetID(rawValue: "/t")])
        try await mock.moveAssets([AssetID(rawValue: "/t")], to: "/dest")
    }

    /// [P0] PhotoLibraryRepository has observeSourceChanges()
    func testPhotoLibraryRepositoryHasObserveSourceChanges() async throws {
        let mock = DITestMockPhotoLibraryRepository()
        let stream = mock.observeSourceChanges()
        // Stream should exist (empty in mock)
        XCTAssertNotNil(stream)
    }

    /// [P0] LLMProvider protocol exists with Sendable conformance
    func testLLMProviderProtocolExists() throws {
        let mock = DITestMockLLMProvider()
        XCTAssertNotNil(mock as LLMProvider)
    }

    /// [P1] LLMProvider has name property
    func testLLMProviderHasNameProperty() throws {
        let mock = DITestMockLLMProvider()
        XCTAssertFalse(mock.name.isEmpty)
    }

    // MARK: - AC3: Mock Replacement (Testability)

    /// [P0] AppDependencies supports mock replacement for photoRepository
    func testAppDependenciesSupportsMockPhotoRepository() async throws {
        await MainActor.run {
            let dependencies = AppDependencies()
            let mockPhotoRepo = DITestMockPhotoLibraryRepository()
            dependencies.photoRepository = mockPhotoRepo

            XCTAssertTrue(dependencies.photoRepository is DITestMockPhotoLibraryRepository)
        }
    }

    /// [P0] AppDependencies supports mock replacement for llmProvider
    func testAppDependenciesSupportsMockLLMProvider() async throws {
        await MainActor.run {
            let dependencies = AppDependencies()
            let mockLLM = DITestMockLLMProvider()
            dependencies.llmProvider = mockLLM

            XCTAssertTrue(dependencies.llmProvider is DITestMockLLMProvider)
        }
    }

    /// [P0] registerMockRepository() works
    func testRegisterMockRepositoryWorks() async throws {
        await MainActor.run {
            let dependencies = AppDependencies()
            dependencies.registerMockRepository()
            XCTAssertNotNil(dependencies.photoRepository)
        }
    }

    // MARK: - registerTestRepository Tests

    /// [P0] registerTestRepository() creates a non-nil repository
    func testRegisterTestRepositoryCreatesNonNilRepository() async throws {
        await MainActor.run {
            let dependencies = AppDependencies()
            dependencies.registerTestRepository()
            XCTAssertNotNil(dependencies.photoRepository,
                "registerTestRepository() should register a non-nil repository")
        }
    }

    /// [P0] registerTestRepository() creates sample photos in temp directory
    func testRegisterTestRepositoryCreatesSamplePhotosInTempDirectory() async throws {
        await MainActor.run {
            let dependencies = AppDependencies()
            dependencies.registerTestRepository()

            // Verify the temp directory was created with sample photo files
            let tempDir = FileManager.default.temporaryDirectory
                .appendingPathComponent("CuratorTestPhotos", isDirectory: true)
            var isDir: ObjCBool = false
            XCTAssertTrue(FileManager.default.fileExists(atPath: tempDir.path, isDirectory: &isDir),
                "registerTestRepository() should create the CuratorTestPhotos temp directory")
            XCTAssertTrue(isDir.boolValue, "CuratorTestPhotos path should be a directory")

            // Verify sample photo files exist
            let expectedFiles = ["test_photo_1.jpg", "test_photo_2.png", "test_photo_3.jpg"]
            for fileName in expectedFiles {
                let fileURL = tempDir.appendingPathComponent(fileName)
                XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path),
                    "Sample photo file \(fileName) should exist in temp directory")
                let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path)
                let fileSize = attributes?[.size] as? UInt ?? 0
                XCTAssertGreaterThan(fileSize, 0,
                    "Sample photo file \(fileName) should have non-zero size")
            }
        }
    }

    // MARK: - registerMockRepository Tests

    /// [P0] registerMockRepository() creates a non-nil repository
    func testRegisterMockRepositoryCreatesNonNilRepository() async throws {
        await MainActor.run {
            let dependencies = AppDependencies()
            dependencies.registerMockRepository()
            XCTAssertNotNil(dependencies.photoRepository,
                "registerMockRepository() should register a non-nil repository")
        }
    }

    /// [P0] registerMockRepository() creates a MockPhotoLibraryRepository
    func testRegisterMockRepositoryCreatesCorrectType() async throws {
        await MainActor.run {
            let dependencies = AppDependencies()
            dependencies.registerMockRepository()
            XCTAssertTrue(dependencies.photoRepository is MockPhotoLibraryRepository,
                "registerMockRepository() should create a MockPhotoLibraryRepository")
        }
    }

    /// [P1] Replaced mock implementations preserve protocol behavior
    func testReplacedMockPhotoRepoIsCallable() async throws {
        let dependencies = await MainActor.run { AppDependencies() }
        await MainActor.run {
            dependencies.photoRepository = DITestMockPhotoLibraryRepository()
        }
        let optionalRepo = await MainActor.run { dependencies.photoRepository as? DITestMockPhotoLibraryRepository }
        let repo = try XCTUnwrap(optionalRepo)
        let result = try await repo.requestReadAccess()
        XCTAssertTrue(result)
    }
}

// MARK: - Mock Implementations for DI Testing

/// Mock PhotoLibraryRepository for DI testing with full protocol conformance.
private struct DITestMockPhotoLibraryRepository: PhotoLibraryRepository {
    func currentBasePath() async -> String? { nil }
    func requestReadAccess() async throws -> Bool { true }
    func requestWriteAccess() async throws -> Bool { true }
    func fetchAssets(predicate: PhotoPredicate, pageSize: Int, pageOffset: Int) async throws -> AssetPage {
        return AssetPage(assets: [], hasMore: false)
    }
    func fetchFullResolutionImage(for assetID: AssetID) async throws -> Data { Data() }
    func fetchThumbnail(for assetID: AssetID, size: CGSize) async throws -> Data { Data() }
    func metadata(for assetID: AssetID) async throws -> AssetMetadata {
        AssetMetadata(fileName: "mock.jpg", fileSize: nil, creationDate: nil, cameraModel: nil, imageWidth: nil, imageHeight: nil, gpsLocation: nil, fileFormat: nil)
    }
    func updateAsset(_ assetID: AssetID, title: String?) async throws {}
    func deleteAssets(_ assetIDs: [AssetID]) async throws {}
    func moveAssets(_ assetIDs: [AssetID], to directory: String) async throws {}
    func observeSourceChanges() -> AsyncStream<SourceChange> { AsyncStream { _ in } }
}

private struct DITestMockLLMProvider: LLMProvider {
    let name: String = "MockLLM"
    func analyze(images: [Data], prompt: String, model: String) async throws -> LLMResponse {
        return LLMResponse(text: "mock analysis result", modelID: model, providerName: name, inputTokens: 0, outputTokens: 0)
    }
    func estimateCost(imageCount: Int, model: String) -> CostEstimate {
        return CostEstimate(estimatedTokens: 0, estimatedCost: 0.0, modelID: model, providerName: name, estimatedAPICalls: 1, currency: "USD")
    }
}
