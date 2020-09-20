import SwiftUI
import SecretKit

struct SecretDetailView<SecretType: Secret>: View {
    
    @State var secret: SecretType

    private let keyWriter = OpenSSHKeyWriter()
    
    var body: some View {
        Form {
            Section {
                CopyableView(title: "Fingerprint", image: Image(systemName: "touchid"), text: keyWriter.openSSHFingerprint(secret: secret))
                Spacer()
                    .frame(height: 20)
                CopyableView(title: "Public Key", image: Image(systemName: "key"), text: keyWriter.openSSHString(secret: secret))
                Spacer()
            }
        }
        .padding()
        .frame(minHeight: 200, maxHeight: .infinity)
    }
    
    var keyString: String {
        keyWriter.openSSHString(secret: secret)
    }
    
    func copy() {
        NSPasteboard.general.declareTypes([.string], owner: nil)
        NSPasteboard.general.setString(keyString, forType: .string)
    }
    
}

struct SecretDetailView_Previews: PreviewProvider {
    static var previews: some View {
        SecretDetailView(secret: Preview.Store(numberOfRandomSecrets: 1).secrets[0])
    }
}

