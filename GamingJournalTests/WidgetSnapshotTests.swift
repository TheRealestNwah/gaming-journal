import XCTest
@testable import GamingJournal

final class WidgetSnapshotTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        calendar.firstWeekday = 2
        return calendar
    }

    private func date(_ month: Int, _ day: Int, _ hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour))!
    }

    /// Wednesday 30 September 2026; the week began Monday the 28th.
    private var now: Date { date(9, 30, 18) }

    private var records: [StatsRecord] {
        [
            StatsRecord(title: "Hades", platform: "PC", start: date(9, 28), minutes: 60),
            StatsRecord(title: "hades", platform: "PC", start: date(9, 29), minutes: 30),
            StatsRecord(title: "Celeste", platform: "Switch", start: date(9, 30, 9), minutes: 45),
            StatsRecord(title: "Old Game", start: date(9, 27), minutes: 300),
            StatsRecord(title: "Future", start: date(10, 2), minutes: 10),
        ]
    }

    func testMakeSummarisesThisWeekAndLastSession() {
        let snapshot = WidgetSnapshot.make(sessions: records, timer: nil, now: now, calendar: calendar)
        XCTAssertEqual(snapshot.weekStart, date(9, 28, 0))
        XCTAssertEqual(snapshot.weekMinutes, 135)
        XCTAssertEqual(snapshot.topGames, [.init(title: "hades", minutes: 90), .init(title: "Celeste", minutes: 45)])
        XCTAssertEqual(snapshot.lastSession, .init(title: "Celeste", platform: "Switch", start: date(9, 30, 9), minutes: 45))
        XCTAssertNil(snapshot.timer)
    }

    func testMakeIncludesTimer() {
        var timer = TimerState(gameTitle: "Balatro", startedAt: date(9, 30, 17))
        timer.pause(at: date(9, 30, 17).addingTimeInterval(600))
        let snapshot = WidgetSnapshot.make(sessions: [], timer: timer, now: now, calendar: calendar)
        XCTAssertEqual(snapshot.timer, .init(title: "Balatro", accumulated: 600, runningSince: nil))
        XCTAssertNil(snapshot.lastSession)
        XCTAssertEqual(snapshot.weekMinutes, 0)
        XCTAssertTrue(snapshot.topGames.isEmpty)
    }

    func testEncodingRoundTripsAndUsesKeysTheWidgetReads() throws {
        let snapshot = WidgetSnapshot.make(sessions: records, timer: TimerState(gameTitle: "Tunic", startedAt: now),
                                           now: now, calendar: calendar)
        let data = try snapshot.encoded()
        XCTAssertEqual(try WidgetSnapshot.decode(data), snapshot)

        // The widget extension decodes these exact keys with seconds-since-1970 dates.
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(Set(json.keys), ["generatedAt", "lastSession", "timer", "weekMinutes", "weekStart", "topGames"])
        XCTAssertEqual(json["weekStart"] as? Double, date(9, 28, 0).timeIntervalSince1970)
        let timer = try XCTUnwrap(json["timer"] as? [String: Any])
        XCTAssertEqual(Set(timer.keys), ["title", "accumulated", "runningSince"])
    }

    func testSameContentIgnoresGeneratedAt() {
        let a = WidgetSnapshot.make(sessions: records, timer: nil, now: now, calendar: calendar)
        var b = a
        b.generatedAt = now.addingTimeInterval(60)
        XCTAssertTrue(a.sameContent(as: b))
        b.weekMinutes += 1
        XCTAssertFalse(a.sameContent(as: b))
    }

    func testPublishWritesToDefaults() throws {
        let suite = "WidgetSnapshotTests"
        UserDefaults().removePersistentDomain(forName: suite)
        defer { UserDefaults().removePersistentDomain(forName: suite) }
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))

        let snapshot = WidgetSnapshot.make(sessions: records, timer: nil, now: now, calendar: calendar)
        snapshot.publish(to: defaults)
        let stored = try XCTUnwrap(defaults.data(forKey: WidgetSnapshot.key))
        XCTAssertEqual(try WidgetSnapshot.decode(stored), snapshot)
    }
}
