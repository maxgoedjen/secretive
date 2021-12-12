import Foundation
import OSLog

public class SocketController {

    private let logger = Logger()
    private var fileHandle: FileHandle?
    private var port: SocketPort?
    public var handler: ((FileHandleReader, FileHandleWriter) -> Void)?

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

    func configureSocket(at path: String) {
        guard let port = port else { return }
        fileHandle = FileHandle(fileDescriptor: port.socket, closeOnDealloc: true)
        NotificationCenter.default.addObserver(self, selector: #selector(handleConnectionAccept(notification:)), name: .NSFileHandleConnectionAccepted, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleConnectionDataAvailable(notification:)), name: .NSFileHandleDataAvailable, object: nil)
        fileHandle?.acceptConnectionInBackgroundAndNotify(forModes: [RunLoop.current.currentMode!])
    }

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

    @objc func handleConnectionAccept(notification: Notification) {
        logger.debug("Socket controller accepted connection")
        guard let new = notification.userInfo?[NSFileHandleNotificationFileHandleItem] as? FileHandle else { return }
        handler?(new, new)
        new.waitForDataInBackgroundAndNotify()
        fileHandle?.acceptConnectionInBackgroundAndNotify(forModes: [RunLoop.current.currentMode!])
    }

    @objc func handleConnectionDataAvailable(notification: Notification) {
        logger.debug("Socket controller has new data available")
        guard let new = notification.object as? FileHandle else { return }
        logger.debug("Socket controller received new file handle")
        handler?(new, new)
    }

}
