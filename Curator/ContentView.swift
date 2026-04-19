import SwiftUI

/// Main content view for the Curator application.
///
/// Checks whether the user has completed the first-launch onboarding flow.
/// If not, displays OnboardingContainerView; otherwise displays MainWorkspaceView
/// which provides the full Agent workspace with photo library sidebar.
/// Uses @AppStorage to persist the onboarding completion state.
struct ContentView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @StateObject private var dependencies = AppDependencies()
    @StateObject private var viewModel: PhotoLibraryViewModel
    @StateObject private var onboardingViewModel: OnboardingViewModel
    @StateObject private var navigationModel = NavigationModel()

    init() {
        let deps = AppDependencies()
        _dependencies = StateObject(wrappedValue: deps)
        _viewModel = StateObject(wrappedValue: PhotoLibraryViewModel(repository: deps.photoRepository))
        _onboardingViewModel = StateObject(wrappedValue: OnboardingViewModel(repository: deps.photoRepository))
    }

    /// Separate init for preview/testing with pre-created dependencies.
    init(dependencies: AppDependencies) {
        _dependencies = StateObject(wrappedValue: dependencies)
        _viewModel = StateObject(wrappedValue: PhotoLibraryViewModel(repository: dependencies.photoRepository))
        _onboardingViewModel = StateObject(wrappedValue: OnboardingViewModel(repository: dependencies.photoRepository))
    }

    var body: some View {
        if hasCompletedOnboarding {
            MainWorkspaceView(
                photoViewModel: viewModel,
                dependencies: dependencies,
                navigationModel: navigationModel
            )
            .frame(minWidth: 900, minHeight: 600)
            .task {
                if CommandLine.arguments.contains("--uitest-mock-photos") {
                    dependencies.registerMockRepository()
                } else {
                    dependencies.registerPhotoKitRepository()
                }
                dependencies.registerLLMGateway()
            }
            .onChange(of: dependencies.photoRepository != nil) { _, hasRepo in
                if hasRepo, let repo = dependencies.photoRepository {
                    viewModel.updateRepository(repo)
                }
            }
        } else {
            OnboardingContainerView(viewModel: onboardingViewModel)
                .frame(minWidth: 900, minHeight: 600)
                .task {
                    if CommandLine.arguments.contains("--uitest-mock-photos") {
                        dependencies.registerMockRepository()
                    } else {
                        dependencies.registerPhotoKitRepository()
                    }
                }
                .onChange(of: dependencies.photoRepository != nil) { _, hasRepo in
                    if hasRepo, let repo = dependencies.photoRepository {
                        onboardingViewModel.updateRepository(repo)
                    }
                }
        }
    }
}

#Preview {
    ContentView()
}
