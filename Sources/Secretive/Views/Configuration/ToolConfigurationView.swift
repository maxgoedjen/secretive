import SwiftUI
import SecretKit

struct ToolConfigurationView: View {

    private let instructions = Instructions()
    let selectedInstruction: ConfigurationFileInstructions
    
    @Environment(\.secretStoreList) private var secretStoreList

    @State var creating = false
    @State var selectedSecret: AnySecret?

    init(selectedInstruction: ConfigurationFileInstructions) {
        self.selectedInstruction = selectedInstruction
    }

    var body: some View {
        Form {
            if selectedInstruction.requiresSecret {
                if secretStoreList.allSecrets.isEmpty {
                    Section {
                        Text(.integrationsConfigureUsingSecretEmptyCreate)
                        if let store = secretStoreList.modifiableStore {
                            HStack {
                                Spacer()
                                Button(.createSecretTitle) {
                                    creating = true
                                }
                                .sheet(isPresented: $creating) {
                                    CreateSecretView(store: store) { created in
                                        selectedSecret = created
                                    }
                                }
                            }
                        }
                    }
                } else {
                    Section {
                        Picker(.integrationsConfigureUsingSecretSecretTitle, selection: $selectedSecret) {
                            if selectedSecret == nil {
                                Text(.integrationsConfigureUsingSecretNoSecret)
                                    .tag(nil as (AnySecret?))
                            }
                            ForEach(secretStoreList.allSecrets) { secret in
                                Text(secret.name)
                                    .tag(secret)
                            }
                        }
                    } header: {
                        Text(.integrationsConfigureUsingSecretHeader)
                    }
                    .onAppear {
                        selectedSecret = secretStoreList.allSecrets.first
                    }
                }
            }
            ForEach(selectedInstruction.steps) { stepGroup in
                Section {
                    ConfigurationItemView(title: .integrationsPathTitle, value: stepGroup.path, action: .revealInFinder(stepGroup.path))
                    ForEach(stepGroup.steps, id: \.self.key) { step in
                        ConfigurationItemView(title: .integrationsAddThisTitle, action: .copy(String(localized: step))) {
                            HStack {
                                Text(placeholdersReplaced(text: String(localized: step)))
                                    .padding(8)
                                    .font(.system(.subheadline, design: .monospaced))
                                Spacer()
                            }
                            .frame(maxWidth: .infinity)
                            .background {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(.black.opacity(0.05))
                                    .stroke(.separator, lineWidth: 1)
                            }
                        }
                    }
                } footer: {
                    if let note = stepGroup.note {
                        Text(note)
                            .font(.caption)
                    }
                }
            }
            if let url = selectedInstruction.website {
                Section {
                    Link(destination: url) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(.integrationsWebLink)
                                .font(.headline)
                            Text(url.absoluteString)
                                .font(.caption2)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)

    }

    func placeholdersReplaced(text: String) -> String {
        guard let selectedSecret else { return text }
        let writer = OpenSSHPublicKeyWriter()
        let fileController = PublicKeyFileStoreController(homeDirectory: URL.agentHomeURL)
        return text
            .replacingOccurrences(of: Instructions.Constants.publicKeyPlaceholder, with: writer.openSSHString(secret: selectedSecret))
            .replacingOccurrences(of: Instructions.Constants.publicKeyPathPlaceholder, with: fileController.publicKeyPath(for: selectedSecret))
    }

}
