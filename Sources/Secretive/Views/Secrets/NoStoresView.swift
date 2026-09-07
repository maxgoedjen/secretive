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

#Preview {
    NoStoresView()
}

