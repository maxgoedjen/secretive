import Foundation
import UserNotifications
import AppKit
import SecretKit
import SecretAgentKit
import Brief
import os

final class Notifier: Sendable {

    private let notificationDelegate = NotificationDelegate()

    init() {
        let updateAction = UNNotificationAction(identifier: Constants.updateActionIdentitifier, title: String(localized: "update_notification_update_button"), options: [])
        let ignoreAction = UNNotificationAction(identifier: Constants.ignoreActionIdentitifier, title: String(localized: "update_notification_ignore_button"), options: [])
        let updateCategory = UNNotificationCategory(identifier: Constants.updateCategoryIdentitifier, actions: [updateAction, ignoreAction], intentIdentifiers: [], options: [])
        let criticalUpdateCategory = UNNotificationCategory(identifier: Constants.criticalUpdateCategoryIdentitifier, actions: [updateAction], intentIdentifiers: [], options: [])

        let rawDurations = [
            Measurement(value: 1, unit: UnitDuration.minutes),
            Measurement(value: 5, unit: UnitDuration.minutes),
            Measurement(value: 1, unit: UnitDuration.hours),
            Measurement(value: 24, unit: UnitDuration.hours)
        ]

        let doNotPersistAction = UNNotificationAction(identifier: Constants.doNotPersistActionIdentitifier, title: String(localized: "persist_authentication_decline_button"), options: [])
        var allPersistenceActions = [doNotPersistAction]

        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .spellOut
        formatter.allowedUnits = [.hour, .minute, .day]

        for duration in rawDurations {
            let seconds = duration.converted(to: .seconds).value
            guard let string = formatter.string(from: seconds)?.capitalized else { continue }
            let identifier = Constants.persistAuthenticationCategoryIdentitifier.appending("\(seconds)")
            let action = UNNotificationAction(identifier: identifier, title: string, options: [])
            notificationDelegate.state.withLock { state in
                state.persistOptions[identifier] = seconds
            }
            allPersistenceActions.append(action)
        }

        let persistAuthenticationCategory = UNNotificationCategory(identifier: Constants.persistAuthenticationCategoryIdentitifier, actions: allPersistenceActions, intentIdentifiers: [], options: [])
        if persistAuthenticationCategory.responds(to: Selector(("actionsMenuTitle"))) {
            persistAuthenticationCategory.setValue(String(localized: "persist_authentication_accept_button"), forKey: "_actionsMenuTitle")
        }
        UNUserNotificationCenter.current().setNotificationCategories([updateCategory, criticalUpdateCategory, persistAuthenticationCategory])
        UNUserNotificationCenter.current().delegate = notificationDelegate

        notificationDelegate.state.withLock { state in
            state.persistAuthentication = { secret, store, duration in
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
        notificationDelegate.state.withLock { state in
            state.pendingPersistableSecrets[secret.id.description] = secret
            state.pendingPersistableStores[store.id.description] = store
        }
        let notificationCenter = UNUserNotificationCenter.current()
        let notificationContent = UNMutableNotificationContent()
        notificationContent.title = String(localized: "signed_notification_title_\(provenance.origin.displayName)")
        notificationContent.subtitle = String(localized: "signed_notification_description_\(secret.name)")
        notificationContent.userInfo[Constants.persistSecretIDKey] = secret.id.description
        notificationContent.userInfo[Constants.persistStoreIDKey] = store.id.description
        notificationContent.interruptionLevel = .timeSensitive
        if await store.existingPersistedAuthenticationContext(secret: secret) == nil && secret.requiresAuthentication {
            notificationContent.categoryIdentifier = Constants.persistAuthenticationCategoryIdentitifier
        }
        if let iconURL = provenance.origin.iconURL, let attachment = try? UNNotificationAttachment(identifier: "icon", url: iconURL, options: nil) {
            notificationContent.attachments = [attachment]
        }
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: notificationContent, trigger: nil)
        try? await notificationCenter.add(request)
    }

    func notify(update: Release, ignore: (@Sendable (Release) -> Void)?) {
        notificationDelegate.state.withLock { [update] state in
            state.release = update
            state.ignore = ignore
        }
        let notificationCenter = UNUserNotificationCenter.current()
        let notificationContent = UNMutableNotificationContent()
        if update.critical {
            notificationContent.interruptionLevel = .critical
            notificationContent.title = String(localized: "update_notification_update_critical_title_\(update.name)")
        } else {
            notificationContent.title = String(localized: "update_notification_update_normal_title_\(update.name)")
        }
        notificationContent.subtitle = String(localized: "update_notification_update_description")
        notificationContent.body = update.body
        notificationContent.categoryIdentifier = update.critical ? Constants.criticalUpdateCategoryIdentitifier : Constants.updateCategoryIdentitifier
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: notificationContent, trigger: nil)
        notificationCenter.add(request, withCompletionHandler: nil)
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

final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate, Sendable {

    struct State {
        typealias PersistAuthentication = (@Sendable (AnySecret, AnySecretStore, TimeInterval?) async -> Void)
        typealias Ignore = ((Release) -> Void)
        fileprivate var release: Release?
        fileprivate var ignore: Ignore?
        fileprivate var persistAuthentication: PersistAuthentication?
        fileprivate var persistOptions: [String: TimeInterval] = [:]
        fileprivate var pendingPersistableStores: [String: AnySecretStore] = [:]
        fileprivate var pendingPersistableSecrets: [String: AnySecret] = [:]
    }

    fileprivate let state: OSAllocatedUnfairLock<State> = .init(uncheckedState: .init())

    func userNotificationCenter(_ center: UNUserNotificationCenter, openSettingsFor notification: UNNotification?) {

    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let category = response.notification.request.content.categoryIdentifier
        switch category {
        case Notifier.Constants.updateCategoryIdentitifier:
            handleUpdateResponse(response: response)
        case Notifier.Constants.persistAuthenticationCategoryIdentitifier:
            await handlePersistAuthenticationResponse(response: response)
        default:
            break
        }
    }

    func handleUpdateResponse(response: UNNotificationResponse) {
        let id = response.actionIdentifier
        state.withLock { state in
            guard let update = state.release else { return }
            switch id {
            case Notifier.Constants.updateActionIdentitifier, UNNotificationDefaultActionIdentifier:
                NSWorkspace.shared.open(update.html_url)
            case Notifier.Constants.ignoreActionIdentitifier:
                state.ignore?(update)
            default:
                fatalError()
            }
        }
    }

    func handlePersistAuthenticationResponse(response: UNNotificationResponse) async {
        guard let secretID = response.notification.request.content.userInfo[Notifier.Constants.persistSecretIDKey] as? String,
              let storeID = response.notification.request.content.userInfo[Notifier.Constants.persistStoreIDKey] as? String else {
            return
        }
        let id = response.actionIdentifier

        let (secret, store, persistOptions, callback): (AnySecret?, AnySecretStore?, TimeInterval?, State.PersistAuthentication?) = state.withLock { state in
            guard let secret = state.pendingPersistableSecrets[secretID],
                let store = state.pendingPersistableStores[storeID]
            else { return (nil, nil, nil, nil) }
            state.pendingPersistableSecrets[secretID] = nil
            return (secret, store, state.persistOptions[id], state.persistAuthentication)
        }
        guard let secret, let store, let persistOptions else { return }
        await callback?(secret, store, persistOptions)
    }


    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.list, .banner]
    }

}

