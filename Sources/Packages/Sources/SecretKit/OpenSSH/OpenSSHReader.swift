import Foundation

/// Reads OpenSSH protocol data.
public final class OpenSSHReader {

    var remaining: Data

    /// Initialize the reader with an OpenSSH data payload.
    /// - Parameter data: The data to read.
    public init(data: Data) {
        remaining = Data(data)
    }

    /// Reads the next chunk of data from the playload.
    /// - Returns: The next chunk of data.
    public func readNextChunk() throws -> Data {
        guard remaining.count > UInt32.bitWidth/8 else { throw EndOfData() }
        let lengthRange = 0..<(UInt32.bitWidth/8)
        let lengthChunk = remaining[lengthRange]
        remaining.removeSubrange(lengthRange)
        let littleEndianLength = lengthChunk.bytes.unsafeLoad(as: UInt32.self)
        let length = Int(littleEndianLength.bigEndian)
        let dataRange = 0..<length
        let ret = Data(remaining[dataRange])
        remaining.removeSubrange(dataRange)
        return ret
    }

    public func readNextBytes<T>(count: Int = 0, as: T.Type) throws -> T {
        let lengthRange = 0..<count
        let lengthChunk = remaining[lengthRange]
        remaining.removeSubrange(lengthRange)
        return lengthChunk.bytes.unsafeLoad(as: T.self)
    }


    public func readNextChunkAsString() throws -> String {
        try String(decoding: readNextChunk(), as: UTF8.self)
    }

    public struct EndOfData: Error {}

}
