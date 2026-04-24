import Foundation

/// Protocol defining the content analysis interface for photo renaming.
///
/// The analyzer uses LLM to identify scenes, people, places, and activities
/// in photos, then generates descriptive file name suggestions.
///
/// Defined in the Domain layer; concrete implementations reside in
/// the Infrastructure layer. Supports test-time replacement with mock implementations.
protocol ContentAnalyzerProtocol: Sendable {
    /// Analyzes photo content and generates rename suggestions.
    ///
    /// - Parameters:
    ///   - assets: Photo assets to analyze.
    ///   - repository: Repository to fetch image data from.
    ///   - language: Preferred language for generated titles (e.g., "en", "zh").
    /// - Returns: Array of RenameSuggestions, one per analyzed asset.
    /// - Throws: `DomainError.analysisFailed` if a critical error occurs.
    func analyzeContent(
        assets: [PhotoAsset],
        repository: PhotoLibraryRepository,
        language: String
    ) async throws -> [RenameSuggestion]

    /// Analyzes photo content with progress reporting.
    ///
    /// - Parameters:
    ///   - assets: Photo assets to analyze.
    ///   - repository: Repository to fetch image data from.
    ///   - language: Preferred language for generated titles (e.g., "en", "zh").
    ///   - progressHandler: Optional callback receiving (analyzed, total) progress updates.
    /// - Returns: Array of RenameSuggestions, one per analyzed asset.
    /// - Throws: `DomainError.analysisFailed` if a critical error occurs.
    func analyzeContent(
        assets: [PhotoAsset],
        repository: PhotoLibraryRepository,
        language: String,
        progressHandler: (@Sendable (Int, Int) -> Void)?
    ) async throws -> [RenameSuggestion]
}
