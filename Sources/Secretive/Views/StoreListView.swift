import SwiftUI
import SecretKit

struct StoreListView: View {

    @Binding var activeSecret: AnySecret?

    @Environment(\.secretStoreList) private var storeList

    private func secretDeleted(secret: AnySecret) {
        activeSecret = nextDefaultSecret
    }

    private func secretRenamed(secret: AnySecret) {
        // Toggle so name updates in list.
        activeSecret = nil
        activeSecret = secret
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
                                    renamedSecret: secretRenamed
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
                EmptyStoreView(store: storeList.modifiableStore ?? storeList.stores.first)
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
