import SwiftUI
import Brief

struct UpdateDetailView: View {

    @Environment(\.updater) var updater
    @Environment(\.openURL) var openURL

    let update: Release

    var body: some View {
            VStack(spacing: 0) {
                HStack {
                    if !update.critical {
                        Button(.updateIgnoreButton) {
                            Task {
                                await updater.ignore(release: update)
                            }
                        }
                        .buttonStyle(ToolbarButtonStyle())
                    }
                    Spacer()
                    if updater.currentVersion.isTestBuild {
                        Button(.updaterDownloadLatestNightlyButton) {
                            openURL(URL(string: "https://github.com/maxgoedjen/secretive/actions/workflows/nightly.yml")!)
                        }
                        .buttonStyle(ToolbarButtonStyle(tint: .accentColor))
                    }
                    Button(.updateUpdateButton) {
                        openURL(update.html_url)
                    }
                    .buttonStyle(ToolbarButtonStyle(tint: .accentColor))
                    .keyboardShortcut(.defaultAction)
                }
                .padding()
                Divider()
                Form {
                    Section {
                        Text(update.attributedBody)
                    } header: {
                        Text(.updateVersionName(updateName: update.name))                    .headerProminence(.increased)
                    }
                }
                .formStyle(.grouped)
        }
    }

}

#Preview {
    UpdateDetailView(update: .init(name: "3.0.0", prerelease: false, html_url: URL(string: "https://example.com")!, body: "Hello"))
}
