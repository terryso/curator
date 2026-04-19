import SwiftUI

/// Onboarding step for configuring the LLM provider.
///
/// Collects base URL, API key, and model selection from the user.
/// The "Next" button is disabled until all fields are filled.
struct LLMConfigView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    let onNext: () -> Void
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "server.rack")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
                .accessibilityLabel("LLM configuration")

            Text("Configure AI Provider")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Enter your LLM provider details to enable AI analysis.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Form {
                TextField("Base URL", text: $viewModel.baseURL)
                    .textFieldStyle(.roundedBorder)
                    .help("e.g. https://api.anthropic.com")

                SecureField("API Key", text: $viewModel.apiKey)
                    .textFieldStyle(.roundedBorder)

                Picker("Model", selection: $viewModel.modelID) {
                    ForEach(LLMModelID.allCases, id: \.rawValue) { model in
                        Text(model.rawValue).tag(model.rawValue)
                    }
                }
                .frame(maxWidth: 300)
            }
            .formStyle(.grouped)
            .frame(maxWidth: 400)

            Spacer()

            HStack {
                Button("Back") { onBack() }
                    .buttonStyle(.bordered)

                Spacer()

                Button("Next") { onNext() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(!viewModel.isLLMConfigValid)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 40)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

#Preview("LLMConfigView") {
    LLMConfigView(
        viewModel: OnboardingViewModel(repository: nil),
        onNext: {},
        onBack: {}
    )
    .frame(width: 600, height: 500)
}
