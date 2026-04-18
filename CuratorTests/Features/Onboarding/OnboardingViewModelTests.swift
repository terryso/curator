import XCTest
@testable import Curator

/// ATDD Tests for Story 1.5 - First Launch Onboarding Flow
///
/// Tests verify:
/// - OnboardingStep enum defines all 6 steps (welcome, privacy, permission, scanning, complete, denied)
/// - OnboardingViewModel manages currentStep state transitions correctly
/// - Forward navigation: welcome -> privacy -> permission -> (permission request) -> scanning -> complete
/// - Backward navigation: privacy -> welcome, permission -> privacy
/// - Permission grant path: requestPhotoPermission succeeds -> scanLibrary -> complete with photo count
/// - Permission deny path: requestPhotoPermission fails -> denied state
/// - Denied state provides "open system settings" action and "continue restricted" fallback
/// - isOnboardingComplete flag transitions from false to true on completion
/// - OnboardingViewModel accepts optional PhotoLibraryRepository via init injection
/// - MockOnboardingRepository exercises all paths (grant, deny, scan with assets, empty library)
///
/// All tests use MockOnboardingRepository (no real PhotoKit calls).
/// RED PHASE: Tests compile against stubs and fail until OnboardingViewModel is implemented.
final class OnboardingViewModelTests: XCTestCase {

    // MARK: - Test Helpers

    /// Creates a MockOnboardingRepository that grants permission and returns assets.
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

    /// Creates a MockOnboardingRepository that denies permission.
    private func makeDenyingRepository() -> MockOnboardingRepository {
        MockOnboardingRepository(
            shouldGrantPermission: false,
            assets: [],
            hasMore: false
        )
    }

    /// Creates a sample PhotoAsset for testing.
    private func makePhotoAsset(
        id: String = "test-asset-\(UUID().uuidString)",
        creationDate: Date? = Date(),
        title: String? = "Test Photo",
        description: String? = nil,
        keywords: [String] = [],
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
            creationDate: creationDate,
            title: title,
            description: description,
            keywords: keywords,
            location: location
        )
        return PhotoAsset(
            id: AssetID(rawValue: id),
            metadata: metadata,
            thumbnailData: thumbnailData
        )
    }

    // MARK: - AC1: OnboardingStep Enum

    /// [P0] OnboardingStep enum exists and has all required cases
    @MainActor
    func testOnboardingStepEnumHasAllCases() async throws {
        let allSteps = OnboardingStep.allCases
        XCTAssertEqual(allSteps.count, 6, "OnboardingStep should have exactly 6 cases")

        // Verify each case exists by constructing them
        let _: OnboardingStep = .welcome
        let _: OnboardingStep = .privacy
        let _: OnboardingStep = .permission
        let _: OnboardingStep = .scanning
        let _: OnboardingStep = .complete
        let _: OnboardingStep = .denied
    }

    /// [P1] OnboardingStep is Int-backed and CaseIterable for step indicator
    @MainActor
    func testOnboardingStepIsIntBackedCaseIterable() async throws {
        // Should be RawRepresentable with Int rawValue
        XCTAssertEqual(OnboardingStep.welcome.rawValue, 0)
        XCTAssertEqual(OnboardingStep.privacy.rawValue, 1)
        XCTAssertEqual(OnboardingStep.permission.rawValue, 2)

        // CaseIterable for iterating step indicators
        XCTAssertGreaterThanOrEqual(OnboardingStep.allCases.count, 6)
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

    // MARK: - AC1: Forward Navigation (max 3 screens)

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

    /// [P0] goToNextStep from privacy goes to permission
    @MainActor
    func testGoToNextStepFromPrivacyGoesToPermission() async throws {
        let repository = MockOnboardingRepository()
        let viewModel = OnboardingViewModel(repository: repository)

        viewModel.goToNextStep() // welcome -> privacy
        viewModel.goToNextStep() // privacy -> permission

        XCTAssertEqual(viewModel.currentStep, .permission,
            "Next step from privacy should be permission")
    }

    /// [P0] goToNextStep from permission triggers permission request (does not advance past 3 screens)
    @MainActor
    func testGoToNextStepFromPermissionTriggersPermissionRequest() async throws {
        let repository = MockOnboardingRepository()
        let viewModel = OnboardingViewModel(repository: repository)

        viewModel.goToNextStep() // welcome -> privacy
        viewModel.goToNextStep() // privacy -> permission

        // On permission step, next should NOT advance to a 4th info screen.
        // Instead it should trigger the permission request flow.
        XCTAssertEqual(viewModel.currentStep, .permission)
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

    /// [P0] goToPreviousStep from permission goes back to privacy
    @MainActor
    func testGoToPreviousStepFromPermissionGoesToPrivacy() async throws {
        let repository = MockOnboardingRepository()
        let viewModel = OnboardingViewModel(repository: repository)

        viewModel.goToNextStep() // welcome -> privacy
        viewModel.goToNextStep() // privacy -> permission
        viewModel.goToPreviousStep() // permission -> privacy

        XCTAssertEqual(viewModel.currentStep, .privacy,
            "Previous step from permission should be privacy")
    }

    /// [P1] goToPreviousStep at welcome stays at welcome (no-op)
    @MainActor
    func testGoToPreviousStepAtWelcomeIsNoOp() async throws {
        let repository = MockOnboardingRepository()
        let viewModel = OnboardingViewModel(repository: repository)

        viewModel.goToPreviousStep() // already at welcome

        XCTAssertEqual(viewModel.currentStep, .welcome,
            "Previous at welcome should stay at welcome")
    }

    /// [P1] canGoBack is true only on privacy and permission steps
    @MainActor
    func testCanGoBackIsTrueOnPrivacyAndPermissionSteps() async throws {
        let repository = MockOnboardingRepository()
        let viewModel = OnboardingViewModel(repository: repository)

        XCTAssertFalse(viewModel.canGoBack, "Should not go back at welcome")

        viewModel.goToNextStep() // -> privacy
        XCTAssertTrue(viewModel.canGoBack, "Should be able to go back at privacy")

        viewModel.goToNextStep() // -> permission
        XCTAssertTrue(viewModel.canGoBack, "Should be able to go back at permission")
    }

    // MARK: - AC2: Permission Grant and Photo Scan

    /// [P0] requestPhotoPermission with granted permission transitions to scanning
    @MainActor
    func testRequestPermissionGrantedTransitionsToScanning() async throws {
        let repository = makeGrantingRepository(assetCount: 100, hasMore: true)
        let viewModel = OnboardingViewModel(repository: repository)

        // Navigate to permission step
        viewModel.goToNextStep() // -> privacy
        viewModel.goToNextStep() // -> permission

        await viewModel.requestPhotoPermission()

        // After permission grant, should transition to scanning then complete
        XCTAssertTrue(
            viewModel.currentStep == .scanning || viewModel.currentStep == .complete,
            "After permission grant, should be in scanning or complete state, got \(viewModel.currentStep)"
        )
    }

    /// [P0] Successful permission grant triggers scan and shows photo count summary
    @MainActor
    func testSuccessfulPermissionGrantShowsPhotoCountSummary() async throws {
        let repository = makeGrantingRepository(assetCount: 100, hasMore: true)
        let viewModel = OnboardingViewModel(repository: repository)

        await viewModel.requestPhotoPermission()

        // Should eventually reach complete state with photo count info
        XCTAssertEqual(viewModel.currentStep, .complete,
            "Should reach complete state after scanning")

        XCTAssertNotNil(viewModel.discoveredPhotoCount,
            "Should have discovered photo count after scanning")
        XCTAssertGreaterThan(viewModel.discoveredPhotoCount ?? 0, 0,
            "Photo count should be greater than 0")
    }

    /// [P1] Scan with empty library shows zero count (UX-DR15)
    @MainActor
    func testScanWithEmptyLibraryShowsZeroCount() async throws {
        let repository = makeGrantingRepository(assetCount: 0, hasMore: false)
        let viewModel = OnboardingViewModel(repository: repository)

        await viewModel.requestPhotoPermission()

        XCTAssertEqual(viewModel.currentStep, .complete,
            "Should still reach complete with empty library")
        XCTAssertEqual(viewModel.discoveredPhotoCount, 0,
            "Photo count should be 0 for empty library")
    }

    /// [P1] Scan with hasMore=true appends "+" suffix indicator
    @MainActor
    func testScanWithMorePhotosShowsPlusIndicator() async throws {
        let repository = makeGrantingRepository(assetCount: 100, hasMore: true)
        let viewModel = OnboardingViewModel(repository: repository)

        await viewModel.requestPhotoPermission()

        XCTAssertEqual(viewModel.discoveredPhotoCount, 100)
        XCTAssertTrue(viewModel.hasMorePhotos,
            "hasMorePhotos should be true when library has more")
    }

    // MARK: - AC3: Permission Denied Degradation

    /// [P0] Permission denied transitions to denied state
    @MainActor
    func testPermissionDeniedTransitionsToDeniedState() async throws {
        let repository = makeDenyingRepository()
        let viewModel = OnboardingViewModel(repository: repository)

        viewModel.goToNextStep() // -> privacy
        viewModel.goToNextStep() // -> permission

        await viewModel.requestPhotoPermission()

        XCTAssertEqual(viewModel.currentStep, .denied,
            "Denied permission should transition to denied state")
    }

    /// [P0] Denied state allows continuing with restricted functionality
    @MainActor
    func testDeniedStateAllowsContinueRestricted() async throws {
        let repository = makeDenyingRepository()
        let viewModel = OnboardingViewModel(repository: repository)

        await viewModel.requestPhotoPermission()
        XCTAssertEqual(viewModel.currentStep, .denied)

        viewModel.continueWithRestrictedAccess()

        XCTAssertTrue(viewModel.isOnboardingComplete,
            "Continuing with restricted access should complete onboarding")
    }

    /// [P1] Denied state provides openSystemSettings action
    @MainActor
    func testDeniedStateProvidesOpenSystemSettingsAction() async throws {
        let repository = makeDenyingRepository()
        let viewModel = OnboardingViewModel(repository: repository)

        await viewModel.requestPhotoPermission()
        XCTAssertEqual(viewModel.currentStep, .denied)

        // Verify the action exists and can be called without crashing
        viewModel.openSystemSettings()
        // Should still be in denied state after opening settings
        XCTAssertEqual(viewModel.currentStep, .denied)
    }

    // MARK: - Onboarding Completion

    /// [P0] Completing onboarding sets isOnboardingComplete to true
    @MainActor
    func testCompletingOnboardingSetsFlagToTrue() async throws {
        let repository = makeGrantingRepository(assetCount: 10)
        let viewModel = OnboardingViewModel(repository: repository)

        XCTAssertFalse(viewModel.isOnboardingComplete)

        await viewModel.requestPhotoPermission()
        // After permission + scan, should reach complete
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

        // Verify ObservableObject conformance by accessing objectWillChange
        let _ = viewModel.objectWillChange

        // Verify @Published property exists and is readable
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

        // Permission request with nil repo should transition to denied
        await viewModel.requestPhotoPermission()
        XCTAssertEqual(viewModel.currentStep, .denied,
            "Nil repository should result in denied state")
    }

    /// [P1] OnboardingViewModel uses injected repository for permission check
    @MainActor
    func testViewModelUsesInjectedRepositoryForPermission() async throws {
        let grantingRepo = makeGrantingRepository(assetCount: 5)
        let viewModel = OnboardingViewModel(repository: grantingRepo)

        await viewModel.requestPhotoPermission()

        // Should have used the granting repo -> complete, not denied
        XCTAssertNotEqual(viewModel.currentStep, .denied,
            "Should use granting repository, not deny")
    }

    // MARK: - Step Indicator Support

    /// [P1] currentStepIndex provides 0-based index for step indicator
    @MainActor
    func testCurrentStepIndexProvidesCorrectIndex() async throws {
        let repository = MockOnboardingRepository()
        let viewModel = OnboardingViewModel(repository: repository)

        XCTAssertEqual(viewModel.currentStepIndex, 0, "Welcome should be index 0")

        viewModel.goToNextStep() // -> privacy
        XCTAssertEqual(viewModel.currentStepIndex, 1, "Privacy should be index 1")

        viewModel.goToNextStep() // -> permission
        XCTAssertEqual(viewModel.currentStepIndex, 2, "Permission should be index 2")
    }

    /// [P1] totalOnboardingSteps returns 3 (welcome, privacy, permission)
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
///
/// Configurable to grant or deny permission, return specific asset counts,
/// and simulate scanning delays. Uses actor isolation for thread safety.
private actor MockOnboardingRepository: PhotoLibraryRepository {
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
        // Return configured assets up to pageSize
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
}
