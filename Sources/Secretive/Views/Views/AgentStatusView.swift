import SwiftUI

struct AgentStatusView: View {

    @Environment(\.launchService) private var launchService

    var body: some View {
        if launchService.status == .enabled {
            AgentRunningView()
        } else {
            AgentNotRunningView()
        }
    }
}
struct AgentRunningView: View {

    @Environment(\.launchService) private var launchService
    @AppStorage("explicitlyDisabled") var explicitlyDisabled = false

    var body: some View {
        Form {
            Section {
//                if let process = agentLaunchController.process {
//                    ConfigurationItemView(
//                        title: .agentDetailsLocationTitle,
//                        value: process.bundleURL!.path(),
//                        action: .revealInFinder(process.bundleURL!.path()),
//                    )
                    ConfigurationItemView(
                        title: .agentDetailsSocketPathTitle,
                        value: URL.socketPath,
                        action: .copy(URL.socketPath),
                    )
//                    ConfigurationItemView(
//                        title: .agentDetailsVersionTitle,
//                        value: Bundle(url: process.bundleURL!)!.infoDictionary!["CFBundleShortVersionString"] as! String
//                    )
//                    if let launchDate = process.launchDate {
//                        ConfigurationItemView(
//                            title: .agentDetailsRunningSinceTitle,
//                            value: launchDate.formatted()
//                        )
//                    }
//                }
            } header: {
                Text(.agentReadyNoticeDetailTitle)
                    .font(.headline)
                    .padding(.top)
            } footer: {
                VStack(alignment: .leading, spacing: 10) {
                    Text(.agentReadyNoticeDetailDescription)
                    HStack {
                        Spacer()
                        Menu(.agentDetailsRestartAgentButton) {
                            Button(.agentDetailsDisableAgentButton) {
                                Task {
                                    explicitlyDisabled = true
                                    launchService.disable()
                                }
                            }
                        } primaryAction: {
                            Task {
                                launchService.configure()
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

    @State var triedRestart = false
    @State var loading = false
    @AppStorage("explicitlyDisabled") var explicitlyDisabled = false

    var body: some View {
        Form {
            Section {
            } header: {
                Text(.agentNotConfiguredNoticeTitle)
                    .font(.headline)
                    .padding(.top)
            } footer: {
                VStack(alignment: .leading, spacing: 10) {
                    Text(.agentNotConfiguredNoticeDetailDescription)
                    HStack {
                        if !triedRestart {
                            Spacer()
                            Button {
                                explicitlyDisabled = false
                                guard !loading else { return }
                                loading = true
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

//#Preview {
//    AgentStatusView()
//        .environment(\.agentLaunchController, PreviewAgentLaunchController(running: false))
//}
//#Preview {
//    AgentStatusView()
//        .environment(\.agentLaunchController, PreviewAgentLaunchController(running: true, process: .current))
//}
