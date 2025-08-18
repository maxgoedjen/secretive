import SwiftUI
import SecretKit

struct CreateSecretView<StoreType: SecretStoreModifiable>: View {

    @State var store: StoreType
    @Binding var showing: Bool

    @State private var name = ""
    @State private var keyAttribution = ""
    @State private var authenticationRequirement: AuthenticationRequirement = .presenceRequired
    @State private var keyType: KeyType?
    @State var advanced = false

    private var authenticationOptions: [AuthenticationRequirement] {
        [.presenceRequired, .notRequired]
    }

    var body: some View {
        VStack(alignment: .trailing) {
            Form {
                Section {
                    TextField(String(localized: .createSecretNameLabel), text: $name, prompt: Text(.createSecretNamePlaceholder))
                    Picker(.createSecretRequireAuthenticationTitle, selection: $authenticationRequirement) {
                        ForEach(authenticationOptions) { option in
                            Text(String(describing: option))
                                .tag(option)
                        }
                    }
                }
                if advanced {
                    Section {
                        VStack {
                            Picker("Key Type", selection: $keyType) {
                                ForEach(store.supportedKeyTypes, id: \.self) { option in
                                    Text(String(describing: option))
                                        .tag(option)
                                        .font(.caption)
                                }
                            }
                            if keyType?.algorithm == .mldsa {
                                Text("Warning: ML-DSA keys are very new, and not supported by many servers yet. Please verify the server you'll be using this key for accepts ML-DSA keys.")
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 3)
                                    .background(.red.opacity(0.5), in:  RoundedRectangle(cornerRadius: 5))
                            }
                        }
                        TextField("Key Attribution", text: $keyAttribution, prompt: Text("test@example.com"))
                    }
                }
            }
            HStack {
                Toggle("Advanced", isOn: $advanced)
                    .toggleStyle(.button)
                Spacer()
                Button(.createSecretCancelButton, role: .cancel) {
                    showing = false
                }
                Button(.createSecretCreateButton, action: save)
                    .disabled(name.isEmpty)
            }
            .padding()
        }
        .onAppear {
            keyType = store.supportedKeyTypes.first
        }
        .formStyle(.grouped)
    }

    func save() {
        let attribution = keyAttribution.isEmpty ? nil : keyAttribution
        Task {
            try! await store.create(
                name: name,
                attributes: .init(
                    keyType: keyType!,
                    authentication: authenticationRequirement,
                    publicKeyAttribution: attribution
                )
            )
            showing = false
        }
    }

}

#Preview {
    CreateSecretView(store: Preview.StoreModifiable(), showing: .constant(true))
}
