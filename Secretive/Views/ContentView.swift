import SwiftUI
import SecretKit
import Brief

struct ContentView<UpdaterType: UpdaterProtocol, AgentStatusCheckerType: AgentStatusCheckerProtocol>: View {
    
    @ObservedObject var storeList: SecretStoreList
    @ObservedObject var updater: UpdaterType
    @ObservedObject var agentStatusChecker: AgentStatusCheckerType
    var runSetupBlock: (() -> Void)?

    @State private var active: AnySecret.ID?
    @State private var showingCreation = false
    @State private var deletingSecret: AnySecret?
    
    var body: some View {
        VStack {
            if storeList.anyAvailable {
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
                    self.active = self.nextDefaultSecret
                }
                .frame(minWidth: 100, idealWidth: 240)
                .sheet(item: $deletingSecret) { secret in
                    if self.storeList.modifiableStore != nil {
                        DeleteSecretView(secret: secret, store: self.storeList.modifiableStore!) { deleted in
                            self.deletingSecret = nil
                            if deleted {
                                self.active = self.nextDefaultSecret
                            }
                        }
                    }
                }
            }
            } else {
                NoStoresView()
            }
        }
        .sheet(isPresented: $showingCreation) {
            CreateSecretView(store: storeList.modifiableStore!) {
                self.showingCreation = false
            }
        }
        .frame(minWidth: 640, minHeight: 320)
        .toolbar {
//            if updater.update != nil {
//                updateNotice()
//            }
//            if !agentStatusChecker.running {
//                agentNotice()z
//            }
            ToolbarItem {
                Button(action: {
                    self.showingCreation = true
                }, label: {
                    Image(systemName: "plus")
                })
            }
        }
    }

//    func updateNotice() -> ToolbarItem<Void, some View> {
//        guard let update = updater.update else { fatalError() }
//        let color: Color
//        let text: String
//        if update.critical {
//            text = "Critical Security Update Required"
//            color = .orange
//        } else {
//            text = "Update Available"
//            color = .red
//        }
//        return ToolbarItem {
//            Button(action: {
//                NSWorkspace.shared.open(update.html_url)
//            }, label: {
//                Text(text)
//                    .font(.headline)
//                    .foregroundColor(.white)
//            })
//            .background(color)
//            .cornerRadius(5)
//        }
//    }
//
//    func agentNotice() -> ToolbarItem<Void, AnyView> {
//        ToolbarItem {
//            Button(action: {
//                self.runSetupBlock?()
//            }, label: {
//                Text("Agent is not running.")
//                    .font(.headline)
//                    .foregroundColor(.white)
//            })
//            .background(Color.orange)
//            .cornerRadius(5)
//        }
//    }

    func delete<SecretType: Secret>(secret: SecretType) {
        deletingSecret = AnySecret(secret)
    }

    var nextDefaultSecret: AnyHashable? {
        let fallback: AnyHashable
        if self.storeList.modifiableStore?.isAvailable ?? false {
            fallback = Constants.emptyStoreModifiableTag
        } else {
            fallback = Constants.emptyStoreTag
        }
        return self.storeList.stores.compactMap(\.secrets.first).first?.id ?? fallback
    }
    
}

private enum Constants {
    static let emptyStoreModifiableTag: AnyHashable = "emptyStoreModifiableTag"
    static let emptyStoreTag: AnyHashable = "emptyStoreModifiableTag"
}


#if DEBUG

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ContentView(storeList: Preview.storeList(stores: [Preview.Store(numberOfRandomSecrets: 0)],
                                                     modifiableStores: [Preview.StoreModifiable(numberOfRandomSecrets: 0)]),
                        updater: PreviewUpdater(),
                        agentStatusChecker: PreviewAgentStatusChecker())
            ContentView(storeList: Preview.storeList(stores: [Preview.Store()], modifiableStores: [Preview.StoreModifiable()]), updater: PreviewUpdater(),
                        agentStatusChecker: PreviewAgentStatusChecker())
            ContentView(storeList: Preview.storeList(stores: [Preview.Store()]), updater: PreviewUpdater(),
                        agentStatusChecker: PreviewAgentStatusChecker())
            ContentView(storeList: Preview.storeList(modifiableStores: [Preview.StoreModifiable()]), updater: PreviewUpdater(),
                        agentStatusChecker: PreviewAgentStatusChecker())
            ContentView(storeList: Preview.storeList(stores: [Preview.Store(numberOfRandomSecrets: 0)], modifiableStores: [Preview.StoreModifiable(numberOfRandomSecrets: 0)]), updater: PreviewUpdater(update: .advisory),
                        agentStatusChecker: PreviewAgentStatusChecker())
            ContentView(storeList: Preview.storeList(stores: [Preview.Store(numberOfRandomSecrets: 0)], modifiableStores: [Preview.StoreModifiable(numberOfRandomSecrets: 0)]), updater: PreviewUpdater(update: .critical),
                        agentStatusChecker: PreviewAgentStatusChecker())
            ContentView(storeList: Preview.storeList(stores: [Preview.Store(numberOfRandomSecrets: 0)], modifiableStores: [Preview.StoreModifiable(numberOfRandomSecrets: 0)]), updater: PreviewUpdater(update: .critical),
                        agentStatusChecker: PreviewAgentStatusChecker(running: false))
        }
    }
}

#endif
