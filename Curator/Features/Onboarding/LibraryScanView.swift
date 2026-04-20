import SwiftUI

/// Scanning-in-progress and scan-complete display view.
///
/// When scanning, shows a ProgressView with "Scanning photo library..." text.
/// When complete, shows the discovered photo count summary and a
/// "Get Started" button to finish onboarding.
struct LibraryScanView: View {
    /// Whether the library scan is in progress.
    let isScanning: Bool
    /// Number of photos discovered (nil until scan completes).
    let discoveredCount: Int?
    /// Whether more photos exist beyond the discovered count.
    let hasMore: Bool
    /// Action called when the user taps "Get Started".
    let onStart: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            if isScanning {
                ProgressView()
                    .controlSize(.large)
                    .accessibilityLabel("Scanning photo library")

                Text("Scanning photo folder...")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.green)
                    .accessibilityHidden(true)

                photoCountSummary

                Button("Get Started") {
                    onStart()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
                .accessibilityLabel("Start using Curator")
            }

            Spacer()
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    @ViewBuilder
    private var photoCountSummary: some View {
        if let count = discoveredCount {
            if count == 0 {
                Text("Your photo folder is empty.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            } else {
                let displayText = hasMore
                    ? "Discovered \(count)+ photos"
                    : "Discovered \(count) photo\(count == 1 ? "" : "s")"
                Text(displayText)
                    .font(.title3)
                    .fontWeight(.medium)
            }
        }
    }
}

#Preview("LibraryScanView - Scanning") {
    LibraryScanView(
        isScanning: true,
        discoveredCount: nil,
        hasMore: false,
        onStart: {}
    )
    .frame(width: 600, height: 500)
}

#Preview("LibraryScanView - Complete") {
    LibraryScanView(
        isScanning: false,
        discoveredCount: 15320,
        hasMore: true,
        onStart: {}
    )
    .frame(width: 600, height: 500)
}

#Preview("LibraryScanView - Empty") {
    LibraryScanView(
        isScanning: false,
        discoveredCount: 0,
        hasMore: false,
        onStart: {}
    )
    .frame(width: 600, height: 500)
}
