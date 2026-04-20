import SwiftUI

@main
struct CuratorApp: App {
    init() {
        let isUITest = CommandLine.arguments.contains("--uitest-reset-onboarding")
            || CommandLine.arguments.contains("--uitest-mock-photos")
        let isUnitTest = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil

        if isUITest || isUnitTest {
            let mockConfig = LLMConfig(
                baseURL: "https://mock.test",
                apiKey: "test-key",
                modelID: "claude-sonnet-4-20250514"
            )
            mockConfig.save()
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
                    // Story 3.5 will implement full session management
                }
                .keyboardShortcut("n", modifiers: .command)
            }
        }

        Settings {
            SettingsPlaceholderView()
        }
    }
}
