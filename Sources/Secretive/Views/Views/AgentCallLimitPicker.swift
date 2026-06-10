import SwiftUI
import Common

private enum AgentCallLimitSelection: Hashable {
    case unlimited
    case preset(Int)
    case custom
}

struct AgentCallLimitPicker: View {

    @State private var selection: AgentCallLimitSelection
    @State private var customValue = ""
    @FocusState private var customFieldFocused: Bool

    init() {
        let state = AgentCallLimitSettings.load()
        if state.limit == AgentCallLimitSettings.unlimited {
            _selection = State(initialValue: .unlimited)
        } else if (1...5).contains(state.limit) {
            _selection = State(initialValue: .preset(state.limit))
            _customValue = State(initialValue: "")
        } else {
            _selection = State(initialValue: .custom)
            _customValue = State(initialValue: String(state.limit))
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            Text(.agentDetailsCallLimitLabel)
                .font(.body)
                .foregroundStyle(.primary)
            Picker("", selection: $selection) {
                Text(.agentDetailsCallLimitUnlimited)
                    .tag(AgentCallLimitSelection.unlimited)
                ForEach(1...5, id: \.self) { count in
                    Text(verbatim: String(count))
                        .tag(AgentCallLimitSelection.preset(count))
                }
                Text(.agentDetailsCallLimitCustom)
                    .tag(AgentCallLimitSelection.custom)
            }
            .labelsHidden()
            .font(.body)
            .foregroundStyle(.primary)
            .fixedSize()
            .onChange(of: selection) { _, newSelection in
                if newSelection == .custom {
                    customFieldFocused = true
                }
                commitCurrentSelection()
            }

            if selection == .custom {
                TextField("", text: $customValue, prompt: Text(.agentDetailsCallLimitCustomPrompt))
                    .font(.body)
                    .frame(width: 44)
                    .multilineTextAlignment(.trailing)
                    .focused($customFieldFocused)
                    .onSubmit(commitCustomValue)
                    .onChange(of: customValue) { _, newValue in
                        let filtered = newValue.filter(\.isNumber)
                        if filtered != newValue {
                            customValue = filtered
                        }
                        commitCustomValue()
                    }
            }
        }
    }

    private func persistLimit(_ limit: Int) {
        AgentCallLimitSettings.setLimit(limit)
    }

    private var resolvedCustomCount: Int? {
        guard let value = Int(customValue), (1...AgentCallLimitSettings.maxLimit).contains(value) else {
            return nil
        }
        return value
    }

    private func commitCustomValue() {
        guard selection == .custom, let count = resolvedCustomCount else { return }
        persistLimit(count)
    }

    private func commitCurrentSelection() {
        switch selection {
        case .unlimited:
            persistLimit(AgentCallLimitSettings.unlimited)
        case .preset(let count):
            persistLimit(count)
        case .custom:
            commitCustomValue()
        }
    }

}
