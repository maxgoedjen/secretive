import SwiftUI
import SecretKit
import Common
import SSHProtocolKit

struct CertificateDetailView: View {

    let certificate: OpenSSHCertificate

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
                    if let validityRange = certificate.validityRange {
                        let epoch = Date(timeIntervalSince1970: 0)
                        let end = Date(timeIntervalSince1970: TimeInterval(UInt64.max))
                        switch (validityRange.lowerBound, validityRange.upperBound) {
                        case (epoch, end):
                            EmptyView()
                        case (epoch, let otherEnd):
                            MultilineInfoView(title: .certificateDetailValidUntilLabel, image: Image(systemName: "calendar.badge.clock"), items: [otherEnd.formatted()])
                            Spacer()
                                .frame(height: 20)
                        case (let otherStart, end):
                            MultilineInfoView(title: .certificateDetailValidAfterLabel, image: Image(systemName: "calendar.badge.clock"), items: [otherStart.formatted()])
                            Spacer()
                                .frame(height: 20)
                        default:
                            MultilineInfoView(title: .certificateDetailValidityRangeLabel, image: Image(systemName: "calendar.badge.clock"), items: [validityRange.formatted()])
                            Spacer()
                                .frame(height: 20)
                        }
                    }
                    if !certificate.principals.isEmpty {
                        MultilineInfoView(title: .certificateDetailPrincipalsLabel, image: Image(systemName: "person.2"), items: certificate.principals)
                        Spacer()
                            .frame(height: 20)
                    }
                    CopyableView(
                        title: .certificateDetailPathLabel,
                        image: Image(systemName: "checkmark.seal.text.page"),
                        text: URL.certificatePath(for: certificate, in: URL.certificatesDirectory),
                        showRevealInFinder: true
                    )
                    Spacer()
                }
            }
            .padding()
        }
        .frame(minHeight: 200, maxHeight: .infinity)
    }


}
