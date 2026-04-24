import Foundation
import OpenAgentSDK

/// Input structure for the analyze_content tool.
///
/// Codable to work with the `defineTool()` factory function's
/// JSON serialization/deserialization pipeline.
struct AnalyzeContentInput: Codable, Sendable {
    /// Maximum number of photos to analyze.
    /// When nil, uses a sensible default (100).
    let maxPhotos: Int?

    /// Preferred language for generated titles (e.g., "en", "zh").
    /// When nil, defaults to "en".
    let language: String?
}

/// Creates an analyze_content tool that performs AI-driven content analysis
/// for photo renaming.
///
/// The tool uses the injected `ContentAnalyzerProtocol` to analyze photo content
/// via LLM and generate descriptive file name suggestions. Returns a JSON array
/// of rename suggestions with confidence scores and descriptions.
///
/// - Parameters:
///   - analyzer: A ContentAnalyzerProtocol implementation for content analysis.
///   - repository: A PhotoLibraryRepository to fetch photo assets from.
/// - Returns: A ToolProtocol instance registered as "analyze_content".
func createAnalyzeContentTool(
    analyzer: any ContentAnalyzerProtocol,
    repository: any PhotoLibraryRepository
) -> ToolProtocol {
    return defineTool(
        name: "analyze_content",
        description: "Analyze photos using AI to generate descriptive file names. Identifies scenes, people, places, and activities in photos and suggests meaningful names to replace generic file names like IMG_001.jpg.",
        inputSchema: [
            "type": "object",
            "properties": [
                "maxPhotos": [
                    "type": "integer",
                    "description": "Maximum number of photos to analyze (default: 100)"
                ],
                "language": [
                    "type": "string",
                    "description": "Preferred language for generated titles (default: 'en', e.g., 'zh' for Chinese)"
                ]
            ] as [String: Any]
        ],
        isReadOnly: true,
        annotations: ToolAnnotations(readOnlyHint: true, destructiveHint: false)
    ) { (input: AnalyzeContentInput, _: ToolContext) async throws -> String in
        // Step 1: Fetch assets from repository
        let pageSize = input.maxPhotos ?? 100
        let page = try await repository.fetchAssets(
            predicate: .all,
            pageSize: pageSize,
            pageOffset: 0
        )

        // Step 2: Run content analysis
        let language = input.language ?? "en"
        let suggestions = try await analyzer.analyzeContent(
            assets: page.assets,
            repository: repository,
            language: language
        )

        // Step 3: Serialize RenameSuggestion list to JSON
        let suggestionsJSON = suggestions.map { suggestion -> [String: Any] in
            var result: [String: Any] = [
                "id": suggestion.id.uuidString,
                "assetID": suggestion.assetID.rawValue,
                "originalFileName": suggestion.originalFileName,
                "suggestedName": suggestion.suggestedName,
                "confidence": suggestion.confidence,
                "status": suggestion.status.stringValue
            ]
            if let desc = suggestion.analysisDescription {
                result["description"] = desc
            }
            return result
        }

        let output: [String: Any] = [
            "suggestions": suggestionsJSON,
            "totalSuggestions": suggestionsJSON.count,
            "analyzedAssets": page.assets.count
        ]

        let data = try JSONSerialization.data(
            withJSONObject: output,
            options: [.prettyPrinted, .sortedKeys]
        )
        return String(data: data, encoding: .utf8)
            ?? "{\"suggestions\": [], \"totalSuggestions\": 0}"
    }
}
