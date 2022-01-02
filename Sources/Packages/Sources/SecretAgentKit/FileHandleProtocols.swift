import Foundation

public protocol FileHandleReader {

    var availableData: Data { get }
    var fileDescriptor: Int32 { get }
    var pidOfConnectedProcess: Int32 { get }

}

public protocol FileHandleWriter {

    func write(_ data: Data)

}

extension FileHandle: FileHandleReader, FileHandleWriter {

    public var pidOfConnectedProcess: Int32 {
        let pidPointer = UnsafeMutableRawPointer.allocate(byteCount: 4, alignment: 1)
        var len = socklen_t(MemoryLayout<Int32>.size)
        getsockopt(fileDescriptor, SOCK_STREAM, LOCAL_PEERPID, pidPointer, &len)
        return pidPointer.load(as: Int32.self)
    }

}
