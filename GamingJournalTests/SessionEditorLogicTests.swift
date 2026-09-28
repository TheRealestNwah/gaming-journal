import XCTest
@testable import GamingJournal

final class GameTitleIndexTests: XCTestCase {
    private let day: TimeInterval = 86_400

    private func index() -> GameTitleIndex {
        GameTitleIndex(entries: [
            .init(title: "Hades", platform: "Switch", date: Date(timeIntervalSince1970: 0)),
            .init(title: "hades ", platform: "PC", date: Date(timeIntervalSince1970: 2 * day)),
            .init(title: "Hollow Knight", platform: "PC", date: Date(timeIntervalSince1970: 1 * day)),
            .init(title: "Death's Door", platform: "", date: Date(timeIntervalSince1970: 3 * day)),
            .init(title: "   ", platform: "PC", date: Date(timeIntervalSince1970: 4 * day)),
        ])
    }

    func testGroupsTitlesCaseInsensitivelyKeepingFirstSpelling() {
        XCTAssertEqual(index().recentTitles, ["Death's Door", "Hades", "Hollow Knight"])
        XCTAssertEqual(index().sessionCount(for: "HADES"), 2)
    }

    func testSuggestionsPreferPrefixMatchesThenRecency() {
        XCTAssertEqual(index().suggestions(for: "h"), ["Hades", "Hollow Knight", "Death's Door"])
        XCTAssertEqual(index().suggestions(for: "door"), ["Death's Door"])
        XCTAssertEqual(index().suggestions(for: "", limit: 2), ["Death's Door", "Hades"])
    }

    func testSuggestionsExcludeExactMatch() {
        XCTAssertEqual(index().suggestions(for: "hades"), [])
    }

    func testCanonicalTitle() {
        XCTAssertEqual(index().canonicalTitle(for: "  HOLLOW   knight "), "Hollow Knight")
        XCTAssertEqual(index().canonicalTitle(for: " New   Game "), "New Game")
    }

    func testLastPlatformUsesMostRecentNonEmpty() {
        XCTAssertEqual(index().lastPlatform(for: "Hades"), "PC")
        XCTAssertNil(index().lastPlatform(for: "Death's Door"))
        XCTAssertNil(index().lastPlatform(for: "Unknown"))
    }
}

final class PlatformPresetsTests: XCTestCase {
    func testOptionsAppendCustomPlatformsOnce() {
        let options = PlatformPresets.options(including: ["pc", "Game Boy", " game boy ", ""])
        XCTAssertEqual(options, PlatformPresets.all + ["Game Boy"])
    }
}

final class SessionDraftTests: XCTestCase {
    func testRoundTripThroughSession() {
        let session = PlaySession(
            gameTitle: "Celeste",
            platform: "Switch",
            durationMinutes: 50,
            enjoyment: 4,
            mood: .focused,
            notes: "Chapter 7",
            tags: ["hard", "platformer"],
            isMilestone: true,
            milestoneNote: "Summit!"
        )
        let draft = SessionDraft(session: session)
        XCTAssertEqual(draft.tagsText, "hard, platformer")

        let copy = draft.makeSession(index: GameTitleIndex(entries: []))
        XCTAssertEqual(copy.gameTitle, "Celeste")
        XCTAssertEqual(copy.platform, "Switch")
        XCTAssertEqual(copy.durationMinutes, 50)
        XCTAssertEqual(copy.enjoyment, 4)
        XCTAssertEqual(copy.mood, .focused)
        XCTAssertEqual(copy.tags, ["hard", "platformer"])
        XCTAssertEqual(copy.milestoneNote, "Summit!")
    }

    func testApplyUsesCanonicalTitleAndClearsMilestoneNote() {
        let index = GameTitleIndex(entries: [.init(title: "Hades", platform: "PC", date: .now)])
        var draft = SessionDraft()
        draft.gameTitle = " hades"
        draft.durationMinutes = -3
        draft.enjoyment = 8
        draft.milestoneNote = "leftover"
        draft.isMilestone = false

        let session = draft.makeSession(index: index)
        XCTAssertEqual(session.gameTitle, "Hades")
        XCTAssertEqual(session.durationMinutes, 0)
        XCTAssertEqual(session.enjoyment, 5)
        XCTAssertEqual(session.milestoneNote, "")
    }

    func testValidity() {
        var draft = SessionDraft()
        XCTAssertFalse(draft.isValid)
        draft.gameTitle = "   "
        XCTAssertFalse(draft.isValid)
        draft.gameTitle = "Tunic"
        XCTAssertTrue(draft.isValid)
    }
}
