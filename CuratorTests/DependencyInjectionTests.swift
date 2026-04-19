import XCTest
@testable import Curator

/// ATDD Tests for Story 1.2 - AC3: 依赖注入容器
///
/// Tests verify:
/// - AppDependencies exists as @MainActor ObservableObject
/// - PhotoLibraryRepository protocol exists (Sendable)
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
        XCTAssertNotNil(dependencies,
            "AppDependencies should be instantiable on MainActor")
    }

    /// [P0] AppDependencies is a MainActor ObservableObject
    func testAppDependenciesIsObservableObject() async throws {
        let dependencies = await MainActor.run {
            AppDependencies()
        }

        // Verify ObservableObject conformance by accessing objectWillChange
        // (If this compiles, AppDependencies conforms to ObservableObject)
        let _ = dependencies.objectWillChange
    }

    /// [P0] AppDependencies has photoRepository property (optional protocol)
    func testAppDependenciesHasPhotoRepositoryProperty() async throws {
        await MainActor.run {
            let dependencies = AppDependencies()

            // Initially nil (no implementation registered yet)
            XCTAssertNil(dependencies.photoRepository,
                "photoRepository should be nil before registration")
        }
    }

    /// [P0] AppDependencies has llmProvider property (optional protocol)
    func testAppDependenciesHasLLMProviderProperty() async throws {
        await MainActor.run {
            let dependencies = AppDependencies()

            // Initially nil (no implementation registered yet)
            XCTAssertNil(dependencies.llmProvider,
                "llmProvider should be nil before registration")
        }
    }

    /// [P0] registerLLMGateway() creates gateway without stored config
    func testRegisterLLMGatewayCreatesGatewayWithoutConfig() async throws {
        await MainActor.run {
            let dependencies = AppDependencies()

            // When: Registering LLM gateway with no stored config
            dependencies.registerLLMGateway()

            // Then: Gateway is still created (with empty credentials)
            XCTAssertNotNil(dependencies.llmGateway,
                "llmGateway should be created even without stored config")
        }
    }

    // MARK: - AC3: Protocol Definitions

    /// [P0] PhotoLibraryRepository protocol exists with Sendable conformance
    func testPhotoLibraryRepositoryProtocolExists() async throws {
        let mock = MockPhotoLibraryRepository()
        XCTAssertNotNil(mock as PhotoLibraryRepository,
            "MockPhotoLibraryRepository should conform to PhotoLibraryRepository")
    }

    /// [P1] PhotoLibraryRepository has requestReadAccess() async throws -> Bool
    func testPhotoLibraryRepositoryHasRequestReadAccess() async throws {
        let mock = MockPhotoLibraryRepository()
        let result = try await mock.requestReadAccess()
        XCTAssertTrue(result,
            "PhotoLibraryRepository.requestReadAccess() should return Bool")
    }

    /// [P1] PhotoLibraryRepository has requestWriteAccess() async throws -> Bool
    func testPhotoLibraryRepositoryHasRequestWriteAccess() async throws {
        let mock = MockPhotoLibraryRepository()
        let result = try await mock.requestWriteAccess()
        XCTAssertTrue(result,
            "PhotoLibraryRepository.requestWriteAccess() should return Bool")
    }

    /// [P0] LLMProvider protocol exists with Sendable conformance
    func testLLMProviderProtocolExists() throws {
        let mock = MockLLMProvider()
        XCTAssertNotNil(mock as LLMProvider,
            "MockLLMProvider should conform to LLMProvider")
    }

    /// [P1] LLMProvider has name property
    func testLLMProviderHasNameProperty() throws {
        let mock = MockLLMProvider()
        XCTAssertFalse(mock.name.isEmpty,
            "LLMProvider.name should return a non-empty string")
    }

    // MARK: - AC3: Mock Replacement (Testability)

    /// [P0] AppDependencies supports mock replacement for photoRepository
    func testAppDependenciesSupportsMockPhotoRepository() async throws {
        await MainActor.run {
            let dependencies = AppDependencies()
            let mockPhotoRepo = MockPhotoLibraryRepository()
            dependencies.photoRepository = mockPhotoRepo

            XCTAssertTrue(dependencies.photoRepository is MockPhotoLibraryRepository,
                "photoRepository should be replaceable with a mock for testing")
        }
    }

    /// [P0] AppDependencies supports mock replacement for llmProvider
    func testAppDependenciesSupportsMockLLMProvider() async throws {
        await MainActor.run {
            let dependencies = AppDependencies()
            let mockLLM = MockLLMProvider()
            dependencies.llmProvider = mockLLM

            XCTAssertTrue(dependencies.llmProvider is MockLLMProvider,
                "llmProvider should be replaceable with a mock for testing")
        }
    }

    /// [P1] Replaced mock implementations preserve protocol behavior
    func testReplacedMockPhotoRepoIsCallable() async throws {
        let dependencies = await MainActor.run { AppDependencies() }
        await MainActor.run {
            dependencies.photoRepository = MockPhotoLibraryRepository()
        }
        let optionalRepo = await MainActor.run { dependencies.photoRepository as? MockPhotoLibraryRepository }
        let repo = try XCTUnwrap(optionalRepo,
            "Should be able to cast to mock for testing"
        )
        let result = try await repo.requestReadAccess()
        XCTAssertTrue(result,
            "Mock implementation should be callable through the protocol")
    }
}

// MARK: - Mock Implementations for Testing

/// Mock PhotoLibraryRepository for testing dependency injection.
/// Implements all required protocol methods with stub responses.
private struct MockPhotoLibraryRepository: PhotoLibraryRepository {
    func requestReadAccess() async throws -> Bool {
        return true
    }

    func requestWriteAccess() async throws -> Bool {
        return true
    }

    func fetchAssets(predicate: PhotoPredicate, pageSize: Int, pageOffset: Int = 0) async throws -> AssetPage {
        return AssetPage(assets: [], hasMore: false)
    }

    func fetchFullResolutionImage(for assetID: AssetID) async throws -> Data {
        return Data()
    }

    func fetchThumbnail(for assetID: AssetID, size: CGSize) async throws -> Data {
        return Data()
    }
}
/// Implements all required protocol methods with stub responses.
private struct MockLLMProvider: LLMProvider {
    let name: String = "MockLLM"

    func analyze(images: [Data], prompt: String, model: String) async throws -> LLMResponse {
        return LLMResponse(text: "mock analysis result", modelID: model, providerName: name, inputTokens: 0, outputTokens: 0)
    }

    func estimateCost(imageCount: Int, model: String) -> CostEstimate {
        return CostEstimate(estimatedTokens: 0, estimatedCost: 0.0, modelID: model, providerName: name)
    }
}
