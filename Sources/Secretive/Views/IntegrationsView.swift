import SwiftUI

struct IntegrationsView: View {

    @Environment(\.dismiss) private var dismiss

    @State private var selectedInstruction: ConfigurationFileInstructions?
    private let instructions = Instructions()

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedInstruction) {
                ForEach(instructions.instructions) { group in
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
                IntegrationsDetailView(selectedInstruction: $selectedInstruction)
                .fauxToolbar {
                    Button("Done") {
                        dismiss()
                    }
                    .normalButton()
                }
        }
        .onAppear {
            selectedInstruction = instructions.gettingStarted
        }
        .frame(minHeight: 500)
    }

}

extension View {

    func fauxToolbar<Content: View>(content: () -> Content) -> some View {
        modifier(FauxToolbarModifier(toolbarContent: content()))
    }

}

struct FauxToolbarModifier<ToolbarContent: View>: ViewModifier {

    var toolbarContent: ToolbarContent

    func body(content: Content) -> some View {
        VStack(alignment: .leading) {
            content
            Divider()
            HStack {
                Spacer()
                toolbarContent
                .padding(.top, 8)
                .padding(.trailing, 16)
                .padding(.bottom, 16)
            }
        }

    }

}

struct IntegrationsDetailView: View {

    @Binding private var selectedInstruction: ConfigurationFileInstructions?
    private let instructions = Instructions()

    init(selectedInstruction: Binding<ConfigurationFileInstructions?>) {
        _selectedInstruction = selectedInstruction
    }

    var body: some View {
        if let selectedInstruction {
            switch selectedInstruction.id {
            case .gettingStarted:
                Form {
                    Section("Configuring Tools for Secretive") {
                        Text("Most tools will try and look for SSH keys on disk in `~/.ssh`. To use Secretive, we need to configure those tools to talk to Secretive instead.")
                    }
                    Section {
                        Group {
                            Text("If you're trying to authenticate with an SSH server or authenticating with a service like GitHub over SSH, configure your SSH client.")
                                .onTapGesture {
                                    self.selectedInstruction = instructions.ssh
                                }
                            VStack(alignment: .leading, spacing: 5) {
                                Text("If you're trying to configure anything your command line runs to use Secretive, configure your shell.")
                                Text("If you don't known what shell you use and haven't changed it, you're probably using `\(instructions.defaultShell.tool)`.")
                                    .font(.caption2)
                            }
                            .onTapGesture {
                                self.selectedInstruction = instructions.defaultShell
                            }
                            Text("If you're trying to sign your git commits, set up Git Signing.")
                                .onTapGesture {
                                    self.selectedInstruction = instructions.git
                                }
                        }
                        .foregroundStyle(.link)

                    } header: {
                        Text("What Should I Configure?")
                    }
                    footer: {
                        Text("You can configure more than one tool, they generally won't interfere with each other.")
                    }
                }
                .formStyle(.grouped)
                case .tool:
                    Form {
                        ForEach(selectedInstruction.steps) { stepGroup in
                            Section {
                                ConfigurationItemView(title: "Configuration File", value: stepGroup.path, action: .revealInFinder(stepGroup.path))
                                ForEach(stepGroup.steps, id: \.self) { step in
                                    ConfigurationItemView(title: "Add This:", action: .copy(step)) {
                                        HStack {
                                            Text(step)
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
                            } footer: {
                                if let note = stepGroup.note {
                                    Text(note)
                                        .font(.caption)
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
                    }
                    .formStyle(.grouped)
                case .otherShell:
                    Form {
                        Section {
                            Link("View on GitHub", destination: URL(string: "https://github.com/maxgoedjen/secretive-config-instructions/tree/main/shells")!)
                        } header: {
                            Text("There's a community-maintained list of shell instructions on GitHub. If the shell you're looking for isn't supported, create an issue and the community may be able to help.")
                                .font(.body)
                        }
                    }
                    .formStyle(.grouped)

                case .otherApp:
                    Form {
                        Section {
                            Link("View on GitHub", destination: URL(string: "https://github.com/maxgoedjen/secretive-config-instructions/tree/main/apps")!)
                        } header: {
                            Text("There's a community-maintained list of instructions for apps on GitHub. If the app you're looking for isn't supported, create an issue and the community may be able to help.")
                                .font(.body)
                        }
                    }
                    .formStyle(.grouped)
                }
        }

    }
}

private struct Instructions {

    private let socketPath = (NSHomeDirectory().replacingOccurrences(of: Bundle.hostBundleID, with: Bundle.agentBundleID) as NSString).appendingPathComponent("socket.ssh") as String


    var defaultShell: ConfigurationFileInstructions {
        zsh
    }

    var gettingStarted: ConfigurationFileInstructions =                 ConfigurationFileInstructions("Getting Started", id: .gettingStarted)

    var ssh: ConfigurationFileInstructions {
        ConfigurationFileInstructions(
            tool: "SSH",
            configPath: "~/.ssh/config",
            configText: "Host *\n\tIdentityAgent \(socketPath)",
            website: URL(string: "https://man.openbsd.org/ssh_config.5")!,
            note: "You can tell SSH to use a specific key for a given host. See the web documentation for more details.",
        )
    }

    var git: ConfigurationFileInstructions {
        ConfigurationFileInstructions(
            tool: "Git Signing",
            steps: [
                .init(path: "~/.gitconfig", steps: [
                    """
                    [user]
                        signingkey = YOUR_PUBLIC_KEY_PATH
                    [commit]
                        gpgsign = true
                    [gpg]
                        format = ssh
                    [gpg "ssh"]
                        allowedSignersFile = ~/.gitallowedsigners
                    """
                ],
                      note: "If any section (like [user]) already exists, just add the entries in the existing section."

                     ),
                .init(
                    path: "~/.gitallowedsigners",
                    steps: [
                        "YOUR_PUBLIC_KEY"
                    ],
                    note: "~/.gitallowedsigners probably does not exist. You'll need to create it."
                ),
            ],
            website:  URL(string: "https://git-scm.com/docs/git-config")!,
        )
    }

    var zsh: ConfigurationFileInstructions {
        ConfigurationFileInstructions(
            tool: "zsh",
            configPath: "~/.zshrc",
            configText: "export SSH_AUTH_SOCK=\(socketPath)"
        )
    }

    var instructions: [ConfigurationGroup] {
        [
            ConfigurationGroup(name:"Integrations", instructions: [
                gettingStarted
            ]),
            ConfigurationGroup(
                name: "System",
                instructions: [
                    ssh,
                    git,
                ]
            ),
            ConfigurationGroup(name: "Shell", instructions: [
                zsh,
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
            ConfigurationGroup(name: "Other", instructions: [
                ConfigurationFileInstructions("Apps", id: .otherApp),
            ]),
        ]
    }

}

struct ConfigurationGroup: Identifiable {
    let id = UUID()
    var name: LocalizedStringResource
    var instructions: [ConfigurationFileInstructions] = []
}

struct ConfigurationFileInstructions: Hashable, Identifiable {

    struct StepGroup: Hashable, Identifiable {
        let path: String
        let steps: [String]
        let note: String?
        var id: String { path }

        init(path: String, steps: [String], note: String? = nil) {
            self.path = path
            self.steps = steps
            self.note = note
        }
    }

    var id: ID
    var tool: String
    var steps: [StepGroup]
    var website: URL?

    init(tool: String, configPath: String, configText: String, website: URL? = nil, note: String? = nil) {
        self.id = .tool(tool)
        self.tool = tool
        self.steps = [StepGroup(path: configPath, steps: [configText], note: note)]
        self.website = website
    }

    init(tool: String, steps: [StepGroup], website: URL? = nil) {
        self.id = .tool(tool)
        self.tool = tool
        self.steps = steps
        self.website = website
    }

    init(_ name: LocalizedStringResource, id: ID) {
        self.id = id
        tool = String(localized: name)
        self.steps = []
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
