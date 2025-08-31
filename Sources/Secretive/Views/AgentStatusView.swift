import SwiftUI

struct AgentStatusView: View {

    @Environment(\.agentStatusChecker) private var agentStatusChecker: any AgentStatusCheckerProtocol
    private let socketPath = (NSHomeDirectory().replacingOccurrences(of: Bundle.hostBundleID, with: Bundle.agentBundleID) as NSString).appendingPathComponent("socket.ssh") as String

    var body: some View {
        if agentStatusChecker.running {
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
                    VStack(alignment: .leading) {
                        Text(.agentRunningNoticeDetailDescription)
                        HStack {
                            Spacer()
                            Menu("Restart Agent") {
                                Button("Disable Agent") {
                                    Task {
                                        await LaunchAgentController()
                                            .uninstall()
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
        } else {
            Form {
                Section {
                } header: {
                    Text(.agentNotRunningNoticeTitle)
                        .font(.headline)
                        .padding(.top)
                } footer: {
                    Text(.agentNotRunningNoticeDetailDescription)
                    Spacer()
                    HStack {
                        Spacer()
                        Button("Start Agent") {
                            Task {
                                let controller = LaunchAgentController()
                                let installed = await controller.install()
                                if !installed {
                                    _ = await controller.forceLaunch()
                                }
                                agentStatusChecker.check()
                            }
                        }
                        .primary()
                    }
                    .padding(.vertical)
                }
            }
            .formStyle(.grouped)
            .frame(width: 400)
        }
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
