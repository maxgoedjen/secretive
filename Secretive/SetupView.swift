import Foundation
import SwiftUI
import ServiceManagement

struct SetupView: View {

    var completion: ((Bool) -> Void)?

    var body: some View {
        Form {
            SetupStepView<Spacer>(text: "Secretive needs to install a helper app to sign requests when the main app isn't running. This app is called \"SecretAgent\" and you might see it in Activity Manager from time to time.",
                                index: 1,
                                nestedView: nil,
                                actionText: "Install") {
                                    self.installLaunchAgent()
            }
            SetupStepView(text: "You need to add a line to your shell config (.bashrc or .zshrc) telling SSH to talk to SecretAgent when it wants to authenticate. Drag this into your config file.",
                          index: 2,
                          nestedView: SetupStepCommandView(text: Constants.socketPrompt),
                          actionText: "Added") {
                            self.markAsDone()
            }
            HStack {
                Spacer()
                    Button(action: { self.completion?(true) }) {
                        Text("Finish")
                    }
                .padding()
            }
        }
    }

}

struct SetupStepView<NestedViewType: View>: View {

    let text: String
    let index: Int
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
                        Text(String(describing: index))
                            .foregroundColor(.white)
                            .bold()
                    }
                }
                .padding()
                VStack {
                    Text(text)
                        .opacity(completed ? 0.5 : 1)
                        .lineLimit(nil)
                        .frame(idealHeight: 0, maxHeight: .infinity)
                    if nestedView != nil {
                        Spacer()
                        nestedView!
                    }
                }
                .padding()
                Button(action: {
                    self.completed = self.action()
                }) {
                    Text(actionText)
                }.disabled(completed)
                    .padding()
            }
        }
    }
}

struct SetupStepCommandView: View {

    let text: String

    var body: some View {
        Text(text)
            .font(.system(.caption, design: .monospaced))
            .lineLimit(nil)
            .frame(idealHeight: 0, maxHeight: .infinity)
            .padding()
            .background(Color(white: 0, opacity: 0.10))
            .cornerRadius(10)
            .onDrag {
                return NSItemProvider(item: NSData(data: self.text.data(using: .utf8)!), typeIdentifier: kUTTypeUTF8PlainText as String)
        }
    }

}

extension SetupView {

    func installLaunchAgent() -> Bool {
        SMLoginItemSetEnabled("com.maxgoedjen.Secretive.SecretAgent" as CFString, true)
    }

    func markAsDone() -> Bool {
        return true
    }

}

extension SetupView {

    enum Constants {
        static let socketPath = (NSHomeDirectory().replacingOccurrences(of: "com.maxgoedjen.Secretive.Host", with: "com.maxgoedjen.Secretive.SecretAgent") as NSString).appendingPathComponent("socket.ssh") as String
        static let socketPrompt = "export SSH_AUTH_SOCK=\(socketPath)"
    }

}

struct SetupView_Previews: PreviewProvider {
    static var previews: some View {
        SetupView()
    }
}
