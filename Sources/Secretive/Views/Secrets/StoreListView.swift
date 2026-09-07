import SwiftUI
import SecretKit
import SSHProtocolKit
import CertificateKit

struct StoreListView: View {

    enum StoreListSelection: Hashable {
        case secret(AnySecret)
        case certificate(Certificate)
    }

    @Binding var selection: StoreListSelection?

    @Environment(\.secretStoreList) private var storeList
    @Environment(\.certificateStore) private var certificateStore

    private func secretDeleted(secret: AnySecret) {
        selection = nextDefaultSecret.map(StoreListSelection.secret)
    }

    private func secretRenamed(secret: AnySecret) {
        // Pull new version from store, so we get all updated attributes
        selection = nil
        selection = storeList.allSecrets.first(where: { $0.id == secret.id }).map(StoreListSelection.secret)
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                ForEach(storeList.stores) { store in
                    if store.isAvailable {
                        Section(header: Text(store.name)) {
                            ForEach(store.secrets) { secret in
                                SecretListItemView(
                                    store: store,
                                    secret: secret,
                                    deletedSecret: secretDeleted,
                                    renamedSecret: secretRenamed,
                                )
                                .tag(StoreListSelection.secret(secret))
                            }
                        }
                    }
                }
                if !certificateStore.certificates.isEmpty {
                    Section("Certificates") {
                        ForEach(certificateStore.certificates) { certificate in
                            CertificateListItemView(
                                certificate: certificate,
                                deletedCertificate: { _ in },
                                renamedCertificate: { _ in }
                            )
                            .tag(StoreListSelection.certificate(certificate))
                        }
                    }
                }
            }
        } detail: {
            switch selection {
            case .secret(let secret):
                SecretDetailView(secret: secret, certificates: certificateStore.certificates(for: secret)) {
                    selection = .certificate($0)
                }
            case .certificate(let certificate):
                CertificateDetailView(certificate: certificate)
            case nil:
                if let nextDefaultSecret {
                    // This just means onAppear hasn't executed yet.
                    // Do this to avoid a blip.
                    SecretDetailView(secret: nextDefaultSecret, certificates: certificateStore.certificates(for: nextDefaultSecret)) {
                        selection = .certificate($0)
                    }
                } else {
                    if let modifiable = storeList.modifiableStore, modifiable.isAvailable {
                        EmptyStoreView(store: modifiable)
                    } else {
                        EmptyStoreView(store: storeList.stores.first(where: \.isAvailable))
                    }
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
        .onAppear {
            selection = nextDefaultSecret.map(StoreListSelection.secret)
        }
        .frame(minWidth: 100, idealWidth: 240)

    }
}

extension StoreListView {

    private var nextDefaultSecret: AnySecret? {
        return storeList.allSecrets.first
    }
    
}
