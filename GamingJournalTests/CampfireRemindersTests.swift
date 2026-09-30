import XCTest
import UserNotifications
@testable import GamingJournal

final class CampfireRemindersTests: XCTestCase {
    private final class FakeScheduler: ReminderScheduling {
        var grants = true
        var pending: [String: UNNotificationRequest] = [:]

        func askPermission() async -> Bool { grants }

        func schedule(_ request: UNNotificationRequest) async {
            pending[request.identifier] = request
        }

        func cancel(_ identifiers: [String]) {
            identifiers.forEach { pending[$0] = nil }
        }
    }

    private let suite = "CampfireRemindersTests"
    private var defaults: UserDefaults!
    private var scheduler: FakeScheduler!
    private var reminders: CampfireReminders!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suite)
        defaults.removePersistentDomain(forName: suite)
        scheduler = FakeScheduler()
        reminders = CampfireReminders(scheduler: scheduler, defaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
        super.tearDown()
    }

    func testEverythingIsOffByDefault() async {
        XCTAssertFalse(reminders.remindsEvenings)
        XCTAssertEqual(reminders.eveningTime, 21 * 60)
        await reminders.applyEveningSetting()
        XCTAssertTrue(scheduler.pending.isEmpty)
    }

    func testEveningReminderFollowsTheSetting() async throws {
        defaults.set(true, forKey: CampfireReminders.eveningKey)
        defaults.set(20 * 60 + 30, forKey: CampfireReminders.eveningTimeKey)
        await reminders.applyEveningSetting()
        let request = try XCTUnwrap(scheduler.pending[CampfireReminders.eveningID])
        let trigger = try XCTUnwrap(request.trigger as? UNCalendarNotificationTrigger)
        XCTAssertTrue(trigger.repeats)
        XCTAssertEqual(trigger.dateComponents.hour, 20)
        XCTAssertEqual(trigger.dateComponents.minute, 30)
        XCTAssertEqual(CampfireReminders.url(from: request.content.userInfo), WidgetSnapshot.writeURL)

        // Applying again (e.g. at launch) keeps exactly one.
        await reminders.applyEveningSetting()
        XCTAssertEqual(scheduler.pending.count, 1)

        defaults.set(false, forKey: CampfireReminders.eveningKey)
        await reminders.applyEveningSetting()
        XCTAssertTrue(scheduler.pending.isEmpty)
    }

    func testEveningComponentsClamp() {
        XCTAssertEqual(CampfireReminders.eveningComponents(minutes: -5), DateComponents(hour: 0, minute: 0))
        XCTAssertEqual(CampfireReminders.eveningComponents(minutes: 9_999), DateComponents(hour: 23, minute: 59))
    }

    func testPermissionRefusedIsReported() async {
        scheduler.grants = false
        let granted = await reminders.enable()
        XCTAssertFalse(granted)
    }

    func testUnrelatedNotificationsHaveNoLink() {
        XCTAssertNil(CampfireReminders.url(from: [:]))
        XCTAssertNil(CampfireReminders.url(from: ["url": 42]))
    }
}
