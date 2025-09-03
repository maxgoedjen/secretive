import SwiftUI

struct AgentStatusView: View {

    @Environment(\.agentStatusChecker) private var agentStatusChecker: any AgentStatusCheckerProtocol

    var body: some View {
        if agentStatusChecker.running {
            AgentRunningView()
        } else {
            AgentNotRunningView()
        }
    }
}
struct AgentRunningView: View {

    @Environment(\.agentStatusChecker) private var agentStatusChecker: any AgentStatusCheckerProtocol

    var body: some View {
        Form {
            Section {
                if let process = agentStatusChecker.process {
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
                                    _ = await LaunchAgentController()
                                        .uninstall()
                                    agentStatusChecker.check()
                                }
                            }
                        } primaryAction: {
                            Task {
                                let controller = LaunchAgentController()
                                let installed = await controller.install()
                                if !installed {
                                    _ = await controller.forceLaunch()
                                }
                                agentStatusChecker.check()
                            }
                        }
                    }
                }
                .padding(.vertical)
            }

        }
        .formStyle(.grouped)
        .frame(width: 400)
    }

}

struct AgentNotRunningView: View {

    @Environment(\.agentStatusChecker) private var agentStatusChecker: any AgentStatusCheckerProtocol
    @State var triedRestart = false
    @State var loading = false

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
                    HStack {
                        if !triedRestart {
                            Spacer()
                            Button {
                                guard !loading else { return }
                                loading = true
                                Task {
                                    let controller = LaunchAgentController()
                                    let installed = await controller.install()
                                    if !installed {
                                        _ = await controller.forceLaunch()
                                    }
                                    agentStatusChecker.check()
                                    loading = false

                                    if !agentStatusChecker.running {
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
        .frame(width: 400)
    }

}

#Preview {
    AgentStatusView()
        .environment(\.agentStatusChecker, PreviewAgentStatusChecker(running: false))
}
#Preview {
    AgentStatusView()
        .environment(\.agentStatusChecker, PreviewAgentStatusChecker(running: true, process: .current))
}
