import SwiftUI
import CertificateKit
import SSHProtocolKit

extension View {

    func showingDeleteConfirmation(isPresented: Binding<Bool>, _ certificate: OpenSSHCertificate,  _ store: CertificateStore, dismissalBlock: @escaping (Bool) -> ()) -> some View {
        modifier(DeleteCertificateConfirmationModifier(isPresented: isPresented, certificate: certificate, store: store, dismissalBlock: dismissalBlock))
    }

}

struct DeleteCertificateConfirmationModifier: ViewModifier {

    var isPresented: Binding<Bool>
    var certificate: OpenSSHCertificate
    var store: CertificateStore
    var dismissalBlock: (Bool) -> ()
    @State var confirmedSecretName = ""
    @State private var errorText: String?

    func body(content: Content) -> some View {
        content
            .confirmationDialog(
                String(localized: .deleteConfirmationTitle(name: certificate.name)),
                isPresented: isPresented,
                titleVisibility: .visible,
                actions: {
                    Button(.deleteConfirmationDeleteButton, action: delete)
                    Button(.deleteConfirmationCancelButton, role: .cancel) {
                        dismissalBlock(false)
                    }
                },
            )
            .dialogIcon(Image(systemName: "lock.trianglebadge.exclamationmark.fill"))
            .onExitCommand {
                dismissalBlock(false)
            }
    }

    func delete() {
        Task {
            do {
                try store.delete(certificate: certificate)
                dismissalBlock(true)
            } catch {
                errorText = error.localizedDescription
            }
        }
    }

}
