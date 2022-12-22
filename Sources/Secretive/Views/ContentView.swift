import SwiftUI
import SecretKit
import SecureEnclaveSecretKit
import SmartCardSecretKit
import Brief

struct ContentView<UpdaterType: UpdaterProtocol, AgentStatusCheckerType: AgentStatusCheckerProtocol>: View {

    @Binding var showingCreation: Bool
    @Binding var runningSetup: Bool
    @Binding var hasRunSetup: Bool
    @State var showingAgentInfo = false
    @Environment(\.colorScheme) var colorScheme

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
            toolbarItem(updateNoticeView, id: "update")
            toolbarItem(runningOrRunSetupView, id: "setup")
            toolbarItem(appPathNoticeView, id: "appPath")
            toolbarItem(newItemView, id: "new")
        }
        .sheet(isPresented: $runningSetup) {
            SetupView(visible: $runningSetup, setupComplete: $hasRunSetup)
        }
    }

}

extension ContentView {


    func toolbarItem(_ view: some View, id: String) -> ToolbarItem<String, some View> {
        ToolbarItem(id: id) { view }
    }

    var needsSetup: Bool {
        (runningSetup || !hasRunSetup || !agentStatusChecker.running) && !agentStatusChecker.developmentBuild
    }

    /// Item either showing a "everything's good, here's more info" or "something's wrong, re-run setup" message
    /// These two are mutually exclusive
    @ViewBuilder
    var runningOrRunSetupView: some View {
        if needsSetup {
            setupNoticeView
        } else {
            runningNoticeView
        }
    }

    var updateNoticeContent: (String, Color)? {
        guard let update = updater.update else { return nil }
        if update.critical {
            return ("Critical Security Update Required", .red)
        } else {
            if updater.testBuild {
                return ("Test Build", .blue)
            } else {
                return ("Update Available", .orange)
            }
        }
    }

    @ViewBuilder
    var updateNoticeView: some View {
        if let update = updater.update, let (text, color) = updateNoticeContent {
            Button(action: {
                selectedUpdate = update
            }, label: {
                Text(text)
                    .font(.headline)
                    .foregroundColor(.white)
            })
            .buttonStyle(ToolbarButtonStyle(color: color))
            .popover(item: $selectedUpdate, attachmentAnchor: .point(.bottom), arrowEdge: .bottom) { update in
                UpdateDetailView(update: update)
            }
        }
    }

    @ViewBuilder
    var newItemView: some View {
        if storeList.modifiableStore?.isAvailable ?? false {
            Button(action: {
                showingCreation = true
            }, label: {
                Image(systemName: "plus")
            })
            .sheet(isPresented: $showingCreation) {
                if let modifiable = storeList.modifiableStore {
                    CreateSecretView(store: modifiable, showing: $showingCreation)
                }
            }
        }
    }

    @ViewBuilder
    var setupNoticeView: some View {
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
        .buttonStyle(ToolbarButtonStyle(color: .orange))
    }

    @ViewBuilder
    var runningNoticeView: some View {
        Button(action: {
            showingAgentInfo = true
        }, label: {
            HStack {
                Text("Agent is Running")
                    .font(.headline)
                    .foregroundColor(colorScheme == .light ? Color(white: 0.3) : .white)
                Circle()
                    .frame(width: 10, height: 10)
                    .foregroundColor(Color.green)
            }
        })
        .buttonStyle(ToolbarButtonStyle(lightColor: .black.opacity(0.05), darkColor: .white.opacity(0.05)))
        .popover(isPresented: $showingAgentInfo, attachmentAnchor: .point(.bottom), arrowEdge: .bottom) {
            VStack {
                Text("SecretAgent is Running")
                    .font(.title)
                    .padding(5)
                Text("SecretAgent is a process that runs in the background to sign requests, so you don't need to keep Secretive open all the time.\n\n**You can close Secretive, and everything will still keep working.**")
                    .frame(width: 300)
                Button("Restart Agent") {
                    self.agentStatusChecker.restart()
                }
            }
            .padding()
        }
    }

    @ViewBuilder
    var appPathNoticeView: some View {
        if !ApplicationDirectoryController().isInApplicationsDirectory {
            Button(action: {
                showingAppPathNotice = true
            }, label: {
                Group {
                    Text("Secretive Is Not in Applications Folder")
                }
                .font(.headline)
                .foregroundColor(.white)
            })
            .buttonStyle(ToolbarButtonStyle(color: .orange))
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

