import SwiftUI
import UniformTypeIdentifiers

struct CopyableView: View {

    var title: LocalizedStringKey
    var image: Image
    var text: String

    @State private var interactionState: InteractionState = .normal
    @Environment(\.colorScheme) private var colorScheme

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
        switch interactionState {
        case .normal:
            return colorScheme == .dark ? Color(white: 0.2) : Color(white: 0.885)
        case .hovering:
            return colorScheme == .dark ? Color(white: 0.275) : Color(white: 0.82)
        case .clicking:
            return .accentColor
        }
    }

    var primaryTextColor: Color {
        switch interactionState {
        case .normal, .hovering:
            return Color(.textColor)
        case .clicking:
            return .white
        }
    }

    var secondaryTextColor: Color {
        switch interactionState {
        case .normal, .hovering:
            return Color(.secondaryLabelColor)
        case .clicking:
            return .white
        }
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
            CopyableView(title: "secret_detail_sha256_fingerprint_label", image: Image(systemName: "figure.wave"), text: "Hello world.")
                .padding()
            CopyableView(title: "secret_detail_sha256_fingerprint_label", image: Image(systemName: "figure.wave"), text: "Long text. Long text. Long text. Long text. Long text. Long text. Long text. Long text. Long text. Long text. Long text. Long text. Long text. Long text. Long text. Long text. Long text. Long text. Long text. Long text. Long text. Long text. Long text. Long text. Long text. Long text. Long text. Long text. Long text. ")
                .padding()
        }
    }
}

#endif
