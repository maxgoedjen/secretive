import SwiftUI
import SecretKit

struct DeleteSecretView<StoreType: SecretStoreModifiable>: View {

    @ObservedObject var store: StoreType
    let secret: StoreType.SecretType
    var dismissalBlock: (Bool) -> ()

    @State private var confirm = ""

    var body: some View {
        VStack {
            HStack {
                Image(nsImage: NSApplication.shared.applicationIconImage)
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
            }
            HStack {
                Spacer()
                Button("Delete", action: delete)
                    .disabled(confirm != secret.name)
                Button("Don't Delete") {
                    dismissalBlock(false)
                }
                .keyboardShortcut(.cancelAction)
            }
        }
        .padding()
        .frame(minWidth: 400)
        .onExitCommand {
            dismissalBlock(false)
        }
    }
    
    func delete() {
        try! store.delete(secret: secret)
        dismissalBlock(true)
    }

}
