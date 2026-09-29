import XCTest
@testable import GamingJournal

final class QuickWriteRosterTests: XCTestCase {
    private func makeJournals() -> [Journal] {
        let older = Journal(characterName: "Nerevar", epithet: "Dunmer", gameTitle: "Morrowind")
        older.updatedAt = Date(timeIntervalSince1970: 1_000)
        let newer = Journal(characterName: "Éira Stormborn", epithet: "Nord", gameTitle: "Skyrim")
        newer.updatedAt = Date(timeIntervalSince1970: 2_000)
        return [older, newer]
    }

    func testMostRecentJournalComesFirst() {
        let roster = QuickWriteRoster(journals: makeJournals())
        XCTAssertEqual(roster.journals.map(\.characterName), ["Éira Stormborn", "Nerevar"])
    }

    func testMatchingIgnoresCaseAndAccentsAndLooksAtEpithetAndGame() {
        let roster = QuickWriteRoster(journals: makeJournals())
        XCTAssertEqual(roster.journals(matching: "eira").map(\.characterName), ["Éira Stormborn"])
        XCTAssertEqual(roster.journals(matching: "DUNMER").map(\.characterName), ["Nerevar"])
        XCTAssertEqual(roster.journals(matching: "skyrim").count, 1)
        XCTAssertEqual(roster.journals(matching: " ").count, 2)
    }

    func testSavesOnlyWhenChangedAndLoadsBack() throws {
        let suite = "QuickWriteRosterTests"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }

        XCTAssertEqual(QuickWriteRoster.load(from: defaults), QuickWriteRoster())
        let roster = QuickWriteRoster(journals: makeJournals())
        XCTAssertTrue(roster.save(to: defaults))
        XCTAssertFalse(roster.save(to: defaults))
        XCTAssertEqual(QuickWriteRoster.load(from: defaults), roster)
    }
}
