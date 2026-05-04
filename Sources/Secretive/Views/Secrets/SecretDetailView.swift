import SwiftUI
import SecretKit
<<<<<<< HEAD
=======
import Common
>>>>>>> main
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
<<<<<<< HEAD
                    CopyableView(
                        title: .secretDetailPublicKeyLabel,
                        path: publicKeyFileStoreController.publicKeyPath(for: secret),
                        image: Image(systemName: "key"),
                        text: keyString
                    )
=======
                    CopyableView(title: .secretDetailPublicKeyLabel, image: Image(systemName: "key"), text: keyString)
                    Spacer()
                        .frame(height: 20)
                    CopyableView(title: .secretDetailPublicKeyPathLabel, image: Image(systemName: "lock.doc"), text: URL.publicKeyPath(for: secret, in: URL.publicKeyDirectory), showRevealInFinder: true)
>>>>>>> main
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
