import SwiftUI
import CertificateKit
import SSHProtocolKit

struct CertificateListItemView: View {

    @Environment(\.certificateStore) private var store

    var certificate: OpenSSHCertificate

    @State var isDeleting: Bool = false
    @State var isRenaming: Bool = false

    var deletedCertificate: (OpenSSHCertificate) -> Void
    var renamedCertificate: (OpenSSHCertificate) -> Void

    var body: some View {
        NavigationLink(value: certificate) {
            Text(certificate.name)
        }
        .sheet(isPresented: $isRenaming, onDismiss: {
            renamedCertificate(certificate)
        }, content: {
            EditCertificateView(store: store, certificate: certificate)
        })
        .showingDeleteConfirmation(isPresented: $isDeleting, certificate, store) { deleted in
            if deleted {
                deletedCertificate(certificate)
            }
        }
        .contextMenu {
                Button(action: { isRenaming = true }) {
                    Image(systemName: "pencil")
                    Text(.secretListEditButton)
                }
                Button(action: { isDeleting = true }) {
                    Image(systemName: "trash")
                    Text(.secretListDeleteButton)
                }
        }
    }
}
