import Foundation
import UserNotifications

/// The notification centre calls reminders need, so tests can stand in for the system.
protocol ReminderScheduling: AnyObject {
    func askPermission() async -> Bool
    func schedule(_ request: UNNotificationRequest) async
    func cancel(_ identifiers: [String])
}

extension UNUserNotificationCenter: ReminderScheduling {
    func askPermission() async -> Bool {
        (try? await requestAuthorization(options: [.alert, .sound])) ?? false
    }

    func schedule(_ request: UNNotificationRequest) async {
        try? await add(request)
    }

    func cancel(_ identifiers: [String]) {
        removePendingNotificationRequests(withIdentifiers: identifiers)
    }
}

/// An optional nudge to write every evening at a chosen time. Off until turned on in Settings,
/// and permission is only asked for then.
final class CampfireReminders {
    static let eveningKey = "reminders.evening"
    /// Minutes after midnight.
    static let eveningTimeKey = "reminders.eveningTime"
    static let defaultEveningTime = 21 * 60
    static let eveningID = "campfire.evening"
    static let urlKey = "url"

    static let shared = CampfireReminders(scheduler: UNUserNotificationCenter.current())

    private let scheduler: ReminderScheduling
    private let defaults: UserDefaults

    init(scheduler: ReminderScheduling, defaults: UserDefaults = .standard) {
        self.scheduler = scheduler
        self.defaults = defaults
    }

    var remindsEvenings: Bool { defaults.bool(forKey: Self.eveningKey) }
    var eveningTime: Int {
        defaults.object(forKey: Self.eveningTimeKey) as? Int ?? Self.defaultEveningTime
    }

    /// Asks for permission when the reminder is switched on. False means the switch should go back off.
    func enable() async -> Bool {
        await scheduler.askPermission()
    }

    static func eveningComponents(minutes: Int) -> DateComponents {
        let clamped = min(max(0, minutes), 24 * 60 - 1)
        return DateComponents(hour: clamped / 60, minute: clamped % 60)
    }

    /// Schedules or clears the daily reminder to match the settings. Safe to call repeatedly.
    func applyEveningSetting() async {
        scheduler.cancel([Self.eveningID])
        guard remindsEvenings else { return }
        let content = UNMutableNotificationContent()
        content.title = "The candle's still lit"
        content.body = "Set down today's deeds before the ink dries."
        content.sound = .default
        content.userInfo = [Self.urlKey: WidgetSnapshot.writeURL.absoluteString]
        let trigger = UNCalendarNotificationTrigger(dateMatching: Self.eveningComponents(minutes: eveningTime), repeats: true)
        await scheduler.schedule(UNNotificationRequest(identifier: Self.eveningID, content: content, trigger: trigger))
    }

    /// The link a tapped reminder opens.
    static func url(from userInfo: [AnyHashable: Any]) -> URL? {
        (userInfo[urlKey] as? String).flatMap(URL.init(string:))
    }
}
