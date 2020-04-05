import SwiftUI
import SecretKit
import Brief

struct ContentView<UpdaterType: UpdaterProtocol, AgentStatusCheckerType: AgentStatusCheckerProtocol>: View {
    
    @ObservedObject var storeList: SecretStoreList
    @ObservedObject var updater: UpdaterType
    @ObservedObject var agentStatusChecker: AgentStatusCheckerType
    var runSetupBlock: (() -> Void)?

    @State fileprivate var active: AnySecret.ID?
    @State fileprivate var showingDeletion = false
    @State fileprivate var deletingSecret: AnySecret?
    
    var body: some View {
        VStack {
            if updater.update != nil {
                updateNotice()
            }
            if !agentStatusChecker.running {
                agentNotice()
            }
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
                .listStyle(SidebarListStyle())
                .frame(minWidth: 100, idealWidth: 240)
            }
            .navigationViewStyle(DoubleColumnNavigationViewStyle())
            .sheet(isPresented: $showingDeletion) {
                if self.storeList.modifiableStore != nil {
                    DeleteSecretView(secret: self.deletingSecret!, store: self.storeList.modifiableStore!) { deleted in
                        self.showingDeletion = false
                        if deleted {
                            self.active = self.nextDefaultSecret
                        }
                    }
                }
            }
            } else {
                NoStoresView()
            }
        }.frame(minWidth: 640, minHeight: 320)
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

    func agentNotice() -> some View {
        NoticeView(text: "Secret Agent isn't running. Run setup again to fix.", severity: .advisory, actionTitle: "Run Setup") {
            self.runSetupBlock?()
        }
    }

    func delete<SecretType: Secret>(secret: SecretType) {
        deletingSecret = AnySecret(secret)
        self.showingDeletion = true
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

fileprivate enum Constants {
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
