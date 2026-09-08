import Foundation
import Observation
import Security
import OSLog

// Setting store backed by macOS keychain for stronger guarantees around ownership/other-process-modification than UserDefaults offers.
@Observable @MainActor public final class SettingsStore: Sendable {

    private let logger = Logger(subsystem: "com.maxgoedjen.secretive.settings", category: "SettingsStore")

    public init() {
    }

    private var state: [ObjectIdentifier: UUID] = [:]

    subscript<SettingsKeyType: SettingsKey>(_ key: SettingsKeyType.Type) -> SettingsKeyType.Value {
        get {
            _ = state[ObjectIdentifier(key)]
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
            do {
                let data = try JSONEncoder().encode(SettingValue(value: newValue))
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
                        throw KeychainError(statusCode: status)
                    }
                default:
                    throw KeychainError(statusCode: status)
                }
                state[ObjectIdentifier(key)] = UUID()
            } catch {
                logger.error("Error updating key: \(String(describing: SettingsKeyType.self), privacy: .public): \(error.localizedDescription.debugDescription, privacy: .public)")
            }
        }
    }


}

extension SettingsStore {

    public protocol SettingsKey<Value>: Equatable, Codable, Sendable {
        associatedtype Value: Codable
        static var defaultValue: Value { get }
    }

}

extension SettingsStore {

    struct SettingValue<Value: Codable>: Codable {
        let value: Value
    }

}


extension SettingsStore {

    fileprivate struct KeychainError: Error {
        let statusCode: OSStatus?
    }

}

fileprivate func KeychainDictionary(_ dictionary: [CFString: Any]) -> CFDictionary {
    dictionary as CFDictionary
}


extension SettingsStore {

    enum Constants {
        static let keyClass = kSecClassGenericPassword as String
        static let keyTag = "com.maxgoedjen.settingsStore"
    }

}
