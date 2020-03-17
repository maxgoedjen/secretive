import Foundation
import SecretKit
import SecretAgentKit
import UserNotifications

class Notifier {

    func prompt() {
        let notificationCenter = UNUserNotificationCenter.current()
        notificationCenter.requestAuthorization(options: .alert) { _, _ in
        }
    }

    func notify(accessTo secret: AnySecret) {
        let notificationCenter = UNUserNotificationCenter.current()
        let notificationContent = UNMutableNotificationContent()
        notificationContent.title = "Signed Request"
        notificationContent.body = "\(secret.name) was used to sign a request."
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: notificationContent, trigger: nil)
        notificationCenter.add(request, withCompletionHandler: nil)
    }

}

extension Notifier: SigningWitness {

    func witness(accessTo secret: AnySecret) throws {
        notify(accessTo: secret)
    }

}
