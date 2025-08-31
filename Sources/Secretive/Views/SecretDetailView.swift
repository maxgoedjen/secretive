import SwiftUI
import SecretKit

struct SecretDetailView<SecretType: Secret>: View {
    
    let secret: SecretType

    private let keyWriter = OpenSSHPublicKeyWriter()
    private let publicKeyFileStoreController = PublicKeyFileStoreController(homeDirectory: URL.agentHomePath)

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
                    CopyableView(title: .secretDetailPublicKeyPathLabel, image: Image(systemName: "lock.doc"), text: publicKeyFileStoreController.publicKeyPath(for: secret))
                    Spacer()
                } header: {
                    Text(verbatim: secret.name)
                        .font(.system(size: 16, weight: .bold, design: .default))
                        .foregroundStyle(.secondary)
                        .padding(.leading)
                        .padding(.bottom)
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

extension URL {

    static var agentHomePath: String {
        URL.homeDirectory.path().replacingOccurrences(of: Bundle.hostBundleID, with: Bundle.agentBundleID)
    }

}

#Preview {
    SecretDetailView(secret: Preview.Secret(name: "Demonstration Secret"))
}
