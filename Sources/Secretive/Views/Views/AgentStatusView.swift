import SwiftUI
import Common

struct AgentStatusView: View {

    @Environment(\.agentLaunchController) private var agentLaunchController: any AgentLaunchControllerProtocol

    var body: some View {
        if agentLaunchController.running {
            AgentRunningView()
        } else {
            AgentNotRunningView()
        }
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
                        Spacer()
                        Menu(.agentDetailsRestartAgentButton) {
                            Button(.agentDetailsDisableAgentButton) {
                                Task {
                                    explicitlyDisabled = true
                                    try? await agentLaunchController
                                        .uninstall()
                                }
                            }
                        } primaryAction: {
                            Task {
                                try? await agentLaunchController.forceLaunch()
                            }
                        }
                    }
                }
                .padding(.vertical)
            }

        }
        .formStyle(.grouped)
        .frame(width: 440)
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
                    HStack(spacing: 8) {
                        if !triedRestart {
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
                        } else {
                            Text(.agentDetailsCouldNotStartError)
                                .bold()
                                .foregroundStyle(.red)
                        }
                    }
                }
                .padding(.bottom)
            }
        }
        .formStyle(.grouped)
        .frame(width: 440)
    }

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
