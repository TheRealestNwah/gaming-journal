import XCTest
@testable import GamingJournal

final class GameLibraryTests: XCTestCase {
    private let day: TimeInterval = 86_400

    private func date(_ days: Double) -> Date {
        Date(timeIntervalSince1970: days * day)
    }

    private func makeSessions() -> [PlaySession] {
        [
            PlaySession(gameTitle: "Hades", platform: "Switch", startDate: date(1), durationMinutes: 60, enjoyment: 4),
            PlaySession(gameTitle: "hades", platform: "PC", startDate: date(5), durationMinutes: 30, enjoyment: 5,
                        isMilestone: true),
            PlaySession(gameTitle: "Hollow Knight", platform: "PC", startDate: date(3), durationMinutes: 240),
            PlaySession(gameTitle: "Hades ", platform: "pc", startDate: date(2), durationMinutes: 15),
            PlaySession(gameTitle: "   ", startDate: date(9), durationMinutes: 5),
        ]
    }

    func testSummariesGroupTitlesAndAggregate() throws {
        let summaries = GameLibrary.summaries(from: makeSessions())
        XCTAssertEqual(summaries.map(\.title), ["hades", "Hollow Knight"])

        let hades = try XCTUnwrap(summaries.first)
        XCTAssertEqual(hades.key, "hades")
        XCTAssertEqual(hades.sessionCount, 3)
        XCTAssertEqual(hades.totalMinutes, 105)
        XCTAssertEqual(hades.firstPlayed, date(1))
        XCTAssertEqual(hades.lastPlayed, date(5))
        XCTAssertEqual(try XCTUnwrap(hades.averageEnjoyment), 4.5, accuracy: 0.001)
        XCTAssertEqual(hades.milestoneCount, 1)
        XCTAssertEqual(hades.platforms, ["PC", "Switch"])

        XCTAssertNil(summaries[1].averageEnjoyment)
    }

    func testSortOrders() {
        let sessions = makeSessions()
        XCTAssertEqual(GameLibrary.summaries(from: sessions, sortedBy: .mostPlayed).map(\.title),
                       ["Hollow Knight", "hades"])
        XCTAssertEqual(GameLibrary.summaries(from: sessions, sortedBy: .title).map(\.title),
                       ["hades", "Hollow Knight"])
    }

    func testSessionsForKeyNewestFirst() {
        let titles = GameLibrary.sessions(forKey: "hades", in: makeSessions()).map(\.startDate)
        XCTAssertEqual(titles, [date(5), date(2), date(1)])
    }

    func testRenameFixesEverySpelling() {
        let sessions = makeSessions()
        XCTAssertEqual(GameLibrary.rename("HADES", to: "  Hades   II ", in: sessions), "Hades II")
        XCTAssertEqual(sessions.filter { $0.gameTitle == "Hades II" }.count, 3)
        XCTAssertEqual(sessions[2].gameTitle, "Hollow Knight")
    }

    func testRenameOntoExistingGameMerges() {
        let sessions = makeSessions()
        XCTAssertEqual(GameLibrary.rename("Hollow Knight", to: "HADES", in: sessions), "hades")
        XCTAssertEqual(Set(sessions.dropLast().map(\.gameTitle)), ["hades"])
        XCTAssertEqual(GameLibrary.summaries(from: sessions).first?.sessionCount, 4)
    }

    func testRenameChangingOnlyCaseNormalisesSpelling() {
        let sessions = makeSessions()
        XCTAssertEqual(GameLibrary.rename("hades", to: "Hades", in: sessions), "Hades")
        XCTAssertEqual(Set(sessions.prefix(4).filter { $0.gameTitle.lowercased().hasPrefix("hades") }.map(\.gameTitle)),
                       ["Hades"])
    }

    func testBlankOrUnchangedRenameDoesNothing() {
        let sessions = makeSessions()
        XCTAssertNil(GameLibrary.rename("Hades", to: "   ", in: sessions))
        XCTAssertNil(GameLibrary.rename("Hollow Knight", to: "Hollow Knight", in: sessions))
    }
}
