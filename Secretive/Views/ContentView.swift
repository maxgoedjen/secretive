import SwiftUI
import SecretKit
import Brief

struct ContentView<UpdaterType: UpdaterProtocol, AgentStatusCheckerType: AgentStatusCheckerProtocol>: View {

    @EnvironmentObject var storeList: SecretStoreList
    @EnvironmentObject var updater: UpdaterType
    @EnvironmentObject var agentStatusChecker: AgentStatusCheckerType

    @State private var active: AnySecret.ID?
    @State private var showingCreation = false
    @State private var deletingSecret: AnySecret?
    @State private var selectedUpdate: Release?
    @Binding var runningSetup: Bool

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
                                            NavigationLink(destination: EmptyStoreModifiableView(), tag: Constants.emptyStoreModifiableTag, selection: $active) {
                                                Text("No Secrets")
                                            }
                                        } else {
                                            NavigationLink(destination: EmptyStoreView(), tag: Constants.emptyStoreTag, selection: $active) {
                                                Text("No Secrets")
                                            }
                                        }
                                    } else {
                                        ForEach(store.secrets) { secret in
                                            NavigationLink(destination: SecretDetailView(secret: secret), tag: secret.id, selection: $active) {
                                                Text(secret.name)
                                            }.contextMenu {
                                                if store is AnySecretStoreModifiable {
                                                    Button(action: { delete(secret: secret) }) {
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
                        active = nextDefaultSecret
                    }
                    .frame(minWidth: 100, idealWidth: 240)
                    .sheet(item: $deletingSecret) { secret in
                        if storeList.modifiableStore != nil {
                            DeleteSecretView(secret: secret, store: storeList.modifiableStore!) { deleted in
                                deletingSecret = nil
                                if deleted {
                                    active = nextDefaultSecret
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
            CreateSecretView(showing: $showingCreation)
        }
        .frame(minWidth: 640, minHeight: 320)
        .toolbar {
            updateNotice
            agentNotice
            newItem
        }
    }

    var updateNotice: ToolbarItem<Void, AnyView> {
        guard let update = updater.update else {
            return ToolbarItem { AnyView(Spacer()) }
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
                selectedUpdate = update
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

    var newItem: ToolbarItem<Void, AnyView> {
        guard storeList.modifiableStore?.isAvailable ?? false else {
            return ToolbarItem { AnyView(Spacer()) }
        }
        return ToolbarItem {
            AnyView(Button(action: {
                showingCreation = true
            }, label: {
                Image(systemName: "plus")
            }))
        }
    }

    var agentNotice: ToolbarItem<Void, AnyView> {
        guard agentStatusChecker.running else {
            return ToolbarItem { AnyView(Spacer()) }
        }
        return ToolbarItem {
            AnyView(
                Button(action: {
                    runningSetup = true
                }, label: {
                    Text("Secret Agent Is Not Running")
                        .font(.headline)
                        .foregroundColor(.white)
                })
                .background(Color.orange)
                .cornerRadius(5)
            )
        }
    }

    func delete<SecretType: Secret>(secret: SecretType) {
        deletingSecret = AnySecret(secret)
    }

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
