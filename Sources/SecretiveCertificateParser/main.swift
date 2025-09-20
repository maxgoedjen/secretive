import Foundation
import XPCWrappers

let delegate = XPCServiceDelegate(exportedObject: SecretiveCertificateParser())
let listener = NSXPCListener.service()
listener.delegate = delegate
listener.resume()
