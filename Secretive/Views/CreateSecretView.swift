import SwiftUI
import SecretKit

struct CreateSecretView<StoreType: SecretStoreModifiable>: View {
    
    @ObservedObject var store: StoreType
    @Binding var showing: Bool
    @State private var comment = ""
    @State private var name = ""
    @State private var requiresAuthentication = true
    let defaults = UserDefaults.standard

    var body: some View {
        VStack {
            HStack {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 64, height: 64)
                    .padding()
                VStack {
                    HStack {
                        Text("Create a New Secret").bold()
                        Spacer()
                    }
                    HStack {
                        Text("Name:")
                        TextField("Shhhhh", text: $name).focusable()
                    }
                    HStack {
                        Text("Comment:")
                        TextField("\(dashedUserName)@\(dashedHostName)", text: $comment).focusable()
                    }
                    HStack {
                        Toggle(isOn: $requiresAuthentication) {
                            Text("Requires Authentication (Biometrics or Password)")
                        }
                        Spacer()
                    }
                }
            }
            HStack {
                Spacer()
                Button("Cancel") {
                    showing = false
                }
                .keyboardShortcut(.cancelAction)
                Button("Create", action: save)
                    .disabled(name.isEmpty)
                    .keyboardShortcut(.defaultAction)
            }
        }.padding()
    }
    var dashedUserName: String {
        NSUserName().replacingOccurrences(of: " ", with: "-")
    }
    var dashedHostName: String {
        [Host.current().localizedName, "local"]
            .compactMap { $0 }
            .joined(separator: ".")
            .replacingOccurrences(of: " ", with: "-")
    }
    
    func save() {
        try! store.create(name: name, requiresAuthentication: requiresAuthentication)
        if comment != "" {
            defaults.set(comment, forKey: name)
        }
        defaults.set(comment, forKey: name)
        showing = false
    }
}
