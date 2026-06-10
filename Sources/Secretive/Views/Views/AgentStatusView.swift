import SwiftUI
import Common

struct AgentStatusView: View {

    @Environment(\.agentLaunchController) private var agentLaunchController: any AgentLaunchControllerProtocol

    var body: some View {
        Group {
            if agentLaunchController.running {
                AgentRunningView()
            } else {
                AgentNotRunningView()
            }
        }
        .frame(width: 440)
        .fixedSize(horizontal: false, vertical: true)
    }
}
struct AgentRunningView: View {

    @Environment(\.agentLaunchController) private var agentLaunchController: any AgentLaunchControllerProtocol
    @AppStorage("explicitlyDisabled") var explicitlyDisabled = false

    var body: some View {
        Form {
            Section {
                if let process = agentLaunchController.process {
                    ConfigurationItemView(
                        title: .agentDetailsLocationTitle,
                        value: process.bundleURL!.path(),
                        action: .revealInFinder(process.bundleURL!.path()),
                    )
                    ConfigurationItemView(
                        title: .agentDetailsSocketPathTitle,
                        value: URL.socketPath,
                        action: .copy(URL.socketPath),
                    )
                    ConfigurationItemView(
                        title: .agentDetailsVersionTitle,
                        value: Bundle(url: process.bundleURL!)!.infoDictionary!["CFBundleShortVersionString"] as! String
                    )
                    if let launchDate = process.launchDate {
                        ConfigurationItemView(
                            title: .agentDetailsRunningSinceTitle,
                            value: launchDate.formatted()
                        )
                    }
                    AgentCallLimitRemainingView()
                }
            } header: {
                Text(.agentRunningNoticeDetailTitle)
                    .font(.headline)
                    .padding(.top)
            } footer: {
                VStack(alignment: .leading, spacing: 10) {
                    Text(.agentRunningNoticeDetailDescription)
                    HStack {
                        Button(.agentDetailsRestartAgentButton) {
                            Task {
                                explicitlyDisabled = false
                                try? await agentLaunchController.forceLaunch()
                            }
                        }
                        .primaryButton()
                        Spacer()
                        Button(.agentDetailsDisableAgentButton) {
                            Task {
                                await disableAgent(
                                    explicitlyDisabled: $explicitlyDisabled,
                                    agentLaunchController: agentLaunchController
                                )
                            }
                        }
                        .danger()
                    }
                }
                .padding(.vertical)
            }

        }
        .formStyle(.grouped)
        .scrollDisabled(true)
    }

}

struct AgentNotRunningView: View {

    @Environment(\.agentLaunchController) private var agentLaunchController
    @State var triedRestart = false
    @State var loading = false
    @AppStorage("explicitlyDisabled") var explicitlyDisabled = false

    var body: some View {
        Form {
            Section {
            } header: {
                Text(.agentNotRunningNoticeTitle)
                    .font(.headline)
                    .padding(.top)
            } footer: {
                VStack(alignment: .leading, spacing: 10) {
                    Text(.agentNotRunningNoticeDetailDescription)
                    if AgentCallLimitSettings.isExhausted() {
                        Text(.agentDetailsCallLimitExhaustedNotice)
                            .foregroundStyle(.secondary)
                    }
                    if !triedRestart {
                        HStack(spacing: 8) {
                            AgentCallLimitPicker()
                            Spacer()
                            Button {
                                explicitlyDisabled = false
                                guard !loading else { return }
                                loading = true
                                Task {
                                    try await agentLaunchController.forceLaunch()
                                    loading = false

                                    if !agentLaunchController.running {
                                        triedRestart = true
                                    }
                                }
                            } label: {
                                if !loading {
                                    Text(.agentDetailsStartAgentButton)
                                } else {
                                    HStack {
                                        Text(.agentDetailsStartAgentButtonStarting)
                                        ProgressView()
                                            .controlSize(.mini)
                                    }
                                }
                            }
                            .primaryButton()
                        }
                        if !explicitlyDisabled && !loading {
                            HStack {
                                Spacer()
                                Button(.agentDetailsDisableAgentButton) {
                                    Task {
                                        await disableAgent(
                                            explicitlyDisabled: $explicitlyDisabled,
                                            agentLaunchController: agentLaunchController
                                        )
                                    }
                                }
                                .danger()
                            }
                        }
                    } else {
                        Text(.agentDetailsCouldNotStartError)
                            .bold()
                            .foregroundStyle(.red)
                    }
                }
                .padding(.bottom)
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
    }

}

@MainActor
private func disableAgent(
    explicitlyDisabled: Binding<Bool>,
    agentLaunchController: any AgentLaunchControllerProtocol
) async {
    explicitlyDisabled.wrappedValue = true
    try? await agentLaunchController.uninstall()
    agentLaunchController.check()
}

private struct AgentCallLimitRemainingView: View {

    @State private var remaining: Int?
    @State private var limit: Int = AgentCallLimitSettings.unlimited

    var body: some View {
        Group {
            if limit > AgentCallLimitSettings.unlimited, let remaining {
                ConfigurationItemView(
                    title: .agentDetailsCallLimitRemainingTitle,
                    value: String(remaining)
                )
            }
        }
        .onAppear(perform: refresh)
    }

    private func refresh() {
        let state = AgentCallLimitSettings.load()
        limit = state.limit
        remaining = state.remaining
    }

}

//#Preview {
//    AgentStatusView()
//        .environment(\.agentLaunchController, PreviewAgentLaunchController(running: false))
//}
//#Preview {
//    AgentStatusView()
//        .environment(\.agentLaunchController, PreviewAgentLaunchController(running: true, process: .current))
//}
