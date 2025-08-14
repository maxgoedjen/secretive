import Foundation

/// Protocol abstraction of the reading aspects of FileHandle.
public protocol FileHandleReader: Sendable {

    /// Gets data that is available for reading.
    var availableData: Data { get }
    /// A file descriptor of the handle.
    var fileDescriptor: Int32 { get }
    /// The  process ID of the process coonnected to the other end of the FileHandle.
    var pidOfConnectedProcess: Int32 { get }
    /// Append data to a buffer and extract the next SSH message if available.
    func appendAndParseMessage(from newData: Data) -> Data?

}

/// Protocol abstraction of the writing aspects of FileHandle.
public protocol FileHandleWriter: Sendable {

    /// Writes data to the handle.
    func write(_ data: Data)

}

// SSHMessageBuffer for reassembly
final class SSHMessageBuffer {
    private var buffer = Data()
    func append(_ newData: Data) {
        buffer.append(newData)
    }
    func nextMessage() -> Data? {
        guard buffer.count >= 4 else { return nil }
        let length = buffer.prefix(4).withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
        guard length < 1_000_000 else { return nil }
        guard buffer.count >= 4 + Int(length) else { return nil }
        let message = buffer.subdata(in: 4..<4+Int(length))
        buffer.removeSubrange(0..<4+Int(length))
        return message
    }
}

extension FileHandle: FileHandleReader, FileHandleWriter {

    public var pidOfConnectedProcess: Int32 {
        let pidPointer = UnsafeMutableRawPointer.allocate(byteCount: 4, alignment: 1)
        var len = socklen_t(MemoryLayout<Int32>.size)
        getsockopt(fileDescriptor, SOCK_STREAM, LOCAL_PEERPID, pidPointer, &len)
        return pidPointer.load(as: Int32.self)
    }

    private static var messageBuffers = [Int32: SSHMessageBuffer]()
    private static let messageBuffersLock = NSLock()
    public func appendAndParseMessage(from newData: Data) -> Data? {
        let fd = self.fileDescriptor
        FileHandle.messageBuffersLock.lock()
        let buffer = FileHandle.messageBuffers[fd] ?? SSHMessageBuffer()
        FileHandle.messageBuffers[fd] = buffer
        FileHandle.messageBuffersLock.unlock()
        buffer.append(newData)
        return buffer.nextMessage()
    }
}
