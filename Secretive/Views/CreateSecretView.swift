import SwiftUI
import SecretKit

struct CreateSecretView: View {
    
    @EnvironmentObject var store: AnySecretStoreModifiable
    
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
                        TextField("Shhhhh", text: $name)
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
                Button("Cancel", action: dismissalBlock)
                    .keyboardShortcut(.cancelAction)
                Button("Create", action: save)
                    .disabled(name.isEmpty)
                    .keyboardShortcut(.defaultAction)
            }
        }.padding()
    }
    
    func save() {
        try! store.create(name: name, requiresAuthentication: requiresAuthentication)
        dismissalBlock()
    }
}
