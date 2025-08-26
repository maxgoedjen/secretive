import Foundation
import OSLog
import SecretKit

/// A controller that manages socket configuration and request dispatching.
public final class SocketController {

    /// The active SocketPort.
    private var port: SocketPort?
    /// A handler that will be notified when a new read/write handle is available.
    /// False if no data could be read
    public var handler: OSAllocatedUnfairLock<(@Sendable (Data, SigningRequestProvenance) async throws -> Data)?> = .init(initialState: nil)
    /// Logger.
    private let logger = Logger(subsystem: "com.maxgoedjen.secretive.secretagent", category: "SocketController")

    private let requestTracer = SigningRequestTracer()

    // Async sequence of message?

    /// Initializes a socket controller with a specified path.
    /// - Parameter path: The path to use as a socket.
    public init(path: String) {
        logger.debug("Socket controller setting up at \(path)")
        if let _ = try? FileManager.default.removeItem(atPath: path) {
            logger.debug("Socket controller removed existing socket")
        }
        let exists = FileManager.default.fileExists(atPath: path)
        assert(!exists)
        logger.debug("Socket controller path is clear")
        port = socketPort(at: path)
        configureSocket(at: path)
        logger.debug("Socket listening at \(path)")
    }

    /// Configures the socket and a corresponding FileHandle.
    /// - Parameter path: The path to use as a socket.
    func configureSocket(at path: String) {
        guard let port = port else { return }
        let fileHandle = FileHandle(fileDescriptor: port.socket, closeOnDealloc: true)
        fileHandle.acceptConnectionInBackgroundAndNotify(forModes: [RunLoop.Mode.common])
        Task { [handler, logger] in
            for await notification in NotificationCenter.default.notifications(named: .NSFileHandleConnectionAccepted) {
                logger.debug("Socket controller accepted connection")
                guard let new = notification.userInfo?[NSFileHandleNotificationFileHandleItem] as? FileHandle else { continue }
                let provenance = SigningRequestTracer().provenance(from: new)
                guard let handler = handler.withLock({ $0 }) else {
                    // FIXME: THIS
                    fatalError()
                }
                let response = try await handler(Data(fileHandle.availableData), provenance)
                try fileHandle.write(contentsOf: response)
                await new.waitForDataInBackgroundAndNotifyOnMainActor()
                await fileHandle.acceptConnectionInBackgroundAndNotifyOnMainActor()
            }
        }
        Task { [logger, handler] in
            for await notification in NotificationCenter.default.notifications(named: .NSFileHandleDataAvailable) {
                logger.debug("Socket controller has new data available")
                guard let new = notification.object as? FileHandle else { return }
                logger.debug("Socket controller received new file handle")
                guard let handler = handler.withLock({ $0 }) else {
                    // FIXME: THIS
                    fatalError()
                }
                do {
                    let provenance = SigningRequestTracer().provenance(from: new)
                    let response = try await handler(Data(fileHandle.availableData), provenance)
                    try fileHandle.write(contentsOf: response)
                    logger.debug("Socket controller handled data, wait for more data")
                    await new.waitForDataInBackgroundAndNotifyOnMainActor()
                } catch {
                    logger.debug("Socket controller called with empty data, socked closed")
                }
            }
        }
    }

    /// Creates a SocketPort for a path.
    /// - Parameter path: The path to use as a socket.
    /// - Returns: A configured SocketPort.
    func socketPort(at path: String) -> SocketPort {
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

        return SocketPort(protocolFamily: AF_UNIX, socketType: SOCK_STREAM, protocol: 0, address: data)!
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
