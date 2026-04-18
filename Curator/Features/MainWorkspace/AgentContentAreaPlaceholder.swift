import SwiftUI

/// Agent execution area placeholder view.
///
/// Displays a welcoming empty state in the detail area of the main workspace.
/// Story 3.3/3.4 will replace this with the actual Agent execution panel
/// and input bar components.
struct AgentContentAreaPlaceholder: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Welcome to Curator")
                .font(.title2)
                .fontWeight(.medium)
            Text("Describe what you'd like to do with your photos...")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    AgentContentAreaPlaceholder()
}
