import SwiftUI
import SecretKit

struct SecretDetailView<SecretType: Secret>: View {
    
    @State var secret: SecretType

    private let keyWriter = OpenSSHKeyWriter()
    
    var body: some View {
        Form {
            Section {
                CopyableView(title: "Fingerprint", image: Image(systemName: "touchid"), text: keyWriter.openSSHFingerprint(secret: secret))
                Spacer()
                    .frame(height: 20)
                CopyableView(title: "Public Key", image: Image(systemName: "key"), text: keyWriter.openSSHString(secret: secret))
                Spacer()
            }
        }
        .padding()
        .frame(minHeight: 150, maxHeight: .infinity)
        
    }
    
    var keyString: String {
        keyWriter.openSSHString(secret: secret)
    }
    
    func copy() {
        NSPasteboard.general.declareTypes([.string], owner: nil)
        NSPasteboard.general.setString(keyString, forType: .string)
    }
    
}

struct SecretDetailView_Previews: PreviewProvider {
    static var previews: some View {
        SecretDetailView(secret: Preview.Store(numberOfRandomSecrets: 1).secrets[0])
    }
}

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
                    .foregroundColor(primaryTextColor)
                Text(title)
                    .font(.headline)
                    .foregroundColor(primaryTextColor)
                Spacer()
                Text(hoverText)
                    .bold()
                    .textCase(.uppercase)
                    .foregroundColor(secondaryTextColor)
                    .transition(.opacity)
            }
            .padding(EdgeInsets(top: 20, leading: 20, bottom: 10, trailing: 20))
            Divider()
            Text(text)
                .foregroundColor(primaryTextColor)
                .padding(EdgeInsets(top: 10, leading: 20, bottom: 20, trailing: 20))
                .multilineTextAlignment(.leading)
                .font(.system(.body, design: .monospaced))
        }
        .frame(minWidth: 150, maxWidth: .infinity)
        .background(backgroundColor)
        .cornerRadius(10)
        .onHover { hovering in
            interactionState = hovering ? .hovering : .normal
        }
        .onDrag {
            NSItemProvider(item: NSData(data: text.data(using: .utf8)!), typeIdentifier: kUTTypeUTF8PlainText as String)
        }
        .animation(.spring())
        .onTapGesture {
            copy()
            interactionState = .clicking
        }
        .gesture(
            TapGesture()
                .onEnded {
                    interactionState = .normal
                }
        )
    }

    var hoverText: String {
        switch interactionState {
        case .hovering:
            return "Click to Copy"
        case .clicking:
            return "Copied!"
        case .normal:
            return ""
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
