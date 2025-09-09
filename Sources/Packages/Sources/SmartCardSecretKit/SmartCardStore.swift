import Foundation
import Observation
import Security
@unsafe @preconcurrency import CryptoTokenKit
import LocalAuthentication
import SecretKit

extension SmartCard {
    
    @MainActor @Observable fileprivate final class State {
        var isAvailable = false
        var name = String(localized: .smartCard)
        var secrets: [Secret] = []
        let watcher = TKTokenWatcher()
        var tokenID: String? = nil
        nonisolated init() {}
    }

    /// An implementation of Store backed by a Smart Card.
    @Observable public final class Store: SecretStore {

        private let state = State()
        public var isAvailable: Bool {
            state.isAvailable
        }
        @MainActor public var smartcardTokenID: String? {
            state.tokenID
        }

        public let id = UUID()
        @MainActor public var name: String {
            state.name
        }
        public var secrets: [Secret] {
            state.secrets
        }

        /// Initializes a Store.
        public init() {
            Task {
                await MainActor.run {
                    if let tokenID = smartcardTokenID {
                        state.isAvailable = true
                        state.watcher.addRemovalHandler(self.smartcardRemoved, forTokenID: tokenID)
                    }
                    loadSecrets()
                }
                // Doing this inside a regular mainactor handler casues thread assertions in CryptoTokenKit to blow up when the handler executes.
                await state.watcher.setInsertionHandler { id in
                    Task {
                        await self.smartcardInserted(for: id)
                    }
                }
            }
        }

        // MARK: Public API

        public func sign(data: Data, with secret: Secret, for provenance: SigningRequestProvenance) async throws -> Data {
            guard let tokenID = await state.tokenID else { fatalError() }
            let context = LAContext()
            context.localizedReason = String(localized: .authContextRequestSignatureDescription(appName: provenance.origin.displayName, secretName: secret.name))
            context.localizedCancelTitle = String(localized: .authContextRequestDenyButton)
            let attributes = KeychainDictionary([
                kSecClass: kSecClassKey,
                kSecAttrKeyClass: kSecAttrKeyClassPrivate,
                kSecAttrApplicationLabel: secret.id as CFData,
                kSecAttrTokenID: tokenID,
                kSecUseAuthenticationContext: context,
                kSecReturnRef: true
            ])
            var untyped: CFTypeRef?
            let status = unsafe SecItemCopyMatching(attributes, &untyped)
            if status != errSecSuccess {
                throw KeychainError(statusCode: status)
            }
            guard let untypedSafe = untyped else {
                throw KeychainError(statusCode: errSecSuccess)
            }
            let key = untypedSafe as! SecKey
            var signError: SecurityError?
            guard let algorithm = signatureAlgorithm(for: secret) else { throw UnsupportKeyType() }
            guard let signature = unsafe SecKeyCreateSignature(key, algorithm, data as CFData, &signError) else {
                throw unsafe SigningError(error: signError)
            }
            return signature as Data
        }
        
        public func existingPersistedAuthenticationContext(secret: Secret) -> PersistedAuthenticationContext? {
            nil
        }

        public func persistAuthentication(secret: Secret, forDuration: TimeInterval) throws {
        }

        /// Reloads all secrets from the store.
        @MainActor public func reloadSecrets() {
            reloadSecretsInternal()
        }

    }

}

extension SmartCard.Store {

    @MainActor private func reloadSecretsInternal() {
        let before = state.secrets
        state.isAvailable = state.tokenID != nil
        state.secrets.removeAll()
        loadSecrets()
        if self.secrets != before {
            NotificationCenter.default.post(name: .secretStoreReloaded, object: self)
        }
    }

    /// Resets the token ID and reloads secrets.
    /// - Parameter tokenID: The ID of the token that was inserted.
    @MainActor private func smartcardInserted(for tokenID: String? = nil) {
        guard let string = state.watcher.nonSecureEnclaveTokens.first else { return }
        guard state.tokenID == nil else { return }
        guard !string.contains("setoken") else { return }
        state.tokenID = string
        state.watcher.addRemovalHandler(self.smartcardRemoved, forTokenID: string)
        state.tokenID = string
        reloadSecretsInternal()
    }

    /// Resets the token ID and reloads secrets.
    /// - Parameter tokenID: The ID of the token that was removed.
    @MainActor private func smartcardRemoved(for tokenID: String? = nil) {
        state.tokenID = nil
        reloadSecrets()
    }

    /// Loads all secrets from the store.
    @MainActor private func loadSecrets() {
        guard let tokenID = state.tokenID  else { return }

        let fallbackName = String(localized: .smartCard)
        if let driverName = state.watcher.tokenInfo(forTokenID: tokenID)?.driverName  {
            state.name = driverName
        } else {
            state.name = fallbackName
        }

        let attributes = KeychainDictionary([
            kSecClass: kSecClassKey,
            kSecAttrTokenID: tokenID,
            kSecReturnRef: true,
            kSecMatchLimit: kSecMatchLimitAll,
            kSecReturnAttributes: true
        ])
        var untyped: CFTypeRef?
        unsafe SecItemCopyMatching(attributes, &untyped)
        guard let typed = untyped as? [[CFString: Any]] else { return }
        let wrapped: [SecretType] = typed.compactMap {
            let name = $0[kSecAttrLabel] as? String ?? String(localized: .unnamedSecret)
            let tokenID = $0[kSecAttrApplicationLabel] as! Data
            let algorithmSecAttr = $0[kSecAttrKeyType] as! NSNumber
            let keySize = $0[kSecAttrKeySizeInBits] as! Int
            let publicKeyRef = $0[kSecValueRef] as! SecKey
            let publicKeySecRef = SecKeyCopyPublicKey(publicKeyRef)!
            let publicKeyAttributes = SecKeyCopyAttributes(publicKeySecRef) as! [CFString: Any]
            let publicKey = publicKeyAttributes[kSecValueData] as! Data
            let attributes = Attributes(keyType: KeyType(secAttr: algorithmSecAttr, size: keySize)!, authentication: .unknown)
            let secret = SmartCard.Secret(id: tokenID, name: name, publicKey: publicKey, attributes: attributes)
            guard signatureAlgorithm(for: secret) != nil else { return nil }
            return secret
        }
        state.secrets.append(contentsOf: wrapped)
    }

}

extension TKTokenWatcher {

    /// All available tokens, excluding the Secure Enclave.
    fileprivate var nonSecureEnclaveTokens: [String] {
        tokenIDs.filter { !$0.contains("setoken") }
    }

}

extension SmartCard {

    public struct UnsupportKeyType: Error {}

}
