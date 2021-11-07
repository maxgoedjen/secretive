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

        let persistForOneMinuteAction = UNNotificationAction(identifier: Constants.persistForOneMinuteActionIdentitifier, title: "1 Minute", options: [])
        let persistForFiveMinutesAction = UNNotificationAction(identifier: Constants.persistForFiveMinutesActionIdentitifier, title: "5 Minutes", options: [])
        let persistForOneHourAction = UNNotificationAction(identifier: Constants.persistForOneHourActionIdentitifier, title: "1 Hour", options: [])
        let persistForOneDayAction = UNNotificationAction(identifier: Constants.persistForOneDayActionIdentitifier, title: "1 Day", options: [])

        let persistAuthenticationCategory = UNNotificationCategory(identifier: Constants.persistAuthenticationCategoryIdentitifier, actions: [persistForOneMinuteAction, persistForFiveMinutesAction, persistForOneHourAction, persistForOneDayAction], intentIdentifiers: [], options: [])
        UNUserNotificationCenter.current().setNotificationCategories([updateCategory, criticalUpdateCategory, persistAuthenticationCategory])
        UNUserNotificationCenter.current().delegate = notificationDelegate
    }

    func prompt() {
        let notificationCenter = UNUserNotificationCenter.current()
        notificationCenter.requestAuthorization(options: .alert) { _, _ in }
    }

    func notify(accessTo secret: AnySecret, by provenance: SigningRequestProvenance, promptToPersist: Bool) {
        let notificationCenter = UNUserNotificationCenter.current()
        let notificationContent = UNMutableNotificationContent()
        notificationContent.title = "Signed Request from \(provenance.origin.displayName)"
        notificationContent.subtitle = "Using secret \"\(secret.name)\""
        if #available(macOS 12.0, *) {
            notificationContent.interruptionLevel = .timeSensitive
        }
        notificationContent.categoryIdentifier = Constants.persistAuthenticationCategoryIdentitifier
        if let iconURL = provenance.origin.iconURL, let attachment = try? UNNotificationAttachment(identifier: "icon", url: iconURL, options: nil) {
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
            if #available(macOS 12.0, *) {
                notificationContent.interruptionLevel = .critical
            }
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

extension Notifier: SigningWitness {

    func speakNowOrForeverHoldYourPeace(forAccessTo secret: AnySecret, by provenance: SigningRequestProvenance) throws {
    }

    func witness(accessTo secret: AnySecret, by provenance: SigningRequestProvenance) throws {
        notify(accessTo: secret, by: provenance, promptToPersist: false)
    }

}

extension Notifier {

    enum Constants {

        // Update notifications
        static let updateCategoryIdentitifier  = "com.maxgoedjen.Secretive.SecretAgent.update"
        static let criticalUpdateCategoryIdentitifier  = "com.maxgoedjen.Secretive.SecretAgent.update.critical"
        static let updateActionIdentitifier  = "com.maxgoedjen.Secretive.SecretAgent.update.updateaction"
        static let ignoreActionIdentitifier  = "com.maxgoedjen.Secretive.SecretAgent.update.ignoreaction"

        // Authorization persistence notificatoins
        static let persistAuthenticationCategoryIdentitifier  = "com.maxgoedjen.Secretive.SecretAgent.persistauthentication"
        static let doNotPersistActionIdentitifier  = "com.maxgoedjen.Secretive.SecretAgent.persistauthentication.donotpersist"
        static let persistForOneMinuteActionIdentitifier  = "com.maxgoedjen.Secretive.SecretAgent.persistauthentication.persist1m"
        static let persistForFiveMinutesActionIdentitifier  = "com.maxgoedjen.Secretive.SecretAgent.persistauthentication.persist5m"
        static let persistForOneHourActionIdentitifier  = "com.maxgoedjen.Secretive.SecretAgent.persistauthentication.persist1h"
        static let persistForOneDayActionIdentitifier  = "com.maxgoedjen.Secretive.SecretAgent.persistauthentication.persist1d"
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
