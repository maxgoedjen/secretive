import Foundation
import OSLog
import SecretKit

public struct Session: Sendable {

    public let messages: AsyncStream<Data>
    public let provenance: SigningRequestProvenance

    private let fileHandle: FileHandle
    private let continuation: AsyncStream<Data>.Continuation
    private let logger = Logger(subsystem: "com.maxgoedjen.secretive.secretagent", category: "Session")

    init(fileHandle: FileHandle) {
        self.fileHandle = fileHandle
        provenance = SigningRequestTracer().provenance(from: fileHandle)
        (messages, continuation) = AsyncStream.makeStream()
        Task { [continuation, logger] in
            await fileHandle.waitForDataInBackgroundAndNotifyOnMainActor()
            for await _ in NotificationCenter.default.notifications(named: .NSFileHandleDataAvailable, object: fileHandle) {
                let data = fileHandle.availableData
                guard !data.isEmpty else {
                    logger.debug("Socket controller received empty data, ending continuation.")
                    continuation.finish()
                    return
                }
                continuation.yield(data)
                logger.debug("Socket controller yielded data.")
            }
        }
    }

    public func write(_ data: Data) async throws {
        try fileHandle.write(contentsOf: data)
        await fileHandle.waitForDataInBackgroundAndNotifyOnMainActor()
    }

    public func close() throws {
        logger.debug("Session closed.")
        try fileHandle.close()
    }

}

/// A controller that manages socket configuration and request dispatching.
public struct SocketController {

    /// The active SocketPort.
    private let port: SocketPort
    /// The FileHandle for the main socket.
    private let fileHandle: FileHandle
    private let logger = Logger(subsystem: "com.maxgoedjen.secretive.secretagent", category: "SocketController")
    private let requestTracer = SigningRequestTracer()

    public let sessions: AsyncStream<Session>
    public let continuation: AsyncStream<Session>.Continuation

    /// Initializes a socket controller with a specified path.
    /// - Parameter path: The path to use as a socket.
    public init(path: String) {
        (sessions, continuation) = AsyncStream<Session>.makeStream()
        logger.debug("Socket controller setting up at \(path)")
        if let _ = try? FileManager.default.removeItem(atPath: path) {
            logger.debug("Socket controller removed existing socket")
        }
        let exists = FileManager.default.fileExists(atPath: path)
        assert(!exists)
        logger.debug("Socket controller path is clear")
        port = SocketPort(path: path)
        fileHandle = FileHandle(fileDescriptor: port.socket, closeOnDealloc: true)
        Task { [fileHandle, continuation, logger] in
            for await notification in NotificationCenter.default.notifications(named: .NSFileHandleConnectionAccepted) {
                logger.debug("Socket controller accepted connection")
                guard let new = notification.userInfo?[NSFileHandleNotificationFileHandleItem] as? FileHandle else { continue }
                let session = Session(fileHandle: new)
                continuation.yield(session)
                await fileHandle.acceptConnectionInBackgroundAndNotifyOnMainActor()
            }
        }
        fileHandle.acceptConnectionInBackgroundAndNotify(forModes: [RunLoop.Mode.common])
        logger.debug("Socket listening at \(path)")
    }

}

extension FileHandle {
    
    /// Ensures waitForDataInBackgroundAndNotify will be called on the main actor.
    @MainActor func waitForDataInBackgroundAndNotifyOnMainActor() {
        waitForDataInBackgroundAndNotify()
    }


    /// Ensures acceptConnectionInBackgroundAndNotify will be called on the main actor.
    /// - Parameter modes: the runloop modes to use.
    @MainActor func acceptConnectionInBackgroundAndNotifyOnMainActor(forModes modes: [RunLoop.Mode]? = [RunLoop.Mode.common]) {
        acceptConnectionInBackgroundAndNotify(forModes: modes)
    }

}

extension SocketPort {

    convenience init(path: String) {
        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)

        var len: Int = 0
        withUnsafeMutablePointer(to: &addr.sun_path.0) { pointer in
            path.withCString { cstring in
                len = strlen(cstring)
                strncpy(pointer, cstring, len)
            }
        }
        addr.sun_len = UInt8(len+2)

        var data: Data!
        withUnsafePointer(to: &addr) { pointer in
            data = Data(bytes: pointer, count: MemoryLayout<sockaddr_un>.size)
        }

        self.init(protocolFamily: AF_UNIX, socketType: SOCK_STREAM, protocol: 0, address: data)!
    }

}
