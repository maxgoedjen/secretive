import SwiftUI

struct PrimaryButtonModifier: ViewModifier {

    @Environment(\.colorScheme) var colorScheme
    @Environment(\.isEnabled) var isEnabled

    func body(content: Content) -> some View {
        // Tinted glass prominent is really hard to read on 26.0.
        if #available(macOS 26.0, *), colorScheme == .dark, isEnabled {
            content.buttonStyle(.glassProminent)
        } else {
            content.buttonStyle(.borderedProminent)
        }
    }

}

extension View {

    func primaryButton() -> some View {
        modifier(PrimaryButtonModifier())
    }

}

struct ToolbarCircleButtonModifier: ViewModifier {

    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content
                .glassEffect(.regular.tint(.white.opacity(0.1)), in: .circle)
        } else {
            content
                .buttonStyle(.borderless)
        }
    }

}

extension View {

    func toolbarCircleButton() -> some View {
        modifier(ToolbarCircleButtonModifier())
    }

}

struct NormalButtonModifier: ViewModifier {

    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content.buttonStyle(.glass)
        } else {
            content.buttonStyle(.bordered)
        }
    }

}

extension View {

    func normalButton() -> some View {
        modifier(NormalButtonModifier())
    }

}

struct DangerButtonModifier: ViewModifier {

    @Environment(\.colorScheme) var colorScheme

    func body(content: Content) -> some View {
        // Tinted glass prominent is really hard to read on 26.0.
        if #available(macOS 26.0, *), colorScheme == .dark {
            content.buttonStyle(.glassProminent)
                .tint(.red)
                .foregroundStyle(.white)
        } else {
            content.buttonStyle(.borderedProminent)
                .tint(.red)
                .foregroundStyle(.white)
        }
    }

}

extension View {

    func danger() -> some View {
        modifier(DangerButtonModifier())
    }

}
