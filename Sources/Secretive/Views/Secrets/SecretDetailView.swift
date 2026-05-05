import SwiftUI
import SecretKit
import Common
import SSHProtocolKit

struct SecretDetailView<SecretType: Secret>: View {
    
    let secret: SecretType
    let certificates: [OpenSSHCertificate]
    let navigateToCertificate: ((OpenSSHCertificate) -> Void)?

    private let keyWriter = OpenSSHPublicKeyWriter()

    var body: some View {
        ScrollView {
            Form {
                Section {
                    CopyableView(
                        title: .secretDetailSha256FingerprintLabel,
                        image: Image(systemName: "touchid"),
                        text: keyWriter.openSSHSHA256Fingerprint(secret: secret)
                    )
                    Spacer()
                        .frame(height: 20)
                    CopyableView(
                        title: .secretDetailMd5FingerprintLabel,
                        image: Image(systemName: "touchid"),
                        text: keyWriter.openSSHMD5Fingerprint(secret: secret)
                    )
                    Spacer()
                        .frame(height: 20)
                    CopyableView(
                        title: .secretDetailPublicKeyPathLabel,
                        image: Image(systemName: "lock.doc"),
                        text: URL.publicKeyPath(for: secret, in: URL.publicKeyDirectory),
                        showRevealInFinder: true
                    )
                    if !certificates.isEmpty {
                        Spacer()
                            .frame(height: 20)
                        MultilineInfoView(
                            title: .secretDetailCertificatePathLabel,
                            image: Image(
                                systemName: "checkmark.seal.text.page"
                            ),
                            items: certificates.map({ certificate in
                                MultilineInfoView.Item(
                                    text: certificate.name,
                                    action: (Image(systemName: "chevron.forward"), { navigateToCertificate?(certificate) })
                                )
                            })
                        )
                    }
                    Spacer()
                }
            }
            .padding()
        }
        .frame(minHeight: 200, maxHeight: .infinity)
    }


}

//#Preview {
//    SecretDetailView(secret: Preview.Secret(name: "Demonstration Secret"))
//}
