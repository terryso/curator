import Foundation
import OpenAgentSDK

/// Input structure for the delete_assets tool.
///
/// Codable to work with the `defineTool()` factory function's
/// JSON serialization/deserialization pipeline.
struct DeleteAssetsInput: Codable, Sendable {
    /// List of asset ID strings to delete.
    let assetIDs: [String]

    /// Optional description of the batch operation.
    let batchDescription: String?
}

/// Error type for DeleteAssetsTool validation failures.
///
/// Used to return structured JSON error information through the
/// defineTool error handling pipeline.
private struct DeleteAssetsToolError: Error, Sendable {
    let message: String
}

/// Creates a delete_assets tool that safely deletes photo assets via OperationManager.
///
/// The tool creates a snapshot before deletion using `OperationManager.beginBatch()`,
/// then executes the deletion via `OperationManager.executeBatch()`. If execution fails,
/// the OperationManager automatically rolls back completed operations.
///
/// - Parameters:
///   - operationManager: An OperationManaging implementation for snapshot/rollback support.
///   - repository: A PhotoLibraryRepository to provide to the OperationManager.
/// - Returns: A ToolProtocol instance registered as "delete_assets".
func createDeleteAssetsTool(
    operationManager: any OperationManaging,
    repository: any PhotoLibraryRepository
) -> ToolProtocol {
    return defineTool(
        name: "delete_assets",
        description: "Delete specified photo assets from the library. This is a destructive operation that requires user confirmation. Creates snapshots for rollback via OperationManager.",
        inputSchema: [
            "type": "object",
            "properties": [
                "assetIDs": [
                    "type": "array",
                    "items": ["type": "string"],
                    "description": "List of asset IDs to delete"
                ],
                "batchDescription": [
                    "type": "string",
                    "description": "Optional description of the batch operation"
                ]
            ] as [String: Any],
            "required": ["assetIDs"]
        ],
        isReadOnly: false,
        annotations: ToolAnnotations(readOnlyHint: false, destructiveHint: true)
    ) { (input: DeleteAssetsInput, _: ToolContext) async throws -> String in
        // Validate input
        guard !input.assetIDs.isEmpty else {
            throw DeleteAssetsToolError(message: "assetIDs cannot be empty")
        }

        // Step 1: Convert string asset IDs to AssetID values
        let assetIDValues = input.assetIDs.map { AssetID(rawValue: $0) }

        // Step 2: Build PlannedOperation array
        let operations = assetIDValues.map { assetID in
            PlannedOperation(
                operationType: .delete,
                assetID: assetID,
                parameters: .delete
            )
        }

        // Step 3: Create snapshot via beginBatch
        let batchID = try await operationManager.beginBatch(
            operations: operations,
            repository: repository
        )

        // Step 4: Execute batch deletion
        try await operationManager.executeBatch(batchID, repository: repository)

        // Step 5: Return success result
        let result: [String: Any] = [
            "success": true,
            "batchID": batchID.uuidString,
            "deletedCount": assetIDValues.count
        ]
        let data = try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
        return String(data: data, encoding: .utf8) ?? "{\"success\": true}"
    }
}
