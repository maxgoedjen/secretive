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
    
    private var backingColor: Color {
        if !hovering {
            colorScheme == .light ? lightColor : darkColor
        } else {
            colorScheme == .light ? .black.opacity(0.1) : .white.opacity(0.05)
        }
    }
    @Namespace var namespace

    func makeBody(configuration: Configuration) -> some View {
        if #available(macOS 26.0, *) {
            configuration
                .label
                .foregroundColor(.white)
                .padding(EdgeInsets(top: 6, leading: 8, bottom: 6, trailing: 8))
                .glassEffect(.regular.tint(backingColor), in: .capsule, isEnabled: true)
                .onHover { hovering in
                    withAnimation {
                        self.hovering = hovering
                    }
                }
        } else {
            configuration
                .label
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
}
