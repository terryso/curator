import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "photo.on.rectangle.angled")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Curator")
                .font(.largeTitle)
                .fontWeight(.bold)
            Text("AI-Powered Photo Management")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(minWidth: 800, minHeight: 600)
    }
}

#Preview {
    ContentView()
}
