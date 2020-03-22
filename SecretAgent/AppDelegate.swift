import Cocoa
import OSLog
import Combine
import SecretKit
import SecretAgentKit
import Brief

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    let storeList: SecretStoreList = {
        let list = SecretStoreList()
        list.add(store: SecureEnclave.Store())
        list.add(store: SmartCard.Store())
        return list
    }()
    let updater = Updater()
    let notifier = Notifier()
    lazy var agent: Agent = {
        Agent(storeList: storeList, witness: notifier)
    }()
    lazy var socketController: SocketController = {
        let path = (NSHomeDirectory() as NSString).appendingPathComponent("socket.ssh") as String
        return SocketController(path: path)
    }()
    fileprivate var updateSink: AnyCancellable?

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        os_log(.debug, "SecretAgent finished launching")
        DispatchQueue.main.async {
            self.socketController.handler = self.agent.handle(fileHandle:)
        }
        notifier.prompt()
        updateSink = updater.$update.sink { release in
            guard let release = release else { return }
            self.notifier.notify(update: release)
        }
    }


}

