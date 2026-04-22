import SwiftUI

@main
struct CuratorApp: App {
    @StateObject private var dependencies = AppDependencies()

    init() {
        let isUITest = CommandLine.arguments.contains("--uitest-reset-onboarding")
            || CommandLine.arguments.contains("--uitest-mock-photos")
        let isUnitTest = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil

        if isUITest || isUnitTest {
            let env = ProcessInfo.processInfo.environment
            if let baseURL = env["CURATOR_LLM_BASE_URL"],
               let apiKey = env["CURATOR_LLM_API_KEY"],
               let model = env["CURATOR_LLM_MODEL"] {
                let providerType: LLMProviderType = env["CURATOR_LLM_PROVIDER"] == "openAICompatible" ? .openAICompatible : .anthropic
                let config = LLMConfig(
                    primary: LLMProviderConfig(
                        providerType: providerType,
                        baseURL: baseURL,
                        apiKey: apiKey,
                        modelID: model,
                        displayName: nil
                    )
                )
                config.save()
            } else {
                let mockConfig = LLMConfig(
                    baseURL: "https://mock.test",
                    apiKey: "test-key",
                    modelID: "claude-sonnet-4-20250514"
                )
                mockConfig.save()
            }
        }

        if CommandLine.arguments.contains("--uitest-reset-onboarding") {
            UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")
        }
        if CommandLine.arguments.contains("--uitest-mock-photos") || isUnitTest {
            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(dependencies)
                .frame(
                    minWidth: 900,
                    idealWidth: 1200,
                    minHeight: 600,
                    idealHeight: 800
                )
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Session") {
                    NotificationCenter.default.post(name: .newSessionRequested, object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)
            }
        }

        Settings {
            SettingsView()
                .environmentObject(dependencies)
        }
    }
}
