import SwiftUI
import SecretKit

struct RenameSecretView<StoreType: SecretStoreModifiable>: View {

    @State var store: StoreType
    let secret: StoreType.SecretType
    var dismissalBlock: (_ renamed: Bool) -> ()

    @State private var newName = ""

    var body: some View {
        VStack {
            HStack {
                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable()
                    .frame(width: 64, height: 64)
                    .padding()
                VStack {
                    HStack {
                        Text(.renameTitle(secretName: secret.name))
                        Spacer()
                    }
                    HStack {
                        TextField(secret.name, text: $newName).focusable()
                    }
                }
            }
            HStack {
                Spacer()
                Button(.renameRenameButton, action: rename)
                    .disabled(newName.count == 0)
                    .keyboardShortcut(.return)
                Button(.renameCancelButton) {
                    dismissalBlock(false)
                }.keyboardShortcut(.cancelAction)
            }
        }
        .padding()
        .frame(minWidth: 400)
        .onExitCommand {
            dismissalBlock(false)
        }
    }

    func rename() {
        Task {
            try? await store.update(secret: secret, name: newName)
            dismissalBlock(true)
        }
    }
}
