import SwiftUI
import SecretKit

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
                    Button(.setupDoneButton) {
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
                    Section(.integrationsGettingStartedTitle) {
                        Text(.integrationsGettingStartedTitleDescription)
                    }
                    Section {
                        Group {
                            Text(.integrationsGettingStartedSuggestionSsh)
                                .onTapGesture {
                                    self.selectedInstruction = instructions.ssh
                                }
                            VStack(alignment: .leading, spacing: 5) {
                                Text(.integrationsGettingStartedSuggestionShell)
                                Text(.integrationsGettingStartedSuggestionShellDefault(shellName: String(localized: instructions.defaultShell.tool)))
                                    .font(.caption2)
                            }
                            .onTapGesture {
                                self.selectedInstruction = instructions.defaultShell
                            }
                            Text(.integrationsGettingStartedSuggestionGit)
                                .onTapGesture {
                                    self.selectedInstruction = instructions.git
                                }
                        }
                        .foregroundStyle(.link)

                    } header: {
                        Text(.integrationsGettingStartedWhatShouldIConfigureTitle)
                    }
                    footer: {
                        Text(.integrationsGettingStartedMultipleConfig)
                    }
                }
                .formStyle(.grouped)
                case .tool:
                    Form {
                        ForEach(selectedInstruction.steps) { stepGroup in
                            Section {
                                ConfigurationItemView(title: .integrationsPathTitle, value: stepGroup.path, action: .revealInFinder(stepGroup.path))
                                ForEach(stepGroup.steps, id: \.self.key) { step in
                                    ConfigurationItemView(title: .integrationsAddThisTitle, action: .copy(String(localized: step))) {
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
                                        Text(.integrationsWebLink)
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
                            Link(.integrationsViewOtherGithubLink, destination: URL(string: "https://github.com/maxgoedjen/secretive-config-instructions/tree/main/shells")!)
                        } header: {
                            Text(.integrationsCommunityShellListDescription)
                                .font(.body)
                        }
                    }
                    .formStyle(.grouped)

                case .otherApp:
                    Form {
                        Section {
                            Link(.integrationsViewOtherGithubLink, destination: URL(string: "https://github.com/maxgoedjen/secretive-config-instructions/tree/main/apps")!)
                        } header: {
                            Text(.integrationsCommunityAppsListDescription)
                                .font(.body)
                        }
                    }
                    .formStyle(.grouped)
                }
        }

    }
}

private struct Instructions {

    private let publicKeyPath = PublicKeyFileStoreController(homeDirectory: URL.agentHomeURL).publicKeyPath(for: String(localized: .integrationsPublicKeyPathPlaceholder))

    var defaultShell: ConfigurationFileInstructions {
        zsh
    }

    var gettingStarted: ConfigurationFileInstructions = ConfigurationFileInstructions(.integrationsGettingStartedRowTitle, id: .gettingStarted)

    var ssh: ConfigurationFileInstructions {
        ConfigurationFileInstructions(
            tool: LocalizedStringResource.integrationsToolNameSsh,
            configPath: "~/.ssh/config",
            configText: "Host *\n\tIdentityAgent \(URL.socketPath)",
            website: URL(string: "https://man.openbsd.org/ssh_config.5")!,
            note: .integrationsSshSpecificKeyNote,
        )
    }

    var git: ConfigurationFileInstructions {
        ConfigurationFileInstructions(
            tool: .integrationsToolNameGitSigning,
            steps: [
                .init(path: "~/.gitconfig", steps: [
                    .integrationsGitStepGitconfigDescription(publicKeyPathPlaceholder: publicKeyPath)
                ],
                      note: .integrationsGitStepGitconfigSectionNote
                ),
                .init(
                    path: "~/.gitallowedsigners",
                    steps: [
                        .integrationsPublicKeyPlaceholder
                    ],
                    note: .integrationsGitStepGitallowedsignersDescription
                ),
            ],
            website:  URL(string: "https://git-scm.com/docs/git-config")!,
        )
    }

    var zsh: ConfigurationFileInstructions {
        ConfigurationFileInstructions(
            tool: .integrationsToolNameZsh,
            configPath: "~/.zshrc",
            configText: "export SSH_AUTH_SOCK=\(URL.socketPath)"
        )
    }

    var instructions: [ConfigurationGroup] {
        [
            ConfigurationGroup(name: .integrationsGettingStartedSectionTitle, instructions: [
                gettingStarted
            ]),
            ConfigurationGroup(
                name: .integrationsSystemSectionTitle,
                instructions: [
                    ssh,
                    git,
                ]
            ),
            ConfigurationGroup(name: .integrationsShellSectionTitle, instructions: [
                zsh,
                ConfigurationFileInstructions(
                    tool: .integrationsToolNameBash,
                    configPath: "~/.bashrc",
                    configText: "export SSH_AUTH_SOCK=\(URL.socketPath)"
                ),
                ConfigurationFileInstructions(
                    tool: .integrationsToolNameFish,
                    configPath: "~/.config/fish/config.fish",
                    configText: "set -x SSH_AUTH_SOCK \(URL.socketPath)"
                ),
                ConfigurationFileInstructions(.integrationsOtherShellRowTitle, id: .otherShell),
            ]),
            ConfigurationGroup(name: .integrationsOtherSectionTitle, instructions: [
                ConfigurationFileInstructions(.integrationsAppsRowTitle, id: .otherApp),
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
        let steps: [LocalizedStringResource]
        let note: LocalizedStringResource?
        var id: String { path }

        init(path: String, steps: [LocalizedStringResource], note: LocalizedStringResource? = nil) {
            self.path = path
            self.steps = steps
            self.note = note
        }

        func hash(into hasher: inout Hasher) {
            id.hash(into: &hasher)
        }
    }

    var id: ID
    var tool: LocalizedStringResource
    var steps: [StepGroup]
    var website: URL?

    init(tool: LocalizedStringResource, configPath: String, configText: LocalizedStringResource, website: URL? = nil, note: LocalizedStringResource? = nil) {
        self.id = .tool(String(localized: tool))
        self.tool = tool
        self.steps = [StepGroup(path: configPath, steps: [configText], note: note)]
        self.website = website
    }

    init(tool: LocalizedStringResource, steps: [StepGroup], website: URL? = nil) {
        self.id = .tool(String(localized: tool))
        self.tool = tool
        self.steps = steps
        self.website = website
    }

    init(_ name: LocalizedStringResource, id: ID) {
        self.id = id
        tool = name
        self.steps = []
    }

    func hash(into hasher: inout Hasher) {
        id.hash(into: &hasher)
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
