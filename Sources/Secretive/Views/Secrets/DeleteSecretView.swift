import SwiftUI
import SecretKit

extension View {

    func showingDeleteConfirmation(isPresented: Binding<Bool>, _ secret: AnySecret,  _ store: AnySecretStoreModifiable?, dismissalBlock: @escaping (Bool) -> ()) -> some View {
        modifier(DeleteSecretConfirmationModifier(isPresented: isPresented, secret: secret, store: store, dismissalBlock: dismissalBlock))
    }

}

struct DeleteSecretConfirmationModifier: ViewModifier {

    var isPresented: Binding<Bool>
    var secret: AnySecret
    var store: AnySecretStoreModifiable?
    var dismissalBlock: (Bool) -> ()
    @State var confirmedSecretName = ""
    @State private var errorText: String?

    func body(content: Content) -> some View {
        content
            .confirmationDialog(
                .deleteConfirmationTitle(secretName: secret.name),
                isPresented: isPresented,
                titleVisibility: .visible,
                actions: {
                    TextField(secret.name, text: $confirmedSecretName)
                    if let errorText {
                        Text(verbatim: errorText)
                            .errorStyle()
                    }
                    Button(.deleteConfirmationDeleteButton, action: delete)
                        .disabled(confirmedSecretName != secret.name)
                    Button(.deleteConfirmationCancelButton, role: .cancel) {
                        dismissalBlock(false)
                    }
                },
                message: {
                    Text(.deleteConfirmationDescription(secretName: secret.name, confirmSecretName: secret.name))
                }
            )
            .dialogIcon(Image(systemName: "lock.trianglebadge.exclamationmark.fill"))
            .onExitCommand {
                dismissalBlock(false)
            }
    }

    func delete() {
        Task {
            do {
                try await store!.delete(secret: secret)
                dismissalBlock(true)
            } catch {
                errorText = error.localizedDescription
            }
        }
    }

}
