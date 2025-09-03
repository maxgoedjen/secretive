import SwiftUI

struct ErrorStyleModifier: ViewModifier {

    func body(content: Content) -> some View {
        content
            .foregroundStyle(.red)
            .font(.callout)
    }
    
}

extension View {

    func errorStyle() -> some View {
        modifier(ErrorStyleModifier())
    }

}
