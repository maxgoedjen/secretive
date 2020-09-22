import SwiftUI
import SecretKit

struct StoreListView: View {

    @Binding var showingCreation: Bool
    
    @State private var activeSecret: AnySecret.ID?
    @State private var deletingSecret: AnySecret?

    @EnvironmentObject private var storeList: SecretStoreList

    var body: some View {
        NavigationView {
            List(selection: $activeSecret) {
                ForEach(storeList.stores) { store in
                    if store.isAvailable {
                        Section(header: Text(store.name)) {
                            if store.secrets.isEmpty {
                                EmptyStoreView(store: store, activeSecret: $activeSecret)
                            } else {
                                SecretListView(store: store, activeSecret: $activeSecret, deletingSecret: $deletingSecret, deletedSecret: { _ in
                                    activeSecret = nextDefaultSecret
                                })
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
