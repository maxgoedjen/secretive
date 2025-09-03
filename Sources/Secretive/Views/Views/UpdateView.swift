import SwiftUI
import Brief

struct UpdateDetailView: View {

    @Environment(\.updater) var updater: any UpdaterProtocol

    let update: Release

    var body: some View {
        VStack {
            Text(.updateVersionName(updateName: update.name)).font(.title)
            GroupBox(label: Text(.updateReleaseNotesTitle)) {
                ScrollView {
                    attributedBody
                }
            }
            HStack {
                if !update.critical {
                    Button(.updateIgnoreButton) {
                        Task {
                            await updater.ignore(release: update)
                        }
                    }
                    Spacer()
                }
                Button(.updateUpdateButton) {
                    NSWorkspace.shared.open(update.html_url)
                }
                .keyboardShortcut(.defaultAction)
            }
            
        }
        .padding()
        .frame(maxWidth: 500)
    }

    var attributedBody: Text {
        var text = Text(verbatim: "")
        for line in update.body.split(whereSeparator: \.isNewline) {
            let attributed: Text
            let split = line.split(separator: " ")
            let unprefixed = split.dropFirst().joined(separator: " ")
            if let prefix = split.first {
                switch prefix {
                case "#":
                    attributed = Text(unprefixed).font(.title) + Text(verbatim: "\n")
                case "##":
                    attributed = Text(unprefixed).font(.title2) + Text(verbatim: "\n")
                case "###":
                    attributed = Text(unprefixed).font(.title3) + Text(verbatim: "\n")
                default:
                    attributed = Text(line) + Text(verbatim: "\n\n")
                }
            } else {
                attributed = Text(line) + Text(verbatim: "\n\n")
            }
            text = text + attributed
        }
        return text
    }

}
