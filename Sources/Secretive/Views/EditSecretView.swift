import SwiftUI
import SecretKit

struct EditSecretView<StoreType: SecretStoreModifiable>: View {

    let store: StoreType
    let secret: StoreType.SecretType
    let dismissalBlock: (_ renamed: Bool) -> ()

    @State private var name: String
    @State private var publicKeyAttribution: String

    init(store: StoreType, secret: StoreType.SecretType, dismissalBlock: @escaping (Bool) -> ()) {
        self.store = store
        self.secret = secret
        self.dismissalBlock = dismissalBlock
        name = secret.name
        publicKeyAttribution = secret.publicKeyAttribution ?? ""
    }

    var body: some View {
        VStack(alignment: .trailing) {
            Form {
                Section {
                    TextField(String(localized: .createSecretNameLabel), text: $name, prompt: Text(.createSecretNamePlaceholder))
                    VStack(alignment: .leading) {
                        TextField("Key Attribution", text: $publicKeyAttribution, prompt: Text("test@example.com"))
                        Text("This shows at the end of your public key.")
                            .font(.caption)
                    }
                }
            }
            HStack {
                Button(.renameRenameButton, action: rename)
                    .disabled(name.isEmpty)
                    .keyboardShortcut(.return)
                Button(.renameCancelButton) {
                    dismissalBlock(false)
                }.keyboardShortcut(.cancelAction)
            }
            .padding()
        }
        .formStyle(.grouped)
    }

    func rename() {
        var attributes = secret.attributes
        if !publicKeyAttribution.isEmpty {
            attributes.publicKeyAttribution = publicKeyAttribution
        }
        Task {
            try? await store.update(secret: secret, name: name, attributes: attributes)
            dismissalBlock(true)
        }
    }
}
