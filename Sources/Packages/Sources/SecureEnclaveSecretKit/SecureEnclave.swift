import Security

/// Namespace for the Secure Enclave implementations.
public enum SecureEnclave {}

extension SecureEnclave {

    static func keyAccessibility(usableWhileLocked: Bool) -> CFString {
        usableWhileLocked ? kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly : kSecAttrAccessibleWhenUnlockedThisDeviceOnly
    }
}
