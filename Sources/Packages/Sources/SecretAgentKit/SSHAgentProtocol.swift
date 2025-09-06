import Foundation

/// A namespace for the SSH Agent Protocol, as described in https://datatracker.ietf.org/doc/html/draft-miller-ssh-agent#section-5.1
public enum SSHAgent {}

extension SSHAgent {

    /// The type of the SSH Agent Request, as described in https://datatracker.ietf.org/doc/html/draft-miller-ssh-agent#section-5.1
    public enum Request: CustomDebugStringConvertible, Codable {

        case requestIdentities
        case signRequest(SignatureRequestContext)
        case addIdentity
        case removeIdentity
        case removeAllIdentities
        case addIDConstrained
        case addSmartcardKey
        case removeSmartcardKey
        case lock
        case unlock
        case addSmartcardKeyConstrained
        case protocolExtension
        case unknown(UInt8)

        public var protocolID: UInt8 {
            switch self {
            case .requestIdentities: 11
            case .signRequest: 13
            case .addIdentity: 17
            case .removeIdentity: 18
            case .removeAllIdentities: 19
            case .addIDConstrained: 25
            case .addSmartcardKey: 20
            case .removeSmartcardKey: 21
            case .lock: 22
            case .unlock: 23
            case .addSmartcardKeyConstrained: 26
            case .protocolExtension: 27
            case .unknown(let value): value
            }
        }

        public var debugDescription: String {
            switch self {
            case .requestIdentities: "SSH_AGENTC_REQUEST_IDENTITIES"
            case .signRequest: "SSH_AGENTC_SIGN_REQUEST"
            case .addIdentity: "SSH_AGENTC_ADD_IDENTITY"
            case .removeIdentity: "SSH_AGENTC_REMOVE_IDENTITY"
            case .removeAllIdentities: "SSH_AGENTC_REMOVE_ALL_IDENTITIES"
            case .addIDConstrained: "SSH_AGENTC_ADD_ID_CONSTRAINED"
            case .addSmartcardKey: "SSH_AGENTC_ADD_SMARTCARD_KEY"
            case .removeSmartcardKey: "SSH_AGENTC_REMOVE_SMARTCARD_KEY"
            case .lock: "SSH_AGENTC_LOCK"
            case .unlock: "SSH_AGENTC_UNLOCK"
            case .addSmartcardKeyConstrained: "SSH_AGENTC_ADD_SMARTCARD_KEY_CONSTRAINED"
            case .protocolExtension: "SSH_AGENTC_EXTENSION"
            case .unknown: "UNKNOWN_MESSAGE"
            }
        }

        public struct SignatureRequestContext: Sendable, Codable {
            public let keyBlob: Data
            public let dataToSign: Data

            public init(keyBlob: Data, dataToSign: Data) {
                self.keyBlob = keyBlob
                self.dataToSign = dataToSign
            }

            public static var empty: SignatureRequestContext {
                SignatureRequestContext(keyBlob: Data(), dataToSign: Data())
            }
        }

    }

    /// The type of the SSH Agent Response, as described in https://datatracker.ietf.org/doc/html/draft-miller-ssh-agent#section-5.1
    public enum Response: UInt8, CustomDebugStringConvertible {
        
        case agentFailure = 5
        case agentSuccess = 6
        case agentIdentitiesAnswer = 12
        case agentSignResponse = 14
        case agentExtensionFailure = 28
        case agentExtensionResponse = 29

        public var debugDescription: String {
            switch self {
            case .agentFailure: "SSH_AGENT_FAILURE"
            case .agentSuccess: "SSH_AGENT_SUCCESS"
            case .agentIdentitiesAnswer: "SSH_AGENT_IDENTITIES_ANSWER"
            case .agentSignResponse: "SSH_AGENT_SIGN_RESPONSE"
            case .agentExtensionFailure: "SSH_AGENT_EXTENSION_FAILURE"
            case .agentExtensionResponse: "SSH_AGENT_EXTENSION_RESPONSE"
            }
        }
    }
    
}
