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
                    Text(attributedBody)
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

    var attributedBody: AttributedString {
        do {
            var text = try AttributedString(
                markdown: update.body,
                options: .init(
                    allowsExtendedAttributes: true,
                    interpretedSyntax: .full,
                ),
                baseURL: URL(string: "https://github.com/maxgoedjen/secretive")!
            )
            .transformingAttributes(AttributeScopes.FoundationAttributes.PresentationIntentAttribute.self) { key in
                let font: Font? = switch key.value?.components.first?.kind {
                case .header(level: 1):
                    Font.title
                case .header(level: 2):
                    Font.title2
                case .header(level: 3):
                    Font.title3
                default:
                    nil
                }
                if let font {
                    key.replace(with: AttributeScopes.SwiftUIAttributes.FontAttribute.self, value: font)
                }
            }
            let lineBreak = AttributedString("\n\n")
            for run in text.runs.reversed() {
                text.insert(lineBreak, at: run.range.lowerBound)
            }
            return text
        } catch {
            var text = AttributedString()
            for line in update.body.split(whereSeparator: \.isNewline) {
                let attributed: AttributedString
                let split = line.split(separator: " ")
                let unprefixed = split.dropFirst().joined(separator: " ")
                if let prefix = split.first {
                    var container = AttributeContainer()
                    switch prefix {
                    case "#":
                        container.font = .title
                    case "##":
                        container.font = .title2
                    case "###":
                        container.font = .title3
                    default:
                        continue
                    }
                    attributed = AttributedString(unprefixed, attributes: container)
                } else {
                    attributed = AttributedString(line + "\n\n")
                }
                text = text + attributed
            }
            return text
        }
    }

}
