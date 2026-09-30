import XCTest
@testable import GamingJournal

final class WidgetSnapshotTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_790_000_000)
    private let journalID = UUID()

    private var snapshot: WidgetSnapshot {
        WidgetSnapshot(
            generatedAt: now,
            latestEntry: WidgetSnapshot.LatestEntry(
                journalID: journalID, characterName: "Eira", heading: "17th of Last Seed", excerpt: "Riverwood.", writtenAt: now
            )
        )
    }

    func testLatestEntryTrimsLongWriting() {
        let journal = Journal(characterName: "Eira Stormborn")
        let entry = Entry(body: String(repeating: "snow ", count: 100) + "\nend", inGameDate: "Day 3")
        entry.journal = journal
        let latest = WidgetSnapshot.LatestEntry(entry: entry)
        XCTAssertEqual(latest.journalID, journal.id)
        XCTAssertEqual(latest.characterName, "Eira Stormborn")
        XCTAssertEqual(latest.heading, "Day 3")
        XCTAssertTrue(latest.excerpt.hasSuffix("…"))
        XCTAssertFalse(latest.excerpt.contains("\n"))
        XCTAssertLessThanOrEqual(latest.excerpt.count, WidgetSnapshot.LatestEntry.excerptLength + 1)
    }

    func testEncodingRoundTripsAndUsesKeysTheWidgetReads() throws {
        let data = try snapshot.encoded()
        XCTAssertEqual(try WidgetSnapshot.decode(data), snapshot)

        // The widget extension decodes these exact keys with seconds-since-1970 dates.
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(Set(json.keys), ["generatedAt", "latestEntry"])
        XCTAssertEqual(json["generatedAt"] as? Double, now.timeIntervalSince1970)
        let latest = try XCTUnwrap(json["latestEntry"] as? [String: Any])
        XCTAssertEqual(Set(latest.keys), ["journalID", "characterName", "heading", "excerpt", "writtenAt"])
    }

    func testSameContentIgnoresGeneratedAt() {
        let a = snapshot
        var b = a
        b.generatedAt = now.addingTimeInterval(60)
        XCTAssertTrue(a.sameContent(as: b))
        b.latestEntry?.excerpt = "Whiterun."
        XCTAssertFalse(a.sameContent(as: b))
    }

    func testPublishWritesToDefaults() throws {
        let suite = "WidgetSnapshotTests"
        UserDefaults().removePersistentDomain(forName: suite)
        defer { UserDefaults().removePersistentDomain(forName: suite) }
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))

        snapshot.publish(to: defaults)
        let stored = try XCTUnwrap(defaults.data(forKey: WidgetSnapshot.key))
        XCTAssertEqual(try WidgetSnapshot.decode(stored), snapshot)
    }

    func testMemoriesComeFromTheSameDayInEarlierYears() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "UTC"))
        func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
            calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 20))!
        }
        let journal = Journal(characterName: "Eira")
        let twoYears = Entry(body: "Helgen.", writtenAt: date(2024, 9, 30))
        let oneYear = Entry(body: "Riverwood.", writtenAt: date(2025, 9, 30))
        let nearby = Entry(body: "Whiterun.", writtenAt: date(2025, 10, 3))
        let lastWeek = Entry(body: "Too recent.", writtenAt: date(2026, 9, 25))
        for entry in [twoYears, oneYear, nearby, lastWeek] { entry.journal = journal }

        let memories = WidgetSnapshot.memories(from: [twoYears, oneYear, nearby, lastWeek], today: date(2026, 9, 30), days: 7, calendar: calendar)
        // Today: the most recent year wins among exact matches.
        XCTAssertEqual(memories.first?.day, calendar.startOfDay(for: date(2026, 9, 30)))
        XCTAssertEqual(memories.first?.entry.entryID, oneYear.id)
        // 3 October has its own entry; 1–2 October fall back to the nearest.
        let byDay = Dictionary(uniqueKeysWithValues: memories.map { (calendar.component(.day, from: $0.day), $0.entry.entryID) })
        XCTAssertEqual(byDay[3], nearby.id)
        XCTAssertEqual(byDay[1], oneYear.id)
        // Three days off still counts.
        XCTAssertEqual(byDay[6], nearby.id)
        XCTAssertFalse(memories.contains { $0.entry.entryID == lastWeek.id })
    }

    func testEntryLinksCarryTheEntry() {
        let entryID = UUID()
        let url = WidgetSnapshot.entryURL(for: entryID)
        XCTAssertTrue(WidgetSnapshot.isEntryURL(url))
        XCTAssertFalse(WidgetSnapshot.isWriteURL(url))
        XCTAssertEqual(WidgetSnapshot.entryID(inEntryURL: url), entryID)
        XCTAssertNil(WidgetSnapshot.entryID(inEntryURL: WidgetSnapshot.writeURL))
    }

    func testWriteLinksCarryTheJournal() {
        let journalID = UUID()
        let url = WidgetSnapshot.writeURL(for: journalID)
        XCTAssertTrue(WidgetSnapshot.isWriteURL(url))
        XCTAssertEqual(WidgetSnapshot.journalID(inWriteURL: url), journalID)
        XCTAssertTrue(WidgetSnapshot.isWriteURL(WidgetSnapshot.writeURL))
        XCTAssertNil(WidgetSnapshot.journalID(inWriteURL: WidgetSnapshot.writeURL))
        XCTAssertFalse(WidgetSnapshot.isWriteURL(URL(string: "gamingjournal://start-timer")!))
    }
}
