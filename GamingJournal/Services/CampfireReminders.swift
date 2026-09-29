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

/// Optional nudges to write, in the journal's voice: one after a play session the writer didn't
/// write about yet, and one every evening at a chosen time. Both are off until turned on in
/// Settings, and permission is only asked for then.
final class CampfireReminders {
    static let afterSessionKey = "reminders.afterSession"
    static let eveningKey = "reminders.evening"
    /// Minutes after midnight.
    static let eveningTimeKey = "reminders.eveningTime"
    static let defaultEveningTime = 21 * 60
    /// How long after a session the nudge comes.
    static let afterSessionDelay: TimeInterval = 60 * 60
    static let eveningID = "campfire.evening"
    static let urlKey = "url"

    static let shared = CampfireReminders(scheduler: UNUserNotificationCenter.current())

    private let scheduler: ReminderScheduling
    private let defaults: UserDefaults

    init(scheduler: ReminderScheduling, defaults: UserDefaults = .standard) {
        self.scheduler = scheduler
        self.defaults = defaults
    }

    var remindsAfterSessions: Bool { defaults.bool(forKey: Self.afterSessionKey) }
    var remindsEvenings: Bool { defaults.bool(forKey: Self.eveningKey) }
    var eveningTime: Int {
        defaults.object(forKey: Self.eveningTimeKey) as? Int ?? Self.defaultEveningTime
    }

    /// Asks for permission when a reminder is switched on. False means the switch should go back off.
    func enable() async -> Bool {
        await scheduler.askPermission()
    }

    // MARK: After a session

    static func afterSessionID(for notebookID: UUID) -> String {
        "campfire.session.\(notebookID.uuidString)"
    }

    /// The writer chose "remind me later" after logging a session in this notebook.
    func sessionLogged(notebookID: UUID, notebookTitle: String, now: Date = .now) async {
        guard remindsAfterSessions else { return }
        let content = UNMutableNotificationContent()
        content.title = "The fire's still warm"
        content.body = "Write what happened in \(notebookTitle) before the embers fade."
        content.sound = .default
        content.userInfo = [Self.urlKey: WidgetSnapshot.writeURL(for: notebookID).absoluteString]
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: Self.afterSessionDelay, repeats: false)
        // Same ID per notebook: a newer session replaces the older nudge.
        await scheduler.schedule(UNNotificationRequest(identifier: Self.afterSessionID(for: notebookID), content: content, trigger: trigger))
    }

    /// An entry was written, so there's nothing left to nudge about in that notebook.
    func entryWritten(in notebookID: UUID) {
        scheduler.cancel([Self.afterSessionID(for: notebookID)])
    }

    // MARK: Evenings

    static func eveningComponents(minutes: Int) -> DateComponents {
        let clamped = min(max(0, minutes), 24 * 60 - 1)
        return DateComponents(hour: clamped / 60, minute: clamped % 60)
    }

    /// Schedules or clears the daily reminder to match the settings. Safe to call repeatedly.
    func applyEveningSetting() async {
        scheduler.cancel([Self.eveningID])
        guard remindsEvenings else { return }
        let content = UNMutableNotificationContent()
        content.title = "The campfire awaits"
        content.body = "Set down tonight's tale while the embers glow."
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
