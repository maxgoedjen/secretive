import SwiftUI
import SecretKit

struct SecretDetailView<SecretType: Secret>: View {
    
    @State var secret: SecretType

    private let keyWriter = OpenSSHKeyWriter()
    
    var body: some View {
        Form {
            Section {
                CopyableView(title: "SHA256 Fingerprint", image: Image(systemName: "touchid"), text: keyWriter.openSSHSHA256Fingerprint(secret: secret))
                Spacer()
                    .frame(height: 20)
                CopyableView(title: "MD5 Fingerprint", image: Image(systemName: "touchid"), text: keyWriter.openSSHMD5Fingerprint(secret: secret))
                Spacer()
                    .frame(height: 20)
                CopyableView(title: "Public Key", image: Image(systemName: "key"), text: keyString)
                Spacer()
            }
        }
        .padding()
        .frame(minHeight: 200, maxHeight: .infinity)
    }

    var dashedKeyName: String {
        secret.name.replacingOccurrences(of: " ", with: "-")
    }

    var dashedHostName: String {
        ["secretive", Host.current().localizedName, "local"]
            .compactMap { $0 }
            .joined(separator: ".")
            .replacingOccurrences(of: " ", with: "-")
    }
    
    var keyString: String {
        keyWriter.openSSHString(secret: secret, comment: "\(dashedKeyName)@\(dashedHostName)")
    }
    
    func copy() {
        NSPasteboard.general.declareTypes([.string], owner: nil)
        NSPasteboard.general.setString(keyString, forType: .string)
    }
    
}

#if DEBUG

struct SecretDetailView_Previews: PreviewProvider {
    static var previews: some View {
        SecretDetailView(secret: Preview.Store(numberOfRandomSecrets: 1).secrets[0])
    }
}

#endif
