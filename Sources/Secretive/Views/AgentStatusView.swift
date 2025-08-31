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
    private let socketPath = (NSHomeDirectory().replacingOccurrences(of: Bundle.hostBundleID, with: Bundle.agentBundleID) as NSString).appendingPathComponent("socket.ssh") as String

    var body: some View {
        Form {
            Section {
                if let process = agentStatusChecker.process {
                    AgentInformationView(
                        title: "Secret Agent Location",
                        value: process.bundleURL!.path(),
                        actions: [.revealInFinder],
                    )
                    AgentInformationView(
                        title: "Socket Path",
                        value: socketPath,
                        actions: [.copy],
                    )
                    AgentInformationView(
                        title: "Version",
                        value: Bundle(url: process.bundleURL!)!.infoDictionary!["CFBundleShortVersionString"] as! String
                    )
                    if let launchDate = process.launchDate {
                        AgentInformationView(
                            title: "Running Since",
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
                        Menu("Restart Agent") {
                            Button("Disable Agent") {
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
                                    Text("Start Agent")
                                } else {
                                    HStack {
                                        Text("Starting Agent")
                                        ProgressView()
                                            .controlSize(.mini)
                                    }
                                }
                            }
                            .primary()
                        } else {
                            Text("Secretive was unable to get SecretAgent to launch. Please try restarting your Mac, and if that doesn't work, file an issue on GitHub.")
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

struct AgentInformationView: View {

    enum Action {
        case copy
        case revealInFinder
    }

    let title: LocalizedStringResource
    let value: String
    let actions: Set<Action>
    @State var tapping = false

    init(title: LocalizedStringResource, value: String, actions: Set<Action> = []) {
        self.title = title
        self.value = value
        self.actions = actions
    }

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(title)
                Spacer()
                if actions.contains(.revealInFinder) {
                    Button("Reveal in Finder", systemImage: "folder") {
                        NSWorkspace.shared.selectFile(value, inFileViewerRootedAtPath: value)
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                }
                if actions.contains(.copy) {
                    Button("Copy", systemImage: "document.on.document") {
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                }
            }
            Text(value)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
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
