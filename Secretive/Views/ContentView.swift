import SwiftUI
import SecretKit
import Brief

struct ContentView<UpdaterType: UpdaterProtocol, AgentStatusCheckerType: AgentStatusCheckerProtocol>: View {
    
    @Binding var showingCreation: Bool
    @Binding var runningSetup: Bool
    @Binding var hasRunSetup: Bool
    
    @EnvironmentObject private var storeList: SecretStoreList
    @EnvironmentObject private var updater: UpdaterType
    @EnvironmentObject private var agentStatusChecker: AgentStatusCheckerType
    
    @State private var selectedUpdate: Release?
    @State private var showingAppPathNotice = false
    
    var body: some View {
        VStack {
            if storeList.anyAvailable {
                StoreListView(showingCreation: $showingCreation)
            } else {
                NoStoresView()
            }
        }
        .frame(minWidth: 640, minHeight: 320)
        .toolbar {
            updateNotice
            setupNotice
            appPathNotice
            newItem
        }
    }
    
}

extension ContentView {
    
    var updateNotice: ToolbarItem<Void, AnyView> {
        guard let update = updater.update else {
            return ToolbarItem { AnyView(EmptyView()) }
        }
        let color: Color
        let text: String
        if update.critical {
            text = "Critical Security Update Required"
            color = .red
        } else {
            if updater.testBuild {
                text = "Test Build"
                color = .blue
            } else {
                text = "Update Available"
                color = .orange
            }
        }
        return ToolbarItem {
            AnyView(
                Button(action: {
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
            return ToolbarItem { AnyView(EmptyView()) }
        }
        return ToolbarItem {
            AnyView(
                Button(action: {
                    showingCreation = true
                }, label: {
                    Image(systemName: "plus")
                })
                    .popover(isPresented: $showingCreation, attachmentAnchor: .point(.bottom), arrowEdge: .bottom) {
                        if let modifiable = storeList.modifiableStore {
                            CreateSecretView(store: modifiable, showing: $showingCreation)
                        }
                    }
                
            )
        }
    }
    
    var setupNotice: ToolbarItem<Void, AnyView> {
        return ToolbarItem {
            AnyView(
                Group {
                    if (runningSetup || !hasRunSetup || !agentStatusChecker.running) && !agentStatusChecker.developmentBuild  {
                        Button(action: {
                            runningSetup = true
                        }, label: {
                            Group {
                                if hasRunSetup && !agentStatusChecker.running {
                                    Text("Secret Agent Is Not Running")
                                } else {
                                    Text("Setup Secretive")
                                }
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                        })
                            .background(Color.orange)
                            .cornerRadius(5)
                    } else {
                        EmptyView()
                    }
                }
                    .sheet(isPresented: $runningSetup) {
                        SetupView(visible: $runningSetup, setupComplete: $hasRunSetup)
                    }
            )
        }
    }
    
    var appPathNotice: ToolbarItem<Void, AnyView> {
        let controller = ApplicationDirectoryController()
        guard !controller.isInApplicationsDirectory else {
            return ToolbarItem { AnyView(EmptyView()) }
        }
        return ToolbarItem {
            AnyView(
                Button(action: {
                    showingAppPathNotice = true
                }, label: {
                    Group {
                        Text("Secretive Is Not in Applications Folder")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                })
                    .background(Color.orange)
                    .cornerRadius(5)
                    .popover(isPresented: $showingAppPathNotice, attachmentAnchor: .point(.bottom), arrowEdge: .bottom) {
                        VStack {
                            Image(systemName: "exclamationmark.triangle")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 64)
                            Text("Secretive needs to be in your Applications folder to work properly. Please move it and relaunch.")
                                .frame(maxWidth: 300)
                        }
                        .padding()
                    }
            )
        }
    }
    
}

#if DEBUG

struct ContentView_Previews: PreviewProvider {
    
    private static let storeList: SecretStoreList = {
        let list = SecretStoreList()
        list.add(store: SecureEnclave.Store())
        list.add(store: SmartCard.Store())
        return list
    }()
    private static let agentStatusChecker = AgentStatusChecker()
    private static let justUpdatedChecker = JustUpdatedChecker()
    
    @State var hasRunSetup = false
    @State private var showingSetup = false
    @State private var showingCreation = false
    
    static var previews: some View {
        Group {
            // Empty on modifiable and nonmodifiable
            ContentView<PreviewUpdater, AgentStatusChecker>(showingCreation: .constant(false), runningSetup: .constant(false), hasRunSetup: .constant(true))
                .environmentObject(Preview.storeList(stores: [Preview.Store(numberOfRandomSecrets: 0)], modifiableStores: [Preview.StoreModifiable(numberOfRandomSecrets: 0)]))
                .environmentObject(PreviewUpdater())
                .environmentObject(agentStatusChecker)
            
            // 5 items on modifiable and nonmodifiable
            ContentView<PreviewUpdater, AgentStatusChecker>(showingCreation: .constant(false), runningSetup: .constant(false), hasRunSetup: .constant(true))
                .environmentObject(Preview.storeList(stores: [Preview.Store()], modifiableStores: [Preview.StoreModifiable()]))
                .environmentObject(PreviewUpdater())
                .environmentObject(agentStatusChecker)
        }
        .environmentObject(agentStatusChecker)
        
    }
}

#endif
