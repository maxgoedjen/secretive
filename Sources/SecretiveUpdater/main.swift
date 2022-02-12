import Foundation

class ServiceDelegate: NSObject, NSXPCListenerDelegate {

    let exported: UpdaterProtocol

    init(exportedObject: UpdaterProtocol) {
        self.exported = exportedObject
    }

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        newConnection.exportedInterface = NSXPCInterface(with: UpdaterProtocol.self)
        newConnection.exportedObject = exported
        newConnection.resume()
        return true
    }

}

let updater = Updater()
let delegate = ServiceDelegate(exportedObject: Updater())
let listener = NSXPCListener.service()
listener.delegate = delegate
listener.resume()
