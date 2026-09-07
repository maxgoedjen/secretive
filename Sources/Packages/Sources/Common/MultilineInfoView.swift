import SwiftUI
import UniformTypeIdentifiers

public struct MultilineInfoView<TitleView: View, ItemView: View>: View {

//    public struct Item {
//        public let text: String
//        public let action: (Image, () -> Void)?
//
//        public init(text: String, action: (Image, () -> Void)?) {
//            self.text = text
//            self.action = action
//        }
//
//    }

    var titleView: TitleView
    var items: ItemView

    public init(@ViewBuilder titleView: () -> TitleView, @ContentBuilder items: () -> ItemView) {
        self.titleView = titleView()
        self.items = items()
    }

//    public init(title: LocalizedStringResource, subtitle: LocalizedStringResource, image: Image, items: [String]) where ItemView == Text {
//        self.init {
//            HStack {
//                image
//                    .renderingMode(.template)
////                    .imageScale(.large)
//                    .foregroundColor(primaryTextColor)
//                Text(title)
//                    .font(.headline)
//                    .foregroundColor(primaryTextColor)
//                Spacer()
//            }
//        } items: {
//            [Text("Hello")]
//        }
//
////        self.init {
////        } items: {
////            ForEach(items) { item in
////                return HStack {
////                    Text(item)
////                    Spacer()
////                    //                if let (image, _) = $0.1 {
////                    //                    image
////                    //                        .foregroundStyle(.secondary)
////                    //                }
////                }
////            }
////        }
//
//    }

    @State private var interactionState: InteractionState = .normal
    @State private var interactionStateIndex: Int?

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            titleView
                .bold()
            .safeAreaPadding(20)
            Group(subviews: items) { subviews in
                ForEach(subviews: subviews) { subview in
                    Divider()
                        .ignoresSafeArea()
                        .opacity(subview.id == subviews.first?.id ? 1 : 0.5)
                    subview
                        .safeAreaPadding(20)
                        .onHover { hovering in
                            withAnimation {
//                                guard item.element.action != nil else { return }
                                interactionState = hovering ? .hovering : .normal
//                                interactionStateIndex = item.offset
                            }
                        }
                        .gesture(
                            TapGesture()
                                .onEnded {
//                                    item.element.action?.1()
                                    withAnimation {
                                        interactionState = .normal
                                        interactionStateIndex = nil
                                    }
                                }
                        )
                }
            }

//            ForEach(Array(items.enumerated()), id: \.offset) { item in
//                Divider()
//                    .ignoresSafeArea()
//                    .opacity(item.offset == 0 ? 1 : 0.75)
//                items.element
//                .safeAreaPadding(20)
//                .onHover { hovering in
//                    withAnimation {
//                        guard item.element.action != nil else { return }
//                        interactionState = hovering ? .hovering : .normal
//                        interactionStateIndex = item.offset
//                    }
//                }
//                .gesture(
//                    TapGesture()
//                        .onEnded {
//                            item.element.action?.1()
//                            withAnimation {
//                                interactionState = .normal
//                                interactionStateIndex = nil
//                            }
//                        }
//                )
//
//            }
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
                .contentShape(RoundedRectangle(cornerRadius: cornerRadius))
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
            let base: Color
            if #available(macOS 27.0, *) {
                base = .clear
            } else {
                base = colorScheme == .dark ? Color(white: 0.2) : Color(white: 1)
            }
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

//#Preview {
//    MultilineInfoView(title: "Multiple", image: Image(systemName: "figure.wave"), items: [
//        MultilineInfoView.Item(text: "hello", action: (Image(systemName: "chevron.forward"), {})),
//        MultilineInfoView.Item(text: "World", action: (Image(systemName: "chevron.forward"), {})),
//    ])
//    .padding()
//}
//
//
#Preview {
    MultilineInfoView {
        Text("Hello")
    } items: {
        Text("World")
        Text("World")
        Text("World")
    }
//    MultilineInfoView(title: "One", image: Image(systemName: "figure.wave"), items: ["Hello world."])
        .padding()
}
