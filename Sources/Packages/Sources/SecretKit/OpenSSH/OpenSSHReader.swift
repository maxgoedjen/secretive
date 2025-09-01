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
    public func readNextChunk(convertEndianness: Bool = true) throws -> Data {
        let littleEndianLength = try readNextBytes(as: UInt32.self)
        let length = convertEndianness ? Int(littleEndianLength.bigEndian) : Int(littleEndianLength)
        guard remaining.count >= length else { throw EndOfData() }
        let dataRange = 0..<length
        let ret = Data(remaining[dataRange])
        remaining.removeSubrange(dataRange)
        return ret
    }

    public func readNextBytes<T>(as: T.Type) throws -> T {
        let size = MemoryLayout<T>.size
        guard remaining.count >= size else { throw EndOfData() }
        let lengthRange = 0..<size
        let lengthChunk = remaining[lengthRange]
        remaining.removeSubrange(lengthRange)
        return lengthChunk.bytes.unsafeLoad(as: T.self)
    }


    public func readNextChunkAsString() throws -> String {
        try String(decoding: readNextChunk(), as: UTF8.self)
    }

    public struct EndOfData: Error {}

}
