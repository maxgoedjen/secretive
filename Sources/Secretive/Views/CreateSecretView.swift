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
        if advanced || authenticationRequirement == .biometryCurrent {
            [.presenceRequired, .notRequired, .biometryCurrent]
        } else {
            [.presenceRequired, .notRequired]
        }
    }

    var body: some View {
        VStack(alignment: .trailing) {
            Form {
                Section {
                    TextField(String(localized: .createSecretNameLabel), text: $name, prompt: Text(.createSecretNamePlaceholder))
                    VStack(alignment: .leading, spacing: 10) {
                        Picker(.createSecretRequireAuthenticationTitle, selection: $authenticationRequirement) {
                            ForEach(authenticationOptions) { option in
                                HStack {
                                    switch option {
                                    case .notRequired:
                                        Image(systemName: "bell")
                                        Text(.createSecretNotifyTitle)
                                    case .presenceRequired:
                                        Image(systemName: "lock")
                                        Text(.createSecretRequireAuthenticationTitle)
                                    case .biometryCurrent:
                                        Image(systemName: "lock.trianglebadge.exclamationmark.fill")
                                        Text("Current Biometrics")
                                    case .unknown:
                                        EmptyView()
                                    }
                                }
                                .tag(option)
                            }
                        }
                        Group {
                            switch  authenticationRequirement {
                            case .notRequired:
                                Text(.createSecretNotifyDescription)
                            case .presenceRequired:
                                Text(.createSecretRequireAuthenticationDescription)
                            case .biometryCurrent:
                                Text("Require authentication with current set of biometrics.")
                            case .unknown:
                                EmptyView()
                            }
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        if authenticationRequirement == .biometryCurrent {
                            Text("If you change your biometric settings in _any way_, including adding a new fingerprint, this key will no longer be accessible.")
                                .padding(.horizontal, 10)
                                .padding(.vertical, 3)
                                .background(.red.opacity(0.5), in:  RoundedRectangle(cornerRadius: 5))
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
                        VStack(alignment: .leading) {
                            TextField("Key Attribution", text: $keyAttribution, prompt: Text("test@example.com"))
                            Text("This shows at the end of your public key.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
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
