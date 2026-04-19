import SwiftUI

@main
struct CuratorApp: App {
    init() {
        // UI test launch arguments
        if CommandLine.arguments.contains("--uitest-reset-onboarding") {
            UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")
        }
        if CommandLine.arguments.contains("--uitest-mock-photos") {
            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
            // Pre-configure LLM for UI tests (avoids Keychain/system prompts)
            let mockConfig = LLMConfig(
                baseURL: "https://mock.test",
                apiKey: "test-key",
                modelID: "claude-sonnet-4-20250514"
            )
            mockConfig.save()
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
