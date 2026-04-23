import Foundation

/// Protocol defining the image analysis pipeline interface.
///
/// The pipeline performs a two-stage analysis:
/// 1. Local pHash filtering to find candidate duplicate pairs.
/// 2. LLM semantic confirmation to verify true duplicates.
///
/// Defined in the Domain layer; concrete implementations reside in
/// the Infrastructure layer. Supports test-time replacement with mock implementations.
protocol ImageAnalysisPipelineProtocol: Sendable {
    /// Analyzes photo assets for duplicates using two-stage analysis.
    ///
    /// - Parameters:
    ///   - assets: Photo assets to analyze.
    ///   - repository: Repository to fetch image data from.
    /// - Returns: Array of confirmed DuplicateGroups, sorted by similarity score descending.
    /// - Throws: `DomainError.analysisFailed` if a critical error occurs.
    func analyze(
        assets: [PhotoAsset],
        repository: PhotoLibraryRepository
    ) async throws -> [DuplicateGroup]

    /// Analyzes photo assets for duplicates with progress reporting.
    ///
    /// - Parameters:
    ///   - assets: Photo assets to analyze.
    ///   - repository: Repository to fetch image data from.
    ///   - progressHandler: Optional callback receiving progress updates during analysis.
    /// - Returns: Array of confirmed DuplicateGroups, sorted by similarity score descending.
    /// - Throws: `DomainError.analysisFailed` if a critical error occurs.
    func analyze(
        assets: [PhotoAsset],
        repository: PhotoLibraryRepository,
        progressHandler: (@Sendable (AnalysisProgress) -> Void)?
    ) async throws -> [DuplicateGroup]
}
