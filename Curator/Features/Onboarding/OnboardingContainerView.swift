import SwiftUI

/// Container view for the first-launch onboarding flow.
///
/// Displays the appropriate sub-view based on the ViewModel's current step.
/// Includes a step indicator (dots) showing progress through the 3 main
/// onboarding screens. Sets @AppStorage("hasCompletedOnboarding") on completion.
struct OnboardingContainerView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var isRequestingPermission = false

    var body: some View {
        ZStack {
            // Step content
            switch viewModel.currentStep {
            case .welcome:
                WelcomeView(onNext: { viewModel.goToNextStep() })

            case .privacy:
                PrivacyExplanationView(
                    onNext: { viewModel.goToNextStep() },
                    onBack: { viewModel.goToPreviousStep() }
                )

            case .permission:
                PermissionRequestView(
                    isRequesting: isRequestingPermission,
                    onRequestPermission: { requestPermission() },
                    onBack: { viewModel.goToPreviousStep() }
                )

            case .scanning:
                LibraryScanView(
                    isScanning: true,
                    discoveredCount: nil,
                    hasMore: false,
                    onStart: {}
                )

            case .complete:
                LibraryScanView(
                    isScanning: false,
                    discoveredCount: viewModel.discoveredPhotoCount,
                    hasMore: viewModel.hasMorePhotos,
                    onStart: { finishOnboarding() }
                )

            case .denied:
                PermissionDeniedView(
                    onOpenSettings: { viewModel.openSystemSettings() },
                    onContinueRestricted: { finishOnboarding() }
                )
            }

            // Step indicator overlay (only for the 3 main steps)
            if showStepIndicator {
                VStack {
                    Spacer()
                    stepIndicator
                        .padding(.bottom, 16)
                }
            }
        }
        .frame(minWidth: 600, minHeight: 500)
        .animation(.easeInOut(duration: 0.25), value: viewModel.currentStep)
    }

    // MARK: - Step Indicator

    /// Whether to show the step indicator dots.
    private var showStepIndicator: Bool {
        switch viewModel.currentStep {
        case .welcome, .privacy, .permission:
            return true
        default:
            return false
        }
    }

    /// Three-dot step indicator showing current position.
    private var stepIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<viewModel.totalOnboardingSteps, id: \.self) { index in
                Circle()
                    .fill(index == viewModel.currentStepIndex
                          ? Color.accentColor
                          : Color.secondary.opacity(0.3))
                    .frame(width: 8, height: 8)
                    .accessibilityLabel("Step \(index + 1) of \(viewModel.totalOnboardingSteps)")
                    .accessibilityHidden(index != viewModel.currentStepIndex)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Step \(viewModel.currentStepIndex + 1) of \(viewModel.totalOnboardingSteps)")
    }

    // MARK: - Actions

    private func requestPermission() {
        isRequestingPermission = true
        Task {
            await viewModel.requestPhotoPermission()
            isRequestingPermission = false
        }
    }

    private func finishOnboarding() {
        viewModel.completeOnboarding()
        withAnimation {
            hasCompletedOnboarding = true
        }
    }
}

#Preview("OnboardingContainerView - Welcome") {
    OnboardingContainerView(
        viewModel: OnboardingViewModel(repository: nil)
    )
    .frame(width: 600, height: 500)
}

#Preview("OnboardingContainerView - Dark") {
    OnboardingContainerView(
        viewModel: OnboardingViewModel(repository: nil)
    )
    .frame(width: 600, height: 500)
    .preferredColorScheme(.dark)
}
