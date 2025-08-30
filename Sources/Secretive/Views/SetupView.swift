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
                            await LaunchAgentController().install()
                            installed = true
                        }
                    }
                }
                Divider()
                NewStepView(
                    title: "setup_updates_title",
                    description: "setup_updates_description",
                    systemImage: "network.badge.shield.half.filled",
                ) {
                    OnboardingButton("setup_updates_ok", false) {
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
                        OnboardingButton("setup_ssh_added_manually_button", false) {
                            sshConfig = true
                        }
                        OnboardingButton("Add Automatically", false) {
                            //                        let controller = ShellConfigurationController()
                            //                        if controller.addToShell(shellInstructions: selectedShellInstruction) {
                            //                        }
                            sshConfig = true
                        }
                        .fileImporter(isPresented: $sshConfig, allowedContentTypes: [.utf8PlainText, .symbolicLink, .data]) { result in
                            print(result)
                        }
                        // FIXME:
                        .fileDialogDefaultDirectory(URL(fileURLWithPath: "/Users/max/"))
                        .fileDialogBrowserOptions([.displayFileExtensions, .includeHiddenFiles])
                        .fileExporterFilenameLabel(Text(".zshrc"))
                        .fileDialogMessage("TfileDialogMessageest")
                        .fileDialogConfirmationLabel("Configure")
                        .fileDialogURLEnabled(#Predicate {
                            return $0.lastPathComponent == ".zshrc" || $0.hasDirectoryPath
                        })
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

struct OldSetupView: View {

    @State var stepIndex = 0
    @Binding var visible: Bool
    @Binding var setupComplete: Bool

    var body: some View {
        GeometryReader { proxy in
            VStack {
                StepView(numberOfSteps: 3, currentStep: stepIndex, width: proxy.size.width)
                GeometryReader { _ in
                    HStack(spacing: 0) {
                        SecretAgentSetupView(buttonAction: advance)
                            .frame(width: proxy.size.width)
                        SSHAgentSetupView(buttonAction: advance)
                            .frame(width: proxy.size.width)
                        UpdaterExplainerView {
                            visible = false
                            setupComplete = true
                        }
                        .frame(width: proxy.size.width)
                    }
                    .offset(x: -proxy.size.width * Double(stepIndex), y: 0)
                }
            }
        }
        .frame(minWidth: 500, idealWidth: 500, minHeight: 500, idealHeight: 500)
    }


    func advance() {
        withAnimation(.spring()) {
            stepIndex += 1
        }
    }

}

struct StepView: View {

    let numberOfSteps: Int
    let currentStep: Int

    // Ideally we'd have a geometry reader inside this view doing this for us, but that crashes on 11.0b7
    let width: Double

    var body: some View {
        ZStack(alignment: .leading) {
            Rectangle()
                .foregroundColor(.blue)
                .frame(height: 5)
            Rectangle()
                .foregroundColor(.green)
                .frame(width: max(0, ((width - (Constants.padding * 2)) / Double(numberOfSteps - 1)) * Double(currentStep) - (Constants.circleWidth / 2)), height: 5)
            HStack {
                ForEach(Array(0..<numberOfSteps), id: \.self) { index in
                    ZStack {
                        if currentStep > index {
                            Circle()
                                .foregroundColor(.green)
                                .frame(width: Constants.circleWidth, height: Constants.circleWidth)
                            Text("setup_step_complete_symbol")
                                .foregroundColor(.white)
                                .bold()
                        } else {
                            Circle()
                                .foregroundColor(.blue)
                                .frame(width: Constants.circleWidth, height: Constants.circleWidth)
                            if currentStep == index {
                                Circle()
                                    .strokeBorder(Color.white, lineWidth: 3)
                                    .frame(width: Constants.circleWidth, height: Constants.circleWidth)
                            }
                            Text(String(describing: index + 1))
                                .foregroundColor(.white)
                                .bold()
                        }
                    }
                    if index < numberOfSteps - 1 {
                        Spacer(minLength: 30)
                    }
                }
            }
        }.padding(Constants.padding)
    }

}

extension StepView {

    enum Constants {

        static let padding: Double = 15
        static let circleWidth: Double = 30

    }

}

struct SetupStepView<Content> : View where Content : View {

    let title: LocalizedStringKey
    let image: Image
    let bodyText: LocalizedStringKey
    let buttonTitle: LocalizedStringKey
    let buttonAction: () -> Void
    let content: Content

    init(title: LocalizedStringKey, image: Image, bodyText: LocalizedStringKey, buttonTitle: LocalizedStringKey, buttonAction: @escaping () -> Void = {}, @ViewBuilder content: () -> Content) {
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
        }.padding()
    }

}

struct SecretAgentSetupView: View {

    let buttonAction: () -> Void

    var body: some View {
        SetupStepView(title: "setup_agent_title",
                      image: Image(nsImage: NSApplication.shared.applicationIconImage),
                      bodyText: "setup_agent_description",
                      buttonTitle: "setup_agent_install_button",
                      buttonAction: install) {
            Text("setup_agent_activity_monitor_description")
                .multilineTextAlignment(.center)
        }
    }

    func install() {
        Task {
            await LaunchAgentController().install()
            buttonAction()
        }
    }

}

struct SSHAgentSetupView: View {

    let buttonAction: () -> Void

    private static let controller = ShellConfigurationController()
    @State private var selectedShellInstruction: ShellConfigInstruction = controller.shellInstructions.first!

    var body: some View {
        SetupStepView(title: "setup_ssh_title",
                      image: Image(systemName: "terminal"),
                      bodyText: "setup_ssh_description",
                      buttonTitle: "setup_ssh_added_manually_button",
                      buttonAction: buttonAction) {
        Link("setup_third_party_faq_link", destination: URL(string: "https://github.com/maxgoedjen/secretive/blob/main/APP_CONFIG.md")!)
            Picker(selection: $selectedShellInstruction, label: EmptyView()) {
                ForEach(SSHAgentSetupView.controller.shellInstructions) { instruction in
                    Text(instruction.shell)
                        .tag(instruction)
                        .padding()
                }
            }.pickerStyle(SegmentedPickerStyle())
            CopyableView(title: "setup_ssh_add_to_config_button_\(selectedShellInstruction.shellConfigPath)", image: Image(systemName: "greaterthan.square"), text: selectedShellInstruction.text)
            Button("setup_ssh_add_for_me_button") {
                let controller = ShellConfigurationController()
                if controller.addToShell(shellInstructions: selectedShellInstruction) {
                    buttonAction()
                }
            }
        }
    }

}

class Delegate: NSObject, NSOpenSavePanelDelegate {

    private let name: String

    init(name: String) {
        self.name = name
    }

    func panel(_ sender: Any, shouldEnable url: URL) -> Bool {
        return url.lastPathComponent == name
    }

}

struct UpdaterExplainerView: View {

    let buttonAction: () -> Void

    var body: some View {
        SetupStepView(title: "setup_updates_title",
                      image: Image(systemName: "dot.radiowaves.left.and.right"),
                      bodyText: "setup_updates_description",
                      buttonTitle: "setup_updates_ok",
                      buttonAction: buttonAction) {
            Link("setup_updates_readmore", destination: SetupView.Constants.updaterFAQURL)
        }
    }

}

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

#if DEBUG

struct SetupView_Previews: PreviewProvider {

    static var previews: some View {
        Group {
            SetupView(visible: .constant(true), setupComplete: .constant(false))
        }
    }

}

struct SecretAgentSetupView_Previews: PreviewProvider {

    static var previews: some View {
        Group {
            SecretAgentSetupView(buttonAction: {})
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

struct UpdaterExplainerView_Previews: PreviewProvider {

    static var previews: some View {
        Group {
            UpdaterExplainerView(buttonAction: {})
        }
    }
    
}

#endif
