import SwiftUI
import SecretKit

struct SecretListItemView: View {
    
    @State var store: AnySecretStore
    var secret: AnySecret
    
    @State var isDeleting: Bool = false
    @State var isRenaming: Bool = false
    
    var deletedSecret: (AnySecret) -> Void
    var renamedSecret: (AnySecret) -> Void
    
    private var showingPopup: Binding<Bool> {
        Binding(
            get: { isDeleting || isRenaming },
            set: {
                if $0 == false {
                    isDeleting = false
                    isRenaming = false
                }
            }
        )
    }
    
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
                    Image(systemName: "pencil")
                    Text(.secretListEditButton)
                }
                Button(action: { isDeleting = true }) {
                    Image(systemName: "trash")
                    Text(.secretListDeleteButton)
                }
            }
        }
        .sheet(isPresented: showingPopup) {
            if let modifiable = store as? AnySecretStoreModifiable {
                if isDeleting {
                    DeleteSecretView(store: modifiable, secret: secret) { deleted in
                        isDeleting = false
                        if deleted {
                            deletedSecret(secret)
                        }
                    }
                } else if isRenaming {
                    EditSecretView(store: modifiable, secret: secret) { renamed in
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
