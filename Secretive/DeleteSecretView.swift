import SwiftUI
import SecretKit

struct DeleteSecretView: View {
    
    let secret: SecureEnclave.Secret
    @ObservedObject var store: SecureEnclave.Store
    
    @State var confirm = ""
    
    fileprivate var dismissalBlock: () -> ()
    
    init(secret: SecureEnclave.Secret, store: SecureEnclave.Store, dismissalBlock: @escaping () -> ()) {
        self.secret = secret
        self.store = store
        self.dismissalBlock = dismissalBlock
    }
    
    var body: some View {
        VStack {
            HStack {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 64, height: 64)
                    .padding()
                VStack {
                    HStack {
                        Text("Delete \(secret.name)?").bold()
                        Spacer()
                    }
                    HStack {
                        Text("If you delete \(secret.name), you will not be able to recover it. Type \"\(secret.name)\" to confirm.")
                        Spacer()
                    }
                    HStack {
                        Text("Confirm Name:")
                        TextField(secret.name, text: $confirm)
                    }
                }
                .onExitCommand(perform: dismissalBlock)
            }
            HStack {
                Spacer()
                Button(action: delete) {
                    Text("Delete")
                }.disabled(confirm != secret.name)
                Button(action: dismissalBlock) {
                    Text("Don't Delete")
                }
            }
        }.padding()
    }
    
    func delete() {
        try! store.delete(secret: secret)
        dismissalBlock()
    }
}
