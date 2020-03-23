import SecretAgentKit
import AppKit

struct StubFileHandleReader: FileHandleReader {

    let availableData: Data
    var fileDescriptor: Int32 {
        NSWorkspace.shared.runningApplications.filter({ $0.localizedName == "Xcode" }).first!.processIdentifier
    }
    var pidOfConnectedProcess: Int32 {
        NSWorkspace.shared.runningApplications.filter({ $0.localizedName == "Xcode" }).first!.processIdentifier
    }

}
