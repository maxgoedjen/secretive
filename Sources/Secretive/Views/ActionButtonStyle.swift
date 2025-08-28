import SwiftUI

struct PrimaryButtonModifier: ViewModifier {

    @Environment(\.colorScheme) var colorScheme

    func body(content: Content) -> some View {
        // Tinted glass prominent is really hard to read on 26.0.
        if #available(macOS 26.0, *), colorScheme == .dark {
            content.buttonStyle(.glassProminent)
        } else {
            content.buttonStyle(.borderedProminent)
        }
    }

}

extension View {

    func primary() -> some View {
        modifier(PrimaryButtonModifier())
    }

}
