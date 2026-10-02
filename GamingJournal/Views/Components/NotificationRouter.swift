#if os(macOS)
import AppKit
#else
import UIKit
#endif
import UserNotifications

/// Shows reminders even while the app is open, and opens a tapped reminder's link, which the
/// app handles like a widget's (`onOpenURL`).
final class NotificationRouter: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationRouter()

    func install() {
        UNUserNotificationCenter.current().delegate = self
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        guard let url = CampfireReminders.url(from: response.notification.request.content.userInfo) else { return }
        await MainActor.run {
            #if os(macOS)
            NSWorkspace.shared.open(url)
            #else
            UIApplication.shared.open(url)
            #endif
        }
    }
}
