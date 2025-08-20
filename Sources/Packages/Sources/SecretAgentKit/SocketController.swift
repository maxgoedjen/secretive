import Foundation
import OSLog

/// A controller that manages socket configuration and request dispatching.
public final class SocketController {

    /// The active FileHandle.
    private var fileHandle: FileHandle?
    /// The active SocketPort.
    private var port: SocketPort?
    /// A handler that will be notified when a new read/write handle is available.
    /// False if no data could be read
    public var handler: (@Sendable (FileHandleReader, FileHandleWriter) async -> Bool)?
    /// Logger.
    private let logger = Logger(subsystem: "com.maxgoedjen.secretive.secretagent", category: "SocketController")


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
        fileHandle = FileHandle(fileDescriptor: port.socket, closeOnDealloc: true)
        NotificationCenter.default.addObserver(self, selector: #selector(handleConnectionAccept(notification:)), name: .NSFileHandleConnectionAccepted, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleConnectionDataAvailable(notification:)), name: .NSFileHandleDataAvailable, object: nil)
        fileHandle?.acceptConnectionInBackgroundAndNotify(forModes: [RunLoop.Mode.common])
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

    /// Handles a new connection being accepted, invokes the handler, and prepares to accept new connections.
    /// - Parameter notification: A `Notification` that triggered the call.
    @objc func handleConnectionAccept(notification: Notification) {
        logger.debug("Socket controller accepted connection")
        guard let new = notification.userInfo?[NSFileHandleNotificationFileHandleItem] as? FileHandle else { return }
        Task { [handler, fileHandle] in
            _ = await handler?(new, new)
            await new.waitForDataInBackgroundAndNotifyOnMainActor()
            await fileHandle?.acceptConnectionInBackgroundAndNotifyOnMainActor()
        }
    }

    /// Handles a new connection providing data and invokes the handler callback.
    /// - Parameter notification: A `Notification` that triggered the call.
    @objc func handleConnectionDataAvailable(notification: Notification) {
        logger.debug("Socket controller has new data available")
        guard let new = notification.object as? FileHandle else { return }
        logger.debug("Socket controller received new file handle")
        Task { [handler, logger = logger] in
            if((await handler?(new, new)) == true) {
                logger.debug("Socket controller handled data, wait for more data")
                await new.waitForDataInBackgroundAndNotifyOnMainActor()
            } else {
                logger.debug("Socket controller called with empty data, socked closed")
            }
        }
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
