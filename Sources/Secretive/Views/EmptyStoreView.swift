import SwiftUI
import SecretKit

struct EmptyStoreView: View {

    @State var store: AnySecretStore?
    
    var body: some View {
        if store is AnySecretStoreModifiable {
            EmptyStoreModifiableView()
        } else {
            EmptyStoreImmutableView()
        }
    }
}

struct EmptyStoreImmutableView: View {
    
    var body: some View {
        VStack {
            Text("empty_store_nonmodifiable_title").bold()
            Text("empty_store_nonmodifiable_description")
            Text("empty_store_nonmodifiable_supported_key_types")
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
}

struct EmptyStoreModifiableView: View {
    
    var body: some View {
        GeometryReader { windowGeometry in
            VStack {
                GeometryReader { g in
                    Path { path in
                        path.move(to: CGPoint(x: g.size.width / 2, y: g.size.height))
                        path.addCurve(to:
                            CGPoint(x: g.size.width * (3/4), y: g.size.height * (1/2)), control1:
                            CGPoint(x: g.size.width / 2, y: g.size.height * (1/2)), control2:
                            CGPoint(x: g.size.width * (3/4), y: g.size.height * (1/2)))
                        path.addCurve(to:
                            CGPoint(x: g.size.width - 13, y: 0), control1:
                            CGPoint(x: g.size.width - 13 , y: g.size.height * (1/2)), control2:
                            CGPoint(x: g.size.width - 13, y: 0))
                    }.stroke(style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    Path { path in
                        path.move(to: CGPoint(x: g.size.width - 23, y: 0))
                        path.addLine(to: CGPoint(x: g.size.width - 13, y: -10))
                        path.addLine(to: CGPoint(x: g.size.width - 3, y: 0))
                    }.fill()
                }.frame(height: (windowGeometry.size.height/2) - 20).padding()
                Text("empty_store_modifiable_click_here_title").bold()
                Text("empty_store_modifiable_click_here_description")
                Spacer()
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

#if DEBUG

struct EmptyStoreModifiableView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            EmptyStoreImmutableView()
            EmptyStoreModifiableView()
        }
    }
}

#endif
