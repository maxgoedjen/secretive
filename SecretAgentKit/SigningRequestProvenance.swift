import Foundation
import AppKit

public struct SigningRequestProvenance {

    public var chain: [Process]
    public init(root: Process) {
        self.chain = [root]
    }

}

extension SigningRequestProvenance {

    public var origin: Process {
        chain.last!
    }

}

extension SigningRequestProvenance {

    public struct Process {

        public let pid: Int32
        public let name: String
        public let path: String
        public let validSignature: Bool
        let parentPID: Int32?

        init(pid: Int32, name: String, path: String, validSignature: Bool, parentPID: Int32?) {
            self.pid = pid
            self.name = name
            self.path = path
            self.validSignature = true
            self.parentPID = parentPID
        }

    }

}
