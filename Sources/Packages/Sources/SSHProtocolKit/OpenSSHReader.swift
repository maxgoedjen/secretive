import Foundation

/// Reads OpenSSH protocol data.
final class OpenSSHReader {

    var remaining: Data
    var done = false

    /// Initialize the reader with an OpenSSH data payload.
    /// - Parameter data: The data to read.
    init(data: Data) {
        remaining = Data(data)
    }

    /// Reads the next chunk of data from the playload.
    /// - Returns: The next chunk of data.
    func readNextChunk(convertEndianness: Bool = true) throws(OpenSSHReaderError) -> Data {
        let length = try readNextBytes(as: UInt32.self, convertEndianness: convertEndianness)
        guard remaining.count >= length else { throw .beyondBounds }
        let dataRange = 0..<Int(length)
        let ret = Data(remaining[dataRange])
        remaining.removeSubrange(dataRange)
        if remaining.isEmpty {
            done = true
        }
        return ret
    }

    func readNextBytes<T: FixedWidthInteger>(as: T.Type, convertEndianness: Bool = true) throws(OpenSSHReaderError) -> T {
        let size = MemoryLayout<T>.size
        guard remaining.count >= size else { throw .beyondBounds }
        let lengthRange = 0..<size
        let lengthChunk = remaining[lengthRange]
        remaining.removeSubrange(lengthRange)
        if remaining.isEmpty {
            done = true
        }
        let value = unsafe lengthChunk.bytes.unsafeLoad(as: T.self)
        return convertEndianness ? T(value.bigEndian) : T(value)
    }

    func readNextChunkAsString(convertEndianness: Bool = true) throws(OpenSSHReaderError) -> String {
        try String(decoding: readNextChunk(convertEndianness: convertEndianness), as: UTF8.self)
    }

    func readNextChunkAsSubReader(convertEndianness: Bool = true) throws(OpenSSHReaderError) -> OpenSSHReader {
        OpenSSHReader(data: try readNextChunk(convertEndianness: convertEndianness))
    }

}

public enum OpenSSHReaderError: Error, Codable {
    case beyondBounds
}
