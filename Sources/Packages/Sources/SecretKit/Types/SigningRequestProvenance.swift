import Foundation
import AppKit

public struct SigningRequestProvenance: Equatable {

    public var chain: [Process]
    public init(root: Process) {
        self.chain = [root]
    }

}

extension SigningRequestProvenance {

    public var origin: Process {
        chain.last!
    }

    public var intact: Bool {
        chain.allSatisfy { $0.validSignature }
    }

}

extension SigningRequestProvenance {

    public struct Process: Equatable {

        public let pid: Int32
        public let processName: String
        public let appName: String?
        public let iconURL: URL?
        public let path: String
        public let validSignature: Bool
        public let parentPID: Int32?

        public init(pid: Int32, processName: String, appName: String?, iconURL: URL?, path: String, validSignature: Bool, parentPID: Int32?) {
            self.pid = pid
            self.processName = processName
            self.appName = appName
            self.iconURL = iconURL
            self.path = path
            self.validSignature = validSignature
            self.parentPID = parentPID
        }

        public var displayName: String {
            appName ?? processName
        }

    }

}
