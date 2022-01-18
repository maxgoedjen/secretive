import SwiftUI
import Brief

struct UpdateDetailView<UpdaterType: Updater>: View {

    @EnvironmentObject var updater: UpdaterType

    let update: Release

    var body: some View {
        VStack {
            Text("Secretive \(update.name)").font(.title)
            GroupBox(label: Text("Release Notes")) {
                ScrollView {
                    attributedBody
                }
            }
            HStack {
                if !update.critical {
                    Button("Ignore") {
                        Task { [updater, update] in
                            await updater.ignore(release: update)
                        }
                    }
                    Spacer()
                }
                Button("Update") {
                    NSWorkspace.shared.open(update.html_url)
                }
                .keyboardShortcut(.defaultAction)
            }
            
        }
        .padding()
        .frame(maxWidth: 500)
    }

    var attributedBody: Text {
        var text = Text("")
        for line in update.body.split(whereSeparator: \.isNewline) {
            let attributed: Text
            let split = line.split(separator: " ")
            let unprefixed = split.dropFirst().joined()
            if let prefix = split.first {
                switch prefix {
                case "#":
                    attributed = Text(unprefixed).font(.title) + Text("\n")
                case "##":
                    attributed = Text(unprefixed).font(.title2) + Text("\n")
                case "###":
                    attributed = Text(unprefixed).font(.title3) + Text("\n")
                default:
                    attributed = Text(line) + Text("\n\n")
                }
            } else {
                attributed = Text(line) + Text("\n\n")
            }
            text = text + attributed
        }
        return text
    }

}
