import SwiftUI

struct SetupView: View {

    @State var stepIndex = 0
    @Binding var visible: Bool

    var body: some View {
        VStack {
            StepView(numberOfSteps: 3, currentStep: stepIndex)
            GeometryReader { proxy in
                HStack {
                    SecretAgentSetupView(buttonAction: advance)
                        .frame(width: proxy.size.width)
                    SSHAgentSetupView(buttonAction: advance)
                        .frame(width: proxy.size.width)
                    UpdaterExplainerView {
                        visible = false
                    }
                        .frame(width: proxy.size.width)
                }
                .offset(x: -proxy.size.width * CGFloat(stepIndex), y: 0)
                .animation(.spring())
            }
        }
        .frame(idealWidth: 500, idealHeight: 500)
    }

    func advance() {
        stepIndex += 1
    }

}

struct SetupView_Previews: PreviewProvider {

    static var previews: some View {
        Group {
            SetupView(visible: .constant(true))
        }
    }

}

struct StepView: View {

    let numberOfSteps: Int
    let currentStep: Int

    var body: some View {
        ZStack {
            Rectangle()
                .foregroundColor(.blue)
                .frame(height: 5)
            HStack {
                ForEach(0..<numberOfSteps) { index in
                    ZStack {
                        if currentStep > index {
                            Circle()
                                .foregroundColor(.green)
                                .frame(width: 30, height: 30)
                            Text("✓")
                                .foregroundColor(.white)
                                .bold()
                        } else {
                            Circle()
                                .foregroundColor(currentStep == index ? .white : .blue)
                                .frame(width: 30, height: 30)
                            Text(String(describing: index + 1))
                                .foregroundColor(currentStep == index ? .blue : .white)
                                .bold()
                        }
                    }
                    if index < numberOfSteps - 1 {
                        Spacer(minLength: 30)
                    }
                }
            }
        }
        .padding()
    }

}

struct SetupStepView<Content> : View where Content : View {

    let title: String
    let image: Image
    let bodyText: String
    let buttonTitle: String
    let buttonAction: () -> Void
    let content: Content

    init(title: String, image: Image, bodyText: String, buttonTitle: String, buttonAction: @escaping () -> Void = {}, @ViewBuilder content: () -> Content) {
        self.title = title
        self.image = image
        self.bodyText = bodyText
        self.buttonTitle = buttonTitle
        self.buttonAction = buttonAction
        self.content = content()
    }

    var body: some View {
        VStack {
            Text(title)
                .font(.title)
            Spacer()
            image
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 64)
            Spacer()
            Text(bodyText)
                .multilineTextAlignment(.center)
            Spacer()
            content
            Spacer()
            Button(buttonTitle) {
                buttonAction()
            }
        }
        .padding()
    }

}

struct SecretAgentSetupView: View {

    let buttonAction: () -> Void

    var body: some View {
        SetupStepView(title: "Setup Secret Agent",
                     image: Image(nsImage: NSApp.applicationIconImage),
                     bodyText: "Secretive needs to set up a helper app to work properly. It will sign requests from SSH clients in the background, so you don't need to keep the main Secretive app open.",
                     buttonTitle: "Install",
                     buttonAction: install) {
            (Text("This helper app is called ") + Text("Secret Agent").bold().underline() + Text(" and you may see it in Activity Manager from time to time."))
                .multilineTextAlignment(.center)
        }
    }

    func install() {
        _ = LaunchAgentController().install()
        buttonAction()
    }

}

struct SecretAgentSetupView_Previews: PreviewProvider {

    static var previews: some View {
        Group {
            SecretAgentSetupView(buttonAction: {})
        }
    }

}

struct SSHAgentSetupView: View {

    @State var selectedShellInstruction: ShellConfigInstruction = SetupView.Constants.socketPrompts.first!

    let buttonAction: () -> Void

    var body: some View {
        SetupStepView(title: "Configure your SSH Agent",
                     image: Image(systemName: "terminal"),
                     bodyText: "Add this line to your shell config telling SSH to talk to Secret Agent when it wants to authenticate. Drag this into your config file.",
                     buttonTitle: "Done",
                    buttonAction: buttonAction) {
            Picker(selection: $selectedShellInstruction, label: EmptyView()) {
                ForEach(SetupView.Constants.socketPrompts) { instruction in
                    Text(instruction.shell)
                        .tag(instruction)
                        .padding()
                }
            }.pickerStyle(SegmentedPickerStyle())
            CopyableView(title: "Add to \(selectedShellInstruction.shellConfigPath)", image: Image(systemName: "greaterthan.square"), text: selectedShellInstruction.text)
        }
    }

}

struct SSHAgentSetupView_Previews: PreviewProvider {

    static var previews: some View {
        Group {
            SSHAgentSetupView(buttonAction: {})
        }
    }

}


struct UpdaterExplainerView: View {

    let buttonAction: () -> Void

    var body: some View {
        SetupStepView(title: "Updates",
                     image: Image(systemName: "dot.radiowaves.left.and.right"),
                     bodyText: "Secretive will periodically check with GitHub to see if there's a new release. If you see any network requests to GitHub, that's why.",
                     buttonTitle: "Okay",
                     buttonAction: buttonAction) {
            Link("Read more about this here.", destination: SetupView.Constants.updaterFAQURL)
        }
    }

}

struct UpdaterExplainerView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            UpdaterExplainerView(buttonAction: {})
        }
    }
}

extension SetupView {

    enum Constants {
        static let socketPath = (NSHomeDirectory().replacingOccurrences(of: "com.maxgoedjen.Secretive.Host", with: "com.maxgoedjen.Secretive.SecretAgent") as NSString).appendingPathComponent("socket.ssh") as String
        static let socketPrompts: [ShellConfigInstruction] = [
            ShellConfigInstruction(shell: "zsh",
                                   shellConfigPath: "~/.zshrc",
                                   text: "export SSH_AUTH_SOCK=\(socketPath)"),
            ShellConfigInstruction(shell: "bash",
                                   shellConfigPath: "~/.bashrc",
                                   text: "export SSH_AUTH_SOCK=\(socketPath)"),
            ShellConfigInstruction(shell: "fish",
                                   shellConfigPath: "~/.config/fish/config.fish",
                                   text: "set -x SSH_AUTH_SOCK=\(socketPath)"),
        ]
        static let updaterFAQURL = URL(string: "https://github.com/maxgoedjen/secretive/blob/main/FAQ.md#whats-this-network-request-to-github")!
    }

}

struct ShellConfigInstruction: Identifiable, Hashable {

    var shell: String
    var shellConfigPath: String
    var text: String

    var id: String {
        shell
    }

}
