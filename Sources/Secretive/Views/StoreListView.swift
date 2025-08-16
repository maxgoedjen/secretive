import SwiftUI
import Combine
import SecretKit

struct StoreListView: View {

    @Binding var activeSecret: AnySecret?

    @Environment(\.secretStoreList) private var storeList: SecretStoreList

    private func secretDeleted(secret: AnySecret) {
        activeSecret = nextDefaultSecret
    }

    private func secretRenamed(secret: AnySecret) {
        activeSecret = secret
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $activeSecret) {
                ForEach(storeList.stores) { store in
                    if store.isAvailable {
                        Section(header: Text(store.name)) {
                            if store.secrets.isEmpty {
                                EmptyStoreView(store: store)
                            } else {
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
            }
        } detail: {
            if let activeSecret {
                SecretDetailView(secret: activeSecret)
            } else {
                EmptyStoreView(store: storeList.modifiableStore ?? storeList.stores.first)
            }
        }
        .navigationSplitViewStyle(.balanced)
        .onAppear {
            withObservationTracking {
                _ = nextDefaultSecret
            } onChange: {
                Task { @MainActor in
                    activeSecret = nextDefaultSecret
                }
            }
        }
        .frame(minWidth: 100, idealWidth: 240)

    }
}

extension StoreListView {

    private var nextDefaultSecret: AnySecret? {
        return storeList.stores.first(where: { !$0.secrets.isEmpty })?.secrets.first
    }
    
}
