import Foundation
import Combine
import AppKit
import OSLog
import SecretKit
import SecretAgentKitProtocol

protocol AgentCommunicationControllerProtocol: ObservableObject {
    var agent: AgentProtocol? { get }
}

class AgentCommunicationController: ObservableObject, AgentCommunicationControllerProtocol {

    private(set) var agent: AgentProtocol? = nil
    private var connection: NSXPCConnection? = nil
    private var running = false

    init() {
    }

    func configure() {
        guard !running else { return }
        connection = NSXPCConnection(machServiceName: Bundle.main.agentBundleID)
        connection?.remoteObjectInterface = NSXPCInterface(with: AgentProtocol.self)
        connection?.invalidationHandler = {
            Logger().warning("XPC connection invalidated")
        }
        connection?.resume()
        agent = connection?.remoteObjectProxyWithErrorHandler({ error in
            Logger().error("\(String(describing: error))")
        }) as! AgentProtocol
        running = true
    }

}


