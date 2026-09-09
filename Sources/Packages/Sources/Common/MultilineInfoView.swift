import SwiftUI
import UniformTypeIdentifiers

public struct MultilineInfoView<TitleView: View, ItemView: View>: View {

    var titleView: TitleView
    var items: ItemView

    public init(@ViewBuilder titleView: () -> TitleView, @ContentBuilder items: () -> ItemView) {
        self.titleView = titleView()
        self.items = items()
    }

    public init(title: LocalizedStringResource, subtitle: LocalizedStringResource? = nil, image: Image, items: [String]) where TitleView == FixedTitleView, ItemView == FixedItemsView {
        self.init {
            FixedTitleView(title: title, subtitle: subtitle, image: image)
        } items: {
            FixedItemsView(items: items)
        }
    }
    public init(title: LocalizedStringResource, subtitle: LocalizedStringResource? = nil, image: Image, @ContentBuilder items: () -> ItemView) where TitleView == FixedTitleView {
        self.init {
            FixedTitleView(title: title, subtitle: subtitle, image: image)
        } items: {
            items()
        }
    }

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
                    HoveringSubview {
                        subview
                    }
                }
            }
        }
        ._background(interactionState: .normal)
        .frame(minWidth: 150, maxWidth: .infinity)
    }

}

struct HoveringSubview<Content: View>: View {

    @State private var multilineAction: MultilineItemActionKey.Box?
    private let content: Content
    @State private var interactionState: InteractionState = .normal

    init(@ViewBuilder _ content: () -> Content) {
        self.multilineAction = nil
        self.content = content()
    }

    var body: some View {
        HStack {
            content
            Spacer()
            if let image = multilineAction?.image {
                image
            }
        }
            .safeAreaPadding(20)
            .onHover { hovering in
                withAnimation {
                    guard multilineAction != nil else { return }
                    interactionState = hovering ? .hovering : .normal
                }
            }
            .gesture(
                TapGesture()
                    .onEnded {
                        multilineAction?.closure()
                        withAnimation {
                            interactionState = .normal
                        }
                    }
            )
            .backgroundStyle(.primary.opacity(interactionState == .hovering ? 0.3 : 0))
            .onPreferenceChange(MultilineItemActionKey.self) {
                multilineAction = $0
            }
    }

}


public struct FixedTitleView: View {
    let title: LocalizedStringResource
    let subtitle: LocalizedStringResource?
    let image: Image

    public var body: some View {
        HStack {
            image
                .renderingMode(.template)
                                .imageScale(.large)
            VStack(alignment: .leading) {
                Text(title)
                    .font(.headline)
                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                }
            }
            Spacer()
        }

    }
}

public struct FixedItemsView: View {

    let items: [String]

    public var body: some View {
        ForEach(Array(items.enumerated()), id: \.offset) {
            Text($0.element)
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

public struct MultilineItemAction: ViewModifier {

    let image: Image?
    let action: () -> Void

    public init(image: Image?, action: @escaping () -> Void) {
        self.image = image
        self.action = action
    }

    public func body(content: Content) -> some View {
        content
            .preference(key: MultilineItemActionKey.self, value: MultilineItemActionKey.Box(image: image, closure: action))
    }

}

extension View {

    public func multilineItemAction(image: Image? = nil, action: @escaping () -> Void) -> some View {
        modifier(MultilineItemAction(image: image, action: action))
    }

}

public struct MultilineItemActionKey : @MainActor PreferenceKey, ~Sendable {

    public struct Box: Equatable {

        let id: UUID = UUID()
        let image: Image?
        let closure: () -> Void

        public static func == (lhs: borrowing MultilineItemActionKey.Box, rhs: borrowing MultilineItemActionKey.Box) -> Bool {
            lhs.id == rhs.id
        }

    }

    public typealias Value = Box?
    @MainActor public static let defaultValue: Box? = nil

    public static func reduce(value: inout Box?, nextValue: () -> Box?) {
        value = nextValue()
    }

}

#Preview {
    MultilineInfoView {
        Text("Hello")
    } items: {
        Text("World")
            .multilineItemAction(image: Image(systemName: "person.wave")) {
                print("Hello")
            }
        Text("World")
        Text("World")
    }
    .padding()
}
#Preview {
    MultilineInfoView(title: "One", image: Image(systemName: "figure.wave"), items: ["Hello world.", "Hello world."])
        .padding()
}
