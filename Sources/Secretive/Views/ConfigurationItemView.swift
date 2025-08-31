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
                    Button("Reveal in Finder", systemImage: "folder") {
                        NSWorkspace.shared.selectFile(string, inFileViewerRootedAtPath: string)
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                case .revealInFinder(let string):
                    Button("Reveal in Finder", systemImage: "folder") {
                        NSWorkspace.shared.selectFile(string, inFileViewerRootedAtPath: string)
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

