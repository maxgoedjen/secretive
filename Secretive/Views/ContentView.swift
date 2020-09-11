import SwiftUI
import SecretKit
import Brief

struct ContentView<UpdaterType: UpdaterProtocol, AgentStatusCheckerType: AgentStatusCheckerProtocol>: View {

    @EnvironmentObject var storeList: SecretStoreList
    @EnvironmentObject var updater: UpdaterType
    @EnvironmentObject var agentStatusChecker: AgentStatusCheckerType
    var runSetupBlock: (() -> Void)?

    @State private var active: AnySecret.ID?
    @State private var showingCreation = false
    @State private var deletingSecret: AnySecret?
    @State private var selectedUpdate: Release?

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
            CreateSecretView {
                self.showingCreation = false
            }
        }
        .frame(minWidth: 640, minHeight: 320)
        .toolbar {
//            if updater.update != nil {
                updateNotice()
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

    func updateNotice() -> ToolbarItem<Void, AnyView> {
//        let update =  updater.update ?? Release(name: "", html_url: URL(string:"https://example.com")!, body: "")
        guard let update = updater.update else {
            return ToolbarItem {
                AnyView(Spacer())
            }
        }
        let color: Color
        let text: String
        if update.critical {
            text = "Critical Security Update Required"
            color = .red
        } else {
            text = "Update Available"
            color = .orange
        }
        return ToolbarItem {
            AnyView(Button(action: {
                self.selectedUpdate = update
            }, label: {
                Text(text)
                    .font(.headline)
                    .foregroundColor(.white)
            })
            .background(color)
            .cornerRadius(5)
            .popover(item: $selectedUpdate, attachmentAnchor: .point(.bottom), arrowEdge: .bottom) { update in
                UpdateDetailView(update: update)
            }
            )
        }
    }
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

//
//#if DEBUG
//
//struct ContentView_Previews: PreviewProvider {
//    static var previews: some View {
//        Group {
//            ContentView(storeList: Preview.storeList(stores: [Preview.Store(numberOfRandomSecrets: 0)],
//                                                     modifiableStores: [Preview.StoreModifiable(numberOfRandomSecrets: 0)]),
//                        updater: PreviewUpdater(),
//                        agentStatusChecker: PreviewAgentStatusChecker())
//            ContentView(storeList: Preview.storeList(stores: [Preview.Store()], modifiableStores: [Preview.StoreModifiable()]), updater: PreviewUpdater(),
//                        agentStatusChecker: PreviewAgentStatusChecker())
//            ContentView(storeList: Preview.storeList(stores: [Preview.Store()]), updater: PreviewUpdater(),
//                        agentStatusChecker: PreviewAgentStatusChecker())
//            ContentView(storeList: Preview.storeList(modifiableStores: [Preview.StoreModifiable()]), updater: PreviewUpdater(),
//                        agentStatusChecker: PreviewAgentStatusChecker())
//            ContentView(storeList: Preview.storeList(stores: [Preview.Store(numberOfRandomSecrets: 0)], modifiableStores: [Preview.StoreModifiable(numberOfRandomSecrets: 0)]), updater: PreviewUpdater(update: .advisory),
//                        agentStatusChecker: PreviewAgentStatusChecker())
//            ContentView(storeList: Preview.storeList(stores: [Preview.Store(numberOfRandomSecrets: 0)], modifiableStores: [Preview.StoreModifiable(numberOfRandomSecrets: 0)]), updater: PreviewUpdater(update: .critical),
//                        agentStatusChecker: PreviewAgentStatusChecker())
//            ContentView(storeList: Preview.storeList(stores: [Preview.Store(numberOfRandomSecrets: 0)], modifiableStores: [Preview.StoreModifiable(numberOfRandomSecrets: 0)]), updater: PreviewUpdater(update: .critical),
//                        agentStatusChecker: PreviewAgentStatusChecker(running: false))
//        }
//    }
//}
//
//#endif
