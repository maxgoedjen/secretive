import SwiftUI

struct AboutView: View {
    var body: some View {
        if #available(macOS 15.0, *) {
            AboutViewContent()
                .containerBackground(
                    .thinMaterial, for: .window
                )
        } else {
            AboutViewContent()
        }
    }
}

struct AboutViewContent: View {

    @Environment(\.openURL) var openURL
    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Image(nsImage: NSApplication.shared.applicationIconImage)
                VStack(alignment: .leading) {
                    Text(verbatim: "Secretive")
                        .font(.system(.largeTitle, weight: .bold))
                    Text("**\(Bundle.main.versionNumber)** (\(Bundle.main.buildNumber))")
                        .fixedSize(horizontal: true, vertical: false)
                    HStack {
                        Button(.aboutViewOnGithubButton) {
                            openURL(URL(string: "https://github.com/maxgoedjen/secretive")!)
                        }
                            .normalButton()
                        Button(.aboutBuildLogButton) {
                            openURL(Bundle.main.buildLog)
                        }
                        .normalButton()
                    }
                }
            }
            Text(.aboutThanks(contributorsLink: "https://github.com/maxgoedjen/secretive/graphs/contributors", sponsorsLink: "https://github.com/sponsors/maxgoedjen"))
                .font(.headline)
            Text(.aboutOpenSourceNotice)
                .font(.subheadline)
        }
        .padding(EdgeInsets(top: 10, leading: 30, bottom: 30, trailing: 30))
    }

}

private extension Bundle {

    var buildLog: URL {
        URL(string: infoDictionary!["GitHubBuildLog"] as! String)!
    }

    var versionNumber: String {
        infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    var buildNumber: String {
        infoDictionary?["CFBundleVersion"] as? String ?? "0.0"
    }

}

#Preview {
    AboutView()
        .frame(width: 500, height: 250)
}
