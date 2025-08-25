import SwiftUI
import SecretKit

struct EditSecretView<StoreType: SecretStoreModifiable>: View {

    let store: StoreType
    let secret: StoreType.SecretType
    let dismissalBlock: (_ renamed: Bool) -> ()

    @State private var name: String
    @State private var publicKeyAttribution: String
    @State var errorText: String?

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
                        TextField(.createSecretKeyAttributionLabel, text: $publicKeyAttribution, prompt: Text(verbatim: "test@example.com"))
                        Text(.createSecretKeyAttributionDescription)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                if let errorText {
                    Text(verbatim: errorText)
                        .foregroundStyle(.red)
                        .font(.callout)
                }
            }
            HStack {
                Button(.editSaveButton, action: rename)
                    .disabled(name.isEmpty)
                    .keyboardShortcut(.return)
                Button(.editCancelButton) {
                    dismissalBlock(false)
                }
                .keyboardShortcut(.cancelAction)
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
            do {
                try await store.update(secret: secret, name: name, attributes: attributes)
                dismissalBlock(true)
            } catch {
                errorText = error.localizedDescription
            }
        }
    }
}
