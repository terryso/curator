import SwiftUI

@main
struct CuratorApp: App {
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

        Settings {
            SettingsPlaceholderView()
        }
    }
}
