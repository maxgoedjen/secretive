import Foundation

extension Data {

    /// Creates an OpenSSH protocol style data object, which has a length header, followed by the data payload.
    /// - Returns: OpenSSH data.
    package var lengthAndData: Data {
        let rawLength = UInt32(count)
        var endian = rawLength.bigEndian
        return Data(bytes: &endian, count: UInt32.bitWidth/8) + self
    }

}

extension String {

    /// Creates an OpenSSH protocol style data object, which has a length header, followed by the data payload.
    /// - Returns: OpenSSH data.
    package var lengthAndData: Data {
        Data(utf8).lengthAndData
    }

}
