import Foundation
import OSLog
import SecretKit
import launch

/// A controller that manages socket configuration and request dispatching.
public struct SocketController {

    /// A stream of Sessions. Each session represents one connection to a class communicating with the socket. Multiple Sessions may be active simultaneously.
    public let sessions: AsyncStream<Session>

    /// A continuation to create new sessions.
    private let sessionsContinuation: AsyncStream<Session>.Continuation

    /// The active SocketPort. Must be retained to be kept valid.
    /// Only applicable for legacy non-launchd sockets.
    private let port: SocketPort?

    /// The FileHandle for the main socket.
    private let fileHandle: FileHandle
    
    /// Logger for the socket controller.
    private let logger = Logger(subsystem: "com.maxgoedjen.secretive.secretagent", category: "SocketController")

    /// Tracer which determines who originates a socket connection.
    private let requestTracer = SigningRequestTracer()

    public enum Socket {
        case launchd(String)
        case path(String)
    }

    public init(_ socket: Socket) {
        (sessions, sessionsContinuation) = AsyncStream<Session>.makeStream()
        switch socket {
        case .path(let path):
            logger.debug("Socket controller setting up at \(path)")
            if let _ = try? FileManager.default.removeItem(atPath: path) {
                logger.debug("Socket controller removed existing socket")
            }
            let exists = FileManager.default.fileExists(atPath: path)
            assert(!exists)
            logger.debug("Socket controller path is clear")
            let port = SocketPort(path: path)
            fileHandle = FileHandle(fileDescriptor: port.socket, closeOnDealloc: true)
            self.port = port
            logger.debug("Socket listening at \(path)")
        case .launchd(let name):
            logger.debug("Socket controller setting for launchd-controlled socket \(name)")
            port = nil
            var fileDescriptors: UnsafeMutablePointer<Int32>? = nil
            var count = 0
            let result = unsafe launch_activate_socket(name, &fileDescriptors, &count)
            guard result == kOSReturnSuccess, let socket = unsafe fileDescriptors?.pointee else {
                fatalError()
            }
            fileHandle = FileHandle(fileDescriptor: socket, closeOnDealloc: true)
        }
        listen()
    }

    func listen() {
        Task { @MainActor [fileHandle, sessionsContinuation, logger] in
            // Create the sequence before triggering the notification to
            // ensure it will not be missed.
            let connectionAcceptedNotifications = NotificationCenter.default.notifications(named: .NSFileHandleConnectionAccepted)

            fileHandle.acceptConnectionInBackgroundAndNotify()

            for await notification in connectionAcceptedNotifications {
                logger.debug("Socket controller accepted connection")
                guard let new = notification.userInfo?[NSFileHandleNotificationFileHandleItem] as? FileHandle else { continue }
                let session = Session(fileHandle: new)
                sessionsContinuation.yield(session)
                fileHandle.acceptConnectionInBackgroundAndNotify()
            }
        }

    }

}

extension SocketController {
    
    /// A session represents a connection that has been established between the two ends of the socket.
    public struct Session: Sendable {
        
        /// Data received by the socket.
        public let messages: AsyncStream<Data>

        /// The provenance of the process that established the session.
        public let provenance: SigningRequestProvenance
        
        /// A FileHandle used to communicate with the socket.
        private let fileHandle: FileHandle

        /// A continuation for issuing new messages.
        private let messagesContinuation: AsyncStream<Data>.Continuation

        /// A logger for the session.
        private let logger = Logger(subsystem: "com.maxgoedjen.secretive.secretagent", category: "Session")
        
        /// Initializes a new Session.
        /// - Parameter fileHandle: The FileHandle used to communicate with the socket.
        init(fileHandle: FileHandle) {
            self.fileHandle = fileHandle
            provenance = SigningRequestTracer().provenance(from: fileHandle)
            (messages, messagesContinuation) = AsyncStream.makeStream()
            Task { @MainActor [messagesContinuation, logger] in
                // Create the sequence before triggering the notification to
                // ensure it will not be missed.
                let dataAvailableNotifications = NotificationCenter.default.notifications(named: .NSFileHandleDataAvailable, object: fileHandle)

                fileHandle.waitForDataInBackgroundAndNotify()

                for await _ in dataAvailableNotifications {
                    let data = fileHandle.availableData
                    guard !data.isEmpty else {
                        logger.debug("Socket controller received empty data, ending continuation.")
                        messagesContinuation.finish()
                        try? fileHandle.close()
                        return
                    }
                    messagesContinuation.yield(data)
                    logger.debug("Socket controller yielded data.")
                }
            }
        }
        
        /// Writes new data to the socket.
        /// - Parameter data: The data to write.
        @MainActor public func write(_ data: Data) throws {
          try fileHandle.write(contentsOf: data)
          fileHandle.waitForDataInBackgroundAndNotify()
        }
        
        /// Closes the socket and cleans up resources.
        public func close() throws {
            logger.debug("Session closed.")
            messagesContinuation.finish()
            try fileHandle.close()
        }

    }

}

private extension SocketPort {

    convenience init(path: String) {
        var addr = sockaddr_un()

        let length = withUnsafeMutablePointer(to: &addr.sun_path.0) { pointer in
            path.withCString { cstring in
                let len = unsafe strlen(cstring)
                unsafe strncpy(pointer, cstring, len)
                return len
            }
        }
        // This doesn't seem to be _strictly_ neccessary with SocketPort.
        // but just for good form.
        addr.sun_family = sa_family_t(AF_UNIX)
        // This mirrors the SUN_LEN macro format.
        addr.sun_len = UInt8(MemoryLayout<sockaddr_un>.size - MemoryLayout.size(ofValue: addr.sun_path) + length)

        let data = unsafe Data(bytes: &addr, count: MemoryLayout<sockaddr_un>.size)
        self.init(protocolFamily: AF_UNIX, socketType: SOCK_STREAM, protocol: 0, address: data)!
    }

}

// Changes the header from `UnsafeMutablePointer<UnsafeMutablePointer<Int32>?>?` -> `UnsafeMutablePointer<UnsafeMutablePointer<Int32>?>!`
@_silgen_name("launch_activate_socket")
func launch_activate_socket(_ name: UnsafePointer<CChar>, _ fds: UnsafeMutablePointer<UnsafeMutablePointer<Int32>?>!, _ cnt: UnsafeMutablePointer<Int>!) -> Int32
