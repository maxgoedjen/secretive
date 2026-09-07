import Foundation
import XPCWrappers

let delegate = XPCServiceDelegate(exportedObject: SecretAgentHostsfileReader())
let listener = NSXPCListener.service()
listener.delegate = delegate
listener.resume()
