import SwiftUI

struct NoStoresView: View {

    var body: some View {
        VStack {
            Text("no_secure_storage_title")
                .bold()
            Text("no_secure_storage_description")
            Link("no_secure_storage_yubico_link", destination: URL(string: "https://www.yubico.com/products/compare-yubikey-5-series/")!)
        }.padding()
    }
    
}

#if DEBUG

struct NoStoresView_Previews: PreviewProvider {
    static var previews: some View {
        NoStoresView()
    }
}

#endif
