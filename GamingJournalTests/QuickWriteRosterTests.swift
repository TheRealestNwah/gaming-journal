import XCTest
@testable import GamingJournal

final class QuickWriteRosterTests: XCTestCase {
    private func makeNotebooks() -> [Notebook] {
        let finished = Notebook(title: "Frostbound", gameTitle: "Dark Souls", status: .completed)
        finished.updatedAt = Date(timeIntervalSince1970: 3_000)
        finished.members = [PartyMember(name: "Solaire", role: "Knight")]

        let current = Notebook(title: "Tav's Road", gameTitle: "Baldur's Gate 3")
        current.updatedAt = Date(timeIntervalSince1970: 1_000)
        let karlach = PartyMember(name: "Karlach", role: "Barbarian", sortIndex: 1)
        let wyll = PartyMember(name: "Wyll", role: "Warlock", sortIndex: 0)
        let gone = PartyMember(name: "Minthara", sortIndex: 2)
        gone.isRetired = true
        current.members = [karlach, gone, wyll]
        return [finished, current]
    }

    func testOngoingTalesComeFirstAndRetiredMembersStayOut() {
        let roster = QuickWriteRoster(notebooks: makeNotebooks())
        XCTAssertEqual(roster.tales.map(\.title), ["Tav's Road", "Frostbound"])
        XCTAssertEqual(roster.characters.map(\.name), ["Wyll", "Karlach", "Solaire"])
        XCTAssertEqual(roster.characters.first?.notebookTitle, "Tav's Road")
    }

    func testMatchingLooksAtNameRoleAndTale() {
        let roster = QuickWriteRoster(notebooks: makeNotebooks())
        XCTAssertEqual(roster.characters(matching: "barb").map(\.name), ["Karlach"])
        XCTAssertEqual(roster.characters(matching: "tav's").map(\.name), ["Wyll", "Karlach"])
        XCTAssertEqual(roster.characters(matching: " ").count, 3)
        XCTAssertEqual(roster.tales(matching: "dark souls").map(\.title), ["Frostbound"])
    }

    func testSavesOnlyWhenChangedAndLoadsBack() throws {
        let suite = "QuickWriteRosterTests"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }

        XCTAssertEqual(QuickWriteRoster.load(from: defaults), QuickWriteRoster())
        let roster = QuickWriteRoster(notebooks: makeNotebooks())
        XCTAssertTrue(roster.save(to: defaults))
        XCTAssertFalse(roster.save(to: defaults))
        XCTAssertEqual(QuickWriteRoster.load(from: defaults), roster)
    }

    func testWriteLinksCarryTheCharacter() {
        let notebookID = UUID()
        let memberID = UUID()
        let url = WidgetSnapshot.writeURL(for: notebookID, member: memberID)
        XCTAssertEqual(WidgetSnapshot.notebookID(inWriteURL: url), notebookID)
        XCTAssertEqual(WidgetSnapshot.memberID(inWriteURL: url), memberID)
        XCTAssertNil(WidgetSnapshot.memberID(inWriteURL: WidgetSnapshot.writeURL(for: notebookID)))
        XCTAssertNil(WidgetSnapshot.memberID(inWriteURL: WidgetSnapshot.startTimerURL))
    }
}
