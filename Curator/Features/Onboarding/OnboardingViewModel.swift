import SwiftUI

/// ViewModel for the first-launch onboarding flow.
///
/// Manages navigation through onboarding steps (welcome, privacy, permission,
/// LLM config), handles photo permission requests, and scans the photo library
/// after permission is granted. Supports degradation to a restricted mode when
/// permission is denied.
@MainActor
final class OnboardingViewModel: ObservableObject {
    @Published var currentStep: OnboardingStep = .welcome
    @Published var isOnboardingComplete: Bool = false
    @Published var discoveredPhotoCount: Int? = nil
    @Published var hasMorePhotos: Bool = false

    /// LLM configuration fields.
    @Published var baseURL: String = LLMConfig.defaultBaseURL
    @Published var apiKey: String = ""
    @Published var modelID: String = LLMModelID.claudeSonnet.rawValue

    /// Number of user-facing onboarding steps (welcome, privacy, permission, llmConfig).
    let totalOnboardingSteps: Int = 4

    /// Current step index for step indicator (0-based among user-facing steps).
    var currentStepIndex: Int {
        switch currentStep {
        case .welcome: return 0
        case .privacy: return 1
        case .permission: return 2
        case .llmConfig: return 3
        default: return 3
        }
    }

    /// Whether the user can navigate backward from the current step.
    var canGoBack: Bool {
        currentStep == .privacy || currentStep == .permission || currentStep == .llmConfig
    }

    /// Whether the LLM config fields are valid.
    var isLLMConfigValid: Bool {
        let config = LLMConfig(baseURL: baseURL, apiKey: apiKey, modelID: modelID)
        return config.isConfigured
    }

    /// Repository for photo library access (injected for testability).
    private var repository: (any PhotoLibraryRepository)?

    init(repository: (any PhotoLibraryRepository)?) {
        self.repository = repository
    }

    /// Update the repository reference (called when PhotoKit registration completes).
    func updateRepository(_ repository: any PhotoLibraryRepository) {
        self.repository = repository
    }

    // MARK: - Navigation

    func goToNextStep() {
        switch currentStep {
        case .welcome:
            currentStep = .privacy
        case .privacy:
            currentStep = .permission
        case .permission:
            currentStep = .llmConfig
        case .llmConfig:
            saveLLMConfig()
            // After LLM config, request photo permission and scan.
            // If repository is not ready yet, scanning will handle it.
            requestPermissionAndScan()
        default:
            break
        }
    }

    func goToPreviousStep() {
        switch currentStep {
        case .privacy:
            currentStep = .welcome
        case .permission:
            currentStep = .privacy
        case .llmConfig:
            currentStep = .permission
        default:
            break
        }
    }

    // MARK: - LLM Config

    func saveLLMConfig() {
        let config = LLMConfig(baseURL: baseURL, apiKey: apiKey, modelID: modelID)
        config.save()
    }

    // MARK: - Permission & Scanning

    private func requestPermissionAndScan() {
        Task {
            await requestPhotoPermission()
        }
    }

    func requestPhotoPermission() async {
        guard let repository = repository else {
            currentStep = .denied
            return
        }

        do {
            let granted = try await repository.requestReadAccess()
            if granted {
                currentStep = .scanning
                await scanLibrary(repository: repository)
            } else {
                currentStep = .denied
            }
        } catch {
            currentStep = .denied
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

    // MARK: - Denied State

    func continueWithRestrictedAccess() {
        isOnboardingComplete = true
    }

    func openSystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Photos") {
            NSWorkspace.shared.open(url)
        }
    }
}
