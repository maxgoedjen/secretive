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
        return chain.reduce(true) { $0 && $1.validSignature }
    }

}

extension SigningRequestProvenance {

    public struct Process: Equatable {

        public let pid: Int32
        public let name: String
        public let path: String
        public let validSignature: Bool
        let parentPID: Int32?

        init(pid: Int32, name: String, path: String, validSignature: Bool, parentPID: Int32?) {
            self.pid = pid
            self.name = name
            self.path = path
            self.validSignature = validSignature
            self.parentPID = parentPID
        }

    }

}
