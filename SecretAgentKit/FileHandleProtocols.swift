import Foundation

public protocol FileHandleReader {

    var availableData: Data { get }
    var fileDescriptor: Int32 { get }

}

public protocol FileHandleWriter {

    func write(_ data: Data)

}

extension FileHandle: FileHandleReader, FileHandleWriter {}
