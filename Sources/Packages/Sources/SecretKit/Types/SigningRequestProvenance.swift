import Foundation
import AppKit

/// Describes the chain of applications that requested a signature operation.
public struct SigningRequestProvenance: Equatable, Sendable {

    /// A list of processes involved in the request.
    /// - Note: A chain will typically consist of many elements even for a simple request. For example, running `git fetch` in Terminal.app would generate a request chain of `ssh` -> `git` -> `zsh` -> `login` -> `Terminal.app`
    public var chain: [Process]
    public init(root: Process) {
        self.chain = [root]
    }

}

extension SigningRequestProvenance {

    /// The `Process` which initiated the signing request.
    public var origin: Process {
        chain.last!
    }

    /// A boolean describing whether all processes in the request chain had a valid code signature.
    public var intact: Bool {
        chain.allSatisfy { $0.validSignature }
    }

}

extension SigningRequestProvenance {

    /// Describes a process in a `SigningRequestProvenance` chain.
    public struct Process: Equatable, Sendable {

        /// The pid of the process.
        public let pid: Int32
        /// A user-facing name for the process.
        public let processName: String
        /// A user-facing name for the application, if one exists.
        public let appName: String?
        /// An icon representation of the application, if one exists.
        public let iconURL: URL?
        /// The path the process exists at.
        public let path: String
        /// A boolean describing whether or not the process has a valid code signature.
        public let validSignature: Bool
        /// The pid of the process's parent.
        public let parentPID: Int32?

        /// Initializes a Process.
        /// - Parameters:
        ///   - pid: The pid of the process.
        ///   - processName: A user-facing name for the process.
        ///   - appName: A user-facing name for the application, if one exists.
        ///   - iconURL: An icon representation of the application, if one exists.
        ///   - path: The path the process exists at.
        ///   - validSignature: A boolean describing whether or not the process has a valid code signature.
        ///   - parentPID: The pid of the process's parent.
        public init(pid: Int32, processName: String, appName: String?, iconURL: URL?, path: String, validSignature: Bool, parentPID: Int32?) {
            self.pid = pid
            self.processName = processName
            self.appName = appName
            self.iconURL = iconURL
            self.path = path
            self.validSignature = validSignature
            self.parentPID = parentPID
        }

        /// The best user-facing name to display for the process.
        public var displayName: String {
            appName ?? processName
        }

    }

}
