import Foundation

/// A snapshot of an asset's metadata before an operation is applied.
///
/// Captures the before-state so that operations can be rolled back.
/// Each snapshot is associated with a single operation in a batch.
struct OperationSnapshot: Sendable, Equatable {
    let id: UUID
    let timestamp: Date
    let operationType: OperationType
    let assetID: AssetID
    let beforeState: AssetMetadata
}

// MARK: - Codable Conformance (manual because AssetMetadata is not Codable)

extension OperationSnapshot: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, timestamp, operationType, assetID
        case beforeStateFileName, beforeStateFileSize, beforeStateCreationDate
        case beforeStateCameraModel, beforeStateImageWidth, beforeStateImageHeight
        case beforeStateFileFormat
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        operationType = try container.decode(OperationType.self, forKey: .operationType)
        assetID = try container.decode(AssetID.self, forKey: .assetID)

        let fileName = try container.decode(String.self, forKey: .beforeStateFileName)
        let fileSize = try container.decodeIfPresent(Int64.self, forKey: .beforeStateFileSize)
        let creationDate = try container.decodeIfPresent(Date.self, forKey: .beforeStateCreationDate)
        let cameraModel = try container.decodeIfPresent(String.self, forKey: .beforeStateCameraModel)
        let imageWidth = try container.decodeIfPresent(Int.self, forKey: .beforeStateImageWidth)
        let imageHeight = try container.decodeIfPresent(Int.self, forKey: .beforeStateImageHeight)
        let fileFormat = try container.decodeIfPresent(FileFormat.self, forKey: .beforeStateFileFormat)

        beforeState = AssetMetadata(
            fileName: fileName,
            fileSize: fileSize,
            creationDate: creationDate,
            cameraModel: cameraModel,
            imageWidth: imageWidth,
            imageHeight: imageHeight,
            gpsLocation: nil,
            fileFormat: fileFormat
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(operationType, forKey: .operationType)
        try container.encode(assetID, forKey: .assetID)

        try container.encode(beforeState.fileName, forKey: .beforeStateFileName)
        try container.encodeIfPresent(beforeState.fileSize, forKey: .beforeStateFileSize)
        try container.encodeIfPresent(beforeState.creationDate, forKey: .beforeStateCreationDate)
        try container.encodeIfPresent(beforeState.cameraModel, forKey: .beforeStateCameraModel)
        try container.encodeIfPresent(beforeState.imageWidth, forKey: .beforeStateImageWidth)
        try container.encodeIfPresent(beforeState.imageHeight, forKey: .beforeStateImageHeight)
        try container.encodeIfPresent(beforeState.fileFormat, forKey: .beforeStateFileFormat)
    }
}
