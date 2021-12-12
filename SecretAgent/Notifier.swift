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

        let rawDurations = [
            Measurement(value: 1, unit: UnitDuration.minutes),
            Measurement(value: 5, unit: UnitDuration.minutes),
            Measurement(value: 1, unit: UnitDuration.hours),
            Measurement(value: 24, unit: UnitDuration.hours)
        ]

        let doNotPersistAction = UNNotificationAction(identifier: Constants.doNotPersistActionIdentitifier, title: "Do Not Unlock", options: [])
        var allPersistenceActions = [doNotPersistAction]

        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .spellOut
        formatter.allowedUnits = [.hour, .minute, .day]

        for duration in rawDurations {
            let seconds = duration.converted(to: .seconds).value
            guard let string = formatter.string(from: seconds)?.capitalized else { continue }
            let identifier = Constants.persistAuthenticationCategoryIdentitifier.appending("\(seconds)")
            let action = UNNotificationAction(identifier: identifier, title: string, options: [])
            notificationDelegate.persistOptions[identifier] = seconds
            allPersistenceActions.append(action)
        }

        let persistAuthenticationCategory = UNNotificationCategory(identifier: Constants.persistAuthenticationCategoryIdentitifier, actions: allPersistenceActions, intentIdentifiers: [], options: [])
        if persistAuthenticationCategory.responds(to: Selector(("actionsMenuTitle"))) {
            persistAuthenticationCategory.setValue("Leave Unlocked", forKey: "_actionsMenuTitle")
        }
        UNUserNotificationCenter.current().setNotificationCategories([updateCategory, criticalUpdateCategory, persistAuthenticationCategory])
        UNUserNotificationCenter.current().delegate = notificationDelegate

        notificationDelegate.persistAuthentication = { secret, store, duration in
            guard let duration = duration else { return }
            try? store.persistAuthentication(secret: secret, forDuration: duration)
        }

    }

    func prompt() {
        let notificationCenter = UNUserNotificationCenter.current()
        notificationCenter.requestAuthorization(options: .alert) { _, _ in }
    }

    func notify(accessTo secret: AnySecret, from store: AnySecretStore, by provenance: SigningRequestProvenance, requiredAuthentication: Bool) {
        notificationDelegate.pendingPersistableSecrets[secret.id.description] = secret
        notificationDelegate.pendingPersistableStores[store.id.description] = store
        let notificationCenter = UNUserNotificationCenter.current()
        let notificationContent = UNMutableNotificationContent()
        notificationContent.title = "Signed Request from \(provenance.origin.displayName)"
        notificationContent.subtitle = "Using secret \"\(secret.name)\""
        notificationContent.userInfo[Constants.persistSecretIDKey] = secret.id.description
        notificationContent.userInfo[Constants.persistStoreIDKey] = store.id.description
        if #available(macOS 12.0, *) {
            notificationContent.interruptionLevel = .timeSensitive
        }
        if requiredAuthentication {
            notificationContent.categoryIdentifier = Constants.persistAuthenticationCategoryIdentitifier
        }
        if let iconURL = provenance.origin.iconURL, let attachment = try? UNNotificationAttachment(identifier: "icon", url: iconURL, options: nil) {
            notificationContent.attachments = [attachment]
        }
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: notificationContent, trigger: nil)
        notificationCenter.add(request, withCompletionHandler: nil)
    }

    func notify(update: Release, ignore: (@MainActor (Release) -> Void)?) {
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

    func speakNowOrForeverHoldYourPeace(forAccessTo secret: AnySecret, from store: AnySecretStore, by provenance: SigningRequestProvenance) throws {
    }

    func witness(accessTo secret: AnySecret, from store: AnySecretStore, by provenance: SigningRequestProvenance, requiredAuthentication: Bool) throws {
        notify(accessTo: secret, from: store, by: provenance, requiredAuthentication: requiredAuthentication)
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
        static let persistForActionIdentitifierPrefix  = "com.maxgoedjen.Secretive.SecretAgent.persistauthentication.persist."

        static let persistSecretIDKey  = "com.maxgoedjen.Secretive.SecretAgent.persistauthentication.secretidkey"
        static let persistStoreIDKey  = "com.maxgoedjen.Secretive.SecretAgent.persistauthentication.storeidkey"
    }

}

class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {

    fileprivate var release: Release?
    fileprivate var ignore: (@MainActor (Release) -> Void)?
    fileprivate var persistAuthentication: ((AnySecret, AnySecretStore, TimeInterval?) -> Void)?
    fileprivate var persistOptions: [String: TimeInterval] = [:]
    fileprivate var pendingPersistableStores: [String: AnySecretStore] = [:]
    fileprivate var pendingPersistableSecrets: [String: AnySecret] = [:]

    func userNotificationCenter(_ center: UNUserNotificationCenter, openSettingsFor notification: UNNotification?) {

    }

    @MainActor func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let category = response.notification.request.content.categoryIdentifier
        switch category {
        case Notifier.Constants.updateCategoryIdentitifier:
            handleUpdateResponse(response: response)
        case Notifier.Constants.persistAuthenticationCategoryIdentitifier:
            handlePersistAuthenticationResponse(response: response)
        default:
            fatalError()
        }

        completionHandler()
    }

    @MainActor func handleUpdateResponse(response: UNNotificationResponse) {
        guard let update = release else { return }
        switch response.actionIdentifier {
        case Notifier.Constants.updateActionIdentitifier, UNNotificationDefaultActionIdentifier:
            NSWorkspace.shared.open(update.html_url)
        case Notifier.Constants.ignoreActionIdentitifier:
            ignore?(update)
        default:
            fatalError()
        }
    }

    func handlePersistAuthenticationResponse(response: UNNotificationResponse) {
        guard let secretID = response.notification.request.content.userInfo[Notifier.Constants.persistSecretIDKey] as? String, let secret = pendingPersistableSecrets[secretID],
              let storeID = response.notification.request.content.userInfo[Notifier.Constants.persistStoreIDKey] as? String, let store = pendingPersistableStores[storeID]
        else { return }
        pendingPersistableSecrets[secretID] = nil
        persistAuthentication?(secret, store, persistOptions[response.actionIdentifier])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.list, .banner])
    }

}
