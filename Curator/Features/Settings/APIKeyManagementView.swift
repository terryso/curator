import SwiftUI

/// API Key management and provider configuration view.
///
/// Displays a Form layout with fields for primary and optional fallback
/// provider configuration. Includes inline validation with success/error feedback.
struct APIKeyManagementView: View {
    let viewModel: SettingsViewModel

    var body: some View {
        providerForm(vm: viewModel)
    }

    private func providerForm(vm: SettingsViewModel) -> some View {
        Form {
            // MARK: - Primary Provider
            Section {
                Picker("Type", selection: binding(for: \.primaryProviderType, in: vm)){
                    ForEach(LLMProviderType.allCases, id: \.self) { type in
                        Text(type.displayName).tag(type)
                    }
                }

                TextField("Base URL", text: binding(for: \.primaryBaseURL, in: vm))
                    .help("e.g. https://api.anthropic.com")

                HStack {
                    SecureField("API Key", text: binding(for: \.primaryAPIKey, in: vm))
                    Button {
                        Task { await vm.validatePrimaryAPIKey() }
                    } label: {
                        if vm.isValidatingPrimary {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text("Validate")
                        }
                    }
                    .disabled(vm.primaryAPIKey.isEmpty || vm.isValidatingPrimary)
                    .buttonStyle(.bordered)
                }

                validationMessage(result: vm.primaryValidationResult)

                Picker("Model", selection: binding(for: \.primaryModelID, in: vm)) {
                    ForEach(LLMModelID.allCases, id: \.rawValue) { model in
                        Text(model.rawValue).tag(model.rawValue)
                    }
                }
            } header: {
                Text("Primary Provider")
            }

            // MARK: - Fallback Provider
            Section {
                Toggle("Enable Fallback Provider", isOn: binding(for: \.hasFallback, in: vm))

                if vm.hasFallback {
                    Picker("Type", selection: binding(for: \.fallbackProviderType, in: vm)) {
                        ForEach(LLMProviderType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }

                    TextField("Display Name", text: binding(for: \.fallbackDisplayName, in: vm))
                        .help("e.g. DeepSeek, Groq")

                    TextField("Base URL", text: binding(for: \.fallbackBaseURL, in: vm))

                    HStack {
                        SecureField("API Key", text: binding(for: \.fallbackAPIKey, in: vm))
                        Button {
                            Task { await vm.validateFallbackAPIKey() }
                        } label: {
                            if vm.isValidatingFallback {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Text("Validate")
                            }
                        }
                        .disabled(vm.fallbackAPIKey.isEmpty || vm.isValidatingFallback)
                        .buttonStyle(.bordered)
                    }

                    validationMessage(result: vm.fallbackValidationResult)

                    Picker("Model", selection: binding(for: \.fallbackModelID, in: vm)) {
                        ForEach(LLMModelID.allCases, id: \.rawValue) { model in
                            Text(model.rawValue).tag(model.rawValue)
                        }
                    }
                }
            } header: {
                Text("Fallback Provider")
            }

            // MARK: - Actions
            Section {
                HStack {
                    Spacer()
                    Button("Save") {
                        vm.saveConfig()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!isPrimaryValid(vm))

                    Button("Reset") {
                        Task { await vm.loadCurrentConfig() }
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Helpers

    @ViewBuilder
    private func validationMessage(result: SettingsViewModel.ValidationResult?) -> some View {
        if let result = result {
            switch result {
            case .success:
                Label("API key is valid", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.caption)
            case .failure(let message):
                Label(message, systemImage: "xmark.circle.fill")
                    .foregroundStyle(.red)
                    .font(.caption)
            }
        }
    }

    private func isPrimaryValid(_ vm: SettingsViewModel) -> Bool {
        !vm.primaryBaseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !vm.primaryAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !vm.primaryModelID.isEmpty
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
    APIKeyManagementView(viewModel: SettingsViewModel(dependencies: AppDependencies()))
}
