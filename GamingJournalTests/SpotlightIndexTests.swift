import XCTest
@testable import GamingJournal

final class SpotlightIndexTests: XCTestCase {
    private func makeNotebook() -> (Notebook, Entry) {
        let notebook = Notebook(title: "Tav's Road", gameTitle: "Baldur's Gate 3", platform: "PC")
        let karlach = PartyMember(name: "Karlach")
        notebook.members = [karlach]
        let entry = Entry(title: "Out of the fire", body: "My engine burns.\nHotter every day.", place: "Emerald Grove", quest: "Find a cure")
        entry.author = karlach
        entry.notebook = notebook
        notebook.entries = [entry]
        return (notebook, entry)
    }

    func testTargetsRoundTripThroughIdentifiers() {
        let id = UUID()
        XCTAssertEqual(SpotlightIndex.Target(identifier: SpotlightIndex.Target.notebook(id).identifier), .notebook(id))
        XCTAssertEqual(SpotlightIndex.Target(identifier: SpotlightIndex.Target.entry(id).identifier), .entry(id))
        XCTAssertNil(SpotlightIndex.Target(identifier: "entry.not-a-uuid"))
        XCTAssertNil(SpotlightIndex.Target(identifier: "session.\(id.uuidString)"))
        XCTAssertNil(SpotlightIndex.Target(identifier: ""))
    }

    func testNotebookItemDescribesTheTale() {
        let (notebook, _) = makeNotebook()
        let item = SpotlightIndex.item(for: notebook)
        XCTAssertEqual(item.uniqueIdentifier, "notebook.\(notebook.id.uuidString)")
        XCTAssertEqual(item.attributeSet.title, "Tav's Road")
        XCTAssertEqual(item.attributeSet.contentDescription, "Baldur's Gate 3 · PC · Ongoing")
        XCTAssertEqual(item.attributeSet.keywords, ["Baldur's Gate 3", "Karlach"])
    }

    func testEntryItemIncludesTheWritingWhenOpen() {
        let (_, entry) = makeNotebook()
        let item = SpotlightIndex.item(for: entry, includeText: true)
        XCTAssertEqual(item.attributeSet.title, "Out of the fire")
        XCTAssertEqual(item.attributeSet.contentDescription, "Tav's Road · Karlach — My engine burns. Hotter every day.")
        XCTAssertEqual(item.attributeSet.keywords, ["Emerald Grove", "Find a cure", "Karlach"])
        XCTAssertEqual(item.domainIdentifier, SpotlightIndex.entryDomain)
    }

    func testLockedJournalKeepsTheWritingOutOfSearch() {
        let (_, entry) = makeNotebook()
        let item = SpotlightIndex.item(for: entry, includeText: false)
        XCTAssertEqual(item.attributeSet.contentDescription, "Tav's Road · Karlach")
        XCTAssertFalse(item.attributeSet.contentDescription?.contains("engine") ?? true)
        XCTAssertEqual(item.attributeSet.keywords, ["Karlach"])
    }

    func testUntitledEntriesAreNamedForTheirWriter() {
        let entry = Entry(body: "No title here.")
        XCTAssertEqual(SpotlightIndex.item(for: entry, includeText: true).attributeSet.title, "Narrator's entry")
    }

    func testItemsCoverEveryNotebookAndEntry() {
        let (notebook, _) = makeNotebook()
        let items = SpotlightIndex.items(notebooks: [notebook, Notebook(title: "Empty")], includeText: true)
        XCTAssertEqual(items.count, 3)
    }

    func testIndexingIsOnUnlessTurnedOff() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "SpotlightIndexTests"))
        defaults.removePersistentDomain(forName: "SpotlightIndexTests")
        XCTAssertTrue(SpotlightIndex.isEnabled(in: defaults))
        defaults.set(false, forKey: SpotlightIndex.enabledKey)
        XCTAssertFalse(SpotlightIndex.isEnabled(in: defaults))
        defaults.removePersistentDomain(forName: "SpotlightIndexTests")
    }
}
