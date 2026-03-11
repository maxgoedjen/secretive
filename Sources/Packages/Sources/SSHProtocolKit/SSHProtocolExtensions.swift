import Foundation

// Extensions, as defined in https://github.com/openssh/openssh-portable/blob/master/PROTOCOL.agent

extension SSHAgent {

    public enum ProtocolExtension: CustomDebugStringConvertible, Codable, Sendable {
        case openSSH(OpenSSHExtension)
        case unknown(String)

        public var debugDescription: String {
            switch self {
            case let .openSSH(protocolExtension):
                protocolExtension.debugDescription
            case .unknown(let string):
                "Unknown (\(string))"
            }
        }

        public static var empty: ProtocolExtension {
            .unknown("empty")
        }

        private struct ProtocolExtensionParsingError: Error {}

    }

}

extension SSHAgent.ProtocolExtension {

    public enum OpenSSHExtension: CustomDebugStringConvertible, Codable, Sendable {
        case sessionBind(SessionBindContext)
        case unknown(String)

        public static var domain: String {
            "openssh.com"
        }

        public var name: String {
            switch self {
            case .sessionBind:
                "session-bind"
            case .unknown(let name):
                name
            }
        }

        public var debugDescription: String {
            "\(name)@\(OpenSSHExtension.domain)"
        }
    }

}

extension SSHAgent.ProtocolExtension.OpenSSHExtension {

    public struct SessionBindContext: Codable, Sendable {

        public let hostKey: Data
        public let sessionID: Data
        public let signature: Data
        public let forwarding: Bool

        public init(hostKey: Data, sessionID: Data, signature: Data, forwarding: Bool) {
            self.hostKey = hostKey
            self.sessionID = sessionID
            self.signature = signature
            self.forwarding = forwarding
        }

        public static let empty = SessionBindContext(hostKey: Data(), sessionID: Data(), signature: Data(), forwarding: false)

    }

}
