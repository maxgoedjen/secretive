import SwiftUI
import SecretKit

struct CreateSecretView<StoreType: SecretStoreModifiable, AgentCommunicationControllerType: AgentCommunicationControllerProtocol>: View {

    @ObservedObject var store: StoreType
    @EnvironmentObject private var agentCommunicationController: AgentCommunicationControllerType
    @Binding var showing: Bool

    @State private var name = ""
    @State private var requiresAuthentication = true

    var body: some View {
        VStack {
            HStack {
                Image(nsImage: NSApplication.shared.applicationIconImage)
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
                        VStack(spacing: 20) {
                            Picker("", selection: $requiresAuthentication) {
                                Text("Requires Authentication (Biometrics or Password) before each use").tag(true)
                                Text("Authentication not required when Mac is unlocked").tag(false)
                            }
                            .pickerStyle(RadioGroupPickerStyle())
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

    func save() {
        try! store.create(name: name, requiresAuthentication: requiresAuthentication)
        Task {
            try! await agentCommunicationController.agent!.updatedStore(withID: store.id)
        }
        showing = false
    }
}
