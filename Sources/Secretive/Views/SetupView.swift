import SwiftUI

struct SetupView: View {

    @Binding var visible: Bool
    @Binding var setupComplete: Bool
    
    @State var installed = false
    @State var updates = false
    @State var sshConfig = false

    var body: some View {
        VStack {
            VStack(spacing: 0) {
                NewStepView(
                    title: "setup_agent_title",
                    description: "setup_agent_description",
                    systemImage: "lock.laptopcomputer",
                ) {
                    OnboardingButton("setup_agent_install_button", installed) {
                        Task {
                            installed = await LaunchAgentController().install()
                        }
                    }
                }
                Divider()
                NewStepView(
                    title: "setup_updates_title",
                    description: "setup_updates_description",
                    systemImage: "network.badge.shield.half.filled",
                ) {
                    OnboardingButton("setup_updates_ok", updates) {
                        Task {
                            updates = true
                        }
                    }
                }
                Divider()
                NewStepView(
                    title: "setup_ssh_title",
                    description: "setup_ssh_description",
                    systemImage: "network.badge.shield.half.filled",
                ) {
                    HStack {
                        OnboardingButton("Configure", false) {
//                            sshConfig = true
                        }
                    }
                }
            }
            .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
            .frame(minWidth: 700, maxWidth: .infinity)
            HStack {
                Spacer()
                Button("Done") {}
                    .styled
            }
        }
        .padding()
    }
}

struct OnboardingButton: View {

    let label: LocalizedStringResource
    let complete: Bool
    let action: () -> Void
    
    init(_ label: LocalizedStringResource, _ complete: Bool, action: @escaping () -> Void) {
        self.label = label
        self.complete = complete
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(label)
                if complete {
                    Image(systemName: "checkmark.circle.fill")
                }
            }
            .padding(.vertical, 2)
        }
        .disabled(complete)
        .styled
    }
        
}

extension View {
    
    @ViewBuilder
    var styled: some View {
        if #available(macOS 26.0, *) {
            buttonStyle(.glassProminent)
        } else {
            buttonStyle(.borderedProminent)
        }
    }
    
}

struct NewStepView<Content: View>: View {
    
    let title: LocalizedStringResource
    let icon: Image
    let description: LocalizedStringResource
    let actions: Content
    
    init(title: LocalizedStringResource, description: LocalizedStringResource, systemImage: String, actions: () -> Content) {
        self.title = title
        self.icon = Image(systemName: systemImage)
        self.description = description
        self.actions = actions()
    }
    
    var body: some View {
        HStack(spacing: 20) {
            icon
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .bold()
                Text(description)
            }
            actions
        }
        .padding(20)
    }
    
}

//struct SSHAgentSetupView: View {
//
//    let buttonAction: () -> Void
//
//    @State private var selectedShellInstruction: ShellConfigInstruction?
//
//    private let socketPath = (NSHomeDirectory().replacingOccurrences(of: Bundle.hostBundleID, with: Bundle.agentBundleID) as NSString).appendingPathComponent("socket.ssh") as String
//
//    private var shellInstructions: [ShellConfigInstruction] {
//        [
//            ShellConfigInstruction(shell: "global",
//                                   shellConfigDirectory: "~/.ssh/",
//                                   shellConfigFilename: "config",
//                                   text: "Host *\n\tIdentityAgent \(socketPath)"),
//            ShellConfigInstruction(shell: "zsh",
//                                   shellConfigDirectory: "~/",
//                                   shellConfigFilename: ".zshrc",
//                                   text: "export SSH_AUTH_SOCK=\(socketPath)"),
//            ShellConfigInstruction(shell: "bash",
//                                   shellConfigDirectory: "~/",
//                                   shellConfigFilename: ".bashrc",
//                                   text: "export SSH_AUTH_SOCK=\(socketPath)"),
//            ShellConfigInstruction(shell: "fish",
//                                   shellConfigDirectory: "~/.config/fish",
//                                   shellConfigFilename: "config.fish",
//                                   text: "set -x SSH_AUTH_SOCK \(socketPath)"),
//        ]
//
//    }
//
//    var body: some View {
//        SetupStepView(title: "setup_ssh_title",
//                      image: Image(systemName: "terminal"),
//                      bodyText: "setup_ssh_description",
//                      buttonTitle: "setup_ssh_added_manually_button",
//                      buttonAction: buttonAction) {
//        Link("setup_third_party_faq_link", destination: URL(string: "https://github.com/maxgoedjen/secretive/blob/main/APP_CONFIG.md")!)
//            Picker(selection: $selectedShellInstruction, label: EmptyView()) {
//                ForEach(SSHAgentSetupView.controller.shellInstructions) { instruction in
//                    Text(instruction.shell)
//                        .tag(instruction)
//                        .padding()
//                }
//            }.pickerStyle(SegmentedPickerStyle())
//            CopyableView(title: "setup_ssh_add_to_config_button_\(selectedShellInstruction.shellConfigPath)", image: Image(systemName: "greaterthan.square"), text: selectedShellInstruction.text)
//            Button("setup_ssh_add_for_me_button") {
//                let controller = ShellConfigurationController()
//                if controller.addToShell(shellInstructions: selectedShellInstruction) {
//                    buttonAction()
//                }
//            }
//        }
//    }
//
//}

extension SetupView {

    enum Constants {
        static let updaterFAQURL = URL(string: "https://github.com/maxgoedjen/secretive/blob/main/FAQ.md#whats-this-network-request-to-github")!
    }

}

struct ShellConfigInstruction: Identifiable, Hashable {

    var shell: String
    var shellConfigDirectory: String
    var shellConfigFilename: String
    var text: String

    var id: String {
        shell
    }

    var shellConfigPath: String {
        return (shellConfigDirectory as NSString).appendingPathComponent(shellConfigFilename)
    }

}

#Preview {
    SetupView(visible: .constant(true), setupComplete: .constant(false))
}

//#Preview {
//    SSHAgentSetupView(buttonAction: {})
//}
