import SwiftUI
import SecretKit

struct CreateSecretView<StoreType: SecretStoreModifiable>: View {

    @State var store: StoreType
    @Environment(\.dismiss) private var dismiss
    var createdSecret: (AnySecret?) -> Void

    @State private var name = ""
    @State private var keyAttribution = ""
    @State private var authenticationRequirement: AuthenticationRequirement = .presenceRequired
    @State private var restrictions: Restrictions = .default
    @State private var keyType: KeyType?
    @State var advanced = true // FIXME: Set back
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
                        Picker(.createSecretProtectionLevelTitle, selection: $authenticationRequirement) {
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
                                .boxBackground(color: .red)
                        }

                    }
                }
                if advanced {
                    SecretRestrictionsView(restrictions: $restrictions)
                    Section {
                        VStack {
                            Picker(.createSecretKeyTypeLabel, selection: $keyType) {
                                ForEach(store.supportedKeyTypes.available, id: \.self) { option in
                                    Text(String(describing: option))
                                        .tag(option)
                                }
                                Divider()
                                ForEach(store.supportedKeyTypes.unavailable, id: \.keyType) { option in
                                    VStack {
                                        Button {
                                        } label: {
                                            Text(String(describing: option.keyType))
                                            switch option.reason {
                                            case .macOSUpdateRequired:
                                                Text(.createSecretKeyTypeMacOSUpdateRequiredLabel)
                                            }
                                        }
                                    }
                                    .selectionDisabled()
                                }
                            }
                            if keyType?.algorithm == .mldsa {
                                Text(.createSecretMldsaWarning)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 3)
                                    .boxBackground(color: .orange)
                            }
                        }
                        VStack(alignment: .leading) {
                            TextField(.createSecretKeyAttributionLabel, text: $keyAttribution, prompt: Text(verbatim: "test@example.com"))
                            Text(.createSecretKeyAttributionDescription)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    } header: {
                        Text("Key Properties")
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
                    .primaryButton()
                    .disabled(name.isEmpty)
            }
            .padding()
        }
        .onAppear {
            keyType = store.supportedKeyTypes.available.first
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
                        restrictions: restrictions,
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
struct SecretRestrictionsView: View {

    @Binding var restrictions: Restrictions

    struct IdentifiedString: Identifiable {
        let value: String
        var id: String { value }
    }

    var body: some View {
        Section {
            Toggle("Allow Forwarding", isOn: $restrictions.allowForwarding)
            Toggle("Allow Signing Operations", isOn: $restrictions.allowSigning)
            Toggle("Allow Connection Operations", isOn: $restrictions.allowConnections)
            Picker(selection: $restrictions.allowedDomains) {
                Text("All")
                    .tag(Restrictions.AllowedDomains.all)
                Text("Specific")
                    .tag(Restrictions.AllowedDomains.specific([]))
            } label: {
                Text("Allowed Domains")
            }
        } header: {
            Text("Restrictions")
        }
        if restrictions.allowedDomains != .all {
            Section {
                switch restrictions.allowedDomains {
                case .all:
                    EmptyView()
                case .specific(let array):
                    if restrictions.allowedDomains != .all {
                        ForEach((array + [""]).map({IdentifiedString(value: $0)})) {
                            TextField("", text: .constant($0.value), prompt: Text("example.com"))
                                .labelsHidden()
                        }
                    }
                }
            } header: {
                Text("Allowed Domains")
            }
        }
    }
}

#Preview {
    CreateSecretView(store: Preview.StoreModifiable()) { _ in }
        .frame(height: 1000)
}
