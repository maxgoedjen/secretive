import SwiftUI
import SSHProtocolKit
import CertificateKit

struct EditCertificateView: View {

    let store: CertificateStore
    let certificate: OpenSSHCertificate

    @State private var name: String
    @State var errorText: String?

    @Environment(\.dismiss) var dismiss

    init(store: CertificateStore, certificate: OpenSSHCertificate) {
        self.store = store
        self.certificate = certificate
        name = certificate.name
    }

    var body: some View {
        VStack(alignment: .trailing) {
            Form {
                Section {
                    TextField(String(localized: .renameCertificateLabel), text: $name, prompt: Text(.renameCertificateNamePlaceholder))
                } footer: {
                    if let errorText {
                        Text(verbatim: errorText)
                            .errorStyle()
                    }
                }
            }
            HStack {
                Button(.editCancelButton) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                Button(.editSaveButton, action: rename)
                    .disabled(name.isEmpty)
                    .keyboardShortcut(.return)
                    .primaryButton()
            }
            .padding()
        }
        .formStyle(.grouped)
    }

    func rename() {
        Task {
            do {
                var updated = certificate
                updated.name = name
                try store.update(certificate: updated)
                dismiss()
            } catch {
                errorText = error.localizedDescription
            }
        }
    }
}
