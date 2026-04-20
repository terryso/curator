import SwiftUI

/// Main Settings window view with navigation sidebar.
///
/// Standard macOS Settings layout using NavigationSplitView:
/// left sidebar for category navigation, right detail area for content.
/// Follows Apple HIG for Settings windows.
struct SettingsView: View {
    @EnvironmentObject private var dependencies: AppDependencies
    @State private var selectedCategory: SettingsCategory = .provider
    @State private var viewModel: SettingsViewModel?

    var body: some View {
        NavigationSplitView {
            List(SettingsCategory.allCases, selection: $selectedCategory) { category in
                Label(category.displayName, systemImage: category.iconName)
                    .tag(category)
            }
            .navigationTitle("Settings")
            .listStyle(.sidebar)
        } detail: {
            Group {
                if let vm = viewModel {
                    switch selectedCategory {
                    case .provider:
                        APIKeyManagementView(viewModel: vm)
                    case .model:
                        ModelSelectionView(viewModel: vm)
                    case .costTracking:
                        CostTrackingSettingsView(viewModel: vm)
                    }
                } else {
                    ProgressView()
                        .onAppear {
                            Task {
                                let vm = SettingsViewModel(dependencies: dependencies)
                                await vm.loadCurrentConfig()
                                viewModel = vm
                            }
                        }
                }
            }
        }
        .frame(minWidth: 600, minHeight: 400)
    }
}

/// Settings sidebar categories.
enum SettingsCategory: String, CaseIterable, Identifiable {
    case provider
    case model
    case costTracking

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .provider: return String(localized: "Provider Config")
        case .model: return String(localized: "Model Selection")
        case .costTracking: return String(localized: "Cost Tracking")
        }
    }

    var iconName: String {
        switch self {
        case .provider: return "server.rack"
        case .model: return "cpu"
        case .costTracking: return "chart.line.uptrend.xyaxis"
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppDependencies())
}
