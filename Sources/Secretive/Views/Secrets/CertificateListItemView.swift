import SwiftUI
import CertificateKit
import SSHProtocolKit

struct CertificateListItemView: View {

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
            Text("WIP")
//            EditSecretView(store: modifiable, secret: secret)
        })
//        .showingDeleteConfirmation(isPresented: $isDeleting, secret, store as? AnySecretStoreModifiable) { deleted in
//            if deleted {
//                deletedSecret(secret)
//            }
//        }
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
