import Foundation
import SecretKit
import UserNotifications
import AppKit

class Notifier {

    func prompt() {
        let notificationCenter = UNUserNotificationCenter.current()
        notificationCenter.requestAuthorization(options: .alert) { _, _ in
        }
    }

    func notify<SecretType: Secret>(accessTo secret: SecretType, from caller: NSRunningApplication) {
        let notificationCenter = UNUserNotificationCenter.current()
        let notificationContent = UNMutableNotificationContent()
        notificationContent.title = "Signed Request"
        notificationContent.body = "\(secret.name) was used to sign a request from \(caller.localizedName!)."
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: notificationContent, trigger: nil)
        notificationCenter.add(request, withCompletionHandler: nil)
    }

}
