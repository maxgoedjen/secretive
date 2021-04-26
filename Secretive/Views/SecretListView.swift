import SwiftUI
import SecretKit

struct SecretListView: View {

    @ObservedObject var store: AnySecretStore
    @Binding var activeSecret: AnySecret.ID?
    @Binding var deletingSecret: AnySecret?
    @Binding var renamingSecret: AnySecret?

    @State var renamingText: String = ""

    var deletedSecret: (AnySecret) -> Void
    var renamedSecret: (AnySecret) -> Void

    var body: some View {
        ForEach(store.secrets) { secret in
            NavigationLink(destination: SecretDetailView(secret: secret), tag: secret.id, selection: $activeSecret) {
                Text(secret.name)
            }.contextMenu {
                if store is AnySecretStoreModifiable {
                    Button(action: { rename(secret: secret) }) {
                        Text("Rename")
                    }
                    Button(action: { delete(secret: secret) }) {
                        Text("Delete")
                    }
                }
            }
            .popover(isPresented: .constant(deletingSecret == secret || renamingSecret == secret)) {
                if let modifiable = store as? AnySecretStoreModifiable {
                    if deletingSecret == secret {
                        DeleteSecretView(store: modifiable, secret: secret) { deleted in
                            deletingSecret = nil
                            if deleted {
                                deletedSecret(secret)
                            }
                        }
                    } else if renamingSecret == secret {
                        RenameSecretView(store: modifiable, secret: secret) { renamed in
                            renamingSecret = nil
                            if renamed {
                                renamedSecret(secret)
                            }
                        }
                    }
                }
            }

        }
    }

    func rename<SecretType: Secret>(secret: SecretType) {
        renamingSecret = AnySecret(secret)
    }

    func delete<SecretType: Secret>(secret: SecretType) {
        deletingSecret = AnySecret(secret)
    }
}
