import Foundation

/// Stages of the image analysis pipeline.
///
/// Represents the sequential phases the pipeline goes through during analysis.
enum AnalysisStage: Sendable, Equatable {
    /// Computing perceptual hashes for all assets.
    case hashing
    /// Comparing hash pairs to find similar photos.
    case pairComparison
    /// Sending candidate groups to LLM for semantic confirmation.
    case llmConfirmation
    /// Generating thumbnails for confirmed duplicate groups.
    case thumbnailGeneration
    /// Analysis pipeline completed.
    case completed
}

/// Value type representing the progress of an image analysis pipeline run.
///
/// Reports the current stage, how many items have been completed,
/// and the total number of items in that stage.
struct AnalysisProgress: Sendable, Equatable {
    /// The current analysis stage.
    let stage: AnalysisStage

    /// Number of items completed in this stage.
    let completed: Int

    /// Total number of items in this stage.
    let total: Int
}
