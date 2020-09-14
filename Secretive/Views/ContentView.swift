import SwiftUI
import SecretKit
import Brief

struct ContentView<UpdaterType: UpdaterProtocol, AgentStatusCheckerType: AgentStatusCheckerProtocol>: View {

    @EnvironmentObject var storeList: SecretStoreList
    @EnvironmentObject var updater: UpdaterType
    @EnvironmentObject var agentStatusChecker: AgentStatusCheckerType

    @State private var showingCreation = false
    @State private var selectedUpdate: Release?
    @Binding var runningSetup: Bool

    var body: some View {
        VStack {
            if storeList.anyAvailable {
                StoreListView()
                    .sheet(isPresented: $showingCreation) {
                        if let store = storeList.modifiableStore {
                            CreateSecretView(store: store, showing: $showingCreation)
                        }
                    }
            } else {
                NoStoresView()
            }
        }
        .frame(minWidth: 640, minHeight: 320)
        .toolbar {
            updateNotice
            agentNotice
            newItem
        }
    }

}

extension ContentView {

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
