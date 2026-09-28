import XCTest
import SwiftData
@testable import GamingJournal

final class PlaySessionTests: XCTestCase {
    func testInitClampsAndTrims() {
        let session = PlaySession(
            gameTitle: "  Hades \n",
            platform: " PC ",
            durationMinutes: -10,
            enjoyment: 9,
            tags: [" boss ", "Boss", "", "late   night"]
        )
        XCTAssertEqual(session.gameTitle, "Hades")
        XCTAssertEqual(session.platform, "PC")
        XCTAssertEqual(session.durationMinutes, 0)
        XCTAssertEqual(session.enjoyment, 5)
        XCTAssertEqual(session.tags, ["boss", "late night"])
        XCTAssertEqual(PlaySession.clampedEnjoyment(0), 1)
        XCTAssertNil(PlaySession.clampedEnjoyment(nil))
    }

    func testDefaults() {
        let session = PlaySession(gameTitle: "Celeste")
        XCTAssertNil(session.enjoyment)
        XCTAssertNil(session.mood)
        XCTAssertEqual(session.notes, "")
        XCTAssertEqual(session.tags, [])
        XCTAssertFalse(session.isMilestone)
        XCTAssertEqual(session.formattedDuration, "—")
    }

    func testMoodRoundTripsThroughRawValue() {
        let session = PlaySession(gameTitle: "Tetris", mood: .focused)
        XCTAssertEqual(session.moodRaw, "focused")
        session.mood = .hyped
        XCTAssertEqual(session.mood, .hyped)
        session.moodRaw = "no-longer-exists"
        XCTAssertNil(session.mood)
    }

    func testEndDate() {
        let start = Date(timeIntervalSince1970: 0)
        let session = PlaySession(gameTitle: "Outer Wilds", startDate: start, durationMinutes: 90)
        XCTAssertEqual(session.endDate, start.addingTimeInterval(5400))
    }

    @MainActor
    func testInMemoryContainerStoresSessions() throws {
        let container = try Persistence.makeContainer(inMemory: true)
        let context = container.mainContext
        context.insert(PlaySession(gameTitle: "Balatro", durationMinutes: 45))
        try context.save()
        let fetched = try context.fetch(FetchDescriptor<PlaySession>())
        XCTAssertEqual(fetched.map(\.gameTitle), ["Balatro"])
    }
}

final class PlaytimeFormatterTests: XCTestCase {
    func testFormatting() {
        XCTAssertEqual(PlaytimeFormatter.string(fromMinutes: 0), "—")
        XCTAssertEqual(PlaytimeFormatter.string(fromMinutes: -5), "—")
        XCTAssertEqual(PlaytimeFormatter.string(fromMinutes: 45), "45m")
        XCTAssertEqual(PlaytimeFormatter.string(fromMinutes: 120), "2h")
        XCTAssertEqual(PlaytimeFormatter.string(fromMinutes: 90), "1h 30m")
    }
}

final class TagParserTests: XCTestCase {
    func testParseSplitsOnCommasAndHashes() {
        XCTAssertEqual(TagParser.parse("boss, #coop, late night"), ["boss", "coop", "late night"])
        XCTAssertEqual(TagParser.parse("#a#b"), ["a", "b"])
        XCTAssertEqual(TagParser.parse("  "), [])
    }

    func testNormalizeDedupesCaseInsensitively() {
        XCTAssertEqual(TagParser.normalize(["Co-op", "co-op", "CO-OP"]), ["Co-op"])
    }
}
