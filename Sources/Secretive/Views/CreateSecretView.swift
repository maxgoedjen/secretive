import SwiftUI
import SecretKit

struct CreateSecretView<StoreType: SecretStoreModifiable>: View {

    @State var store: StoreType
    @Environment(\.dismiss) private var dismiss
    var createdSecret: (AnySecret?) -> Void

    @State private var name = ""
    @State private var keyAttribution = ""
    @State private var authenticationRequirement: AuthenticationRequirement = .presenceRequired
    @State private var keyType: KeyType?
    @State var advanced = false
    @State var errorText: String?

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
                                        Text(.createSecretRequireAuthenticationBiometricCurrentTitle)
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
                                Text(.createSecretRequireAuthenticationBiometricCurrentDescription)
                            case .unknown:
                                EmptyView()
                            }
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        if authenticationRequirement == .biometryCurrent {
                            Text(.createSecretBiometryCurrentWarning)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 3)
                                .background(.red.opacity(0.5), in:  RoundedRectangle(cornerRadius: 5))
                        }

                    }
                }
                if advanced {
                    Section {
                        VStack {
                            Picker(.createSecretKeyTypeLabel, selection: $keyType) {
                                ForEach(store.supportedKeyTypes, id: \.self) { option in
                                    Text(String(describing: option))
                                        .tag(option)
                                        .font(.caption)
                                }
                            }
                            if keyType?.algorithm == .mldsa {
                                Text(.createSecretMldsaWarning)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 3)
                                    .background(.red.opacity(0.5), in:  RoundedRectangle(cornerRadius: 5))
                            }
                        }
                        VStack(alignment: .leading) {
                            TextField(.createSecretKeyAttributionLabel, text: $keyAttribution, prompt: Text(verbatim: "test@example.com"))
                            Text(.createSecretKeyAttributionDescription)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                if let errorText {
                    Section {
                    } footer: {
                        Text(verbatim: errorText)
                            .errorStyle()
                    }
                }
            }
            HStack {
                Toggle(.createSecretAdvancedLabel, isOn: $advanced)
                    .toggleStyle(.button)
                Spacer()
                Button(.createSecretCancelButton, role: .cancel) {
                    dismiss()
                }
                Button(.createSecretCreateButton, action: save)
                    .keyboardShortcut(.return)
                    .primary()
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
            do {
                let new = try await store.create(
                    name: name,
                    attributes: .init(
                        keyType: keyType!,
                        authentication: authenticationRequirement,
                        publicKeyAttribution: attribution
                    )
                )
                createdSecret(AnySecret(new))
                dismiss()
            } catch {
                errorText = error.localizedDescription
            }
        }
    }

}

#Preview {
    CreateSecretView(store: Preview.StoreModifiable()) { _ in }
}
