import SwiftUI
import UniformTypeIdentifiers

struct CopyableView: View {

    var title: LocalizedStringResource
    var image: Image
    var text: String
    var showRevealInFinder = false

    @State private var interactionState: InteractionState = .normal
    
    var content: some View {
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
                    HStack {
                        if showRevealInFinder {
                            revealInFinderButton
                        }
                        copyButton
                    }
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
        ._background(interactionState: interactionState)
        .frame(minWidth: 150, maxWidth: .infinity)
    }

    var body: some View {
        content
        .onHover { hovering in
            withAnimation {
                interactionState = hovering ? .hovering : .normal
            }
        }
        .onDrag({
            NSItemProvider(item: NSData(data: text.data(using: .utf8)!), typeIdentifier: UTType.utf8PlainText.identifier)
        }, preview: {
            content
                ._background(interactionState: .dragging)
        })
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

    @ViewBuilder
    var copyButton: some View {
        switch interactionState {
        case .hovering:
            Button(.copyableClickToCopyButton, systemImage: "document.on.document") {
                withAnimation {
                    // Button will eat the click, so we set interaction state manually.
                    interactionState = .clicking
                }
                copy()
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
        case .clicking:
            Image(systemName: "checkmark.circle.fill")
                .accessibilityLabel(String(localized: .copyableCopied))
        case .normal, .dragging:
            EmptyView()
        }
    }

    var revealInFinderButton: some View {
        Button(.revealInFinderButton, systemImage: "folder") {
            let (processedPath, folder) = text.normalizedPathAndFolder
            NSWorkspace.shared.selectFile(processedPath, inFileViewerRootedAtPath: folder)
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.borderless)
    }

    var primaryTextColor: Color {
        switch interactionState {
        case .normal, .hovering, .dragging:
            return Color(.textColor)
        case .clicking:
            return .white
        }
    }

    var secondaryTextColor: Color {
        switch interactionState {
        case .normal, .hovering, .dragging:
            return Color(.secondaryLabelColor)
        case .clicking:
            return .white
        }
    }

    func copy() {
        NSPasteboard.general.declareTypes([.string], owner: nil)
        NSPasteboard.general.setString(text, forType: .string)
    }

}

fileprivate enum InteractionState {
    case normal, hovering, clicking, dragging
}

extension View {
       
    fileprivate func _background(interactionState: InteractionState) -> some View {
        modifier(BackgroundViewModifier(interactionState: interactionState))
    }
    
}

fileprivate struct BackgroundViewModifier: ViewModifier {
    
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.appearsActive) private var appearsActive

    let interactionState: InteractionState

    func body(content: Content) -> some View {
        if interactionState == .dragging {
            content
                .background(backgroundColor(interactionState: interactionState), in: RoundedRectangle(cornerRadius: 15))
        } else {
            if #available(macOS 26.0, *) {
                content
                // Very thin opacity lets user hover anywhere over the view, glassEffect doesn't allow.
                    .background(.white.opacity(0.01), in: RoundedRectangle(cornerRadius: 15))
                    .glassEffect(.regular.tint(backgroundColor(interactionState: interactionState)), in: RoundedRectangle(cornerRadius: 15))
                
            } else {
                content
                    .background(backgroundColor(interactionState: interactionState))
                    .cornerRadius(10)
            }
        }
    }
    
    func backgroundColor(interactionState: InteractionState) -> Color {
        guard appearsActive else { return Color.clear }
        switch interactionState {
        case .normal:
            return colorScheme == .dark ? Color(white: 0.2) : Color(white: 0.885)
        case .hovering, .dragging:
            return colorScheme == .dark ? Color(white: 0.275) : Color(white: 0.82)
        case .clicking:
            return .accentColor
        }
    }

    
}

#Preview {
    CopyableView(title: .secretDetailSha256FingerprintLabel, image: Image(systemName: "figure.wave"), text: "Hello world.")
        .padding()
}

#Preview {
    CopyableView(title: .secretDetailSha256FingerprintLabel, image: Image(systemName: "figure.wave"), text: "Long text. Long text. Long text. Long text. Long text. Long text. Long text. Long text. Long text. Long text. Long text. Long text. Long text. Long text. Long text. Long text. Long text. Long text. Long text. Long text. Long text. Long text. Long text. Long text. Long text. Long text. Long text. Long text. Long text. ")
        .padding()
}
