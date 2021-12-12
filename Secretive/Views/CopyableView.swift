import SwiftUI
import UniformTypeIdentifiers

struct CopyableView: View {

    var title: String
    var image: Image
    var text: String

    @State private var interactionState: InteractionState = .normal

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                image
                    .renderingMode(.template)
                    .imageScale(.large)
                    .foregroundColor(primaryTextColor)
                Text(title)
                    .font(.headline)
                    .foregroundColor(primaryTextColor)
                Spacer()
                if interactionState != .normal {
                    Text(hoverText)
                        .bold()
                        .textCase(.uppercase)
                        .foregroundColor(secondaryTextColor)
                        .transition(.opacity)
                }

            }
            .padding(EdgeInsets(top: 20, leading: 20, bottom: 10, trailing: 20))
            Divider()
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
                .foregroundColor(primaryTextColor)
                .padding(EdgeInsets(top: 10, leading: 20, bottom: 20, trailing: 20))
                .multilineTextAlignment(.leading)
                .font(.system(.body, design: .monospaced))
        }
        .background(backgroundColor)
        .frame(minWidth: 150, maxWidth: .infinity)
        .cornerRadius(10)
        .onHover { hovering in
            withAnimation {
                interactionState = hovering ? .hovering : .normal
            }
        }
        .onDrag {
            NSItemProvider(item: NSData(data: text.data(using: .utf8)!), typeIdentifier: UTType.utf8PlainText.identifier)
        }
        .onTapGesture {
            copy()
            withAnimation {
                interactionState = .clicking
            }
        }
        .gesture(
            TapGesture()
                .onEnded {
                    withAnimation {
                        interactionState = .normal
                    }
                }
        )
    }

    var hoverText: String {
        switch interactionState {
        case .hovering:
            return "Click to Copy"
        case .clicking:
            return "Copied"
        case .normal:
            fatalError()
        }
    }

    var backgroundColor: Color {
        let color: NSColor
        switch interactionState {
        case .normal:
            color = .windowBackgroundColor
        case .hovering:
            color = .unemphasizedSelectedContentBackgroundColor
        case .clicking:
            color = .selectedContentBackgroundColor
        }
        return Color(color)
    }

    var primaryTextColor: Color {
        let color: NSColor
        switch interactionState {
        case .normal, .hovering:
            color = .textColor
        case .clicking:
            color = .white
        }
        return Color(color)
    }

    var secondaryTextColor: Color {
        let color: NSColor
        switch interactionState {
        case .normal, .hovering:
            color = .secondaryLabelColor
        case .clicking:
            color = .white
        }
        return Color(color)
    }

    func copy() {
        NSPasteboard.general.declareTypes([.string], owner: nil)
        NSPasteboard.general.setString(text, forType: .string)
    }

    private enum InteractionState {
        case normal, hovering, clicking
    }

}

#if DEBUG

struct CopyableView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            CopyableView(title: "Title", image: Image(systemName: "figure.wave"), text: "Hello world.")
            CopyableView(title: "Title", image: Image(systemName: "figure.wave"), text: "Long text. Long text. Long text. Long text. Long text. Long text. Long text. Long text. Long text. Long text. Long text. Long text. Long text. Long text. Long text. Long text. Long text. Long text. Long text. Long text. Long text. Long text. Long text. Long text. Long text. Long text. Long text. Long text. Long text. ")
        }
    }
}

#endif
