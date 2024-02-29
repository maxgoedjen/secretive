//
//  SettingsHelper.swift
//  Secretive
//
//  Created by Paul Heidekrüger on 27.02.24.
//  Copyright © 2024 Max Goedjen. All rights reserved.
//

import Foundation

class SettingsStore {
    static let service = "com.maxgoedjen.Secretive"
}

extension SettingsStore {
    static func set(key: String, value: String) -> Bool {
        let valueData = value.data(using: String.Encoding.utf8)!
        
        if let keyVal = get(key: key) {
            if keyVal == value {
                return true
            }
            
            let updateQuery: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                              kSecAttrServer as String: service]
            let attributes: [String: Any] = [kSecAttrAccount as String: key,
                                             kSecValueData as String: valueData]
            // FIXME: Make this non-blocking as described here: https://developer.apple.com/documentation/security/1393617-secitemupdate
            let status = SecItemUpdate(updateQuery as CFDictionary, attributes as CFDictionary)
            guard status == errSecSuccess else {
                print("Couldn't update item in keychain. " + status.description)
                return false
            }
        } else {
            let addquery: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                           kSecAttrAccount as String: key,
                                           kSecAttrServer as String: service,
                                           kSecValueData as String: valueData]
            // FIXME: Make this non-blocking as described here: https://developer.apple.com/documentation/security/1401659-secitemadd 
            let status = SecItemAdd(addquery as CFDictionary, nil)
            guard status == errSecSuccess else {
                print("Couldn't add item to keychain. " + status.description)
                return false
            }
        }
        return true
    }

    static func get(key: String) -> String? {
        let getquery: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                       kSecAttrAccount as String: key,
                                       kSecAttrServer as String: service,
                                       kSecMatchLimit as String: kSecMatchLimitOne,
                                       kSecReturnData as String: true]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(getquery as CFDictionary, &item)
        
        return status == errSecSuccess ? String(decoding: item as! Data, as: UTF8.self) : nil 
    }
}
