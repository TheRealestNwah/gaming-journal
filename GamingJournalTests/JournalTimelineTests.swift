import XCTest
@testable import GamingJournal

final class JournalFilterTests: XCTestCase {
    private let sessions = [
        PlaySession(gameTitle: "Hades", platform: "PC", notes: "Beat Hades with the bow", tags: ["roguelike", "boss"]),
        PlaySession(gameTitle: "Hollow Knight", platform: "Switch", notes: "Explored Greenpath", tags: ["metroidvania"]),
        PlaySession(gameTitle: "Celeste", platform: "PC", tags: ["platformer"], isMilestone: true, milestoneNote: "Summit"),
    ]

    private func titles(_ filter: JournalFilter) -> [String] {
        filter.apply(to: sessions).map(\.gameTitle)
    }

    func testEmptyFilterKeepsEverything() {
        let filter = JournalFilter()
        XCTAssertFalse(filter.isActive)
        XCTAssertEqual(titles(filter), ["Hades", "Hollow Knight", "Celeste"])
    }

    func testSearchMatchesTitleNotesTagsAndMilestoneNote() {
        XCTAssertEqual(titles(JournalFilter(searchText: "greenpath")), ["Hollow Knight"])
        XCTAssertEqual(titles(JournalFilter(searchText: "ROGUE")), ["Hades"])
        XCTAssertEqual(titles(JournalFilter(searchText: "summit")), ["Celeste"])
        XCTAssertEqual(titles(JournalFilter(searchText: "h")), ["Hades", "Hollow Knight"])
    }

    func testSearchRequiresEveryWord() {
        XCTAssertEqual(titles(JournalFilter(searchText: "  bow   hades ")), ["Hades"])
        XCTAssertEqual(titles(JournalFilter(searchText: "bow greenpath")), [])
    }

    func testFacetsCompareCaseInsensitively() {
        XCTAssertEqual(titles(JournalFilter(game: " hollow  knight")), ["Hollow Knight"])
        XCTAssertEqual(titles(JournalFilter(platform: "pc")), ["Hades", "Celeste"])
        XCTAssertEqual(titles(JournalFilter(tag: "BOSS")), ["Hades"])
        XCTAssertEqual(titles(JournalFilter(milestonesOnly: true)), ["Celeste"])
    }

    func testFacetsCombineWithSearch() {
        XCTAssertEqual(titles(JournalFilter(searchText: "beat", platform: "PC")), ["Hades"])
        XCTAssertEqual(titles(JournalFilter(platform: "PC", milestonesOnly: true)), ["Celeste"])
    }

    func testClearFacetsKeepsSearchText() {
        var filter = JournalFilter(searchText: "hades", game: "Hades", platform: "PC", tag: "boss", milestonesOnly: true)
        XCTAssertTrue(filter.hasFacets)
        filter.clearFacets()
        XCTAssertFalse(filter.hasFacets)
        XCTAssertTrue(filter.isActive)
        XCTAssertEqual(filter.searchText, "hades")
    }

    func testFacetValuesAreDistinctAndSorted() {
        let extra = sessions + [PlaySession(gameTitle: "hades", platform: " pc ", tags: ["Boss", "co-op"])]
        let facets = JournalFacets(sessions: extra)
        XCTAssertEqual(facets.games, ["Celeste", "Hades", "Hollow Knight"])
        XCTAssertEqual(facets.platforms, ["PC", "Switch"])
        XCTAssertEqual(facets.tags, ["boss", "co-op", "metroidvania", "platformer", "roguelike"])
    }
}

final class TimelineGroupingTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    func testGroupsByDayAndMonthNewestFirst() {
        let sessions = [
            PlaySession(gameTitle: "A", startDate: date(2026, 8, 31, 22), durationMinutes: 30),
            PlaySession(gameTitle: "B", startDate: date(2026, 9, 2, 9), durationMinutes: 60),
            PlaySession(gameTitle: "C", startDate: date(2026, 9, 2, 20), durationMinutes: 45),
            PlaySession(gameTitle: "D", startDate: date(2026, 9, 1, 0), durationMinutes: 15),
        ]
        let months = TimelineGrouping.months(from: sessions, calendar: calendar)

        XCTAssertEqual(months.map(\.date), [date(2026, 9, 1, 0), date(2026, 8, 1, 0)])
        XCTAssertEqual(months[0].days.map(\.date), [date(2026, 9, 2, 0), date(2026, 9, 1, 0)])
        XCTAssertEqual(months[0].days[0].sessions.map(\.gameTitle), ["C", "B"])
        XCTAssertEqual(months[0].days[0].totalMinutes, 105)
        XCTAssertEqual(months[0].totalMinutes, 120)
        XCTAssertEqual(months[1].days.map { $0.sessions.map(\.gameTitle) }, [["A"]])
    }

    func testEmptyInputGivesNoMonths() {
        XCTAssertTrue(TimelineGrouping.months(from: [], calendar: calendar).isEmpty)
    }
}

final class RestorableCopyTests: XCTestCase {
    func testCopyKeepsIdAndValues() {
        let original = PlaySession(
            gameTitle: "Tunic",
            platform: "PC",
            durationMinutes: 40,
            enjoyment: 5,
            mood: .relaxed,
            notes: "Found the manual page",
            tags: ["secret"],
            isMilestone: true,
            milestoneNote: "Golden path"
        )
        let copy = original.restorableCopy()
        XCTAssertFalse(copy === original)
        XCTAssertEqual(copy.id, original.id)
        XCTAssertEqual(copy.gameTitle, "Tunic")
        XCTAssertEqual(copy.durationMinutes, 40)
        XCTAssertEqual(copy.mood, .relaxed)
        XCTAssertEqual(copy.tags, ["secret"])
        XCTAssertEqual(copy.milestoneNote, "Golden path")
        XCTAssertEqual(copy.createdAt, original.createdAt)
        XCTAssertEqual(copy.startDate, original.startDate)
    }
}
