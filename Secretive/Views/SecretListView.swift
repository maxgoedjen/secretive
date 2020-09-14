import SwiftUI
import SecretKit

struct SecretListView: View {

    @ObservedObject var store: AnySecretStore
    @Binding var activeSecret: AnySecret.ID?
    @Binding var deletingSecret: AnySecret?

    var deletedSecret: (AnySecret) -> Void

    var body: some View {
        ForEach(store.secrets) { secret in
            NavigationLink(destination: SecretDetailView(secret: secret), tag: secret.id, selection: $activeSecret) {
                Text(secret.name)
            }.contextMenu {
                if store is AnySecretStoreModifiable {
                    Button(action: { delete(secret: secret) }) {
                        Text("Delete")
                    }
                }
            }
            .sheet(item: $deletingSecret) { secret in
                if let modifiable = store as? AnySecretStoreModifiable {
                    DeleteSecretView(store: modifiable, secret: secret) { deleted in
                        deletingSecret = nil
                        if deleted {
                            deletedSecret(AnySecret(secret))
                        }
                    }
                }
            }
        }
    }

    func delete<SecretType: Secret>(secret: SecretType) {
        deletingSecret = AnySecret(secret)
    }

}
