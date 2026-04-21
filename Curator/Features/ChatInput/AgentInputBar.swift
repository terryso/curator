import SwiftUI

/// Bottom-fixed input bar for Agent interaction.
///
/// Provides a text field for natural language instructions with Enter to submit
/// and Shift+Enter for newlines. Displays a loading indicator and cancel button
/// during Agent execution.
///
/// AC1: Bottom-fixed single-line input (default), Enter submit, Shift+Enter newline.
/// AC4: Disabled input with loading indicator during Agent execution.
struct AgentInputBar: View {

    /// The ViewModel managing input state and Agent execution.
    @Bindable var viewModel: ChatInputViewModel

    /// Focus state for the text field.
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            if viewModel.isAgentRunning {
                agentRunningView
            } else {
                normalInputView
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
    }

    // MARK: - Normal Input State

    /// Input field + send button when Agent is idle.
    private var normalInputView: some View {
        HStack(spacing: 8) {
            TextField(
                "试试'找出所有重复照片'...",
                text: $viewModel.inputText,
                axis: .vertical
            )
            .lineLimit(1...5)
            .textFieldStyle(.plain)
            .focused($isTextFieldFocused)
            .onKeyPress { press in
                guard press.key == .return else { return .ignored }
                if press.modifiers.contains(.shift) {
                    return .ignored // Allow Shift+Enter newline
                }
                viewModel.submitInput()
                return .handled
            }
            .accessibilityLabel("Agent instruction input")
            .accessibilityHint("Type a natural language instruction and press Enter to submit")

            // Send button
            Button {
                viewModel.submitInput()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundStyle(viewModel.isInputEnabled ? Color.accentColor : .secondary)
            }
            .disabled(!viewModel.isInputEnabled)
            .buttonStyle(.plain)
            .accessibilityLabel("Send instruction")
        }
    }

    // MARK: - Agent Running State

    /// Disabled input with progress indicator + cancel button when Agent is running.
    private var agentRunningView: some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)

            Text("Agent 正在工作中...")
                .font(.body)
                .foregroundStyle(.secondary)

            Spacer()

            // Cancel button
            Button {
                viewModel.cancelExecution()
            } label: {
                Label("Cancel", systemImage: "xmark.circle.fill")
                    .font(.body)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .accessibilityLabel("Cancel Agent execution")
            .accessibilityHint("Stop the currently running Agent task")
        }
    }
}
