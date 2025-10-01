import SwiftUI
import SecretKit
import SecureEnclaveSecretKit
import SmartCardSecretKit
import Brief

struct ContentView: View {

    @State var activeSecret: AnySecret?

    @State private var selectedUpdate: Release?

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openWindow) private var openWindow
    @Environment(\.secretStoreList) private var storeList
    @Environment(\.updater) private var updater
    @Environment(\.agentLaunchController) private var agentLaunchController

    @AppStorage("defaultsHasRunSetup") private var hasRunSetup = false
    @State private var showingCreation = false
    @State private var showingAppPathNotice = false
    @State private var runningSetup = false
    @State private var showingAgentInfo = false

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
        .onAppear {
            if !hasRunSetup {
                runningSetup = true
            }
        }
        .focusedSceneValue(\.showCreateSecret,  .init(isEnabled: !runningSetup) {
            showingCreation = true
        })
        .sheet(isPresented: $showingCreation) {
            if let modifiable = storeList.modifiableStore {
                CreateSecretView(store: modifiable) { created in
                    if let created {
                        activeSecret = created
                    }
                }
            }
        }
        .sheet(isPresented: $runningSetup) {
            SetupView(setupComplete: $hasRunSetup)
        }
    }

}

extension ContentView {


    @ToolbarContentBuilder
    func toolbarItem(_ view: some View, id: String) -> some ToolbarContent {
        if #available(macOS 26.0, *) {
            ToolbarItem(id: id) { view }
                .sharedBackgroundVisibility(.hidden)
        } else {
            ToolbarItem(id: id) { view }
        }
    }

    /// Item either showing a "everything's good, here's more info" or "something's wrong, re-run setup" message
    /// These two are mutually exclusive
    @ViewBuilder
    var runningOrRunSetupView: some View {
        agentStatusToolbarView
    }

    var updateNoticeContent: (LocalizedStringResource, Color)? {
        guard let update = updater.update else { return nil }
        if update.critical {
            return (.updateCriticalNoticeTitle, .red)
        } else {
            if updater.currentVersion.isTestBuild {
                return (.updateTestNoticeTitle, .blue)
            } else {
                return (.updateNormalNoticeTitle, .orange)
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
            .buttonStyle(ToolbarStatusButtonStyle(color: color))
            .sheet(item: $selectedUpdate) { update in
                UpdateDetailView(update: update)
            }
        }
    }

    @ViewBuilder
    var newItemView: some View {
        if storeList.modifiableStore?.isAvailable ?? false {
            Button(.appMenuNewSecretButton, systemImage: "plus") {
                showingCreation = true
            }
            .toolbarCircleButton()
        }
    }

    @ViewBuilder
    var agentStatusToolbarView: some View {
        Button(action: {
            showingAgentInfo = true
        }, label: {
            HStack {
                if agentLaunchController.running {
                    Text(.agentRunningNoticeTitle)
                        .font(.headline)
                        .foregroundColor(colorScheme == .light ? Color(white: 0.3) : .white)
                    Circle()
                        .frame(width: 10, height: 10)
                        .foregroundColor(Color.green)
                } else {
                    Text(.agentNotRunningNoticeTitle)
                        .font(.headline)
                    Circle()
                        .frame(width: 10, height: 10)
                        .foregroundColor(Color.red)
                }
            }
        })
        .buttonStyle(
            ToolbarStatusButtonStyle(
                lightColor: agentLaunchController.running ? .black.opacity(0.05) : .red.opacity(0.75),
                darkColor: agentLaunchController.running ? .white.opacity(0.05) : .red.opacity(0.5),
            )
        )
        .popover(isPresented: $showingAgentInfo, attachmentAnchor: attachmentAnchor, arrowEdge: .bottom) {
            AgentStatusView()
        }
    }

    @ViewBuilder
    var appPathNoticeView: some View {
        if !ApplicationDirectoryController().isInApplicationsDirectory {
            Button(action: {
                showingAppPathNotice = true
            }, label: {
                Group {
                    Text(.appNotInApplicationsNoticeTitle)
                }
                .font(.headline)
                .foregroundColor(.white)
            })
            .buttonStyle(ToolbarStatusButtonStyle(color: .orange))
            .confirmationDialog(.appNotInApplicationsNoticeTitle, isPresented: $showingAppPathNotice) {
                Button(.appNotInApplicationsNoticeCancelButton, role:  .cancel) {
                }
                Button(.appNotInApplicationsNoticeQuitButton) {
                    NSWorkspace.shared.selectFile(Bundle.main.bundlePath, inFileViewerRootedAtPath: Bundle.main.bundlePath)
                    NSApplication.shared.terminate(nil)
                }
            } message: {
                Text(.appNotInApplicationsNoticeDetailDescription)
            }
            .dialogIcon(Image(systemName: "folder.fill.badge.questionmark"))
        }
    }

    var attachmentAnchor: PopoverAttachmentAnchor {
        .rect(.bounds)
    }

}


//#Preview {
//    // Empty on modifiable and nonmodifiable
//    ContentView(showingCreation: .constant(false), runningSetup: .constant(false), hasRunSetup: .constant(true))
//        .environment(Preview.storeList(stores: [Preview.Store(numberOfRandomSecrets: 0)], modifiableStores: [Preview.StoreModifiable(numberOfRandomSecrets: 0)]))
//        .environment(PreviewUpdater())
//}
//
//#Preview {
//    // 5 items on modifiable and nonmodifiable
//    ContentView(showingCreation: .constant(false), runningSetup: .constant(false), hasRunSetup: .constant(true))
//        .environment(Preview.storeList(stores: [Preview.Store()], modifiableStores: [Preview.StoreModifiable()]))
//        .environment(PreviewUpdater())
//}
