import SwiftUI

struct NoStoresView: View {

    var body: some View {
        VStack {
            Text("No Secure Storage Available").bold()
            Text("Your Mac doesn't have a Secure Enclave, and there's not a compatible Smart Card inserted.")
            Link("If you're looking to add one to your Mac, the YubiKey 5 Series are great.", destination: URL(string: "https://www.yubico.com/products/compare-yubikey-5-series/")!)
        }.padding()
    }
    
}

struct NoStoresView_Previews: PreviewProvider {
    static var previews: some View {
        NoStoresView()
    }
}
