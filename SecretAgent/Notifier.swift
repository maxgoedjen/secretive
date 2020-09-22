import Foundation
import UserNotifications
import AppKit
import SecretKit
import SecretAgentKit
import Brief

class Notifier {

    private let notificationDelegate = NotificationDelegate()

    init() {
        let updateAction = UNNotificationAction(identifier: Constants.updateActionIdentitifier, title: "Update", options: [])
        let ignoreAction = UNNotificationAction(identifier: Constants.ignoreActionIdentitifier, title: "Ignore", options: [])
        let updateCategory = UNNotificationCategory(identifier: Constants.updateCategoryIdentitifier, actions: [updateAction, ignoreAction], intentIdentifiers: [], options: [])
        let criticalUpdateCategory = UNNotificationCategory(identifier: Constants.criticalUpdateCategoryIdentitifier, actions: [updateAction], intentIdentifiers: [], options: [])
        UNUserNotificationCenter.current().setNotificationCategories([updateCategory, criticalUpdateCategory])
        UNUserNotificationCenter.current().delegate = notificationDelegate
    }

    func prompt() {
        let notificationCenter = UNUserNotificationCenter.current()
        notificationCenter.requestAuthorization(options: .alert) { _, _ in }
    }

    func notify(accessTo secret: AnySecret, by provenance: SigningRequestProvenance) {
        let notificationCenter = UNUserNotificationCenter.current()
        let notificationContent = UNMutableNotificationContent()
        notificationContent.title = "Signed Request from \(provenance.origin.name)"
        notificationContent.subtitle = "Using secret \"\(secret.name)\""
        if let iconURL = iconURL(for: provenance), let attachment = try? UNNotificationAttachment(identifier: "icon", url: iconURL, options: nil) {
            notificationContent.attachments = [attachment]
        }
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: notificationContent, trigger: nil)
        notificationCenter.add(request, withCompletionHandler: nil)
    }

    func notify(update: Release, ignore: ((Release) -> Void)?) {
        notificationDelegate.release = update
        notificationDelegate.ignore = ignore
        let notificationCenter = UNUserNotificationCenter.current()
        let notificationContent = UNMutableNotificationContent()
        if update.critical {
            notificationContent.title = "Critical Security Update - \(update.name)"
        } else {
            notificationContent.title = "Update Available - \(update.name)"
        }
        notificationContent.subtitle = "Click to Update"
        notificationContent.body = update.body
        notificationContent.categoryIdentifier = update.critical ? Constants.criticalUpdateCategoryIdentitifier : Constants.updateCategoryIdentitifier
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: notificationContent, trigger: nil)
        notificationCenter.add(request, withCompletionHandler: nil)
    }

}

extension Notifier {

    func iconURL(for provenance: SigningRequestProvenance) -> URL? {
        do {
            if let app = NSRunningApplication(processIdentifier: provenance.origin.pid), let icon = app.icon?.tiffRepresentation {
                let temporaryURL = URL(fileURLWithPath: (NSTemporaryDirectory() as NSString).appendingPathComponent("\(UUID().uuidString).png"))
                let bitmap = NSBitmapImageRep(data: icon)
                try bitmap?.representation(using: .png, properties: [:])?.write(to: temporaryURL)
                return temporaryURL
            }
        } catch {
        }
        return nil
    }

}

extension Notifier: SigningWitness {

    func speakNowOrForeverHoldYourPeace(forAccessTo secret: AnySecret, by provenance: SigningRequestProvenance) throws {
    }

    func witness(accessTo secret: AnySecret, by provenance: SigningRequestProvenance) throws {
        notify(accessTo: secret, by: provenance)
    }

}

extension Notifier {

    enum Constants {
        static let updateCategoryIdentitifier  = "com.maxgoedjen.Secretive.SecretAgent.update"
        static let criticalUpdateCategoryIdentitifier  = "com.maxgoedjen.Secretive.SecretAgent.update.critical"
        static let updateActionIdentitifier  = "com.maxgoedjen.Secretive.SecretAgent.update.updateaction"
        static let ignoreActionIdentitifier  = "com.maxgoedjen.Secretive.SecretAgent.update.ignoreaction"
    }

}

class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {

    fileprivate var release: Release?
    fileprivate var ignore: ((Release) -> Void)?

    func userNotificationCenter(_ center: UNUserNotificationCenter, openSettingsFor notification: UNNotification?) {

    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        guard let update = release else { return }
        switch response.actionIdentifier {
        case Notifier.Constants.updateActionIdentitifier, UNNotificationDefaultActionIdentifier:
            NSWorkspace.shared.open(update.html_url)
        case Notifier.Constants.ignoreActionIdentitifier:
            ignore?(update)
        default:
            fatalError()
        }
        completionHandler()
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.list, .banner])
    }

}
