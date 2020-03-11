import SwiftUI

struct EmptyStoreView: View {
    
    var body: some View {
        VStack {
            Text("No Secrets").bold()
            Text("Use your Smart Card's management tool to create a secret.")
            Text("Secretive only supports Elliptic Curve keys.")
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
                            CGPoint(x: g.size.width, y: 0), control1:
                            CGPoint(x: g.size.width, y: g.size.height * (1/2)), control2:
                            CGPoint(x: g.size.width, y: 0))
                    }.stroke(style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    Path { path in
                        path.move(to: CGPoint(x: g.size.width - 10, y: 0))
                        path.addLine(to: CGPoint(x: g.size.width, y: -10))
                        path.addLine(to: CGPoint(x: g.size.width + 10, y: 0))
                    }.fill()
                }.frame(height: (windowGeometry.size.height/2) - 20).padding()
                Text("No Secrets").bold()
                Text("Create a new one by clicking here.")
                Spacer()
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

struct EmptyStoreModifiableView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            EmptyStoreView()
            EmptyStoreModifiableView()
        }
    }
}
