import Foundation
import OpenAgentSDK

/// Input structure for the analyze_duplicates tool.
///
/// Codable to work with the `defineTool()` factory function's
/// JSON serialization/deserialization pipeline.
struct AnalyzeDuplicatesInput: Codable, Sendable {
    /// Maximum number of photos to analyze.
    /// When nil, uses a sensible default (500).
    let maxPhotos: Int?

    /// pHash hamming distance threshold for candidate filtering.
    /// When nil, the pipeline uses its default threshold (10).
    ///
    /// - Note: Currently accepted but not forwarded to `ImageAnalysisPipelineProtocol`,
    ///   which uses its own internal default. Will be wired through when the pipeline
    ///   protocol gains threshold configuration support.
    let hashThreshold: Int?
}

/// Creates an analyze_duplicates tool that performs two-stage duplicate detection.
///
/// The tool uses the injected `ImageAnalysisPipelineProtocol` to run local perceptual
/// hashing followed by LLM semantic confirmation. Returns a JSON array of duplicate
/// groups with similarity scores and match reasons.
///
/// - Parameters:
///   - pipeline: An ImageAnalysisPipelineProtocol implementation for two-stage analysis.
///   - repository: A PhotoLibraryRepository to fetch photo assets from.
/// - Returns: A ToolProtocol instance registered as "analyze_duplicates".
func createAnalyzeDuplicatesTool(
    pipeline: any ImageAnalysisPipelineProtocol,
    repository: any PhotoLibraryRepository
) -> ToolProtocol {
    return defineTool(
        name: "analyze_duplicates",
        description: "Analyze photos in the library for duplicates using two-stage analysis: local perceptual hashing followed by AI confirmation. Returns groups of duplicate photos with similarity scores and explanations.",
        inputSchema: [
            "type": "object",
            "properties": [
                "maxPhotos": [
                    "type": "integer",
                    "description": "Maximum number of photos to analyze (default: 500)"
                ],
                "hashThreshold": [
                    "type": "integer",
                    "description": "pHash hamming distance threshold for candidate filtering (default: 10)"
                ]
            ] as [String: Any]
        ],
        isReadOnly: true,
        annotations: ToolAnnotations(readOnlyHint: true, destructiveHint: false)
    ) { (input: AnalyzeDuplicatesInput, _: ToolContext) async throws -> String in
        // Step 1: Fetch assets from repository
        let pageSize = input.maxPhotos ?? 500
        let page = try await repository.fetchAssets(
            predicate: .all,
            pageSize: pageSize,
            pageOffset: 0
        )

        // Step 2: Run two-stage analysis pipeline
        let groups = try await pipeline.analyze(
            assets: page.assets,
            repository: repository
        )

        // Step 3: Serialize DuplicateGroup list to JSON
        let groupsJSON = groups.map { group -> [String: Any] in
            return [
                "id": group.id.uuidString,
                "assetIDs": group.assets.map { $0.id.rawValue },
                "fileNames": group.assets.map { $0.metadata.fileName },
                "similarityScore": group.similarityScore,
                "reason": group.reason ?? "",
                "assetCount": group.assets.count,
                "status": group.status.stringValue
            ] as [String: Any]
        }

        let result: [String: Any] = [
            "groups": groupsJSON,
            "totalGroups": groupsJSON.count,
            "analyzedAssets": page.assets.count
        ]

        let data = try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
        return String(data: data, encoding: .utf8) ?? "{\"groups\": [], \"totalGroups\": 0}"
    }
}
