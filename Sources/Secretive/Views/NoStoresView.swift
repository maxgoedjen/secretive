import SwiftUI

struct NoStoresView: View {

    var body: some View {
        VStack {
            Text(.noSecureStorageTitle)
                .bold()
            Text(.noSecureStorageDescription)
            Link(.noSecureStorageYubicoLink, destination: URL(string: "https://www.yubico.com/products/compare-yubikey-5-series/")!)
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
