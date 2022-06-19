import Foundation
import OSLog

/// A controller that manages socket configuration and request dispatching.
public class SocketController {

    /// The active FileHandle.
    private var fileHandle: FileHandle?
    /// The active SocketPort.
    private var port: SocketPort?
    /// A handler that will be notified when a new read/write handle is available.
    /// False if no data could be read
    public var handler: ((FileHandleReader, FileHandleWriter) -> Bool)?


    /// Initializes a socket controller with a specified path.
    /// - Parameter path: The path to use as a socket.
    public init(path: String) {
        Logger().debug("Socket controller setting up at \(path)")
        if let _ = try? FileManager.default.removeItem(atPath: path) {
            Logger().debug("Socket controller removed existing socket")
        }
        let exists = FileManager.default.fileExists(atPath: path)
        assert(!exists)
        Logger().debug("Socket controller path is clear")
        port = socketPort(at: path)
        configureSocket(at: path)
        Logger().debug("Socket listening at \(path)")
    }

    /// Configures the socket and a corresponding FileHandle.
    /// - Parameter path: The path to use as a socket.
    func configureSocket(at path: String) {
        guard let port = port else { return }
        fileHandle = FileHandle(fileDescriptor: port.socket, closeOnDealloc: true)
        NotificationCenter.default.addObserver(self, selector: #selector(handleConnectionAccept(notification:)), name: .NSFileHandleConnectionAccepted, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleConnectionDataAvailable(notification:)), name: .NSFileHandleDataAvailable, object: nil)
        fileHandle?.acceptConnectionInBackgroundAndNotify(forModes: [RunLoop.current.currentMode!])
    }

    /// Creates a SocketPort for a path.
    /// - Parameter path: The path to use as a socket.
    /// - Returns: A configured SocketPort.
    func socketPort(at path: String) -> SocketPort {
        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)

        let len = MemoryLayout.size(ofValue: addr.sun_path) - 1
        withUnsafeMutablePointer(to: &addr.sun_path.0) { pointer in
            // The buffer is pre-zeroed, so manual termination is unnecessary.
            precondition(memccpy(pointer, path, 0, len) != nil)
        }
        addr.sun_len = UInt8(len)

        let data = withUnsafeBytes(of: &addr, Data.init(_:))
        return SocketPort(protocolFamily: AF_UNIX, socketType: SOCK_STREAM, protocol: 0, address: data)!
    }

    /// Handles a new connection being accepted, invokes the handler, and prepares to accept new connections.
    /// - Parameter notification: A `Notification` that triggered the call.
    @objc func handleConnectionAccept(notification: Notification) {
        Logger().debug("Socket controller accepted connection")
        guard let new = notification.userInfo?[NSFileHandleNotificationFileHandleItem] as? FileHandle else { return }
        _ = handler?(new, new)
        new.waitForDataInBackgroundAndNotify()
        fileHandle?.acceptConnectionInBackgroundAndNotify(forModes: [RunLoop.current.currentMode!])
    }

    /// Handles a new connection providing data and invokes the handler callback.
    /// - Parameter notification: A `Notification` that triggered the call.
    @objc func handleConnectionDataAvailable(notification: Notification) {
        Logger().debug("Socket controller has new data available")
        guard let new = notification.object as? FileHandle else { return }
        Logger().debug("Socket controller received new file handle")
        if((handler?(new, new)) == true) {
            Logger().debug("Socket controller handled data, wait for more data")
            new.waitForDataInBackgroundAndNotify()
        } else {
            Logger().debug("Socket controller called with empty data, socked closed")
        }
    }

}
