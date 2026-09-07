import Foundation
import Observation
import Security

// FIXME: DEDUP
private func KeychainDictionary(_ dictionary: [CFString: Any]) -> CFDictionary {
    dictionary as CFDictionary
}


// Setting store backed by macOS keychain for stronger guarantees around ownership/other-process-modification than UserDefaults offers.
@Observable @MainActor public final class SettingsStore: Sendable {

    public init() {
        let old = self[RequireDestinationInformationSettingsKey.self]
        let oldTwo = self[SomeStringSettingsKey.self]
        print(old, oldTwo)
        self[SomeStringSettingsKey.self] = UUID().uuidString
    }

    subscript<SettingsKeyType: SettingsKey>(_ key: SettingsKeyType.Type) -> SettingsKeyType.Value {
        get {
            let queryAttributes = KeychainDictionary([
                kSecClass: Constants.keyClass,
                kSecAttrService: Constants.keyTag,
                kSecAttrAccount: String(describing: SettingsKeyType.self),
                kSecUseDataProtectionKeychain: true,
                kSecReturnData: true,
                kSecReturnAttributes: true,
                kSecMatchLimit: kSecMatchLimitOne,
                ])
            var untyped: CFTypeRef?
            unsafe SecItemCopyMatching(queryAttributes, &untyped)
            guard let typed = untyped as? [CFString: Any] else { return SettingsKeyType.defaultValue }
            let decoder = JSONDecoder()
            guard let data = typed[kSecValueData] as? Data else { return SettingsKeyType.defaultValue }
            return (try? decoder.decode(SettingValue<SettingsKeyType.Value>.self, from: data).value) ?? SettingsKeyType.defaultValue
        }
        set {
            guard let data = try? JSONEncoder().encode(SettingValue(value: newValue)) else { return }
            let keychainAttributes = KeychainDictionary([
                kSecClass: Constants.keyClass,
                kSecAttrService: Constants.keyTag,
                kSecAttrAccount: String(describing: SettingsKeyType.self),
                kSecUseDataProtectionKeychain: true,
                kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
                kSecValueData: data,
            ])
            let status = SecItemAdd(keychainAttributes, nil)
            switch status {
            case errSecSuccess:
                break
            case errSecDuplicateItem:
                let updateQuery = KeychainDictionary([
                    kSecClass: Constants.keyClass,
                    kSecAttrService: Constants.keyTag,
                    kSecAttrAccount: String(describing: SettingsKeyType.self),
                ])
                let updatedAttributes = KeychainDictionary([
                    kSecValueData: data,
                ])
                let status = SecItemUpdate(updateQuery, updatedAttributes)
                if status != errSecSuccess {
                    fatalError()
                }
                break
            default:
                // FIXME: THIS
                fatalError()
//                throw KeychainError(statusCode: status)
            }
        }
    }


}

extension SettingsStore {

    public protocol SettingsKey<Value>: Equatable, Codable, Sendable {
        associatedtype Value: Codable
        static var defaultValue: Value { get }
    }

    struct RequireDestinationInformationSettingsKey: SettingsKey {
        static let defaultValue: Bool = true
    }

    struct SomeStringSettingsKey: SettingsKey {
        static let defaultValue: String = "hello"
    }

}

extension SettingsStore {

    struct SettingValue<Value: Codable>: Codable {
        let value: Value
    }

}

extension SettingsStore {

    enum Constants {
        static let keyClass = kSecClassGenericPassword as String
        static let keyTag = "com.maxgoedjen.settingsStore"
    }

}
