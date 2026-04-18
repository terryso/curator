import Foundation

/// Steps in the first-launch onboarding flow.
///
/// Defined as Int-backed enum for use with step indicators.
/// Cases: welcome (product intro), privacy (privacy explanation),
/// permission (photo access request), scanning (library scan in progress),
/// complete (scan done, photo count shown), denied (permission rejected).
enum OnboardingStep: Int, CaseIterable, Equatable, Sendable {
    case welcome = 0
    case privacy = 1
    case permission = 2
    case scanning = 3
    case complete = 4
    case denied = 5
}
