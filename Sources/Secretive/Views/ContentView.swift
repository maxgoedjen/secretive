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
    @State var activeSecret: AnySecret.ID?
    @Environment(\.colorScheme) var colorScheme

    @EnvironmentObject private var storeList: SecretStoreList
    @EnvironmentObject private var updater: UpdaterType
    @EnvironmentObject private var agentStatusChecker: AgentStatusCheckerType

    @State private var selectedUpdate: Release?
    @State private var showingAppPathNotice = false

    var body: some View {
        VStack {
            if storeList.anyAvailable {
                StoreListView(activeSecret: $activeSecret)
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

    var updateNoticeContent: (LocalizedStringKey, Color)? {
        guard let update = updater.update else { return nil }
        if update.critical {
            return ("update_critical_notice_title", .red)
        } else {
            if updater.testBuild {
                return ("update_test_notice_title", .blue)
            } else {
                return ("update_normal_notice_title", .orange)
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
            .popover(item: $selectedUpdate, attachmentAnchor: attachmentAnchor, arrowEdge: .bottom) { update in
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
                        .onDisappear {
                            guard let newest = modifiable.secrets.last?.id else { return }
                            activeSecret = newest
                        }
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
                    Text("agent_not_running_notice_title")
                } else {
                    Text("agent_setup_notice_title")
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
                Text("agent_running_notice_title")
                    .font(.headline)
                    .foregroundColor(colorScheme == .light ? Color(white: 0.3) : .white)
                Circle()
                    .frame(width: 10, height: 10)
                    .foregroundColor(Color.green)
            }
        })
        .buttonStyle(ToolbarButtonStyle(lightColor: .black.opacity(0.05), darkColor: .white.opacity(0.05)))
        .popover(isPresented: $showingAgentInfo, attachmentAnchor: attachmentAnchor, arrowEdge: .bottom) {
            VStack {
                Text("agent_running_notice_detail_title")
                    .font(.title)
                    .padding(5)
                Text("agent_running_notice_detail_description")
                    .frame(width: 300)
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
                    Text("app_not_in_applications_notice_title")
                }
                .font(.headline)
                .foregroundColor(.white)
            })
            .buttonStyle(ToolbarButtonStyle(color: .orange))
            .popover(isPresented: $showingAppPathNotice, attachmentAnchor: attachmentAnchor, arrowEdge: .bottom) {
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 64)
                    Text("app_not_in_applications_notice_detail_description")
                        .frame(maxWidth: 300)
                }
                .padding()
            }
        }
    }

    var attachmentAnchor: PopoverAttachmentAnchor {
        // Ideally .point(.bottom), but broken on Sonoma (FB12726503)
        .rect(.bounds)
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

