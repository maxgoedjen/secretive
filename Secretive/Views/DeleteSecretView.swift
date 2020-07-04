import SwiftUI
import SecretKit

struct DeleteSecretView<StoreType: SecretStoreModifiable>: View {
    
    let secret: StoreType.SecretType
    @ObservedObject var store: StoreType
    
    @State var confirm = ""
    
    fileprivate var dismissalBlock: (Bool) -> ()
    
    init(secret: StoreType.SecretType, store: StoreType, dismissalBlock: @escaping (Bool) -> ()) {
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
                .onExitCommand {
                    self.dismissalBlock(false)
                }
            }
            HStack {
                Spacer()
                Button(action: delete) {
                    Text("Delete")
                }.disabled(confirm != secret.name)
                Button(action: { self.dismissalBlock(false) }) {
                    Text("Don't Delete")
                }
            }
        }.padding()
        .frame(minWidth: 400)
    }
    
    func delete() {
        try! store.delete(secret: secret)
        self.dismissalBlock(true)
    }
}
