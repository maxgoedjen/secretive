import Foundation
import SecretAgentKit

class StubFileHandleWriter: FileHandleWriter, @unchecked Sendable {

    var data = Data()

    func write(_ data: Data) {
        self.data.append(data)
    }

}
