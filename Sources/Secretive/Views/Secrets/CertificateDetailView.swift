import SwiftUI
import SecretKit
import Common
import SSHProtocolKit

struct CertificateDetailsView: View {

    let certificate: OpenSSHCertificate

    var body: some View {
        Form {
            LabeledContent(String(localized: .certificateDetailKeyIdLabel), value: certificate.keyID)
            LabeledContent(String(localized: .certificateDetailSerialLabel), value: certificate.serial.formatted())
            if let validityRange = certificate.validityRange {
                let epoch = Date(timeIntervalSince1970: 0)
                let end = Date(timeIntervalSince1970: TimeInterval(UInt64.max))
                switch (validityRange.lowerBound, validityRange.upperBound) {
                case (epoch, end):
                    EmptyView()
                case (epoch, let otherEnd):
                    LabeledContent(String(localized: .certificateDetailValidUntilLabel), value: otherEnd.formatted())
                case (let otherStart, end):
                    LabeledContent(String(localized: .certificateDetailValidAfterLabel), value: otherStart.formatted())
                default:
                    LabeledContent(String(localized: .certificateDetailValidityRangeLabel), value: validityRange.formatted())
                }
            }
            if !certificate.principals.isEmpty {
                LabeledContent(String(localized: .certificateDetailPrincipalsLabel)) {
                    ForEach(Array(certificate.principals.enumerated()), id: \.offset) {
                        Text(verbatim: $0.element)
                    }
                }
            }
        }
        .formStyle(.columns)
    }
}
