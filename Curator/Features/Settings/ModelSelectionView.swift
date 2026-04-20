import SwiftUI

/// Model selection view displaying available LLM models with pricing.
///
/// Shows all models from LLMModelID.allCases with input/output pricing
/// per million tokens. The selected model is bound to SettingsViewModel.
struct ModelSelectionView: View {
    let viewModel: SettingsViewModel

    var body: some View {
        modelList(vm: viewModel)
    }

    private func modelList(vm: SettingsViewModel) -> some View {
        Form {
            Section {
                Picker("Default Model", selection: binding(for: \.primaryModelID, in: vm)) {
                    ForEach(LLMModelID.allCases, id: \.rawValue) { model in
                        Text(model.rawValue).tag(model.rawValue)
                    }
                }
            } header: {
                Text("Default Model")
            }

            Section {
                HStack {
                    Spacer()
                    Button("Save") {
                        vm.saveConfig()
                    }
                    .buttonStyle(.borderedProminent)
                    Button("Reset") {
                        Task { await vm.loadCurrentConfig() }
                    }
                    .buttonStyle(.bordered)
                }
            }

            Section {
                ForEach(LLMModelID.allCases, id: \.self) { model in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(model.rawValue)
                                .font(.body)
                            Text(providerLabel(for: model))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text(String(format: "In: $%.2f/M", model.inputPricePerMillionTokens))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(String(format: "Out: $%.2f/M", model.outputPricePerMillionTokens))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 2)
                }
            } header: {
                Text("Available Models & Pricing")
            } footer: {
                Text("Prices shown per 1 million tokens (USD)")
                    .font(.caption2)
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Helpers

    private func providerLabel(for model: LLMModelID) -> String {
        switch model {
        case .claudeSonnet, .claudeHaiku:
            return "Anthropic"
        case .gpt4o, .gpt4oMini, .deepseekChat:
            return "OpenAI Compatible"
        }
    }

    /// Creates a binding to a SettingsViewModel property via key path.
    private func binding<T>(for keyPath: ReferenceWritableKeyPath<SettingsViewModel, T>, in vm: SettingsViewModel) -> Binding<T> {
        Binding(
            get: { vm[keyPath: keyPath] },
            set: { vm[keyPath: keyPath] = $0 }
        )
    }
}

#Preview {
    ModelSelectionView(viewModel: SettingsViewModel(dependencies: AppDependencies()))
}
