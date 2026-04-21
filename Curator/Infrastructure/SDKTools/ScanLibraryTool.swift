import Foundation
import OpenAgentSDK

/// Input structure for the scan_library tool.
///
/// Codable to work with the `defineTool()` factory function's
/// JSON serialization/deserialization pipeline.
struct ScanLibraryInput: Codable, Sendable {
    /// Maximum number of photos to include in the summary.
    /// When nil, uses a sensible default (100).
    let maxResults: Int?
}

/// Creates a scan_library tool that scans the user's photo library via dependency injection.
///
/// The tool uses the injected `PhotoLibraryRepository` protocol to fetch assets,
/// following the project's dependency injection pattern. The repository is captured
/// in the closure, avoiding direct concrete type instantiation.
///
/// - Parameter repository: A PhotoLibraryRepository implementation (e.g., LocalFolderRepository).
/// - Returns: A ToolProtocol instance registered as "scan_library".
func createScanLibraryTool(repository: any PhotoLibraryRepository) -> ToolProtocol {
    return defineTool(
        name: "scan_library",
        description: "Scan the user's photo folder and return a summary of photos found, including count, formats, and date range.",
        inputSchema: [
            "type": "object",
            "properties": [
                "maxResults": [
                    "type": "integer",
                    "description": "Maximum number of photos to return in the summary"
                ]
            ] as [String: Any]
        ],
        isReadOnly: true,
        annotations: ToolAnnotations(readOnlyHint: true, destructiveHint: false)
    ) { (input: ScanLibraryInput, _: ToolContext) async throws -> String in
        let pageSize = input.maxResults ?? 100
        let page = try await repository.fetchAssets(
            predicate: .all,
            pageSize: pageSize,
            pageOffset: 0
        )

        // Build JSON result summary
        let photoCount = page.assets.count
        var formatCounts: [String: Int] = [:]
        var dateRange: [String: String] = [:]

        for asset in page.assets {
            let ext = (asset.metadata.fileName as NSString).pathExtension.lowercased()
            formatCounts[ext, default: 0] += 1
        }

        let dates = page.assets.compactMap { $0.metadata.creationDate }.sorted()
        if let oldest = dates.first, let newest = dates.last {
            let formatter = ISO8601DateFormatter()
            dateRange = [
                "oldest": formatter.string(from: oldest),
                "newest": formatter.string(from: newest)
            ]
        }

        let result: [String: Any] = [
            "photoCount": photoCount,
            "hasMore": page.hasMore,
            "formats": formatCounts,
            "dateRange": dateRange
        ]

        let data = try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
        return String(data: data, encoding: .utf8) ?? "{}"
    }
}
