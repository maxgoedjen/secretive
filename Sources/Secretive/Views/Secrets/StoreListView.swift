import SwiftUI
import SecretKit

struct StoreListView: View {

    @Binding var activeSecret: AnySecret?

    @Environment(\.secretStoreList) private var storeList

    private func secretDeleted(secret: AnySecret) {
        activeSecret = nextDefaultSecret
    }

    private func secretRenamed(secret: AnySecret) {
        // Pull new version from store, so we get all updated attributes
        activeSecret = nil
        activeSecret = storeList.allSecrets.first(where: { $0.id == secret.id })
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $activeSecret) {
                ForEach(storeList.stores) { store in
                    if store.isAvailable {
                        Section(header: Text(store.name)) {
                            ForEach(store.secrets) { secret in
                                SecretListItemView(
                                    store: store,
                                    secret: secret,
                                    deletedSecret: secretDeleted,
                                    renamedSecret: secretRenamed,
                                )
                            }
                        }
                    }
                }
            }
        } detail: {
            if let activeSecret {
                SecretDetailView(secret: activeSecret)
            } else if let nextDefaultSecret {
                // This just means onAppear hasn't executed yet.
                // Do this to avoid a blip.
                SecretDetailView(secret: nextDefaultSecret)
            } else {
                if let modifiable = storeList.modifiableStore, modifiable.isAvailable {
                    EmptyStoreView(store: modifiable)
                } else {
                    EmptyStoreView(store: storeList.stores.first(where: \.isAvailable))
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
        .onAppear {
            activeSecret = nextDefaultSecret
        }
        .frame(minWidth: 100, idealWidth: 240)

    }
}

extension StoreListView {

    private var nextDefaultSecret: AnySecret? {
        return storeList.allSecrets.first
    }
    
}
