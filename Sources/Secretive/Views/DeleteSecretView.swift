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
                        Text(.deleteConfirmationTitle(secretName: secret.name)).bold()
                        Spacer()
                    }
                    HStack {
                        Text(.deleteConfirmationDescription(secretName: secret.name, confirmSecretName: secret.name))
                        Spacer()
                    }
                    HStack {
                        Text(.deleteConfirmationConfirmNameLabel)
                        TextField(secret.name, text: $confirm)
                    }
                }
            }
            HStack {
                Spacer()
                Button(.deleteConfirmationDeleteButton, action: delete)
                    .disabled(confirm != secret.name)
                Button(.deleteConfirmationCancelButton) {
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
        Task {
            try! await store.delete(secret: secret)
            dismissalBlock(true)
        }
    }

}
