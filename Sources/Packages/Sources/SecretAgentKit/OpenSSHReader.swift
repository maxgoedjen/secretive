import Foundation

/// Reads OpenSSH protocol data.
final class OpenSSHReader {

    var remaining: Data

    /// Initialize the reader with an OpenSSH data payload.
    /// - Parameter data: The data to read.
    init(data: Data) {
        remaining = Data(data)
    }

    /// Reads the next chunk of data from the playload.
    /// - Returns: The next chunk of data.
    func readNextChunk(convertEndianness: Bool = true) throws(OpenSSHReaderError) -> Data {
        let littleEndianLength = try readNextBytes(as: UInt32.self)
        let length = convertEndianness ? Int(littleEndianLength.bigEndian) : Int(littleEndianLength)
        guard remaining.count >= length else { throw .beyondBounds }
        let dataRange = 0..<length
        let ret = Data(remaining[dataRange])
        remaining.removeSubrange(dataRange)
        return ret
    }

    func readNextBytes<T>(as: T.Type) throws(OpenSSHReaderError) -> T {
        let size = MemoryLayout<T>.size
        guard remaining.count >= size else { throw .beyondBounds }
        let lengthRange = 0..<size
        let lengthChunk = remaining[lengthRange]
        remaining.removeSubrange(lengthRange)
        return lengthChunk.bytes.unsafeLoad(as: T.self)
    }


    func readNextChunkAsString() throws -> String {
        try String(decoding: readNextChunk(), as: UTF8.self)
    }

}

public enum OpenSSHReaderError: Error, Codable {
    case beyondBounds
}
