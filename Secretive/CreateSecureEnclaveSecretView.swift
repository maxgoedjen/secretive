import SwiftUI
import SecretKit

struct CreateSecureEnclaveSecretView: View {

    @ObservedObject var store: SecureEnclave.Store

    @State var name = ""
    @State var requiresAuthentication = true

    var dismissalBlock: () -> ()

    var body: some View {
        Form {
            Section(header: Text("Secret Name")) {
                TextField("Name", text: $name)
            }
            Section {
                Toggle(isOn: $requiresAuthentication) {
                    Text("Requires Authentication (Biometrics or Password)")
                }
            }
            Section {
                HStack {
                    Spacer()
                    Button(action: dismissalBlock) {
                        Text("Cancel")
                    }
                    Button(action: save) {
                        Text("Save")
                    }.disabled(name.isEmpty)
                }
            }
        }
        .padding()
        .onExitCommand(perform: dismissalBlock)
    }

    func save() {
        try! store.create(name: name, requiresAuthentication: requiresAuthentication)
        dismissalBlock()
    }
}
