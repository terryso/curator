import SwiftUI
import Charts

/// Full cost tracking panel showing monthly and all-time cost summaries.
///
/// Displays aggregated cost data with provider and session breakdowns,
/// time range selection, recent records, and a cost trend chart.
/// Expanded from the simple monthly summary (Story 2.5) to full panel (Story 2.6).
struct CostTrackingSettingsView: View {
    let viewModel: SettingsViewModel

    var body: some View {
        costContent(vm: viewModel)
    }

    private func costContent(vm: SettingsViewModel) -> some View {
        Form {
            // MARK: - Time Range & Summary
            Section {
                timeRangePicker(vm: vm)

                if let summary = currentSummary(vm: vm) {
                    summaryHeader(summary: summary)

                    LabeledContent("Total Calls", value: "\(summary.callCount)")
                    LabeledContent("Input Tokens", value: formatNumber(summary.totalInputTokens))
                    LabeledContent("Output Tokens", value: formatNumber(summary.totalOutputTokens))
                } else {
                    emptyState
                }
            } header: {
                Text(currentSectionTitle(vm: vm))
            }

            // MARK: - Provider Breakdown
            if let summary = currentSummary(vm: vm), !summary.byProvider.isEmpty {
                Section {
                    ForEach(Array(summary.byProvider.sorted(by: { $0.value > $1.value })), id: \.key) { provider, cost in
                        HStack {
                            Text(provider)
                            Spacer()
                            Text(formatUSD(cost))
                                .foregroundStyle(.secondary)
                            if summary.totalCost > 0 {
                                Text(String(format: "%.1f%%", cost / summary.totalCost * 100))
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                } header: {
                    Text("Provider Breakdown")
                }
            }

            // MARK: - Session Breakdown
            if let summary = currentSummary(vm: vm), !summary.bySession.isEmpty {
                Section {
                    ForEach(Array(summary.bySession.sorted(by: { $0.value > $1.value })), id: \.key) { session, cost in
                        HStack {
                            Text(sessionIDDisplay(session))
                                .lineLimit(1)
                            Spacer()
                            Text(formatUSD(cost))
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Session Breakdown")
                }
            }

            // MARK: - Cost Chart
            if let summary = currentSummary(vm: vm), !summary.byProvider.isEmpty {
                Section {
                    costChart(summary: summary)
                        .frame(height: 200)
                } header: {
                    Text("Cost by Provider")
                }
            }

            // MARK: - Recent Records
            Section {
                if vm.recentRecords.isEmpty {
                    Text("No recent records")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(vm.recentRecords) { record in
                        recentRecordRow(record: record)
                    }
                }
            } header: {
                Text("Recent Records")
            }

            // MARK: - Actions
            Section {
                HStack {
                    Spacer()
                    Button("Refresh") {
                        Task {
                            await vm.refreshCostData()
                            await vm.loadRecentRecords()
                        }
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .formStyle(.grouped)
        .task {
            await vm.refreshCostData()
            await vm.loadRecentRecords()
        }
        .task(id: vm.selectedTimeRange) {
            await vm.refreshCostData()
        }
    }

    // MARK: - Subviews

    private func timeRangePicker(vm: SettingsViewModel) -> some View {
        Picker("Time Range", selection: Binding(
            get: { vm.selectedTimeRange },
            set: { vm.selectedTimeRange = $0 }
        )) {
            Text("This Month").tag(CostTimeRange.month)
            Text("All Time").tag(CostTimeRange.all)
        }
        .pickerStyle(.segmented)
    }

    @ViewBuilder
    private func summaryHeader(summary: CostSummary) -> some View {
        HStack {
            Text("Total Cost")
                .font(.headline)
            Spacer()
            Text(formatUSD(summary.totalCost))
                .font(.title2)
                .fontWeight(.semibold)
        }
    }

    private var emptyState: some View {
        HStack {
            Spacer()
            VStack(spacing: 8) {
                Image(systemName: "tray")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text("No cost data available")
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 20)
    }

    @ViewBuilder
    private func recentRecordRow(record: CostRecord) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(record.providerName)
                    .font(.body)
                Text(record.modelID)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(formatUSD(record.costUSD))
                    .font(.body)
                Text(record.timestamp, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func costChart(summary: CostSummary) -> some View {
        let data = summary.byProvider.sorted(by: { $0.value > $1.value }).map { (provider, cost) in
            ProviderCostData(provider: provider, cost: cost)
        }
        Chart(data) { item in
            BarMark(
                x: .value("Cost (USD)", item.cost),
                y: .value("Provider", item.provider)
            )
            .annotation(position: .trailing) {
                Text(formatUSD(item.cost))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .chartXAxis {
            AxisMarks { value in
                if let doubleVal = value.as(Double.self) {
                    AxisValueLabel {
                        Text(formatUSD(doubleVal))
                            .font(.caption2)
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    /// Returns the current summary based on selected time range.
    private func currentSummary(vm: SettingsViewModel) -> CostSummary? {
        switch vm.selectedTimeRange {
        case .month:
            return vm.monthlyCostSummary
        case .all:
            return vm.allTimeSummary
        }
    }

    /// Returns the section title based on selected time range.
    private func currentSectionTitle(vm: SettingsViewModel) -> String {
        switch vm.selectedTimeRange {
        case .month:
            return "Monthly Summary"
        case .all:
            return "All-Time Summary"
        }
    }

    /// Truncates session ID for display.
    private func sessionIDDisplay(_ sessionID: String) -> String {
        if sessionID.count > 12 {
            return String(sessionID.prefix(12)) + "..."
        }
        return sessionID
    }

    /// Formats a USD amount with 4 decimal places and thousands separator.
    private func formatUSD(_ value: Double) -> String {
        return Self.usdFormatter.string(from: NSNumber(value: value)) ?? String(format: "$%.4f", value)
    }

    /// Formats an integer with thousands separator.
    private func formatNumber(_ value: Int) -> String {
        return Self.numberFormatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    /// Shared USD formatter to avoid recreating on every render.
    private static let usdFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.minimumFractionDigits = 4
        formatter.maximumFractionDigits = 4
        return formatter
    }()

    /// Shared number formatter to avoid recreating on every render.
    private static let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter
    }()
}

/// Data point for cost chart visualization.
private struct ProviderCostData: Identifiable, Sendable {
    let id = UUID()
    let provider: String
    let cost: Double
}

#Preview {
    CostTrackingSettingsView(viewModel: SettingsViewModel(dependencies: AppDependencies()))
}
