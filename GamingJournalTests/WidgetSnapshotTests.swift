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
