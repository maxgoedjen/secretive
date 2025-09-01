import Foundation

extension Data {

    /// Creates an OpenSSH protocol style data object, which has a length header, followed by the data payload.
    /// - Returns: OpenSSH data.
    package var lengthAndData: Data {
        let rawLength = UInt32(count)
        var endian = rawLength.bigEndian
        return Data(bytes: &endian, count: MemoryLayout<UInt32>.size) + self
    }

}

extension String {

    /// Creates an OpenSSH protocol style data object, which has a length header, followed by the data payload.
    /// - Returns: OpenSSH data.
    package var lengthAndData: Data {
        Data(utf8).lengthAndData
    }

}
