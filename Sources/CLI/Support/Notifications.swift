import Foundation

// MARK: - Distributed Notification Wrapper

/// Posts cross-process notifications so Secretive.app and SecretAgent.app
/// immediately reflect changes made by the CLI.
enum Notifications {
    /// Posts the `secretStoreUpdated` distributed notification.
    /// Call this after any key creation, deletion, rename, or attribute update.
    static func postSecretStoreUpdated() {
        DistributedNotificationCenter.default().postNotificationName(
            .secretStoreUpdated,
            object: UUID().uuidString,
            deliverImmediately: true,
        )
    }

    /// Posts the `certificateStoreUpdated` distributed notification.
    /// Call this after importing or deleting a certificate.
    static func postCertificateStoreUpdated() {
        DistributedNotificationCenter.default().postNotificationName(
            .certificateStoreUpdated,
            object: UUID().uuidString,
            deliverImmediately: true,
        )
    }
}
