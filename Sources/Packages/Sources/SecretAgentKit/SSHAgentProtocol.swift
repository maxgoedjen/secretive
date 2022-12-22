import Foundation

/// A namespace for the SSH Agent Protocol, as described in https://datatracker.ietf.org/doc/html/draft-miller-ssh-agent#section-5.1
public enum SSHAgent {}

extension SSHAgent {

    /// The type of the SSH Agent Request, as described in https://datatracker.ietf.org/doc/html/draft-miller-ssh-agent#section-5.1
    public enum RequestType: UInt8, CustomDebugStringConvertible {

        case requestIdentities = 11
        case signRequest = 13

        public var debugDescription: String {
            switch self {
            case .requestIdentities:
                return "RequestIdentities"
            case .signRequest:
                return "SignRequest"
            }
        }
    }

    /// The type of the SSH Agent Response, as described in https://datatracker.ietf.org/doc/html/draft-miller-ssh-agent#section-5.1
    public enum ResponseType: UInt8, CustomDebugStringConvertible {
        
        case agentFailure = 5
        case agentSuccess = 6
        case agentIdentitiesAnswer = 12
        case agentSignResponse = 14

        public var debugDescription: String {
            switch self {
            case .agentFailure:
                return "AgentFailure"
            case .agentSuccess:
                return "AgentSuccess"
            case .agentIdentitiesAnswer:
                return "AgentIdentitiesAnswer"
            case .agentSignResponse:
                return "AgentSignResponse"
            }
        }
    }
    
}
