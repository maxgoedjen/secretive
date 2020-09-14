import SwiftUI
import SecretKit

struct StoreListView: View {

    @State private var activeSecret: AnySecret.ID?
    @State private var deletingSecret: AnySecret?

    @EnvironmentObject var storeList: SecretStoreList

    var body: some View {
        NavigationView {
            List(selection: $activeSecret) {
                ForEach(storeList.stores) { store in
                    if store.isAvailable {
                        Section(header: Text(store.name)) {
                            if store.secrets.isEmpty {
                                if store is AnySecretStoreModifiable {
                                    NavigationLink(destination: EmptyStoreModifiableView(), tag: Constants.emptyStoreModifiableTag, selection: $activeSecret) {
                                        Text("No Secrets")
                                    }
                                } else {
                                    NavigationLink(destination: EmptyStoreView(), tag: Constants.emptyStoreTag, selection: $activeSecret) {
                                        Text("No Secrets")
                                    }
                                }
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
            fallback = Constants.emptyStoreModifiableTag
        } else {
            fallback = Constants.emptyStoreTag
        }
        return storeList.stores.compactMap(\.secrets.first).first?.id ?? fallback
    }
    
}

private enum Constants {
    static let emptyStoreModifiableTag: AnyHashable = "emptyStoreModifiableTag"
    static let emptyStoreTag: AnyHashable = "emptyStoreModifiableTag"
}
