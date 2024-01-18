import SwiftUI
import Brief

struct UpdateDetailView<UpdaterType: Updater>: View {

    @EnvironmentObject var updater: UpdaterType

    let update: Release

    var body: some View {
        VStack {
            Text("update_version_name_\(update.name)").font(.title)
            GroupBox(label: Text("update_release_notes_title")) {
                ScrollView {
                    attributedBody
                }
            }
            HStack {
                if !update.critical {
                    Button("update_ignore_button") {
                        updater.ignore(release: update)
                    }
                    Spacer()
                }
                Button("update_update_button") {
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
