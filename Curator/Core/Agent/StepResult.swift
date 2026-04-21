import Foundation

/// Result of a completed Agent step.
///
/// Contains the step output data and optional metadata.
/// Specific step types (scan, analyze, rename) will extend this
/// with typed payloads in later Stories (Epic 5, 6).
struct StepResult: Sendable, Equatable {
    let stepID: UUID
    let message: String
    let data: [String: String]
}
