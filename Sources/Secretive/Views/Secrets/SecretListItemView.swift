import SwiftUI
import SecretKit

struct SecretListItemView: View {
    
    @State var store: AnySecretStore
    var secret: AnySecret
    
    @State var isDeleting: Bool = false
    @State var isRenaming: Bool = false
    
    var deletedSecret: (AnySecret) -> Void
    var renamedSecret: (AnySecret) -> Void
    
    var body: some View {
        NavigationLink(value: secret) {
            if secret.authenticationRequirement.required {
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
                    // Image(systemName: "pencil")
                    Text(.secretListEditButton)
                }
                Button(action: { isDeleting = true }) {
                    // Image(systemName: "trash")
                    Text(.secretListDeleteButton)
                }
            }
        }
        .showingDeleteConfirmation(isPresented: $isDeleting, secret, store as? AnySecretStoreModifiable) { deleted in
            if deleted {
                deletedSecret(secret)
            }
        }
        .sheet(isPresented: $isRenaming, onDismiss: {
            renamedSecret(secret)
        }, content: {
            if let modifiable = store as? AnySecretStoreModifiable {
                EditSecretView(store: modifiable, secret: secret)
            }
        })
    }
}
