import SwiftUI
import SecretKit

struct EditSecretView<StoreType: SecretStoreModifiable>: View {

    let store: StoreType
    let secret: StoreType.SecretType

    @State private var name: String
    @State private var publicKeyAttribution: String
    @State var errorText: String?

    @Environment(\.dismiss) var dismiss

    init(store: StoreType, secret: StoreType.SecretType) {
        self.store = store
        self.secret = secret
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
                } footer: {
                    if let errorText {
                        Text(verbatim: errorText)
                            .errorStyle()
                    }
                }
            }
            HStack {
                Button(.editCancelButton) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                Button(.editSaveButton, action: rename)
                    .disabled(name.isEmpty)
                    .keyboardShortcut(.return)
                    .primaryButton()
            }
            .padding()
        }
        .formStyle(.grouped)
    }

    func rename() {
        var attributes = secret.attributes
        attributes.publicKeyAttribution = publicKeyAttribution.isEmpty ? nil : publicKeyAttribution
        Task {
            do {
                try await store.update(secret: secret, name: name, attributes: attributes)
                dismiss()
            } catch {
                errorText = error.localizedDescription
            }
        }
    }
}
