import Foundation

public enum SSHAgent {}

extension SSHAgent {

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

    public enum ResponseType: UInt8, CustomDebugStringConvertible {
        case agentFailure = 5
        case agentIdentitiesAnswer = 12
        case agentSignResponse = 14

        public var debugDescription: String {
            switch self {
            case .agentFailure:
                return "AgentFailure"
            case .agentIdentitiesAnswer:
                return "AgentIdentitiesAnswer"
            case .agentSignResponse:
                return "AgentSignResponse"
            }
        }
    }
    
}
