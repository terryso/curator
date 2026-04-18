import SwiftUI

/// Placeholder settings view for the Settings scene.
///
/// Minimal placeholder that will be replaced by the full settings UI
/// in Story 2.5 (Provider Settings UI). Provides the Settings scene
/// target so that Cmd+, opens a Settings window.
struct SettingsPlaceholderView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "gear")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text("Settings")
                .font(.title2)
                .fontWeight(.medium)
            Text("Settings will be available in a future update.")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(width: 400, height: 300)
    }
}

#Preview {
    SettingsPlaceholderView()
}
