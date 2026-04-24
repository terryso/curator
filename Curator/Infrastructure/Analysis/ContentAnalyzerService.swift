import Foundation

/// Actor implementing the content analysis service for photo renaming.
///
/// Uses LLM to analyze photo content and generate descriptive file name suggestions.
/// Processes photos individually to enable error isolation and progress tracking.
/// All analysis operations run within the actor's isolation context,
/// ensuring thread safety without blocking the main thread.
actor ContentAnalyzerService: ContentAnalyzerProtocol {
    private let llmGateway: any LLMGatewayProtocol

    /// LLM model identifier for content analysis.
    private let llmModel: String

    /// Creates a new ContentAnalyzerService.
    ///
    /// - Parameters:
    ///   - llmGateway: LLM gateway for content analysis calls.
    ///   - llmModel: LLM model to use for analysis (default: "claude-sonnet-4-20250514").
    init(
        llmGateway: any LLMGatewayProtocol,
        llmModel: String = "claude-sonnet-4-20250514"
    ) {
        self.llmGateway = llmGateway
        self.llmModel = llmModel
    }

    // MARK: - ContentAnalyzerProtocol

    func analyzeContent(
        assets: [PhotoAsset],
        repository: PhotoLibraryRepository,
        language: String
    ) async throws -> [RenameSuggestion] {
        try await analyzeContent(
            assets: assets,
            repository: repository,
            language: language,
            progressHandler: nil
        )
    }

    func analyzeContent(
        assets: [PhotoAsset],
        repository: PhotoLibraryRepository,
        language: String,
        progressHandler: (@Sendable (Int, Int) -> Void)?
    ) async throws -> [RenameSuggestion] {
        guard !assets.isEmpty else {
            return []
        }

        let total = assets.count
        var suggestions: [RenameSuggestion] = []

        for (index, asset) in assets.enumerated() {
            try Task.checkCancellation()

            do {
                let imageData = try await repository.fetchFullResolutionImage(for: asset.id)
                let prompt = buildLLMPrompt(language: language, metadata: asset.metadata)
                let response = try await llmGateway.analyze(
                    images: [imageData],
                    prompt: prompt,
                    model: llmModel
                )

                if let parsed = parseLLMResponse(response.text) {
                    let ext = (asset.metadata.fileName as NSString).pathExtension
                    let sanitizedTitle = RenameSuggestion.sanitizeFileName(
                        parsed.title,
                        extension: ext
                    )
                    let suggestedName = ext.isEmpty
                        ? sanitizedTitle
                        : "\(sanitizedTitle).\(ext)"

                    let suggestion = RenameSuggestion(
                        assetID: asset.id,
                        originalFileName: asset.metadata.fileName,
                        suggestedName: suggestedName,
                        confidence: parsed.confidence,
                        analysisDescription: parsed.description,
                        status: .pending
                    )
                    suggestions.append(suggestion)
                } else {
                    // LLM response could not be parsed — mark as failed
                    let suggestion = RenameSuggestion(
                        assetID: asset.id,
                        originalFileName: asset.metadata.fileName,
                        suggestedName: asset.metadata.fileName,
                        confidence: 0.0,
                        analysisDescription: nil,
                        status: .failed("Failed to parse LLM response")
                    )
                    suggestions.append(suggestion)
                }
            } catch {
                // Single photo failure — mark as failed, continue with others
                let suggestion = RenameSuggestion(
                    assetID: asset.id,
                    originalFileName: asset.metadata.fileName,
                    suggestedName: asset.metadata.fileName,
                    confidence: 0.0,
                    analysisDescription: nil,
                    status: .failed(error.localizedDescription)
                )
                suggestions.append(suggestion)
            }

            progressHandler?(index + 1, total)
        }

        return suggestions
    }

    // MARK: - LLM Integration

    /// Constructs the LLM prompt for photo content analysis.
    ///
    /// Instructs the LLM to identify key elements and generate a descriptive title
    /// in the user's preferred language, returning structured JSON.
    private func buildLLMPrompt(language: String, metadata: AssetMetadata) -> String {
        var context = ""
        if let camera = metadata.cameraModel {
            context += "Camera: \(camera). "
        }
        if let date = metadata.creationDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            context += "Date: \(formatter.string(from: date)). "
        }
        if let width = metadata.imageWidth, let height = metadata.imageHeight {
            context += "Resolution: \(width)x\(height). "
        }

        let languageName: String
        switch language {
        case "zh", "zh-CN", "zh-Hans", "zh-Hant":
            languageName = "Chinese"
        case "en":
            languageName = "English"
        case "ja":
            languageName = "Japanese"
        case "ko":
            languageName = "Korean"
        case "fr":
            languageName = "French"
        case "de":
            languageName = "German"
        case "es":
            languageName = "Spanish"
        default:
            languageName = language
        }

        return """
        Analyze this photo and generate a descriptive file name title.

        Requirements:
        1. Identify key elements: scene, people (do not identify specific names), places, activities, time characteristics
        2. Generate a concise descriptive title (5-15 words) in \(languageName)
        3. Return JSON format: {"title": "descriptive title", "description": "detailed description", "confidence": 0.85}

        File name rules:
        - No special characters (\\ / : * ? " < > |)
        - Does not start or end with a period
        - Maximum 200 characters
        \(context.isEmpty ? "" : "\nContext: \(context)")
        """
    }

    /// Parses the LLM response text to extract content analysis result.
    private func parseLLMResponse(_ text: String) -> (title: String, description: String, confidence: Double)? {
        guard let jsonData = extractJSON(from: text),
              let jsonObject = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            return nil
        }

        guard let title = jsonObject["title"] as? String, !title.isEmpty else { return nil }

        let description = jsonObject["description"] as? String ?? ""
        let confidence = jsonObject["confidence"] as? Double ?? 0.5

        return (title: title, description: description, confidence: confidence)
    }

    /// Extracts a JSON object string from potentially wrapped text.
    ///
    /// Handles cases where LLM wraps JSON in markdown code fences or prose.
    /// Uses brace-counting to find the first complete balanced JSON object.
    private func extractJSON(from text: String) -> Data? {
        // First try the entire text as JSON
        if let data = text.trimmingCharacters(in: .whitespacesAndNewlines).data(using: .utf8),
           let _ = try? JSONSerialization.jsonObject(with: data) {
            return data
        }

        // Find the first complete balanced JSON object using brace counting
        let characters = Array(text)
        guard let startIndex = characters.firstIndex(of: "{") else { return nil }

        var depth = 0
        var inString = false
        var escapeNext = false

        for i in startIndex..<characters.count {
            let char = characters[i]

            if escapeNext {
                escapeNext = false
                continue
            }

            if char == "\\" {
                escapeNext = true
                continue
            }

            if char == "\"" {
                inString.toggle()
                continue
            }

            if inString { continue }

            if char == "{" { depth += 1 }
            if char == "}" {
                depth -= 1
                if depth == 0 {
                    let jsonString = String(characters[startIndex...i])
                    if let data = jsonString.data(using: .utf8),
                       let _ = try? JSONSerialization.jsonObject(with: data) {
                        return data
                    }
                    break
                }
            }
        }

        return nil
    }
}
