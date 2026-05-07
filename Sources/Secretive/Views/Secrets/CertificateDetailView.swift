import SwiftUI
import SecretKit
import Common
import CertificateKit
import SSHProtocolKit
import CryptoKit
struct CertificateDetailView: View {

    let certificate: Certificate

    var body: some View {
        ScrollView {
            Form {
                Section {
                    CopyableView(
                        title: .certificateDetailKeyIdLabel,
                        image: Image(systemName: "person.text.rectangle"),
                        text: certificate.keyID
                    )
                    Spacer()
                        .frame(height: 20)
                    CopyableView(
                        title: .certificateDetailSerialLabel,
                        image: Image(systemName: "number.circle"),
                        text: certificate.serial.formatted()
                    )
                    Spacer()
                        .frame(height: 20)
                    CopyableView(
                        title: .secretDetailSha256FingerprintLabel,
                        image: Image(systemName: "touchid"),
                        text: OpenSSHCertificateWriter().openSSHSHA256KeyFingerprint(publicKey: certificate.publicKey)
                    )
                    Spacer()
                        .frame(height: 20)
                    CopyableView(
                        title: .secretDetailSha256FingerprintLabel,
                        image: Image(systemName: "touchid"),
                        text: OpenSSHCertificateWriter().openSSHSHA256KeyFingerprint(publicKey: certificate.signingKey)
                    )
                    Spacer()
                        .frame(height: 20)
                    CopyableView(
                        title: .certificateDetailPathLabel,
                        image: Image(systemName: "checkmark.seal.text.page"),
                        text: URL.certificatePath(for: certificate.id, in: URL.certificatesDirectory),
                        showRevealInFinder: true
                    )
                    if let validityRange = certificate.validityRange {
                        let epoch = Date(timeIntervalSince1970: 0)
                        let end = Date(timeIntervalSince1970: TimeInterval(UInt64.max))
                        switch (validityRange.lowerBound, validityRange.upperBound) {
                        case (epoch, end):
                            EmptyView()
                        case (epoch, let otherEnd):
                            Spacer()
                                .frame(height: 20)
                            MultilineInfoView(title: .certificateDetailValidUntilLabel, image: Image(systemName: "calendar.badge.clock"), items: [otherEnd.formatted()])
                        case (let otherStart, end):
                            Spacer()
                                .frame(height: 20)
                            MultilineInfoView(title: .certificateDetailValidAfterLabel, image: Image(systemName: "calendar.badge.clock"), items: [otherStart.formatted()])
                        default:
                            Spacer()
                                .frame(height: 20)
                            MultilineInfoView(title: .certificateDetailValidityRangeLabel, image: Image(systemName: "calendar.badge.clock"), items: [validityRange.formatted()])
                        }
                    }
                    if !certificate.principals.isEmpty {
                        Spacer()
                            .frame(height: 20)
                        MultilineInfoView(title: .certificateDetailPrincipalsLabel, image: Image(systemName: "person.2"), items: certificate.principals)
                    }
                    if !certificate.criticalOptions.isEmpty {
                        Spacer()
                            .frame(height: 20)
                        MultilineInfoView(title: .certificateDetailCriticalOptionsLabel, image: Image(systemName: "person.2"), items: certificate.criticalOptions)
                    }
                    if !certificate.extensions.isEmpty {
                        Spacer()
                            .frame(height: 20)
                        MultilineInfoView(title: .certificateDetailExtensionsLabel, image: Image(systemName: "person.2"), items: certificate.extensions)
                    }
                    Spacer()
                }
            }
            .padding()
        }
        .frame(minHeight: 200, maxHeight: .infinity)
    }


}
