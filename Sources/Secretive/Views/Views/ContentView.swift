import SwiftUI
import SecretKit
import SecureEnclaveSecretKit
import SmartCardSecretKit
import Brief

struct ContentView: View {

    @Binding var showingCreation: Bool
    @Binding var runningSetup: Bool
    @Binding var hasRunSetup: Bool
    @State var showingAgentInfo = false
    @State var activeSecret: AnySecret?
    @Environment(\.colorScheme) var colorScheme

    @Environment(\.secretStoreList) private var storeList
    @Environment(\.updater) private var updater: any UpdaterProtocol
    @Environment(\.agentStatusChecker) private var agentStatusChecker: any AgentStatusCheckerProtocol

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
            .buttonStyle(ToolbarButtonStyle(color: color))
            .sheet(item: $selectedUpdate) { update in
                VStack {
                    if updater.currentVersion.isTestBuild {
                        VStack {
                            if let description = updater.currentVersion.previewDescription {
                                Text(description)
                            }
                            Link(destination: URL(string: "https://github.com/maxgoedjen/secretive/actions/workflows/nightly.yml")!) {
                                Button(.updaterDownloadLatestNightlyButton) {}
                                    .frame(maxWidth: .infinity)
                                    .primaryButton()
                            }
                        }
                        .padding()
                    }
                    UpdateDetailView(update: update)
                }
            }
        }
    }

    @ViewBuilder
    var newItemView: some View {
        if storeList.modifiableStore?.isAvailable ?? false {
            Button(.appMenuNewSecretButton, systemImage: "plus") {
                showingCreation = true
            }
            .menuButton()
            .sheet(isPresented: $showingCreation) {
                if let modifiable = storeList.modifiableStore {
                    CreateSecretView(store: modifiable) { created in
                        if let created {
                            activeSecret = created
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    var agentStatusToolbarView: some View {
        Button(action: {
            showingAgentInfo = true
        }, label: {
            HStack {
                if agentStatusChecker.running {
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
            ToolbarButtonStyle(
                lightColor: agentStatusChecker.running ? .black.opacity(0.05) : .red.opacity(0.75),
                darkColor: agentStatusChecker.running ? .white.opacity(0.05) : .red.opacity(0.5),
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
            .buttonStyle(ToolbarButtonStyle(color: .orange))
            .popover(isPresented: $showingAppPathNotice, attachmentAnchor: attachmentAnchor, arrowEdge: .bottom) {
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 64)
                    Text(.appNotInApplicationsNoticeDetailDescription)
                        .frame(maxWidth: 300)
                }
                .padding()
            }
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
