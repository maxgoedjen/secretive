import SwiftUI
import SecretKit

struct SecretListItemView: View {

    @ObservedObject var store: AnySecretStore
    var secret: AnySecret
    @Binding var activeSecret: AnySecret.ID?

    @State var isDeleting: Bool = false
    @State var isRenaming: Bool = false

    var deletedSecret: (AnySecret) -> Void
    var renamedSecret: (AnySecret) -> Void

    var body: some View {
        let showingPopupWrapped = Binding(
            get: { isDeleting || isRenaming },
            set: { if $0 == false { isDeleting = false; isRenaming = false } }
        )

        return NavigationLink(destination: SecretDetailView(secret: secret), tag: secret.id, selection: $activeSecret) {
            if secret.requiresAuthentication {
                HStack {
                    Text(secret.name)
                    Spacer()
                    Image(systemName: "lock")
                }
            } else {
                Text(secret.name)
            }
        }
        .contextMenu {
            if store is AnySecretStoreModifiable {
                Button(action: { isRenaming = true }) {
                    Text("Rename")
                }
                Button(action: { isDeleting = true }) {
                    Text("Delete")
                }
            }
        }
        .popover(isPresented: showingPopupWrapped) {
            if let modifiable = store as? AnySecretStoreModifiable {
                if isDeleting {
                    DeleteSecretView(store: modifiable, secret: secret) { deleted in
                        isDeleting = false
                        if deleted {
                            deletedSecret(secret)
                        }
                    }
                } else if isRenaming {
                    RenameSecretView(store: modifiable, secret: secret) { renamed in
                        isRenaming = false
                        if renamed {
                            renamedSecret(secret)
                        }
                    }
                }
            }
        }
    }
}
