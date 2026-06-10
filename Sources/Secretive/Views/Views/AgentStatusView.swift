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
    @State private var disableErrorText: String?

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
                    if let disableErrorText {
                        Text(verbatim: disableErrorText)
                            .errorStyle()
                    }
                    HStack {
                        Button(.agentDetailsRestartAgentButton) {
                            Task {
                                disableErrorText = nil
                                explicitlyDisabled = false
                                try? await agentLaunchController.forceLaunch()
                            }
                        }
                        .primaryButton()
                        Spacer()
                        Button(.agentDetailsDisableAgentButton) {
                            Task {
                                disableErrorText = await disableAgent(
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
    @State private var disableErrorText: String?
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
                    if !explicitlyDisabled && agentLaunchController.isCallLimitExhausted {
                        Text(.agentDetailsCallLimitExhaustedNotice)
                            .foregroundStyle(.secondary)
                    }
                    if let disableErrorText {
                        Text(verbatim: disableErrorText)
                            .errorStyle()
                    }
                    if !triedRestart {
                        HStack(spacing: 8) {
                            AgentCallLimitPicker()
                            Spacer()
                            Button {
                                disableErrorText = nil
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
                                        disableErrorText = await disableAgent(
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
) async -> String? {
    explicitlyDisabled.wrappedValue = true
    do {
        try await agentLaunchController.disable()
        agentLaunchController.check()
        return nil
    } catch {
        explicitlyDisabled.wrappedValue = false
        agentLaunchController.check()
        return error.localizedDescription
    }
}

private struct AgentCallLimitRemainingView: View {

    @Environment(\.agentLaunchController) private var agentLaunchController
    @State private var remaining: Int?

    var body: some View {
        Group {
            if let remaining {
                ConfigurationItemView(
                    title: .agentDetailsCallLimitRemainingTitle,
                    value: String(remaining)
                )
            }
        }
        .onAppear(perform: refresh)
        .onReceive(Timer.publish(every: 2, on: .main, in: .common).autoconnect()) { _ in
            refresh()
        }
    }

    private func refresh() {
        remaining = agentLaunchController.callLimitRemaining
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
