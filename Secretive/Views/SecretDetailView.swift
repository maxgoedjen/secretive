import SwiftUI
import SecretKit

struct SecretDetailView<SecretType: Secret>: View {
    
    @State var secret: SecretType

    let defaults = UserDefaults.standard
    
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

    var dashedUserName: String {
        NSUserName().replacingOccurrences(of: " ", with: "-")
    }

    var dashedHostName: String {
        [Host.current().localizedName, "local"]
            .compactMap { $0 }
            .joined(separator: ".")
            .replacingOccurrences(of: " ", with: "-")
    }
    
    var keyString: String {
        if defaults.string(forKey: secret.name) != "" {
            return keyWriter.openSSHString(secret: secret, comment: defaults.string(forKey: secret.name))
        } else {
            return keyWriter.openSSHString(secret: secret, comment: "\(dashedUserName)@\(dashedHostName)")
        }
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
