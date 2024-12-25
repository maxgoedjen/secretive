import SwiftUI
import SecretKit

struct DeleteSecretView<StoreType: SecretStoreModifiable>: View {

    @State var store: StoreType
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
                        Text("delete_confirmation_title_\(secret.name)").bold()
                        Spacer()
                    }
                    HStack {
                        Text("delete_confirmation_description_\(secret.name)_\(secret.name)")
                        Spacer()
                    }
                    HStack {
                        Text("delete_confirmation_confirm_name_label")
                        TextField(secret.name, text: $confirm)
                    }
                }
            }
            HStack {
                Spacer()
                Button("delete_confirmation_delete_button", action: delete)
                    .disabled(confirm != secret.name)
                Button("delete_confirmation_cancel_button") {
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
        // FIXME: THIS
//        try! store.delete(secret: secret)
        dismissalBlock(true)
    }

}
