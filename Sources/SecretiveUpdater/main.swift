import Foundation
import XPCWrappers

let delegate = XPCServiceDelegate(exportedObject: SecretiveUpdater())
let listener = NSXPCListener.service()
listener.delegate = delegate
listener.resume()
