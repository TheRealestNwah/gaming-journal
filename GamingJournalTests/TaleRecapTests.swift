import XCTest
@testable import GamingJournal

final class TaleRecapTests: XCTestCase {
    private func day(_ n: Int) -> Date { Date(timeIntervalSince1970: TimeInterval(n) * 86_400) }

    private func makeTale() -> Notebook {
        let notebook = Notebook(title: "Tav's Road", status: .completed, startedAt: day(0))
        let karlach = PartyMember(name: "Karlach", sortIndex: 0)
        let wyll = PartyMember(name: "Wyll", sortIndex: 1)
        let quiet = PartyMember(name: "Gale", sortIndex: 2)
        notebook.members = [wyll, karlach, quiet]

        let start = Entry(title: "Out of the fire", writtenAt: day(1), emotions: [FeltEmotion(.lost, intensity: 3)])
        start.author = karlach
        let middle = Entry(title: "The pact", writtenAt: day(5), isTurningPoint: true,
                           emotions: [FeltEmotion(.determined, intensity: 2)],
                           bonds: [Bond(targetName: "Mizora", affinity: -3, note: "Never again")])
        middle.author = wyll
        let end = Entry(title: "Engine cooled", writtenAt: day(9), isTurningPoint: true,
                        emotions: [FeltEmotion(.determined, intensity: 3)],
                        bonds: [Bond(targetName: "Wyll", affinity: 2)])
        end.author = karlach
        notebook.entries = [end, start, middle]
        notebook.updatedAt = day(10)
        return notebook
    }

    func testRecapWalksTheTaleInOrder() {
        let recap = TaleRecap(notebook: makeTale())
        XCTAssertTrue(recap.hasStory)
        XCTAssertEqual(recap.firstEntry?.title, "Out of the fire")
        XCTAssertEqual(recap.lastEntry?.title, "Engine cooled")
        XCTAssertEqual(recap.turningPoints.map(\.title), ["The pact", "Engine cooled"])
        XCTAssertEqual(recap.summary.entryCount, 3)
        XCTAssertEqual(recap.summary.daysOnJourney, 11)
    }

    func testArcsFollowThePartyAndSkipSilentMembers() {
        let recap = TaleRecap(notebook: makeTale())
        XCTAssertEqual(recap.arcs.map(\.member.name), ["Karlach", "Wyll"])
        let karlach = recap.arcs[0]
        XCTAssertEqual(karlach.entryCount, 2)
        XCTAssertEqual(karlach.opening, Emotion.lost.group)
        XCTAssertEqual(karlach.closing, Emotion.determined.group)
        XCTAssertEqual(karlach.journey, "From \(Emotion.lost.group.label) to \(Emotion.determined.group.label)")
        XCTAssertEqual(karlach.mostFelt, .determined)
        XCTAssertEqual(recap.arcs[1].journey, "Held to \(Emotion.determined.group.label)")
    }

    func testStrongestBondsFirst() {
        let recap = TaleRecap(notebook: makeTale())
        XCTAssertEqual(recap.bonds.map(\.name), ["Mizora", "Wyll"])
        XCTAssertEqual(recap.bonds.first?.latestNote, "Never again")
        XCTAssertEqual(TaleRecap(notebook: makeTale(), bondLimit: 1).bonds.count, 1)
    }

    func testPrevailingFeelingIsTheStrongestFamily() {
        XCTAssertEqual(TaleRecap(notebook: makeTale()).prevailingFeeling, Emotion.determined.group)
    }

    func testEmptyAndOneEntryTales() {
        let empty = TaleRecap(notebook: Notebook(title: "Unwritten", status: .completed))
        XCTAssertFalse(empty.hasStory)
        XCTAssertTrue(empty.arcs.isEmpty)
        XCTAssertNil(empty.prevailingFeeling)

        let single = Notebook(title: "Short")
        single.entries = [Entry(title: "Only page")]
        let recap = TaleRecap(notebook: single)
        XCTAssertEqual(recap.firstEntry?.title, "Only page")
        // One entry is the beginning, not also the end.
        XCTAssertNil(recap.lastEntry)
    }

    func testArcWithoutFeelingsHasNoJourneyLine() {
        let notebook = Notebook(title: "Stoic")
        let member = PartyMember(name: "Astarion")
        notebook.members = [member]
        let entry = Entry(title: "Nothing to say")
        entry.author = member
        notebook.entries = [entry]
        let arc = TaleRecap(notebook: notebook).arcs.first
        XCTAssertEqual(arc?.entryCount, 1)
        XCTAssertNil(arc?.journey)
    }
}
