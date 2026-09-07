import SwiftUI

struct BoxBackgroundModifier: ViewModifier {

    let color: Color

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: 5)
                    .fill(color.opacity(0.3))
                    .stroke(color, lineWidth: 1)
            }
    }
}

extension View {

    func boxBackground(color: Color) -> some View {
        modifier(BoxBackgroundModifier(color: color))
    }

}

#Preview {
    Text("Hello")
        .boxBackground(color: .red)
        .padding()
    Text("Hello")
        .boxBackground(color: .orange)
        .padding()
}
