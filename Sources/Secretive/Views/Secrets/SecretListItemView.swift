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
            if secret.attributes.usableWhileLocked {
                HStack {
                    Text(secret.name)
                    Spacer()
                    Image(systemName: "lock.open.trianglebadge.exclamationmark")
                        .accessibilityLabel(String(localized: .createSecretUsableWhileLockedWarning))
                }
                .help(String(localized: .createSecretUsableWhileLockedWarning))
            } else if secret.authenticationRequirement.required {
                HStack {
                    Text(secret.name)
                    Spacer()
                    Image(systemName: "lock")
                        .accessibilityLabel(String(localized: .createSecretRequireAuthenticationDescription))
                }
                .help(String(localized: .createSecretRequireAuthenticationDescription))
            } else {
                HStack {
                    Text(secret.name)
                    Spacer()
                    Image(systemName: "lock.open")
                        .accessibilityLabel(String(localized: .createSecretNotifyDescription))
                }
                .help(String(localized: .createSecretNotifyDescription))
            }
        }
        .sheet(isPresented: $isRenaming, onDismiss: {
            renamedSecret(secret)
        }, content: {
            if let modifiable = store as? AnySecretStoreModifiable {
                EditSecretView(store: modifiable, secret: secret)
            }
        })
        .showingDeleteConfirmation(isPresented: $isDeleting, secret, store as? AnySecretStoreModifiable) { deleted in
            if deleted {
                deletedSecret(secret)
            }
        }
        .contextMenu {
            if store is AnySecretStoreModifiable {
                Button(action: { isRenaming = true }) {
                    Image(systemName: "pencil")
                    Text(.secretListEditButton)
                }
                Button(action: { isDeleting = true }) {
                    Image(systemName: "trash")
                    Text(.secretListDeleteButton)
                }
            }
        }
    }
}
