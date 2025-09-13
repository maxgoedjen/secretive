import SwiftUI

struct WindowBackgroundStyleModifier: ViewModifier {

    let shapeStyle: any ShapeStyle

    func body(content: Content) -> some View {
        if #available(macOS 15.0, *) {
            content
                .containerBackground(
                    shapeStyle, for: .window
                )
        } else {
            content
        }
    }

}

extension View {

    func windowBackgroundStyle(_ style: some ShapeStyle) -> some View {
        modifier(WindowBackgroundStyleModifier(shapeStyle: style))
    }

}

struct HiddenToolbarModifier: ViewModifier {

    func body(content: Content) -> some View {
        if #available(macOS 15.0, *) {
            content
                .toolbarBackgroundVisibility(.hidden, for: .automatic)
        } else {
            content
        }
    }

}

extension View {

    func hiddenToolbar() -> some View {
        modifier(HiddenToolbarModifier())
    }

}
