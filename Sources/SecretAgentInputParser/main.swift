import Foundation
import XPCWrappers

let delegate = XPCServiceDelegate(exportedObject: SecretAgentInputParser())
let listener = NSXPCListener.service()
listener.delegate = delegate
listener.resume()
