import XCTest
@testable import GamingJournal

final class JournalEntryTests: XCTestCase {
    func testPlaytimeFormatting() {
        XCTAssertEqual(PlaytimeFormatter.string(fromMinutes: 0), "—")
        XCTAssertEqual(PlaytimeFormatter.string(fromMinutes: 45), "45m")
        XCTAssertEqual(PlaytimeFormatter.string(fromMinutes: 120), "2h")
        XCTAssertEqual(PlaytimeFormatter.string(fromMinutes: 90), "1h 30m")
    }

    func testInitClampsValues() {
        let entry = JournalEntry(gameTitle: "Hades", minutesPlayed: -10, rating: 9)
        XCTAssertEqual(entry.minutesPlayed, 0)
        XCTAssertEqual(entry.rating, 5)
        XCTAssertNil(JournalEntry(gameTitle: "Celeste").rating)
    }
}
