import SwiftUI

struct ConfigurationView: View {

    @Binding var visible: Bool


    let buttonAction: () -> Void

    @State private var selectedShellInstruction: ShellConfigInstruction?

    private let socketPath = (NSHomeDirectory().replacingOccurrences(of: Bundle.hostBundleID, with: Bundle.agentBundleID) as NSString).appendingPathComponent("socket.ssh") as String

    private var shellInstructions: [ShellConfigInstruction] {
        [
            ShellConfigInstruction(shell: "SSH",
                                   shellConfigDirectory: "~/.ssh/",
                                   shellConfigFilename: "config",
                                   text: "Host *\n\tIdentityAgent \(socketPath)"),
            ShellConfigInstruction(shell: "zsh",
                                   shellConfigDirectory: "~/",
                                   shellConfigFilename: ".zshrc",
                                   text: "export SSH_AUTH_SOCK=\(socketPath)"),
            ShellConfigInstruction(shell: "bash",
                                   shellConfigDirectory: "~/",
                                   shellConfigFilename: ".bashrc",
                                   text: "export SSH_AUTH_SOCK=\(socketPath)"),
            ShellConfigInstruction(shell: "fish",
                                   shellConfigDirectory: "~/.config/fish",
                                   shellConfigFilename: "config.fish",
                                   text: "set -x SSH_AUTH_SOCK \(socketPath)"),
        ]

    }

    var body: some View {
        Form {
            Section {
                Picker("Configuring", selection: $selectedShellInstruction) {
                    ForEach(shellInstructions) { instruction in
                        Text(instruction.shell)
                            .tag(instruction)
                            .padding()
                    }
                }
                if let selectedShellInstruction {
                    ConfigurationItemView(title: "Configuration File", value: selectedShellInstruction.shellConfigPath, action: .revealInFinder(selectedShellInstruction.shellConfigPath))
                    ConfigurationItemView(title: "Add This:", action: .copy(selectedShellInstruction.text)) {
                        HStack {
                            Text(selectedShellInstruction.text)
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
                    Button("setup_ssh_add_for_me_button") {
                    }
                }
            } footer: {
                Link("setup_third_party_faq_link", destination: URL(string: "https://github.com/maxgoedjen/secretive/blob/main/APP_CONFIG.md")!)
            }
        }
        .formStyle(.grouped)
        .onAppear {
            selectedShellInstruction = shellInstructions.first
        }
//        }
    }

}

#Preview {
    ConfigurationView(visible: .constant(true)) {}
        .frame(width: 400, height: 300)
}
