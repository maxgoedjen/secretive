import Foundation
import SecretKit

public class PublicKeyStandinFileStoreController {

    var files: [PublicKeyStandinFileController] = []

    public init(secrets: [AnySecret]) {
        let directory = NSHomeDirectory().appending("/PublicKeys")
        try? FileManager.default.removeItem(at: URL(fileURLWithPath: directory))
        try? FileManager.default.createDirectory(at: URL(fileURLWithPath: directory), withIntermediateDirectories: false, attributes: nil)
        // TODO: TEST
        files = secrets.filter({ $0.name == "Git Signature"})
        /*files = secrets*/.map { PublicKeyStandinFileController(secret: $0, path: directory.appending("/").appending("test") )}
        print("Done")
    }

    enum Constants {
        static var standinExtension = "secretive-public-key"
    }

}

public class PublicKeyStandinFileController {

    private var fileHandle: FileHandle?
    private let secret: AnySecret
    private let keyWriter = OpenSSHKeyWriter()

    public init(secret: AnySecret, path: String) {
        self.secret = secret
        resetHandle(path: path)
    }

    func resetHandle(path: String) {
        try? FileManager.default.removeItem(atPath: path)
        let fifo = mkfifo(UnsafePointer(Array(path.utf8CString)), S_IRWXU)
        assert(fifo == 0)
        fileHandle = nil
        fileHandle = FileHandle(forWritingAtPath: path)
        fileHandle?.writeabilityHandler = { [self] handle in
            try! handle.write(contentsOf: keyWriter.openSSHString(secret: secret).data(using: .utf8)!)
            try! fileHandle?.close()
//            self.resetHandle(path: path)
        }
    }
}
