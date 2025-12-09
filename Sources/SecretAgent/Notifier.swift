import Foundation
import UserNotifications
import AppKit
import SecretKit
import SecretAgentKit
import Brief

final class Notifier: Sendable {

    private let notificationDelegate = NotificationDelegate()

    init() {
        let updateAction = UNNotificationAction(identifier: Constants.updateActionIdentitifier, title: String(localized: .updateNotificationUpdateButton), options: [])
        let ignoreAction = UNNotificationAction(identifier: Constants.ignoreActionIdentitifier, title: String(localized: .updateNotificationIgnoreButton), options: [])
        let updateCategory = UNNotificationCategory(identifier: Constants.updateCategoryIdentitifier, actions: [updateAction, ignoreAction], intentIdentifiers: [], options: [])
        let criticalUpdateCategory = UNNotificationCategory(identifier: Constants.criticalUpdateCategoryIdentitifier, actions: [updateAction], intentIdentifiers: [], options: [])

        let rawDurations = [
            Measurement(value: 1, unit: UnitDuration.minutes),
            Measurement(value: 5, unit: UnitDuration.minutes),
            Measurement(value: 1, unit: UnitDuration.hours),
            Measurement(value: 24, unit: UnitDuration.hours)
        ]

        let doNotPersistAction = UNNotificationAction(identifier: Constants.doNotPersistActionIdentitifier, title: String(localized: .persistAuthenticationDeclineButton), options: [])
        var allPersistenceActions = [doNotPersistAction]

        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .spellOut
        formatter.allowedUnits = [.hour, .minute, .day]

        var identifiers: [String: TimeInterval] = [:]
        for duration in rawDurations {
            let seconds = duration.converted(to: .seconds).value
            guard let string = formatter.string(from: seconds)?.capitalized else { continue }
            let identifier = Constants.persistAuthenticationCategoryIdentitifier.appending("\(seconds)")
            let action = UNNotificationAction(identifier: identifier, title: string, options: [])
            identifiers[identifier] = seconds
            allPersistenceActions.append(action)
        }

        let persistAuthenticationCategory = UNNotificationCategory(identifier: Constants.persistAuthenticationCategoryIdentitifier, actions: allPersistenceActions, intentIdentifiers: [], options: [])
        if persistAuthenticationCategory.responds(to: Selector(("actionsMenuTitle"))) {
            persistAuthenticationCategory.setValue(String(localized: .persistAuthenticationAcceptButton), forKey: "_actionsMenuTitle")
        }
        UNUserNotificationCenter.current().setNotificationCategories([updateCategory, criticalUpdateCategory, persistAuthenticationCategory])
        UNUserNotificationCenter.current().delegate = notificationDelegate

        Task {
            await notificationDelegate.state.setPersistenceState(options: identifiers) { secret, store, duration in
                guard let duration = duration else { return }
                try? await store.persistAuthentication(secret: secret, forDuration: duration)
            }
        }

    }

    func prompt() {
        let notificationCenter = UNUserNotificationCenter.current()
        notificationCenter.requestAuthorization(options: .alert) { _, _ in }
    }

    func notify(accessTo secret: AnySecret, from store: AnySecretStore, by provenance: SigningRequestProvenance) async {
        await notificationDelegate.state.setPending(secret: secret, store: store)
        let notificationCenter = UNUserNotificationCenter.current()
        let notificationContent = UNMutableNotificationContent()
        notificationContent.title = String(localized: .signedNotificationTitle(appName: provenance.origin.displayName))
        notificationContent.subtitle = String(localized: .signedNotificationDescription(secretName: secret.name))
        notificationContent.userInfo[Constants.persistSecretIDKey] = secret.id.description
        notificationContent.userInfo[Constants.persistStoreIDKey] = store.id.description
        notificationContent.interruptionLevel = .timeSensitive
        if await store.existingPersistedAuthenticationContext(secret: secret) == nil && secret.authenticationRequirement.required {
            notificationContent.categoryIdentifier = Constants.persistAuthenticationCategoryIdentitifier
        }
        if let iconURL = provenance.origin.iconURL, let attachment = try? UNNotificationAttachment(identifier: "icon", url: iconURL, options: nil) {
            notificationContent.attachments = [attachment]
        }
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: notificationContent, trigger: nil)
        try? await notificationCenter.add(request)
    }

    func notify(update: Release, ignore: (@Sendable (Release) async -> Void)?) async {
        await notificationDelegate.state.prepareForNotification(release: update, ignoreAction: ignore)
        let notificationCenter = UNUserNotificationCenter.current()
        let notificationContent = UNMutableNotificationContent()
        if update.critical {
            notificationContent.interruptionLevel = .critical
            notificationContent.title = String(localized: .updateNotificationUpdateCriticalTitle(updateName: update.name))
        } else {
            notificationContent.title = String(localized: .updateNotificationUpdateNormalTitle(updateName: update.name))
        }
        notificationContent.subtitle = String(localized: .updateNotificationUpdateDescription)
        notificationContent.body = update.body
        notificationContent.categoryIdentifier = update.critical ? Constants.criticalUpdateCategoryIdentitifier : Constants.updateCategoryIdentitifier
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: notificationContent, trigger: nil)
        try? await notificationCenter.add(request)
    }

}

extension Notifier: SigningWitness {

    func speakNowOrForeverHoldYourPeace(forAccessTo secret: AnySecret, from store: AnySecretStore, by provenance: SigningRequestProvenance) async throws {
    }

    func witness(accessTo secret: AnySecret, from store: AnySecretStore, by provenance: SigningRequestProvenance) async throws {
        await notify(accessTo: secret, from: store, by: provenance)
    }

}

extension Notifier {

    enum Constants {

        // Update notifications
        static let updateCategoryIdentitifier  = "com.cursorinternal.Secretive.SecretAgent.update"
        static let criticalUpdateCategoryIdentitifier  = "com.cursorinternal.Secretive.SecretAgent.update.critical"
        static let updateActionIdentitifier  = "com.cursorinternal.Secretive.SecretAgent.update.updateaction"
        static let ignoreActionIdentitifier  = "com.cursorinternal.Secretive.SecretAgent.update.ignoreaction"

        // Authorization persistence notificatoins
        static let persistAuthenticationCategoryIdentitifier  = "com.cursorinternal.Secretive.SecretAgent.persistauthentication"
        static let doNotPersistActionIdentitifier  = "com.cursorinternal.Secretive.SecretAgent.persistauthentication.donotpersist"
        static let persistForActionIdentitifierPrefix  = "com.cursorinternal.Secretive.SecretAgent.persistauthentication.persist."

        static let persistSecretIDKey  = "com.cursorinternal.Secretive.SecretAgent.persistauthentication.secretidkey"
        static let persistStoreIDKey  = "com.cursorinternal.Secretive.SecretAgent.persistauthentication.storeidkey"
    }

}

final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate, Sendable {

    fileprivate actor State {
        typealias PersistAction = (@Sendable (AnySecret, AnySecretStore, TimeInterval?) async -> Void)
        typealias IgnoreAction = (@Sendable (Release) async -> Void)
        fileprivate var release: Release?
        fileprivate var ignoreAction: IgnoreAction?
        fileprivate var persistAction: PersistAction?
        fileprivate var persistOptions: [String: TimeInterval] = [:]
        fileprivate var pendingPersistableStores: [String: AnySecretStore] = [:]
        fileprivate var pendingPersistableSecrets: [String: AnySecret] = [:]

        func setPending(secret: AnySecret, store: AnySecretStore) {
            pendingPersistableSecrets[secret.id.description] = secret
            pendingPersistableStores[store.id.description] = store
        }

        func retrievePending(secretID: String, storeID: String, optionID: String) -> (AnySecret, AnySecretStore, TimeInterval)? {
            guard let secret = pendingPersistableSecrets[secretID],
                  let store = pendingPersistableStores[storeID],
                  let options = persistOptions[optionID] else {
                return nil
            }
            pendingPersistableSecrets.removeValue(forKey: secretID)
            return (secret, store, options)
        }

        func setPersistenceState(options: [String: TimeInterval], action: @escaping PersistAction) {
            self.persistOptions = options
            self.persistAction = action
        }

        func prepareForNotification(release: Release, ignoreAction: IgnoreAction?) {
            self.release = release
            self.ignoreAction = ignoreAction
        }

        
    }

    fileprivate let state = State()

    func userNotificationCenter(_ center: UNUserNotificationCenter, openSettingsFor notification: UNNotification?) {

    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let category = response.notification.request.content.categoryIdentifier
        switch category {
        case Notifier.Constants.updateCategoryIdentitifier:
            await handleUpdateResponse(response: response)
        case Notifier.Constants.persistAuthenticationCategoryIdentitifier:
            await handlePersistAuthenticationResponse(response: response)
        default:
            break
        }
    }

    func handleUpdateResponse(response: UNNotificationResponse) async {
        let id = response.actionIdentifier
        guard let update = await state.release else { return }
        switch id {
        case Notifier.Constants.updateActionIdentitifier, UNNotificationDefaultActionIdentifier:
            NSWorkspace.shared.open(update.html_url)
        case Notifier.Constants.ignoreActionIdentitifier:
            await state.ignoreAction?(update)
        default:
            fatalError()
        }
    }

    func handlePersistAuthenticationResponse(response: UNNotificationResponse) async {
        guard let secretID = response.notification.request.content.userInfo[Notifier.Constants.persistSecretIDKey] as? String,
              let storeID = response.notification.request.content.userInfo[Notifier.Constants.persistStoreIDKey] as? String else {
            return
        }
        let optionID = response.actionIdentifier
        guard let (secret, store, persistOptions) = await state.retrievePending(secretID: secretID, storeID: storeID, optionID: optionID) else { return }
        await state.persistAction?(secret, store, persistOptions)
    }


    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.list, .banner]
    }

}

