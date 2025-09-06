import Foundation

extension FileHandle {

    public var pidOfConnectedProcess: Int32 {
        let pidPointer = UnsafeMutableRawPointer.allocate(byteCount: MemoryLayout<Int32>.size, alignment: 1)
        var len = socklen_t(MemoryLayout<Int32>.size)
        getsockopt(fileDescriptor, SOCK_STREAM, LOCAL_PEERPID, pidPointer, &len)
        return pidPointer.load(as: Int32.self)
    }

}
