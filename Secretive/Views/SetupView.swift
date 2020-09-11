import Foundation
import SwiftUI

struct SetupView: View {
    
    var completion: ((Bool) -> Void)?
    
    var body: some View {
        Form {
            SetupStepView<Spacer>(text: "Secretive needs to install a helper app to sign requests when the main app isn't running. This app is called \"SecretAgent\" and you might see it in Activity Manager from time to time.",
                                  index: 1,
                                  nestedView: nil,
                                  actionText: "Install") {
                                    installLaunchAgent()
            }
            SetupStepView(text: "Add this line to your shell config (.bashrc or .zshrc) telling SSH to talk to SecretAgent when it wants to authenticate. Drag this into your config file.",
                          index: 2,
                          nestedView: SetupStepCommandView(text: Constants.socketPrompt),
                          actionText: "Added") {
                            markAsDone()
            }
            HStack {
                Spacer()
                Button(action: { completion?(true) }) {
                    Text("Finish")
                }
                .padding()
            }
        }.frame(minWidth: 640, minHeight: 400)
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
                    if nestedView != nil {
                        nestedView!.padding()
                    }
                }
                .padding()
                Button(action: {
                    completed = action()
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
        VStack(alignment: .leading) {
            Text(text)
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
        }
        .padding()
        .background(Color(white: 0, opacity: 0.10))
        .cornerRadius(10)
        .onDrag {
            return NSItemProvider(item: NSData(data: text.data(using: .utf8)!), typeIdentifier: kUTTypeUTF8PlainText as String)
        }
    }
    
    func copy() {
        NSPasteboard.general.declareTypes([.string], owner: nil)
        NSPasteboard.general.setString(text, forType: .string)
    }
    
}

extension SetupView {
    
    func installLaunchAgent() -> Bool {
        LaunchAgentController().install()
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

#if DEBUG

struct SetupView_Previews: PreviewProvider {
    static var previews: some View {
        SetupView()
    }
}

#endif
