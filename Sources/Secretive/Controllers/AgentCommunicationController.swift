import Foundation
import Combine
import AppKit
import SecretKit
import SecretAgentKitProtocol

protocol AgentCommunicationControllerProtocol: ObservableObject {
    var agent: AgentProtocol { get }
}

class AgentCommunicationController: ObservableObject, AgentCommunicationControllerProtocol {

    let agent: AgentProtocol
    private let connection: NSXPCConnection
    private var running = false

    init() {
        connection = NSXPCConnection(machServiceName: Bundle.main.agentBundleID)
        connection.remoteObjectInterface = NSXPCInterface(with: AgentProtocol.self)
        connection.invalidationHandler = {
            print("INVALID")
        }
        agent = connection.remoteObjectProxyWithErrorHandler({ x in
            print(x)
        }) as! AgentProtocol
    }

    func configure() {
        guard !running else { return }
        running = true
        connection.resume()
    }

}


