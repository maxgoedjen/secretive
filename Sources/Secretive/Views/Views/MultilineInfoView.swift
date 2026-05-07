import SwiftUI
import UniformTypeIdentifiers

struct MultilineInfoView: View {

    struct Item {
        let text: String
        let action: (Image, () -> Void)?
    }

    var title: LocalizedStringResource
    var image: Image
    var items: [Item]

    init(title: LocalizedStringResource, image: Image, items: [Item]) {
        self.title = title
        self.image = image
        self.items = items
    }

    init(title: LocalizedStringResource, image: Image, items: [String]) {
        self.title = title
        self.image = image
        self.items = items.map({ Item(text: $0, action: nil) })
    }

    @State private var interactionState: InteractionState = .normal
    @State private var interactionStateIndex: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                image
                    .renderingMode(.template)
                    .imageScale(.large)
                    .foregroundColor(primaryTextColor)
                Text(title)
                    .font(.headline)
                    .foregroundColor(primaryTextColor)
                Spacer()
            }
            .safeAreaPadding(20)
            ForEach(Array(items.enumerated()), id: \.offset) { item in
                Divider()
                    .ignoresSafeArea()
                    .opacity(item.offset == 0 ? 1 : 0.75)
                HStack {
                    Text(item.element.text)
                    Spacer()
                    if let (image, _) = item.element.action {
                        image
                            .foregroundStyle(.secondary)
                    }
                }
                .safeAreaPadding(20)
                ._background(interactionState: interactionStateIndex == item.offset ?  interactionState : .normal, cornerRadius: 0)
                .onHover { hovering in
                    withAnimation {
                        guard item.element.action != nil else { return }
                        interactionState = hovering ? .hovering : .normal
                        interactionStateIndex = item.offset
                    }
                }
                .gesture(
                    TapGesture()
                        .onEnded {
                            item.element.action?.1()
                            withAnimation {
                                interactionState = .normal
                                interactionStateIndex = nil
                            }
                        }
                )

            }
        }
        ._background(interactionState: .normal)
        .frame(minWidth: 150, maxWidth: .infinity)
    }

    var primaryTextColor: Color {
        switch interactionState {
        case .normal, .hovering:
            return Color(.textColor)
        }
    }

    var secondaryTextColor: Color {
        switch interactionState {
        case .normal, .hovering:
            return Color(.secondaryLabelColor)
        }
    }

}

fileprivate enum InteractionState {
    case normal, hovering
}

extension View {
       
    fileprivate func _background(interactionState: InteractionState, cornerRadius: Double = 15) -> some View {
        modifier(BackgroundViewModifier(interactionState: interactionState, cornerRadius: cornerRadius))
    }
    
}

fileprivate struct BackgroundViewModifier: ViewModifier {
    
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.appearsActive) private var appearsActive
    
    let interactionState: InteractionState
    let cornerRadius: Double
    
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content
            // Very thin opacity lets user hover anywhere over the view, glassEffect doesn't allow.
                .background(.white.opacity(0.01), in: RoundedRectangle(cornerRadius: 15))
                .glassEffect(.regular.tint(backgroundColor(interactionState: interactionState)), in: RoundedRectangle(cornerRadius: cornerRadius))
                .mask(RoundedRectangle(cornerRadius: cornerRadius))
                .shadow(color: .black.opacity(0.1), radius: 5)
        } else {
            content
                .background(backgroundColor(interactionState: interactionState))
                .cornerRadius(10)
        }
    }
    
    func backgroundColor(interactionState: InteractionState) -> Color {
        guard appearsActive else { return Color.clear }
        if #available(macOS 26.0, *) {
            let base = colorScheme == .dark ? Color(white: 0.2) : Color(white: 1)
            switch interactionState {
            case .normal:
                return base
            case .hovering:
                return base.mix(with: .accentColor, by: colorScheme == .dark ? 0.2 : 0.1)
            }
        } else {
            switch interactionState {
            case .normal:
                return colorScheme == .dark ? Color(white: 0.2) : Color(white: 0.885)
            case .hovering:
                return colorScheme == .dark ? Color(white: 0.275) : Color(white: 0.82)
            }
        }
    }
    
    
}

#Preview {
    MultilineInfoView(title: "Multiple", image: Image(systemName: "figure.wave"), items: [
        MultilineInfoView.Item(text: "hello", action: (Image(systemName: "chevron.forward"), {})),
        MultilineInfoView.Item(text: "World", action: (Image(systemName: "chevron.forward"), {})),
    ])
    .padding()
}


#Preview {
    MultilineInfoView(title: "One", image: Image(systemName: "figure.wave"), items: ["Hello world."])
        .padding()
}
