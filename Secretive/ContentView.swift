import SwiftUI
import SecretKit

struct ContentView<UpdaterType: UpdaterProtocol>: View {
    
    @ObservedObject var storeList: SecretStoreList
    @ObservedObject var updater: UpdaterType

    @State fileprivate var active: AnySecret.ID?
    @State fileprivate var showingDeletion = false
    @State fileprivate var deletingSecret: AnySecret?
    
    var body: some View {
        VStack {
            if updater.update != nil {
                updateNotice()
            }
            NavigationView {
                List(selection: $active) {
                    ForEach(storeList.stores) { store in
                        if store.isAvailable {
                            Section(header: Text(store.name)) {
                                if store.secrets.isEmpty {
                                    if store is AnySecretStoreModifiable {
                                        NavigationLink(destination: EmptyStoreModifiableView(), tag: Constants.emptyStoreModifiableTag, selection: self.$active) {
                                            Text("No Secrets")
                                        }
                                    } else {
                                        NavigationLink(destination: EmptyStoreView(), tag: Constants.emptyStoreTag, selection: self.$active) {
                                            Text("No Secrets")
                                        }
                                    }
                                } else {
                                    ForEach(store.secrets) { secret in
                                        NavigationLink(destination: SecretDetailView(secret: secret), tag: secret.id, selection: self.$active) {
                                            Text(secret.name)
                                        }.contextMenu {
                                            if store is AnySecretStoreModifiable {
                                                Button(action: { self.delete(secret: secret) }) {
                                                    Text("Delete")
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }.onAppear {
                    let fallback: AnyHashable
                    if self.storeList.modifiableStore?.isAvailable ?? false {
                        fallback = Constants.emptyStoreModifiableTag
                    } else {
                        fallback = Constants.emptyStoreTag
                    }
                    self.active = self.storeList.stores.compactMap { $0.secrets.first }.first?.id ?? fallback
                }
                .listStyle(SidebarListStyle())
                .frame(minWidth: 100, idealWidth: 240)
            }
            .navigationViewStyle(DoubleColumnNavigationViewStyle())
            .sheet(isPresented: $showingDeletion) {
                if self.storeList.modifiableStore != nil {
                    DeleteSecretView(secret: self.deletingSecret!, store: self.storeList.modifiableStore!) {
                        self.showingDeletion = false
                    }
                }
            }
        }
    }

    func updateNotice() -> some View {
        guard let update = updater.update else { return AnyView(Spacer()) }
        let severity: NoticeView.Severity
        let text: String
        if update.critical {
            severity = .critical
            text = "Critical Security Update Required"
        } else {
            severity = .advisory
            text = "Update Available"
        }
        return AnyView(NoticeView(text: text, severity: severity, actionTitle: "Update") {
            NSWorkspace.shared.open(update.html_url)
        })
    }

    func delete<SecretType: Secret>(secret: SecretType) {
        deletingSecret = AnySecret(secret)
        self.showingDeletion = true
    }
    
}

fileprivate enum Constants {
    static let emptyStoreModifiableTag: AnyHashable = "emptyStoreModifiableTag"
    static let emptyStoreTag: AnyHashable = "emptyStoreModifiableTag"
}


#if DEBUG

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ContentView(storeList: Preview.storeList(stores: [Preview.Store(numberOfRandomSecrets: 0)], modifiableStores: [Preview.StoreModifiable(numberOfRandomSecrets: 0)]), updater: PreviewUpdater())
            ContentView(storeList: Preview.storeList(stores: [Preview.Store()], modifiableStores: [Preview.StoreModifiable()]), updater: PreviewUpdater())
            ContentView(storeList: Preview.storeList(stores: [Preview.Store()]), updater: PreviewUpdater())
            ContentView(storeList: Preview.storeList(modifiableStores: [Preview.StoreModifiable()]), updater: PreviewUpdater())
            ContentView(storeList: Preview.storeList(stores: [Preview.Store(numberOfRandomSecrets: 0)], modifiableStores: [Preview.StoreModifiable(numberOfRandomSecrets: 0)]), updater: PreviewUpdater(update: .advisory))
            ContentView(storeList: Preview.storeList(stores: [Preview.Store(numberOfRandomSecrets: 0)], modifiableStores: [Preview.StoreModifiable(numberOfRandomSecrets: 0)]), updater: PreviewUpdater(update: .critical))
        }
    }
}

#endif
