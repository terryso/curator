import Foundation

/// Status of a rename suggestion throughout its lifecycle.
///
/// Tracks the progression from initial suggestion through user review
/// to final outcome (accepted, rejected, edited, or failed).
enum RenameSuggestionStatus: Sendable, Equatable {
    /// Suggestion generated but not yet reviewed.
    case pending
    /// User accepted the suggested name.
    case accepted
    /// User rejected the suggested name.
    case rejected
    /// User edited the suggested name with a custom replacement.
    case edited(String)
    /// Analysis failed for this asset (LLM error, image decode failure, etc.).
    case failed(String)

    /// Stable string representation for JSON serialization.
    var stringValue: String {
        switch self {
        case .pending: return "pending"
        case .accepted: return "accepted"
        case .rejected: return "rejected"
        case .edited: return "edited"
        case .failed: return "failed"
        }
    }
}

/// Value type representing an AI-generated rename suggestion for a photo.
///
/// Contains the original file name, the suggested descriptive name,
/// confidence score from the LLM analysis, and the current review status.
/// Designed as a Sendable value type for safe use across concurrency domains.
struct RenameSuggestion: Sendable, Identifiable {
    /// Unique identifier for this rename suggestion.
    let id: UUID

    /// The photo asset this suggestion applies to.
    let assetID: AssetID

    /// The original file name of the photo.
    let originalFileName: String

    /// The AI-suggested descriptive file name.
    let suggestedName: String

    /// Confidence score from the LLM analysis (0.0 to 1.0).
    let confidence: Double

    /// Optional detailed description of what the LLM identified in the photo.
    let analysisDescription: String?

    /// Current review status of this suggestion.
    let status: RenameSuggestionStatus

    /// Creates a new RenameSuggestion.
    ///
    /// - Parameters:
    ///   - id: Unique identifier (auto-generated if not provided).
    ///   - assetID: The photo asset this suggestion applies to.
    ///   - originalFileName: The original file name.
    ///   - suggestedName: The AI-suggested descriptive name.
    ///   - confidence: Confidence score (0.0 to 1.0).
    ///   - analysisDescription: Optional detailed description of photo content.
    ///   - status: Current review status (default: .pending).
    init(
        id: UUID = UUID(),
        assetID: AssetID,
        originalFileName: String,
        suggestedName: String,
        confidence: Double,
        analysisDescription: String? = nil,
        status: RenameSuggestionStatus = .pending
    ) {
        self.id = id
        self.assetID = assetID
        self.originalFileName = originalFileName
        self.suggestedName = suggestedName
        self.confidence = confidence
        self.analysisDescription = analysisDescription
        self.status = status
    }

    // MARK: - File Name Validation

    /// Maximum allowed length for a file name (excluding extension).
    static let maxFileNameLength = 200

    /// Characters forbidden in file system names.
    private static let illegalCharacterSet = CharacterSet(charactersIn: "\\/:*?\"<>|")

    /// Validates whether a file name is compliant with file system naming rules.
    ///
    /// A valid file name:
    /// - Is not empty
    /// - Does not contain illegal characters (\ / : * ? " < > |)
    /// - Does not exceed 200 characters
    /// - Does not start or end with a period
    ///
    /// - Parameter name: The file name to validate.
    /// - Returns: `true` if the name is valid, `false` otherwise.
    static func isValidFileName(_ name: String) -> Bool {
        guard !name.isEmpty else { return false }
        guard name.count <= maxFileNameLength else { return false }
        guard !name.unicodeScalars.contains(where: { illegalCharacterSet.contains($0) }) else { return false }
        guard !name.hasPrefix(".") && !name.hasSuffix(".") else { return false }
        return true
    }

    /// Sanitizes a file name by removing illegal characters and truncating to a safe length.
    ///
    /// - Parameters:
    ///   - name: The raw file name from LLM output.
    ///   - ext: The original file extension to preserve.
    /// - Returns: A sanitized file name safe for file system use.
    static func sanitizeFileName(_ name: String, extension ext: String) -> String {
        var sanitized = name
        // Remove illegal characters
        sanitized = sanitized.components(separatedBy: illegalCharacterSet).joined()
        // Remove leading/trailing whitespace and newlines
        sanitized = sanitized.trimmingCharacters(in: .whitespacesAndNewlines)
        // Remove leading/trailing periods
        sanitized = sanitized.trimmingCharacters(in: CharacterSet(charactersIn: "."))
        // Truncate to max length (accounting for extension)
        let maxBaseLength = maxFileNameLength - ext.count - 1 // -1 for the dot
        if sanitized.count > maxBaseLength {
            sanitized = String(sanitized.prefix(maxBaseLength))
        }
        return sanitized.isEmpty ? "unnamed" : sanitized
    }
}
