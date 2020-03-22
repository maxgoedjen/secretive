import SecretAgentKit
import AppKit

struct StubFileHandleReader: FileHandleReader {

    let availableData: Data
    var fileDescriptor: Int32 {
        return NSRunningApplication.current.processIdentifier
    }

}
