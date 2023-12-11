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
    public func readNextChunk() -> Data {
        let lengthRange = 0..<(UInt32.bitWidth/8)
        let lengthChunk = remaining[lengthRange]
        remaining.removeSubrange(lengthRange)
        let littleEndianLength = lengthChunk.withUnsafeBytes { pointer in
            return pointer.load(as: UInt32.self)
        }
        let length = Int(littleEndianLength.bigEndian)
        let dataRange = 0..<length
        let ret = Data(remaining[dataRange])
        remaining.removeSubrange(dataRange)
        return ret
    }

}
