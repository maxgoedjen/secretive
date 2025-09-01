import SwiftUI

struct IntegrationsView: View {

    @Environment(\.dismiss) private var dismiss

    @State private var selectedInstruction: ConfigurationFileInstructions?

    private let socketPath = (NSHomeDirectory().replacingOccurrences(of: Bundle.hostBundleID, with: Bundle.agentBundleID) as NSString).appendingPathComponent("socket.ssh") as String

    private var instructions: [ConfigurationGroup] {
        [
            ConfigurationGroup(name:"Integrations", instructions: [
                ConfigurationFileInstructions("Getting Started", id: .gettingStarted),
            ]),
            ConfigurationGroup(name: "System", instructions: [
                ConfigurationFileInstructions(
                    tool: "ssh",
                    configPath: "~/.ssh/config",
                    configText: "Host *\n\tIdentityAgent \(socketPath)",
                    website: URL(string: "https://man.openbsd.org/ssh_config.5")!,
                ),
                ConfigurationFileInstructions(
                    tool: "git",
                    configPath: "~/.gitconfig",
                    configText: "PLACEHOLDER",
                    website: URL(string: "https://git-scm.com/docs/git-config")!
                )
            ]),
            ConfigurationGroup(name: "Shell", instructions: [
                ConfigurationFileInstructions(
                    tool: "zsh",
                    configPath: "~/.zshrc",
                    configText: "export SSH_AUTH_SOCK=\(socketPath)"
                ),
                ConfigurationFileInstructions(
                    tool: "bash",
                    configPath: "~/.bashrc",
                    configText: "export SSH_AUTH_SOCK=\(socketPath)"
                ),
                ConfigurationFileInstructions(
                    tool: "fish",
                    configPath: "~/.config/fish/config.fish",
                    configText: "set -x SSH_AUTH_SOCK \(socketPath)"
                ),
                ConfigurationFileInstructions("other", id: .otherShell),
            ]),
            ConfigurationGroup(name:"Apps", instructions: [
                ConfigurationFileInstructions("Other", id: .otherApp),
            ]),
        ]
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedInstruction) {
                ForEach(instructions) { group in
                    Section(group.name) {
                        ForEach(group.instructions) { instruction in
                            Text(instruction.tool)
                                .padding(.vertical, 8)
                                .tag(instruction)
                        }
                    }
                }
            }
        } detail: {
            if let selectedInstruction {
                Form {
                    switch selectedInstruction.id {
                    case .gettingStarted:
                        Text("TBD")
                    case .tool:
                        Section(selectedInstruction.tool) {
                            ConfigurationItemView(title: "Configuration File", value: selectedInstruction.configPath, action: .revealInFinder( selectedInstruction.configPath))
                            ConfigurationItemView(title: "Add This:", action: .copy(selectedInstruction.configText)) {
                                HStack {
                                    Text(selectedInstruction.configText)
                                        .padding(8)
                                        .font(.system(.subheadline, design: .monospaced))
                                    Spacer()
                                }
                                .frame(maxWidth: .infinity)
                                .background {
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(.black.opacity(0.05))
                                        .stroke(.separator, lineWidth: 1)
                                }
                            }
                        }
                        if let url = selectedInstruction.website {
                            Section {
                                Link(destination: url) {
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text("View Documentation on Web")
                                            .font(.headline)
                                        Text(url.absoluteString)
                                            .font(.caption2)
                                    }
                                }
                            }
                        }
                    case .otherShell:
                        Section {
                            Link("View on GitHub", destination: URL(string: "https://github.com/maxgoedjen/secretive-config-instructions/tree/main/shells")!)
                        } header: {
                            Text("There's a community-maintained list of shell instructions on GitHub. If the shell you're looking for isn't supported, create an issue and the community may be able to help.")
                                .font(.body)
                        }
                    case .otherApp:
                        Section {
                            Link("View on GitHub", destination: URL(string: "https://github.com/maxgoedjen/secretive-config-instructions/tree/main/apps")!)
                        } header: {
                            Text("There's a community-maintained list of instructions for apps on GitHub. If the app you're looking for isn't supported, create an issue and the community may be able to help.")
                                .font(.body)
                        }
                    }
                }
                .formStyle(.grouped)
            }
        }
        .onAppear {
            selectedInstruction = instructions.first?.instructions.first
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Done") {
                    dismiss()
                }
                .styled
            }
        }
    }

}

struct ConfigurationGroup: Identifiable {
    let id = UUID()
    var name: LocalizedStringResource
    var instructions: [ConfigurationFileInstructions] = []
}

struct ConfigurationFileInstructions: Identifiable, Hashable {

    var id: ID
    var tool: String
    var configPath: String
    var configText: String
    var website: URL?

    init(tool: String, configPath: String, configText: String, website: URL? = nil) {
        self.id = .tool(tool)
        self.tool = tool
        self.configPath = configPath
        self.configText = configText
        self.website = website
    }

    init(_ name: LocalizedStringResource, id: ID) {
        self.id = id
        tool = String(localized: name)
        configPath = ""
        configText = ""
    }

    enum ID: Identifiable, Hashable {
        case gettingStarted
        case tool(String)
        case otherShell
        case otherApp

        var id: String {
            switch self {
            case .gettingStarted:
                "getting_started"
            case .tool(let name):
                name
            case .otherShell:
                "other_shell"
            case .otherApp:
                "other_app"
            }
        }
    }

}


#Preview {
    IntegrationsView()
        .frame(height: 500)
}
