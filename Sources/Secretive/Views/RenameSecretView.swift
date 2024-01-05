import SwiftUI
import SecretKit

struct RenameSecretView<StoreType: SecretStoreModifiable>: View {

    @ObservedObject var store: StoreType
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
                        Text("rename_title_\(secret.name)")
                        Spacer()
                    }
                    HStack {
                        TextField(secret.name, text: $newName).focusable()
                    }
                }
            }
            HStack {
                Spacer()
                Button("rename_rename_button", action: rename)
                    .disabled(newName.count == 0)
                    .keyboardShortcut(.return)
                Button("rename_cancel_button") {
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
        try? store.update(secret: secret, name: newName)
        dismissalBlock(true)
    }
}
