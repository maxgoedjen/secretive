import SwiftUI
import SecretKit

struct EmptyStoreView: View {

    @ObservedObject var store: AnySecretStore
    @Binding var activeSecret: AnySecret.ID?

    var body: some View {
        if store is AnySecretStoreModifiable {
            NavigationLink(destination: EmptyStoreModifiableView(), tag: Constants.emptyStoreModifiableTag + store.name, selection: $activeSecret) {
                Text("No Secrets")
            }
        } else {
            NavigationLink(destination: EmptyStoreImmutableView(), tag: Constants.emptyStoreTag + store.name, selection: $activeSecret) {
                Text("No Secrets")
            }
        }
    }
}

extension EmptyStoreView {
    
    enum Constants {
        static let emptyStoreModifiableTag = "emptyStoreModifiableTag"
        static let emptyStoreTag = "emptyStoreModifiableTag"
    }

}

struct EmptyStoreImmutableView: View {
    
    var body: some View {
        VStack {
            Text("No Secrets").bold()
            Text("Use your Smart Card's management tool to create a secret.")
            Text("Secretive supports EC256, EC384, RSA1024, and RSA2048 keys.")
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
                Text("No Secrets").bold()
                Text("Create a new one by clicking here.")
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
