
import Foundation

class SettingsStore: ObservableObject {
    enum Constants {
        static let service = "com.maxgoedjen.Secretive"
    }
}

extension SettingsStore {
    subscript(key: String) -> String? {
        set(value) {
            guard let valueData = value?.data(using: String.Encoding.utf8)! else {
                return
            }
            
            if let keyVal = self[key] {
                if keyVal == value {
                    return
                }
                
                let updateQuery: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                                  kSecAttrServer as String: Constants.service]
                let attributes: [String: Any] = [kSecAttrAccount as String: key,
                                                 kSecValueData as String: valueData]
                // FIXME: Make this non-blocking as described here: https://developer.apple.com/documentation/security/1393617-secitemupdate
                let status = SecItemUpdate(updateQuery as CFDictionary, attributes as CFDictionary)
                guard status == errSecSuccess else {
                    print("Couldn't update item in keychain. " + status.description)
                    return
                }
            } else {
                let addquery: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                               kSecAttrAccount as String: key,
                                               kSecAttrServer as String: Constants.service,
                                               kSecValueData as String: valueData]
                // FIXME: Make this non-blocking as described here: https://developer.apple.com/documentation/security/1401659-secitemadd
                let status = SecItemAdd(addquery as CFDictionary, nil)
                guard status == errSecSuccess else {
                    print("Couldn't add item to keychain. " + status.description)
                    return
                }
            }
        }
        
        get {
            let getquery: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                           kSecAttrAccount as String: key,
                                           kSecAttrServer as String: Constants.service,
                                           kSecMatchLimit as String: kSecMatchLimitOne,
                                           kSecReturnData as String: true]
            var item: CFTypeRef?
            let status = SecItemCopyMatching(getquery as CFDictionary, &item)
            
            return status == errSecSuccess ? String(decoding: item as! Data, as: UTF8.self) : nil
        }
    }
}
