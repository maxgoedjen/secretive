import Foundation

/// Protocol abstraction of the reading aspects of FileHandle.
public protocol FileHandleReader: Sendable {

    /// Gets data that is available for reading.
    var availableData: Data { get }
    /// A file descriptor of the handle.
    var fileDescriptor: Int32 { get }
    /// The  process ID of the process coonnected to the other end of the FileHandle.
    var pidOfConnectedProcess: Int32 { get }

}

/// Protocol abstraction of the writing aspects of FileHandle.
public protocol FileHandleWriter: Sendable {

    /// Writes data to the handle.
    func write(_ data: Data)

}

extension FileHandle: FileHandleReader, FileHandleWriter {

    public var pidOfConnectedProcess: Int32 {
        let pidPointer = UnsafeMutableRawPointer.allocate(byteCount: MemoryLayout<Int32>.size, alignment: 1)
        var len = socklen_t(MemoryLayout<Int32>.size)
        getsockopt(fileDescriptor, SOCK_STREAM, LOCAL_PEERPID, pidPointer, &len)
        return pidPointer.load(as: Int32.self)
    }

}
