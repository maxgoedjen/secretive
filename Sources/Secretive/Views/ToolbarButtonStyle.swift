import SwiftUI

struct ToolbarButtonStyle: ButtonStyle {

    private let lightColor: Color
    private let darkColor: Color
    @Environment(\.colorScheme) var colorScheme
    @State var hovering = false

    init(color: Color) {
        self.lightColor = color
        self.darkColor = color
    }

    init(lightColor: Color, darkColor: Color) {
        self.lightColor = lightColor
        self.darkColor = darkColor
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(EdgeInsets(top: 6, leading: 8, bottom: 6, trailing: 8))
            .background(colorScheme == .light ? lightColor : darkColor)
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 5))
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(colorScheme == .light ? .black.opacity(0.15) : .white.opacity(0.15), lineWidth: 1)
                    .background(hovering ? (colorScheme == .light ? .black.opacity(0.1) : .white.opacity(0.05)) : Color.clear)
            )
            .onHover { hovering in
                withAnimation {
                    self.hovering = hovering
                }
            }
    }
}
