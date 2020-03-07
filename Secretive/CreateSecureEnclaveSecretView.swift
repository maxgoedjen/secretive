import SwiftUI
import SecretKit

struct CreateSecureEnclaveSecretView: View {
    
    @ObservedObject var store: SecureEnclave.Store
    
    @State var name = ""
    @State var requiresAuthentication = true
    
    var dismissalBlock: () -> ()
    
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
                        TextField("Name", text: $name)
                    }
                    HStack {
                        Toggle(isOn: $requiresAuthentication) {
                            Text("Requires Authentication (Biometrics or Password)")
                        }
                        Spacer()
                    }
                }
                .onExitCommand(perform: dismissalBlock)
            }
            HStack {
                Spacer()
                Button(action: dismissalBlock) {
                    Text("Cancel")
                }
                Button(action: save) {
                    Text("Create")
                }.disabled(name.isEmpty)
            }
        }.padding()
    }
    
    func save() {
        try! store.create(name: name, requiresAuthentication: requiresAuthentication)
        dismissalBlock()
    }
}
