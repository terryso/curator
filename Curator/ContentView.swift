import SwiftUI

/// Main content view for the Curator application.
///
/// Serves as the container for the photo library grid view.
/// Initializes AppDependencies and injects the PhotoLibraryViewModel.
/// Observes repository changes so the ViewModel gets updated once registered.
struct ContentView: View {
    @StateObject private var dependencies = AppDependencies()
    @StateObject private var viewModel: PhotoLibraryViewModel

    init() {
        let deps = AppDependencies()
        _dependencies = StateObject(wrappedValue: deps)
        _viewModel = StateObject(wrappedValue: PhotoLibraryViewModel(repository: deps.photoRepository))
    }

    /// Separate init for preview/testing with pre-created dependencies.
    init(dependencies: AppDependencies) {
        _dependencies = StateObject(wrappedValue: dependencies)
        _viewModel = StateObject(wrappedValue: PhotoLibraryViewModel(repository: dependencies.photoRepository))
    }

    var body: some View {
        PhotoGridView(viewModel: viewModel)
            .frame(minWidth: 800, minHeight: 600)
            .task {
                dependencies.registerPhotoKitRepository()
            }
            .onChange(of: dependencies.photoRepository != nil) { _, hasRepo in
                if hasRepo, let repo = dependencies.photoRepository {
                    viewModel.updateRepository(repo)
                }
            }
    }
}

#Preview {
    ContentView()
}
