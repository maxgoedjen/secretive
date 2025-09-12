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
        
    @available(macOS 26.0, *)
    private var glassTint: Color {
        if !hovering {
            colorScheme == .light ? lightColor : darkColor
        } else {
            colorScheme == .light ? lightColor.exposureAdjust(1) : darkColor.exposureAdjust(1)
        }
    }

    func makeBody(configuration: Configuration) -> some View {
        if #available(macOS 26.0, *) {
            configuration
                .label
                .foregroundColor(.white)
                .padding(EdgeInsets(top: 6, leading: 8, bottom: 6, trailing: 8))
                .glassEffect(.regular.tint(glassTint), in: .capsule)
                .onHover { hovering in
                    self.hovering = hovering
                }
        } else {
            configuration
                .label
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
}
