import Foundation
import SecretKit
import SecretAgentKit
import UserNotifications
import AppKit

class Notifier {

    func prompt() {
        let notificationCenter = UNUserNotificationCenter.current()
        notificationCenter.requestAuthorization(options: .alert) { _, _ in
        }
    }

    func notify(accessTo secret: AnySecret, by provenance: SigningRequestProvenance) {
        let notificationCenter = UNUserNotificationCenter.current()
        let notificationContent = UNMutableNotificationContent()
        notificationContent.title = "Signed Request from \(provenance.origin.name)"
        notificationContent.subtitle = secret.name
        if let iconURL = iconURL(for: provenance), let attachment = try? UNNotificationAttachment(identifier: "icon", url: iconURL, options: nil) {
            notificationContent.attachments = [attachment]
        }
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
