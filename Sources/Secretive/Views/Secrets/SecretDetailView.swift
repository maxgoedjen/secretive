import SwiftUI
import SecretKit
import Common
import SSHProtocolKit

struct SecretDetailView<SecretType: Secret>: View {
    
    let secret: SecretType

    private let keyWriter = OpenSSHPublicKeyWriter()

    var body: some View {
        ScrollView {
            Form {
                Section {
                    CopyableView(title: .secretDetailSha256FingerprintLabel, image: Image(systemName: "touchid"), text: keyWriter.openSSHSHA256Fingerprint(secret: secret))
                    Spacer()
                        .frame(height: 20)
                    CopyableView(title: .secretDetailMd5FingerprintLabel, image: Image(systemName: "touchid"), text: keyWriter.openSSHMD5Fingerprint(secret: secret))
                    Spacer()
                        .frame(height: 20)
                    CopyableView(title: .secretDetailPublicKeyLabel, image: Image(systemName: "key"), text: keyString)
                    Spacer()
                        .frame(height: 20)
                    CopyableView(title: .secretDetailPublicKeyPathLabel, image: Image(systemName: "lock.doc"), text: URL.publicKeyPath(for: secret, in: URL.publicKeyDirectory), showRevealInFinder: true)
                    Spacer()
                }
            }
            .padding()
        }
        .frame(minHeight: 200, maxHeight: .infinity)
    }


    var keyString: String {
        keyWriter.openSSHString(secret: secret)
    }

}

//#Preview {
//    SecretDetailView(secret: Preview.Secret(name: "Demonstration Secret"))
//}
