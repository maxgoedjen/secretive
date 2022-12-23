import SwiftUI
import Combine
import SecretKit

struct StoreListView: View {

    @Binding var activeSecret: AnySecret.ID?
    
    @EnvironmentObject private var storeList: SecretStoreList

    private func secretDeleted(secret: AnySecret) {
        activeSecret = nextDefaultSecret
    }

    private func secretRenamed(secret: AnySecret) {
        activeSecret = secret.id
    }

    var body: some View {
        NavigationView {
            List(selection: $activeSecret) {
                ForEach(storeList.stores) { store in
                    if store.isAvailable {
                        Section(header: Text(store.name)) {
                            if store.secrets.isEmpty {
                                EmptyStoreView(store: store, activeSecret: $activeSecret)
                            } else {
                                ForEach(store.secrets) { secret in
                                    SecretListItemView(
                                        store: store,
                                        secret: secret,
                                        activeSecret: $activeSecret,
                                        deletedSecret: self.secretDeleted,
                                        renamedSecret: self.secretRenamed
                                    )
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(SidebarListStyle())
            .onAppear {
                activeSecret = nextDefaultSecret
            }
            .frame(minWidth: 100, idealWidth: 240)
        }
    }
}

extension StoreListView {

    var nextDefaultSecret: AnyHashable? {
        let fallback: AnyHashable
        if storeList.modifiableStore?.isAvailable ?? false {
            fallback = EmptyStoreView.Constants.emptyStoreModifiableTag
        } else {
            fallback = EmptyStoreView.Constants.emptyStoreTag
        }
        return storeList.stores.compactMap(\.secrets.first).first?.id ?? fallback
    }
    
}
