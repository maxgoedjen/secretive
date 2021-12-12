import SecretAgentKit
import Foundation

class StubFileHandleWriter: FileHandleWriter {

    var data = Data()

    func write(_ data: Data) {
        self.data.append(data)
    }

}
