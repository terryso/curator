import Foundation
import OpenAgentSDK

/// Input structure for a single rename item within the rename_assets tool.
///
/// Each item represents one accepted rename suggestion with the asset ID,
/// the suggested (or user-edited) name, and the original file name.
/// Codable to work with the `defineTool()` factory function's
/// JSON serialization/deserialization pipeline.
struct RenameItemInput: Codable, Sendable {
    /// The raw asset ID string identifying the photo to rename.
    let assetID: String

    /// The new descriptive file name to apply (may include extension).
    let suggestedName: String

    /// The original file name before renaming (for reference and logging).
    let originalFileName: String
}

/// Input structure for the rename_assets tool.
///
/// Codable to work with the `defineTool()` factory function's
/// JSON serialization/deserialization pipeline.
struct RenameAssetsInput: Codable, Sendable {
    /// List of reviewed and accepted rename suggestions.
    /// Each item contains assetID, suggestedName, and originalFileName.
    let suggestions: [RenameItemInput]

    /// Optional description of the batch operation.
    let batchDescription: String?
}

/// Error type for RenameAssetsTool validation failures.
///
/// Used to return structured JSON error information through the
/// defineTool error handling pipeline.
private struct RenameAssetsToolError: Error, Sendable {
    let message: String
}

/// Creates a rename_assets tool that safely renames photo assets via OperationManager.
///
/// The tool creates a snapshot before renaming using `OperationManager.beginBatch()`,
/// then executes the rename via `OperationManager.executeBatch()`. If execution fails,
/// the OperationManager automatically rolls back completed operations.
///
/// This follows the same architecture pattern as DeleteAssetsTool:
/// validate input -> convert to PlannedOperation -> beginBatch -> executeBatch -> return result.
///
/// - Parameters:
///   - operationManager: An OperationManaging implementation for snapshot/rollback support.
///   - repository: A PhotoLibraryRepository to provide to the OperationManager.
/// - Returns: A ToolProtocol instance registered as "rename_assets".
func createRenameAssetsTool(
    operationManager: any OperationManaging,
    repository: any PhotoLibraryRepository
) -> ToolProtocol {
    return defineTool(
        name: "rename_assets",
        description: "Rename photo assets with AI-generated descriptive names. This is a destructive operation that requires user confirmation. Creates snapshots for rollback via OperationManager.",
        inputSchema: [
            "type": "object",
            "properties": [
                "suggestions": [
                    "type": "array",
                    "items": [
                        "type": "object",
                        "properties": [
                            "assetID": [
                                "type": "string",
                                "description": "The asset ID of the photo to rename"
                            ],
                            "suggestedName": [
                                "type": "string",
                                "description": "The new descriptive file name"
                            ],
                            "originalFileName": [
                                "type": "string",
                                "description": "The original file name before renaming"
                            ]
                        ] as [String: Any],
                        "required": ["assetID", "suggestedName", "originalFileName"]
                    ],
                    "description": "List of accepted rename suggestions"
                ],
                "batchDescription": [
                    "type": "string",
                    "description": "Optional description of the batch operation"
                ]
            ] as [String: Any],
            "required": ["suggestions"]
        ],
        isReadOnly: false,
        annotations: ToolAnnotations(readOnlyHint: false, destructiveHint: true)
    ) { (input: RenameAssetsInput, _: ToolContext) async throws -> String in
        // Step 1: Validate input
        guard !input.suggestions.isEmpty else {
            throw RenameAssetsToolError(message: "suggestions cannot be empty")
        }

        // Step 1b: Validate each suggestion has non-empty assetID and suggestedName
        for (index, item) in input.suggestions.enumerated() {
            guard !item.assetID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw RenameAssetsToolError(message: "suggestions[\(index)].assetID cannot be empty")
            }
            let trimmedName = item.suggestedName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedName.isEmpty else {
                throw RenameAssetsToolError(message: "suggestions[\(index)].suggestedName cannot be empty")
            }
            guard RenameSuggestion.isValidFileName(trimmedName) else {
                throw RenameAssetsToolError(message: "suggestions[\(index)].suggestedName contains invalid characters or is too long: '\(trimmedName)'")
            }
        }

        // Step 2: Build PlannedOperation array from rename suggestions
        let operations = input.suggestions.map { item in
            PlannedOperation(
                operationType: .rename,
                assetID: AssetID(rawValue: item.assetID),
                parameters: .rename(newTitle: item.suggestedName)
            )
        }

        // Step 3: Create snapshot via beginBatch
        let batchID = try await operationManager.beginBatch(
            operations: operations,
            repository: repository
        )

        // Step 4: Execute batch rename
        try await operationManager.executeBatch(batchID, repository: repository)

        // Step 5: Return success result
        let result: [String: Any] = [
            "success": true,
            "batchID": batchID.uuidString,
            "renamedCount": input.suggestions.count
        ]
        let data = try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
        return String(data: data, encoding: .utf8) ?? "{\"success\": true}"
    }
}
