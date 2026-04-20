import Foundation

/// Steps in the first-launch onboarding flow.
///
/// Defined as Int-backed enum for use with step indicators.
/// Cases: welcome (product intro), privacy (privacy explanation),
/// folderSelection (NSOpenPanel folder pick), scanning (folder scan in progress),
/// complete (scan done, photo count shown), noFolder (user skipped/cancelled).
enum OnboardingStep: Int, CaseIterable, Equatable, Sendable {
    case welcome = 0
    case privacy = 1
    case folderSelection = 2
    case scanning = 3
    case complete = 4
    case noFolder = 5
}
