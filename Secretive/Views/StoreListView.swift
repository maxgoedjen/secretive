import SwiftUI
import SecretKit

struct StoreListView: View {

    @Binding var showingCreation: Bool
    
    @State private var activeSecret: AnySecret.ID?
    @State private var deletingSecret: AnySecret?
    @State private var renamingSecret: AnySecret?

    @EnvironmentObject private var storeList: SecretStoreList

    var body: some View {
        let secretDeleted = { (secret: AnySecret) in
            activeSecret = nextDefaultSecret
        }

        let secretRenamed = { (secret: AnySecret) in
            activeSecret = nextDefaultSecret
        }

        NavigationView {
            List(selection: $activeSecret) {
                ForEach(storeList.stores) { store in
                    if store.isAvailable {
                        Section(header: Text(store.name)) {
                            if store.secrets.isEmpty {
                                EmptyStoreView(store: store, activeSecret: $activeSecret)
                            } else {
                                SecretListView(
                                    store: store,
                                    activeSecret: $activeSecret,
                                    deletingSecret: $deletingSecret,
                                    renamingSecret: $renamingSecret,
                                    deletedSecret: secretDeleted,
                                    renamedSecret: secretRenamed
                                )
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
