import SwiftUI

/// ViewModel for the first-launch onboarding flow.
///
/// Manages navigation through 3 onboarding screens (welcome, privacy, folderSelection),
/// handles folder selection via NSOpenPanel, and scans the photo library after access
/// is granted. Supports degradation to restricted mode when the user skips folder selection.
@MainActor
final class OnboardingViewModel: ObservableObject {
    @Published var currentStep: OnboardingStep = .welcome
    @Published var isOnboardingComplete: Bool = false
    @Published var discoveredPhotoCount: Int? = nil
    @Published var hasMorePhotos: Bool = false

    /// Number of user-facing onboarding steps (welcome, privacy, folderSelection).
    let totalOnboardingSteps: Int = 3

    /// Current step index for step indicator (0-based among user-facing steps).
    var currentStepIndex: Int {
        switch currentStep {
        case .welcome: return 0
        case .privacy: return 1
        case .folderSelection: return 2
        default: return 2
        }
    }

    /// Whether the user can navigate backward from the current step.
    var canGoBack: Bool {
        currentStep == .privacy || currentStep == .folderSelection
    }

    /// Repository for photo library access (injected for testability).
    private var repository: (any PhotoLibraryRepository)?

    init(repository: (any PhotoLibraryRepository)?) {
        self.repository = repository
    }

    /// Update the repository reference (called when DI registration completes).
    func updateRepository(_ repository: any PhotoLibraryRepository) {
        self.repository = repository
    }

    // MARK: - Navigation

    func goToNextStep() {
        switch currentStep {
        case .welcome:
            currentStep = .privacy
        case .privacy:
            currentStep = .folderSelection
        case .folderSelection:
            selectPhotoFolder()
        default:
            break
        }
    }

    func goToPreviousStep() {
        switch currentStep {
        case .privacy:
            currentStep = .welcome
        case .folderSelection:
            currentStep = .privacy
        default:
            break
        }
    }

    // MARK: - Folder Selection

    func selectPhotoFolder() {
        Task {
            await requestPhotoPermission()
        }
    }

    func retryFolderSelection() {
        currentStep = .folderSelection
    }

    // MARK: - Permission & Scanning

    func requestPhotoPermission() async {
        guard let repository = repository else {
            currentStep = .noFolder
            return
        }

        do {
            let granted = try await repository.requestReadAccess()
            if granted {
                currentStep = .scanning
                await scanLibrary(repository: repository)
            } else {
                currentStep = .noFolder
            }
        } catch {
            currentStep = .noFolder
        }
    }

    private func scanLibrary(repository: any PhotoLibraryRepository) async {
        do {
            let page = try await repository.fetchAssets(
                predicate: .all,
                pageSize: 100,
                pageOffset: 0
            )
            discoveredPhotoCount = page.assets.count
            hasMorePhotos = page.hasMore
            currentStep = .complete
        } catch {
            discoveredPhotoCount = 0
            hasMorePhotos = false
            currentStep = .complete
        }
    }

    func completeOnboarding() {
        isOnboardingComplete = true
    }

    func continueWithRestrictedAccess() {
        isOnboardingComplete = true
    }
}
