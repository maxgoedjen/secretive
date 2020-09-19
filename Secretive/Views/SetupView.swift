import Foundation
import SwiftUI

struct SetupView: View {
    
    var completion: ((Bool) -> Void)?
    @State var completedSteps: Set<Step> = []
    
    var body: some View {
        Form {
            SetupStepView<Spacer>(text: "Secretive needs to install a helper app to sign requests when the main app isn't running. This app is called \"SecretAgent\" and you might see it in Activity Manager from time to time.",
                                  stepID: .agent,
                                  nestedView: nil,
                                  actionText: "Install") {
                let success = installLaunchAgent()
                if success {
                    completedSteps.insert(.agent)
                }
                return success
            }
            SetupStepView(text: "Add this line to your shell config telling SSH to talk to SecretAgent when it wants to authenticate. Drag this into your config file.",
                          stepID: .shellConfig,
                          nestedView: SetupStepCommandView(instructions: Constants.socketPrompts, selectedShellInstruction: Constants.socketPrompts.first!),
                          actionText: "Added") {
                markAsDone(.shellConfig)
            }
            SetupStepView<Link>(text: "Secretive will periodically check with GitHub to see if there's a new release. If you see any network requests to GitHub, that's why.",
                                stepID: .updateNotice,
                                nestedView: Link("Read more about this here.", destination: Constants.updaterFAQURL),
                                actionText: "Got it") {
                markAsDone(.updateNotice)
            }
            HStack {
                Spacer()
                Button("Finish") {
                    completion?(completedAllSteps)
                }.disabled(!completedAllSteps)
                .padding()
            }
        }.frame(minWidth: 640, minHeight: 400)
    }
    
}

struct SetupStepView<NestedViewType: View>: View {
    
    let text: String
    let stepID: Step
    let nestedView: NestedViewType?
    @State var completed = false
    let actionText: String
    let action: (() -> Bool)
    
    var body: some View {
        Section {
            HStack {
                ZStack {
                    if completed {
                        Circle().foregroundColor(.green)
                            .frame(width: 30, height: 30)
                        Text("✓")
                            .foregroundColor(.white)
                            .bold()
                    } else {
                        Circle().foregroundColor(.blue)
                            .frame(width: 30, height: 30)
                        Text(String(describing: stepID.rawValue + 1))
                            .foregroundColor(.white)
                            .bold()
                    }
                }
                .padding()
                VStack {
                    Text(text)
                        .opacity(completed ? 0.5 : 1)
                        .lineLimit(nil)
                    if nestedView != nil {
                        nestedView!.padding()
                    }
                }
                .padding()
                Button(actionText) {
                    completed = action()
                }.frame(alignment: .trailing)
                .disabled(completed)
                .padding()
            }
        }
    }
}

struct SetupStepCommandView: View {
    
    let instructions: [ShellConfigInstruction]

    @State var selectedShellInstruction: ShellConfigInstruction

    var body: some View {
        TabView(selection: $selectedShellInstruction) {
            ForEach(instructions) { instruction in
                VStack(alignment: .leading) {
                    Text(instruction.text)
                        .lineLimit(nil)
                        .font(.system(.caption, design: .monospaced))
                        .multilineTextAlignment(.leading)
                        .frame(minHeight: 50)
                    HStack {
                        Spacer()
                        Button(action: copy) {
                            Text("Copy")
                        }
                    }
                }.tabItem {
                    Text(instruction.shell)
                }
                .tag(instruction)
                .padding()
            }
        }
        .onDrag {
            return NSItemProvider(item: NSData(data: selectedShellInstruction.text.data(using: .utf8)!), typeIdentifier: kUTTypeUTF8PlainText as String)
        }
    }
    
    func copy() {
        NSPasteboard.general.declareTypes([.string], owner: nil)
        NSPasteboard.general.setString(selectedShellInstruction.text, forType: .string)
    }
    
}

extension SetupView {
    
    func installLaunchAgent() -> Bool {
        LaunchAgentController().install()
    }
    
    func markAsDone(_ step: Step) -> Bool {
        completedSteps.insert(step)
        return true
    }

    var completedAllSteps: Bool {
        completedSteps == Set(Step.allCases)
    }
    
}

extension SetupView {
    
    enum Constants {
        static let socketPath = (NSHomeDirectory().replacingOccurrences(of: "com.maxgoedjen.Secretive.Host", with: "com.maxgoedjen.Secretive.SecretAgent") as NSString).appendingPathComponent("socket.ssh") as String
        static let socketPrompts: [ShellConfigInstruction] = [
            ShellConfigInstruction(shell: "zsh", text: "export SSH_AUTH_SOCK=\(socketPath)"),
            ShellConfigInstruction(shell: "bash", text: "export SSH_AUTH_SOCK=\(socketPath)"),
            ShellConfigInstruction(shell: "fish", text: "set -x SSH_AUTH_SOCK=\(socketPath)"),
        ]
        static let updaterFAQURL = URL(string: "https://github.com/maxgoedjen/secretive/blob/main/FAQ.md#whats-this-network-request-to-github")!
    }
    
}

struct ShellConfigInstruction: Identifiable, Hashable {

    var shell: String
    var text: String

    var id: String {
        shell
    }

}

enum Step: Int, Identifiable, Hashable, CaseIterable {

    case agent, shellConfig, updateNotice

    var id: Int {
        rawValue
    }

}

struct SetupView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            SetupView()
            SetupView()
                .frame(width: 1500, height: 400)
        }
    }
}
