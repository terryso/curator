import Foundation

/// Actor implementing the two-stage image analysis pipeline.
///
/// Stage 1 (Local pHash): Computes perceptual hashes and finds candidate similar pairs.
/// Stage 2 (LLM Confirmation): Sends candidate groups to LLM for semantic verification.
/// Stage 3 (Thumbnail Generation): Generates thumbnails for confirmed duplicate groups.
///
/// All analysis operations run within the actor's isolation context,
/// ensuring thread safety without blocking the main thread.
actor ImageAnalysisPipeline: ImageAnalysisPipelineProtocol {
    private let hasher: any PerceptualHasherProtocol
    private let llmGateway: any LLMGatewayProtocol
    private let thumbnailGenerator: any ThumbnailGeneratorProtocol

    /// Hamming distance threshold for pHash similarity.
    private let hashThreshold: Int

    /// Maximum number of assets allowed in a single candidate group.
    /// Groups exceeding this limit are split to control memory usage during LLM confirmation.
    private let maxGroupSize: Int

    /// LLM model identifier for duplicate analysis.
    private let llmModel: String

    /// Target size for generated thumbnails.
    private let thumbnailSize: CGSize

    /// Creates a new ImageAnalysisPipeline.
    ///
    /// - Parameters:
    ///   - hasher: Perceptual hash engine for local similarity detection.
    ///   - llmGateway: LLM gateway for semantic confirmation.
    ///   - thumbnailGenerator: Thumbnail generator for preview images.
    ///   - hashThreshold: Hamming distance threshold for pHash (default: 10).
    ///   - llmModel: LLM model to use for confirmation (default: "claude-sonnet-4-20250514").
    ///   - thumbnailSize: Target thumbnail dimensions (default: 200x200).
    ///   - maxGroupSize: Maximum assets per candidate group (default: 10, for memory control).
    init(
        hasher: any PerceptualHasherProtocol,
        llmGateway: any LLMGatewayProtocol,
        thumbnailGenerator: any ThumbnailGeneratorProtocol,
        hashThreshold: Int = 10,
        llmModel: String = "claude-sonnet-4-20250514",
        thumbnailSize: CGSize = CGSize(width: 200, height: 200),
        maxGroupSize: Int = 10
    ) {
        self.hasher = hasher
        self.llmGateway = llmGateway
        self.thumbnailGenerator = thumbnailGenerator
        self.hashThreshold = hashThreshold
        self.llmModel = llmModel
        self.thumbnailSize = thumbnailSize
        self.maxGroupSize = maxGroupSize
    }

    // MARK: - ImageAnalysisPipelineProtocol

    func analyze(
        assets: [PhotoAsset],
        repository: PhotoLibraryRepository
    ) async throws -> [DuplicateGroup] {
        try await analyze(assets: assets, repository: repository, progressHandler: nil)
    }

    func analyze(
        assets: [PhotoAsset],
        repository: PhotoLibraryRepository,
        progressHandler: (@Sendable (AnalysisProgress) -> Void)?
    ) async throws -> [DuplicateGroup] {
        // Stage 1: Local pHash filtering
        let report: (AnalysisStage, Int, Int) -> Void = { stage, completed, total in
            progressHandler?(AnalysisProgress(stage: stage, completed: completed, total: total))
        }

        report(.hashing, 0, assets.count)
        let hashes = try await hasher.computeHashes(for: assets, repository: repository)
        report(.hashing, assets.count, assets.count)

        try Task.checkCancellation()

        report(.pairComparison, 0, hashes.count)
        let similarPairs = await hasher.findSimilarPairs(hashes: hashes, threshold: hashThreshold)
        report(.pairComparison, hashes.count, hashes.count)

        try Task.checkCancellation()

        // Cluster pairs into connected component groups
        let candidateGroups = clusterPairsIntoGroups(similarPairs: similarPairs, assets: assets)

        guard !candidateGroups.isEmpty else {
            report(.completed, 0, 0)
            return []
        }

        // Stage 2: LLM semantic confirmation
        report(.llmConfirmation, 0, candidateGroups.count)
        var confirmedGroups: [(assets: [PhotoAsset], reason: String, confidence: Double)] = []
        var failedGroups: [(assets: [PhotoAsset], reason: String)] = []

        for (index, group) in candidateGroups.enumerated() {
            try Task.checkCancellation()

            do {
                let images = try await loadImages(for: group, repository: repository)
                let prompt = buildLLMPrompt(assetCount: group.count)
                let response = try await llmGateway.analyze(images: images, prompt: prompt, model: llmModel)

                if let parsed = parseLLMResponse(response.text), parsed.isDuplicate {
                    confirmedGroups.append((
                        assets: group,
                        reason: parsed.reason,
                        confidence: parsed.confidence
                    ))
                }

                report(.llmConfirmation, index + 1, candidateGroups.count)
            } catch {
                // LLM failure for this group — mark as analysisFailed, continue with others
                failedGroups.append((assets: group, reason: error.localizedDescription))
                report(.llmConfirmation, index + 1, candidateGroups.count)
                continue
            }
        }

        try Task.checkCancellation()

        // Stage 3: Thumbnail generation
        report(.thumbnailGeneration, 0, confirmedGroups.count)
        var results: [DuplicateGroup] = []

        for (index, confirmed) in confirmedGroups.enumerated() {
            try Task.checkCancellation()

            let thumbnails = await thumbnailGenerator.generateThumbnails(
                for: confirmed.assets,
                repository: repository,
                targetSize: thumbnailSize
            )

            let group = DuplicateGroup(
                assets: confirmed.assets,
                similarityScore: confirmed.confidence,
                reason: confirmed.reason,
                thumbnails: thumbnails,
                status: .pending
            )
            results.append(group)

            report(.thumbnailGeneration, index + 1, confirmedGroups.count)
        }

        // Append failed groups as .analysisFailed for downstream visibility
        for failed in failedGroups {
            let group = DuplicateGroup(
                assets: failed.assets,
                similarityScore: 0.0,
                reason: failed.reason,
                status: .analysisFailed
            )
            results.append(group)
        }

        // Sort by similarity score descending
        results.sort()

        report(.completed, results.count, results.count)

        return results
    }

    // MARK: - Connected Component Clustering

    /// Clusters pairwise similarities into disjoint groups using BFS.
    ///
    /// For example, given A-B and B-C similarities, produces [A, B, C] as one group.
    private func clusterPairsIntoGroups(
        similarPairs: [PairwiseSimilarity],
        assets: [PhotoAsset]
    ) -> [[PhotoAsset]] {
        guard !similarPairs.isEmpty else { return [] }

        // Build adjacency map
        var adjacency: [AssetID: Set<AssetID>] = [:]
        for pair in similarPairs {
            adjacency[pair.assetID1, default: []].insert(pair.assetID2)
            adjacency[pair.assetID2, default: []].insert(pair.assetID1)
        }

        // Build asset lookup
        var assetMap: [AssetID: PhotoAsset] = [:]
        for asset in assets {
            assetMap[asset.id] = asset
        }

        // BFS to find connected components
        var visited: Set<AssetID> = []
        var groups: [[PhotoAsset]] = []

        for (node, _) in adjacency {
            if visited.contains(node) { continue }

            var group: [PhotoAsset] = []
            var queue: [AssetID] = [node]
            visited.insert(node)

            while !queue.isEmpty {
                let current = queue.removeFirst()
                if let asset = assetMap[current] {
                    group.append(asset)
                }

                for neighbor in adjacency[current] ?? [] {
                    if !visited.contains(neighbor) {
                        visited.insert(neighbor)
                        queue.append(neighbor)
                    }
                }
            }

            if !group.isEmpty {
                // Split oversized groups to control memory during LLM confirmation
                if group.count > maxGroupSize {
                    for chunkStart in stride(from: 0, to: group.count, by: maxGroupSize) {
                        let end = min(chunkStart + maxGroupSize, group.count)
                        groups.append(Array(group[chunkStart..<end]))
                    }
                } else {
                    groups.append(group)
                }
            }
        }

        return groups
    }

    // MARK: - LLM Integration

    /// Loads full-resolution images for a group of assets.
    private func loadImages(
        for assets: [PhotoAsset],
        repository: PhotoLibraryRepository
    ) async throws -> [Data] {
        var images: [Data] = []
        for asset in assets {
            let data = try await repository.fetchFullResolutionImage(for: asset.id)
            images.append(data)
        }
        return images
    }

    /// Constructs the LLM prompt for duplicate analysis.
    private func buildLLMPrompt(assetCount: Int) -> String {
        """
        你是照片去重专家。请判断以下 \(assetCount) 张照片是否为重复照片（即同一场景的不同版本、副本、裁剪或压缩版本）。

        规则：
        - 连拍照片（同一场景但不同瞬间）**不是**重复
        - 同一场景的不同曝光/焦距版本**是**重复
        - 完全相同或仅经过缩放/压缩的**是**重复

        请以 JSON 格式回复：
        {
          "isDuplicate": true/false,
          "reason": "简要说明判断原因",
          "confidence": 0.0-1.0
        }
        """
    }

    /// Parses the LLM response text to extract duplicate analysis result.
    private func parseLLMResponse(_ text: String) -> (isDuplicate: Bool, reason: String, confidence: Double)? {
        // Try to extract JSON from the response
        guard let jsonData = extractJSON(from: text),
              let jsonObject = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            return nil
        }

        guard let isDuplicate = jsonObject["isDuplicate"] as? Bool else { return nil }

        let reason = jsonObject["reason"] as? String ?? "No reason provided"
        let confidence = jsonObject["confidence"] as? Double ?? 0.5

        return (isDuplicate: isDuplicate, reason: reason, confidence: confidence)
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
        // This handles markdown code fences, prose before/after, and nested objects
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
