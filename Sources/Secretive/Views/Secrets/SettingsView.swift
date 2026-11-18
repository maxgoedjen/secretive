import SwiftUI
import SettingsKit

struct SettingsView: View {

    enum TabID {
        case general
        case agent
    }

    @Environment(\.settingsStore) var settingsStore
    @State var selection: TabID = .agent

    var body: some View {
        @Bindable var settingsStore = settingsStore
        NavigationSplitView {
            List(selection: $selection) {
                NavigationLink(.settingsAgentTabTitle, value: TabID.agent)
            }
            .toolbar(removing: .sidebarToggle)
        } detail: {
            switch selection {
            case .general:
                // Placeholder
                EmptyView()
            case .agent:
                Form {
                    Section(.settingsMultipleAuthenticationSectionTitle) {
                        Toggle(isOn: $settingsStore.multipleRequestScreenEnabled) {
                            Text(.settingsMultipleAuthenticationEnabledLabel)
                        }
                        Group {
                            Toggle(isOn: $settingsStore.showDockItemWithPendingRequestsScreen) {
                                Text(.settingsMultipleAuthenticationShowsDockIconLabel)
                            }
                            // Value binding here is a hack to get around annoying Stepper behavior where it
                            // won't draw the number of any non-floating point value (ie, ints)
                            Stepper(.settingsMultipleAuthenticationThresholdLabel, value: .init(get: {
                                Double(settingsStore.multipleRequestScreenCountThreshold)
                            }, set: { newValue in
                                settingsStore.multipleRequestScreenCountThreshold = Int(newValue)
                            }), in: 2...100, format: .number)
                        }
                        .disabled(!settingsStore.multipleRequestScreenEnabled)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 480, minHeight: 320)
    }
}
