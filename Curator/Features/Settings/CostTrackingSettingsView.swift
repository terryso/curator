import SwiftUI

/// Cost tracking settings view showing monthly cost summary.
///
/// Displays the current month's accumulated cost from CostTracker.
/// Acts as an entry point for the full cost tracking panel (Story 2.6).
struct CostTrackingSettingsView: View {
    let viewModel: SettingsViewModel

    var body: some View {
        costContent(vm: viewModel)
    }

    private func costContent(vm: SettingsViewModel) -> some View {
        Form {
            Section {
                if let summary = vm.monthlyCostSummary {
                    HStack {
                        Text("This Month")
                            .font(.headline)
                        Spacer()
                        Text(String(format: "$%.4f", summary.totalCost))
                            .font(.title2)
                            .fontWeight(.semibold)
                    }

                    LabeledContent("Total Calls", value: "\(summary.callCount)")
                    LabeledContent("Input Tokens", value: formatNumber(summary.totalInputTokens))
                    LabeledContent("Output Tokens", value: formatNumber(summary.totalOutputTokens))

                    if !summary.byProvider.isEmpty {
                        Divider()
                        ForEach(Array(summary.byProvider.sorted(by: { $0.key < $1.key })), id: \.key) { provider, cost in
                            LabeledContent(provider, value: String(format: "$%.4f", cost))
                        }
                    }
                } else {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: "tray")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                            Text("No cost data available")
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 20)
                }
            } header: {
                Text("Monthly Summary")
            }

            Section {
                HStack {
                    Spacer()
                    Button("Refresh") {
                        Task { await vm.loadMonthlyCostSummary() }
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Helpers

    private func formatNumber(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}

#Preview {
    CostTrackingSettingsView(viewModel: SettingsViewModel(dependencies: AppDependencies()))
}
