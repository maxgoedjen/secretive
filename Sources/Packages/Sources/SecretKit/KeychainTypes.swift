import Foundation

public typealias SecurityError = Unmanaged<CFError>

/// Wraps a Swift dictionary in a CFDictionary.
/// - Parameter dictionary: The Swift dictionary to wrap.
/// - Returns: A CFDictionary containing the keys and values.
public func KeychainDictionary(_ dictionary: [CFString: Any]) -> CFDictionary {
    dictionary as CFDictionary
}

public extension CFError {

    /// The CFError returned when a verification operation fails.
    static let verifyError = CFErrorCreate(nil, NSOSStatusErrorDomain as CFErrorDomain, CFIndex(errSecVerifyFailed), nil)!

    /// Equality operation that only considers domain and code.
    static func ~=(lhs: CFError, rhs: CFError) -> Bool {
        CFErrorGetDomain(lhs) == CFErrorGetDomain(rhs) && CFErrorGetCode(lhs) == CFErrorGetCode(rhs)
    }

}

/// A wrapper around an error code reported by a Keychain API.
public struct KeychainError: Error {
    /// The status code involved, if one was reported.
    public let statusCode: OSStatus?

    /// Initializes a KeychainError with an optional error code.
    /// - Parameter statusCode: The status code returned by the keychain operation, if one is applicable.
    public init(statusCode: OSStatus?) {
        self.statusCode = statusCode
    }
}

/// A signing-related error.
public struct SigningError: Error {
    /// The underlying error reported by the API, if one was returned.
    public let error: CFError?

    /// Initializes a SigningError with an optional SecurityError.
    /// - Parameter statusCode: The SecurityError, if one is applicable.
    public init(error: SecurityError?) {
        self.error = unsafe error?.takeRetainedValue()
    }

}

public extension SecretStore {

    /// Returns the appropriate keychian signature algorithm to use for a given secret.
    /// - Parameters:
    ///   - secret: The secret which will be used for signing.
    /// - Returns: The appropriate algorithm.
    func signatureAlgorithm(for secret: SecretType) -> SecKeyAlgorithm? {
        switch secret.keyType {
        case .ecdsa256:
            .ecdsaSignatureMessageX962SHA256
        case .ecdsa384:
            .ecdsaSignatureMessageX962SHA384
        case .rsa2048:
            .rsaSignatureMessagePKCS1v15SHA512
        default:
            nil
        }

    }

}
