import SwiftUI

/// Settings view for configuring the LLM provider.
///
/// Displays and edits the base URL, API key, and model selection
/// stored in UserDefaults via LLMConfig. Changes are saved immediately.
struct SettingsPlaceholderView: View {
    @State private var baseURL: String = ""
    @State private var apiKey: String = ""
    @State private var modelID: String = LLMModelID.claudeSonnet.rawValue
    @State private var isConfigured: Bool = false
    @State private var showSaved: Bool = false

    var body: some View {
        VStack(spacing: 20) {
            Text("Settings")
                .font(.title2)
                .fontWeight(.medium)

            if isConfigured {
                Label("AI provider configured", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Label("AI provider not configured", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            }

            Form {
                TextField("Base URL", text: $baseURL)
                    .help("e.g. https://api.anthropic.com")

                SecureField("API Key", text: $apiKey)

                Picker("Model", selection: $modelID) {
                    ForEach(LLMModelID.allCases, id: \.rawValue) { model in
                        Text(model.rawValue).tag(model.rawValue)
                    }
                }
            }
            .formStyle(.grouped)

            if showSaved {
                Text("Saved")
                    .font(.caption)
                    .foregroundStyle(.green)
                    .transition(.opacity)
            }

            HStack {
                Spacer()
                Button("Save") { saveConfig() }
                    .buttonStyle(.borderedProminent)
                    .disabled(!isValid)
                Button("Reset") { loadConfig() }
                    .buttonStyle(.bordered)
            }
            .padding(.horizontal, 20)
        }
        .padding(20)
        .frame(width: 450, height: 380)
        .onAppear { loadConfig() }
        .onChange(of: baseURL) { _, _ in saveConfig() }
        .onChange(of: apiKey) { _, _ in saveConfig() }
        .onChange(of: modelID) { _, _ in saveConfig() }
    }

    private var isValid: Bool {
        let config = LLMConfig(baseURL: baseURL, apiKey: apiKey, modelID: modelID)
        return config.isConfigured
    }

    private func loadConfig() {
        if let config = LLMConfig.load() {
            baseURL = config.baseURL
            apiKey = config.apiKey
            modelID = config.modelID
            isConfigured = config.isConfigured
        } else {
            baseURL = LLMConfig.defaultBaseURL
        }
    }

    private func saveConfig() {
        let config = LLMConfig(baseURL: baseURL, apiKey: apiKey, modelID: modelID)
        if config.isConfigured {
            config.save()
            isConfigured = true
        }
        withAnimation {
            showSaved = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            withAnimation { showSaved = false }
        }
    }
}

#Preview {
    SettingsPlaceholderView()
}
