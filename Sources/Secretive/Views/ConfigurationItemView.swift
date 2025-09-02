import SwiftUI

struct ConfigurationItemView<Content: View>: View {

    enum Action: Hashable {
        case copy(String)
        case revealInFinder(String)
    }

    let title: LocalizedStringResource
    let content: Content
    let action: Action?

    init(title: LocalizedStringResource, value: String, action: Action? = nil) where Content == Text {
        self.title = title
        self.content = Text(value)
            .font(.subheadline)
            .foregroundStyle(.secondary)
        self.action = action
    }

    init(title: LocalizedStringResource, action: Action? = nil, content: () -> Content) {
        self.title = title
        self.content = content()
        self.action = action
    }

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(title)
                Spacer()
                switch action {
                case .copy(let string):
                    Button(.copyButton, systemImage: "document.on.document") {
                        NSPasteboard.general.declareTypes([.string], owner: nil)
                        NSPasteboard.general.setString(string, forType: .string)
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                case .revealInFinder(let rawPath):
                    Button(.revealInFinderButton, systemImage: "folder") {
                        // All foundation-based normalization methods replace this with the container directly.
                        let processedPath = rawPath.replacingOccurrences(of: "~", with: "/Users/\(NSUserName())")
                        let url = URL(filePath: processedPath)
                        let folder = url.deletingLastPathComponent().path()
                        NSWorkspace.shared.selectFile(processedPath, inFileViewerRootedAtPath: folder)
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                case nil:
                    EmptyView()
                }
            }
            content
        }
    }
}

