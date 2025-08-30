import SwiftUI

struct ConfigurationView: View {

    @Binding var visible: Bool

    @State var running = true
    @State var sshConfig = false

    @Environment(\.agentStatusChecker) var agentStatusChecker

    var body: some View {
        VStack(spacing: 0) {
            NewStepView(
                title: "setup_agent_title",
                description: "setup_agent_description",
                systemImage: "network.badge.shield.half.filled",
            ) {
                OnboardingButton("setup_agent_install_button", running) {
                    Task {
                        _ = await LaunchAgentController().forceLaunch()
                        agentStatusChecker.check()
                        running = agentStatusChecker.running
                    }
                }
            }
            Divider()
            Divider()
            NewStepView(
                title: "setup_ssh_title",
                description: "setup_ssh_description",
                systemImage: "network.badge.shield.half.filled",
            ) {
                HStack {
                    OnboardingButton("setup_ssh_added_manually_button", false) {
                        sshConfig = true
                    }
                    OnboardingButton("Add Automatically", false) {
//                        let controller = ShellConfigurationController()
//                        if controller.addToShell(shellInstructions: selectedShellInstruction) {
//                        }
                        sshConfig = true
                    }
                }
            }
        }
        .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
        .frame(minWidth: 500, idealWidth: 500, minHeight: 500, idealHeight: 500)
        .padding()
        .task {
            running = agentStatusChecker.running
        }
    }

}
