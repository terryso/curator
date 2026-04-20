import SwiftUI

/// Cost estimate card showing projected LLM API costs before execution.
///
/// Displays estimated API calls, cost, and selected model.
/// Supports model switching to compare costs across different models.
/// Intended for use in the settings panel and (future) agent execution preview.
struct CostEstimateCard: View {
    let gateway: any LLMGatewayProtocol
    let imageCount: Int
    @State private var selectedModel: String
    @State private var estimate: CostEstimate?

    init(gateway: any LLMGatewayProtocol, imageCount: Int, selectedModel: String = LLMModelID.claudeSonnet.rawValue) {
        self.gateway = gateway
        self.imageCount = imageCount
        self._selectedModel = State(initialValue: selectedModel)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Cost Estimate")
                .font(.headline)

            // Model picker
            Picker("Model", selection: $selectedModel) {
                ForEach(LLMModelID.allCases, id: \.rawValue) { model in
                    Text(modelDisplayName(model)).tag(model.rawValue)
                }
            }
            .labelsHidden()

            if let estimate {
                LabeledContent("Provider", value: estimate.providerName)
                LabeledContent("Estimated Calls", value: "\(estimate.estimatedAPICalls)")
                LabeledContent("Estimated Tokens", value: formatNumber(estimate.estimatedTokens))
                LabeledContent("Estimated Cost", value: formatUSD(estimate.estimatedCost))
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .background(.background.secondary, in: .rect(cornerRadius: 8))
        .task { await loadEstimate() }
        .onChange(of: selectedModel) { _, _ in
            Task { await loadEstimate() }
        }
    }

    // MARK: - Private

    private func loadEstimate() async {
        estimate = await gateway.estimateCost(imageCount: imageCount, model: selectedModel)
    }

    /// Formats a USD amount with 4 decimal places and thousands separator.
    private func formatUSD(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.minimumFractionDigits = 4
        formatter.maximumFractionDigits = 4
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "$%.4f", value)
    }

    /// Formats an integer with thousands separator.
    private func formatNumber(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    /// Returns a human-readable display name for a model identifier.
    private func modelDisplayName(_ model: LLMModelID) -> String {
        switch model {
        case .claudeSonnet: return "Claude Sonnet 4"
        case .claudeHaiku: return "Claude Haiku 4"
        case .gpt4o: return "GPT-4o"
        case .gpt4oMini: return "GPT-4o Mini"
        case .deepseekChat: return "DeepSeek Chat"
        }
    }
}

#Preview {
    CostEstimateCard(
        gateway: LLMGateway(providers: []),
        imageCount: 50
    )
    .frame(width: 300)
}
