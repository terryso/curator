import XCTest
@testable import Curator

/// ATDD Tests for Story 1.5 - First Launch Onboarding Flow
///
/// Tests verify:
/// - OnboardingStep enum defines all 6 steps (welcome, privacy, folderSelection, scanning, complete, noFolder)
/// - OnboardingViewModel manages currentStep state transitions correctly
/// - Forward navigation: welcome -> privacy -> folderSelection -> (folder pick) -> scanning -> complete
/// - Backward navigation: privacy -> welcome, folderSelection -> privacy
/// - Folder selection success path: requestPhotoPermission succeeds -> scanLibrary -> complete with photo count
/// - Folder selection cancelled path: requestPhotoPermission fails -> noFolder state
/// - noFolder state provides retry action and "continue restricted" fallback
/// - isOnboardingComplete flag transitions from false to true on completion
/// - OnboardingViewModel accepts optional PhotoLibraryRepository via init injection
/// - MockOnboardingRepository exercises all paths (grant, deny, scan with assets, empty library)
///
/// All tests use MockOnboardingRepository (no real file system calls).
final class OnboardingViewModelTests: XCTestCase {

    // MARK: - Test Helpers

    private func makeGrantingRepository(
        assetCount: Int = 10,
        hasMore: Bool = false
    ) -> MockOnboardingRepository {
        MockOnboardingRepository(
            shouldGrantPermission: true,
            assets: (0..<assetCount).map { makePhotoAsset(id: "onboard-asset-\($0)") },
            hasMore: hasMore
        )
    }

    private func makeDenyingRepository() -> MockOnboardingRepository {
        MockOnboardingRepository(
            shouldGrantPermission: false,
            assets: [],
            hasMore: false
        )
    }

    private func makePhotoAsset(
        id: String = "/Users/mock/Photos/test-\(UUID().uuidString).jpg",
        creationDate: Date? = Date(),
        fileName: String = "test.jpg",
        latitude: Double? = nil,
        longitude: Double? = nil,
        thumbnailData: Data? = nil
    ) -> PhotoAsset {
        let location: LocationData? = if let lat = latitude, let lon = longitude {
            LocationData(latitude: lat, longitude: lon)
        } else {
            nil
        }
        let metadata = AssetMetadata(
            fileName: fileName,
            fileSize: nil,
            creationDate: creationDate,
            cameraModel: nil,
            imageWidth: nil,
            imageHeight: nil,
            gpsLocation: location,
            fileFormat: .jpeg
        )
        return PhotoAsset(
            id: AssetID(rawValue: id),
            metadata: metadata,
            thumbnailData: thumbnailData
        )
    }

    // MARK: - AC1: OnboardingStep Enum

    /// [P0] OnboardingStep enum has all 6 required cases
    @MainActor
    func testOnboardingStepEnumHasAllCases() async throws {
        let allSteps = OnboardingStep.allCases
        XCTAssertEqual(allSteps.count, 6, "OnboardingStep should have exactly 6 cases")

        let _: OnboardingStep = .welcome
        let _: OnboardingStep = .privacy
        let _: OnboardingStep = .folderSelection
        let _: OnboardingStep = .scanning
        let _: OnboardingStep = .complete
        let _: OnboardingStep = .noFolder
    }

    /// [P1] OnboardingStep is Int-backed with correct rawValues
    @MainActor
    func testOnboardingStepRawValues() async throws {
        XCTAssertEqual(OnboardingStep.welcome.rawValue, 0)
        XCTAssertEqual(OnboardingStep.privacy.rawValue, 1)
        XCTAssertEqual(OnboardingStep.folderSelection.rawValue, 2)
        XCTAssertEqual(OnboardingStep.scanning.rawValue, 3)
        XCTAssertEqual(OnboardingStep.complete.rawValue, 4)
        XCTAssertEqual(OnboardingStep.noFolder.rawValue, 5)
    }

    // MARK: - AC1: ViewModel Initialization

    /// [P0] OnboardingViewModel exists as @MainActor ObservableObject
    @MainActor
    func testOnboardingViewModelExists() async throws {
        let repository = MockOnboardingRepository()
        let viewModel = OnboardingViewModel(repository: repository)
        XCTAssertNotNil(viewModel)
    }

    /// [P0] OnboardingViewModel initializes with currentStep = .welcome
    @MainActor
    func testViewModelInitializesWithWelcomeStep() async throws {
        let repository = MockOnboardingRepository()
        let viewModel = OnboardingViewModel(repository: repository)

        XCTAssertEqual(viewModel.currentStep, .welcome,
            "ViewModel should start at welcome step")
    }

    /// [P0] OnboardingViewModel initializes with isOnboardingComplete = false
    @MainActor
    func testViewModelInitializesWithOnboardingIncomplete() async throws {
        let repository = MockOnboardingRepository()
        let viewModel = OnboardingViewModel(repository: repository)

        XCTAssertFalse(viewModel.isOnboardingComplete,
            "Onboarding should not be complete on init")
    }

    // MARK: - AC1: Forward Navigation (3 screens)

    /// [P0] goToNextStep from welcome goes to privacy
    @MainActor
    func testGoToNextStepFromWelcomeGoesToPrivacy() async throws {
        let repository = MockOnboardingRepository()
        let viewModel = OnboardingViewModel(repository: repository)
        XCTAssertEqual(viewModel.currentStep, .welcome)

        viewModel.goToNextStep()

        XCTAssertEqual(viewModel.currentStep, .privacy,
            "Next step from welcome should be privacy")
    }

    /// [P0] goToNextStep from privacy goes to folderSelection
    @MainActor
    func testGoToNextStepFromPrivacyGoesToFolderSelection() async throws {
        let repository = MockOnboardingRepository()
        let viewModel = OnboardingViewModel(repository: repository)

        viewModel.goToNextStep() // welcome -> privacy
        viewModel.goToNextStep() // privacy -> folderSelection

        XCTAssertEqual(viewModel.currentStep, .folderSelection,
            "Next step from privacy should be folderSelection")
    }

    /// [P0] goToNextStep from folderSelection triggers selectPhotoFolder
    @MainActor
    func testGoToNextStepFromFolderSelectionTriggersSelection() async throws {
        let repository = makeGrantingRepository(assetCount: 5)
        let viewModel = OnboardingViewModel(repository: repository)

        viewModel.goToNextStep() // welcome -> privacy
        viewModel.goToNextStep() // privacy -> folderSelection
        viewModel.goToNextStep() // folderSelection -> triggers selectPhotoFolder (async)

        // selectPhotoFolder dispatches a Task; yield to let it execute
        try await Task.sleep(for: .milliseconds(200))

        XCTAssertNotEqual(viewModel.currentStep, .folderSelection,
            "After next from folderSelection, should have started folder pick")
    }

    // MARK: - AC1: Backward Navigation

    /// [P0] goToPreviousStep from privacy goes back to welcome
    @MainActor
    func testGoToPreviousStepFromPrivacyGoesToWelcome() async throws {
        let repository = MockOnboardingRepository()
        let viewModel = OnboardingViewModel(repository: repository)

        viewModel.goToNextStep() // welcome -> privacy
        viewModel.goToPreviousStep() // privacy -> welcome

        XCTAssertEqual(viewModel.currentStep, .welcome,
            "Previous step from privacy should be welcome")
    }

    /// [P0] goToPreviousStep from folderSelection goes back to privacy
    @MainActor
    func testGoToPreviousStepFromFolderSelectionGoesToPrivacy() async throws {
        let repository = MockOnboardingRepository()
        let viewModel = OnboardingViewModel(repository: repository)

        viewModel.goToNextStep() // welcome -> privacy
        viewModel.goToNextStep() // privacy -> folderSelection
        viewModel.goToPreviousStep() // folderSelection -> privacy

        XCTAssertEqual(viewModel.currentStep, .privacy,
            "Previous step from folderSelection should be privacy")
    }

    /// [P1] goToPreviousStep at welcome stays at welcome (no-op)
    @MainActor
    func testGoToPreviousStepAtWelcomeIsNoOp() async throws {
        let repository = MockOnboardingRepository()
        let viewModel = OnboardingViewModel(repository: repository)

        viewModel.goToPreviousStep()

        XCTAssertEqual(viewModel.currentStep, .welcome,
            "Previous at welcome should stay at welcome")
    }

    /// [P1] canGoBack is true on privacy and folderSelection, false on welcome
    @MainActor
    func testCanGoBackIsTrueOnNavigableSteps() async throws {
        let repository = MockOnboardingRepository()
        let viewModel = OnboardingViewModel(repository: repository)

        XCTAssertFalse(viewModel.canGoBack, "Should not go back at welcome")

        viewModel.goToNextStep() // -> privacy
        XCTAssertTrue(viewModel.canGoBack, "Should be able to go back at privacy")

        viewModel.goToNextStep() // -> folderSelection
        XCTAssertTrue(viewModel.canGoBack, "Should be able to go back at folderSelection")
    }

    // MARK: - AC2: Folder Selection Success and Photo Scan

    /// [P0] Folder selection granted transitions to scanning
    @MainActor
    func testFolderSelectionGrantedTransitionsToScanning() async throws {
        let repository = makeGrantingRepository(assetCount: 100, hasMore: true)
        let viewModel = OnboardingViewModel(repository: repository)

        await viewModel.requestPhotoPermission()

        XCTAssertTrue(
            viewModel.currentStep == .scanning || viewModel.currentStep == .complete,
            "After folder selection grant, should be in scanning or complete state, got \(viewModel.currentStep)"
        )
    }

    /// [P0] Successful folder selection triggers scan and shows photo count summary
    @MainActor
    func testSuccessfulFolderSelectionShowsPhotoCountSummary() async throws {
        let repository = makeGrantingRepository(assetCount: 100, hasMore: true)
        let viewModel = OnboardingViewModel(repository: repository)

        await viewModel.requestPhotoPermission()

        XCTAssertEqual(viewModel.currentStep, .complete,
            "Should reach complete state after scanning")

        XCTAssertNotNil(viewModel.discoveredPhotoCount,
            "Should have discovered photo count after scanning")
        XCTAssertGreaterThan(viewModel.discoveredPhotoCount ?? 0, 0,
            "Photo count should be greater than 0")
    }

    /// [P1] Scan with empty folder shows zero count (UX-DR15)
    @MainActor
    func testScanWithEmptyFolderShowsZeroCount() async throws {
        let repository = makeGrantingRepository(assetCount: 0, hasMore: false)
        let viewModel = OnboardingViewModel(repository: repository)

        await viewModel.requestPhotoPermission()

        XCTAssertEqual(viewModel.currentStep, .complete,
            "Should still reach complete with empty folder")
        XCTAssertEqual(viewModel.discoveredPhotoCount, 0,
            "Photo count should be 0 for empty folder")
    }

    /// [P1] Scan with hasMore=true sets hasMorePhotos flag
    @MainActor
    func testScanWithMorePhotosShowsPlusIndicator() async throws {
        let repository = makeGrantingRepository(assetCount: 100, hasMore: true)
        let viewModel = OnboardingViewModel(repository: repository)

        await viewModel.requestPhotoPermission()

        XCTAssertEqual(viewModel.discoveredPhotoCount, 100)
        XCTAssertTrue(viewModel.hasMorePhotos,
            "hasMorePhotos should be true when folder has more")
    }

    // MARK: - AC3: Folder Selection Cancelled / No Folder

    /// [P0] Folder selection cancelled transitions to noFolder state
    @MainActor
    func testFolderSelectionCancelledTransitionsToNoFolderState() async throws {
        let repository = makeDenyingRepository()
        let viewModel = OnboardingViewModel(repository: repository)

        viewModel.goToNextStep() // welcome -> privacy
        viewModel.goToNextStep() // privacy -> folderSelection

        await viewModel.requestPhotoPermission()

        XCTAssertEqual(viewModel.currentStep, .noFolder,
            "Cancelled folder selection should transition to noFolder state")
    }

    /// [P0] noFolder state allows continuing with restricted functionality
    @MainActor
    func testNoFolderStateAllowsContinueRestricted() async throws {
        let repository = makeDenyingRepository()
        let viewModel = OnboardingViewModel(repository: repository)

        await viewModel.requestPhotoPermission()
        XCTAssertEqual(viewModel.currentStep, .noFolder)

        viewModel.continueWithRestrictedAccess()

        XCTAssertTrue(viewModel.isOnboardingComplete,
            "Continuing with restricted access should complete onboarding")
    }

    /// [P1] noFolder state provides retryFolderSelection action
    @MainActor
    func testNoFolderStateProvidesRetryAction() async throws {
        let repository = makeDenyingRepository()
        let viewModel = OnboardingViewModel(repository: repository)

        await viewModel.requestPhotoPermission()
        XCTAssertEqual(viewModel.currentStep, .noFolder)

        viewModel.retryFolderSelection()

        XCTAssertEqual(viewModel.currentStep, .folderSelection,
            "Retry should go back to folderSelection step")
    }

    // MARK: - Onboarding Completion

    /// [P0] Completing onboarding sets isOnboardingComplete to true
    @MainActor
    func testCompletingOnboardingSetsFlagToTrue() async throws {
        let repository = makeGrantingRepository(assetCount: 10)
        let viewModel = OnboardingViewModel(repository: repository)

        XCTAssertFalse(viewModel.isOnboardingComplete)

        await viewModel.requestPhotoPermission()
        XCTAssertEqual(viewModel.currentStep, .complete)

        viewModel.completeOnboarding()

        XCTAssertTrue(viewModel.isOnboardingComplete,
            "completeOnboarding should set isOnboardingComplete to true")
    }

    /// [P1] isOnboardingComplete is observable by SwiftUI views
    @MainActor
    func testIsOnboardingCompleteIsPublished() async throws {
        let repository = MockOnboardingRepository()
        let viewModel = OnboardingViewModel(repository: repository)

        let _ = viewModel.objectWillChange
        XCTAssertFalse(viewModel.isOnboardingComplete)
    }

    // MARK: - Repository Injection

    /// [P0] OnboardingViewModel accepts repository via init injection
    @MainActor
    func testViewModelAcceptsRepositoryInjection() async throws {
        let repository = MockOnboardingRepository()
        let viewModel = OnboardingViewModel(repository: repository)

        XCTAssertNotNil(viewModel)
    }

    /// [P0] OnboardingViewModel handles nil repository gracefully
    @MainActor
    func testViewModelHandlesNilRepository() async throws {
        let viewModel = OnboardingViewModel(repository: nil)

        XCTAssertNotNil(viewModel)
        XCTAssertEqual(viewModel.currentStep, .welcome)

        await viewModel.requestPhotoPermission()
        XCTAssertEqual(viewModel.currentStep, .noFolder,
            "Nil repository should result in noFolder state")
    }

    /// [P1] OnboardingViewModel uses injected repository for folder selection
    @MainActor
    func testViewModelUsesInjectedRepositoryForFolderSelection() async throws {
        let grantingRepo = makeGrantingRepository(assetCount: 5)
        let viewModel = OnboardingViewModel(repository: grantingRepo)

        await viewModel.requestPhotoPermission()

        XCTAssertNotEqual(viewModel.currentStep, .noFolder,
            "Should use granting repository, not deny")
    }

    // MARK: - Step Indicator Support

    /// [P1] currentStepIndex provides correct 0-based index for 3-step flow
    @MainActor
    func testCurrentStepIndexProvidesCorrectIndex() async throws {
        let repository = MockOnboardingRepository()
        let viewModel = OnboardingViewModel(repository: repository)

        XCTAssertEqual(viewModel.currentStepIndex, 0, "Welcome should be index 0")

        viewModel.goToNextStep() // -> privacy
        XCTAssertEqual(viewModel.currentStepIndex, 1, "Privacy should be index 1")

        viewModel.goToNextStep() // -> folderSelection
        XCTAssertEqual(viewModel.currentStepIndex, 2, "FolderSelection should be index 2")
    }

    /// [P1] totalOnboardingSteps returns 3
    @MainActor
    func testTotalOnboardingStepsIsThree() async throws {
        let repository = MockOnboardingRepository()
        let viewModel = OnboardingViewModel(repository: repository)

        XCTAssertEqual(viewModel.totalOnboardingSteps, 3,
            "Total user-facing onboarding steps should be 3")
    }
}

// MARK: - Mock Repository

/// Mock implementation of PhotoLibraryRepository for onboarding tests.
private struct MockOnboardingRepository: PhotoLibraryRepository {
    private let shouldGrantPermission: Bool
    private let assets: [PhotoAsset]
    private let hasMore: Bool

    init(
        shouldGrantPermission: Bool = true,
        assets: [PhotoAsset] = [],
        hasMore: Bool = false
    ) {
        self.shouldGrantPermission = shouldGrantPermission
        self.assets = assets
        self.hasMore = hasMore
    }

    func requestReadAccess() async throws -> Bool {
        return shouldGrantPermission
    }

    func requestWriteAccess() async throws -> Bool {
        return false
    }

    func fetchAssets(predicate: PhotoPredicate, pageSize: Int, pageOffset: Int) async throws -> AssetPage {
        let endIndex = min(pageOffset + pageSize, assets.count)
        let pageAssets = if pageOffset < assets.count {
            Array(assets[pageOffset..<endIndex])
        } else {
            [PhotoAsset]()
        }
        let stillHasMore = hasMore && endIndex < assets.count
        let nextOffset = stillHasMore ? endIndex : nil
        return AssetPage(assets: pageAssets, hasMore: stillHasMore || (hasMore && pageAssets.count == pageSize), nextOffset: nextOffset)
    }

    func fetchFullResolutionImage(for assetID: AssetID) async throws -> Data {
        return Data()
    }

    func fetchThumbnail(for assetID: AssetID, size: CGSize) async throws -> Data {
        return Data()
    }

    func updateAsset(_ assetID: AssetID, title: String?) async throws {}
    func deleteAssets(_ assetIDs: [AssetID]) async throws {}
    func moveAssets(_ assetIDs: [AssetID], to directory: String) async throws {}
    func observeSourceChanges() -> AsyncStream<SourceChange> { AsyncStream { _ in } }
}
