import Foundation
import SecretKit
import UserNotifications

class Notifier {

    func prompt() {
        let notificationCenter = UNUserNotificationCenter.current()
        notificationCenter.requestAuthorization(options: .alert) { _, _ in
        }
    }

    func notify<SecretType: Secret>(accessTo secret: SecretType) {
        let notificationCenter = UNUserNotificationCenter.current()
        let notificationContent = UNMutableNotificationContent()
        notificationContent.title = "Signed Request"
        notificationContent.body = "\(secret.name) was used to sign a request."
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: notificationContent, trigger: nil)
        notificationCenter.add(request, withCompletionHandler: nil)
    }

}
