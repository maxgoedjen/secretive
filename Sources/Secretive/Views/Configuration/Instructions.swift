import Foundation

struct Instructions {

    enum Constants {
        static let publicKeyPathPlaceholder = "_PUBLIC_KEY_PATH_PLACEHOLDER_"
        static let publicKeyPlaceholder = "_PUBLIC_KEY_PLACEHOLDER_"
    }

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
                    .integrationsGitStepGitconfigDescription(publicKeyPathPlaceholder: Constants.publicKeyPathPlaceholder)
                ],
                      note: .integrationsGitStepGitconfigSectionNote
                ),
                .init(
                    path: "~/.gitallowedsigners",
                    steps: [
                        LocalizedStringResource(stringLiteral: Constants.publicKeyPlaceholder)
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
    var requiresSecret: Bool
    var website: URL?

    init(
        tool: LocalizedStringResource,
        configPath: String,
        configText: LocalizedStringResource,
        requiresSecret: Bool = false,
        website: URL? = nil,
        note: LocalizedStringResource? = nil
    ) {
        self.id = .tool(String(localized: tool))
        self.tool = tool
        self.steps = [StepGroup(path: configPath, steps: [configText], note: note)]
        self.requiresSecret = requiresSecret
        self.website = website
    }

    init(
        tool: LocalizedStringResource,
        steps: [StepGroup],
        requiresSecret: Bool = false,
        website: URL? = nil
    ) {
        self.id = .tool(String(localized: tool))
        self.tool = tool
        self.steps = steps
        self.requiresSecret = true
        self.website = website
    }

    init(_ name: LocalizedStringResource, id: ID) {
        self.id = id
        tool = name
        steps = []
        requiresSecret = false
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
