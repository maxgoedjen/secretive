import SwiftUI
import SecretKit
import Common
import SSHProtocolKit

struct SecretDetailView<SecretType: Secret>: View {
    
    let secret: SecretType
    let certificates: [OpenSSHCertificate]

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
                    Spacer()
                }
                if !certificates.isEmpty {
                    Section {
                        Spacer()
                            .frame(height: 20)
                        ForEach(certificates) { certificate in
                            CopyableView(
                                title: .secretDetailCertificatePathLabel,
                                subtitle: certificate.name,
                                image: Image(systemName: "checkmark.seal.text.page"),
                                text: URL.certificatePath(for: certificate, in: URL.certificatesDirectory),
                                showRevealInFinder: true
                            ) {
                                CertificateDetailsView(certificate: certificate)
                            }
                            .contextMenu {
                                Button("Delete") {
                                    //FIXME
                                }
                            }
                        }
                    }
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
