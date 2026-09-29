import XCTest
@testable import GamingJournal

final class SpotlightIndexTests: XCTestCase {
    private func makeJournal() -> (Journal, Entry) {
        let journal = Journal(characterName: "Eira Stormborn", epithet: "Nord", gameTitle: "Skyrim")
        let entry = Entry(body: "The dragon came out of nowhere.", inGameDate: "16th of Last Seed")
        entry.journal = journal
        journal.entries = [entry]
        return (journal, entry)
    }

    func testTargetsRoundTripThroughIdentifiers() {
        let id = UUID()
        XCTAssertEqual(SpotlightIndex.Target(identifier: SpotlightIndex.Target.journal(id).identifier), .journal(id))
        XCTAssertEqual(SpotlightIndex.Target(identifier: SpotlightIndex.Target.entry(id).identifier), .entry(id))
        XCTAssertNil(SpotlightIndex.Target(identifier: "notebook.\(id.uuidString)"))
        XCTAssertNil(SpotlightIndex.Target(identifier: "journal.not-a-uuid"))
    }

    func testJournalItemNamesTheCharacter() {
        let (journal, _) = makeJournal()
        let item = SpotlightIndex.item(for: journal)
        XCTAssertEqual(item.uniqueIdentifier, "journal.\(journal.id.uuidString)")
        XCTAssertEqual(item.attributeSet.title, "The Journal of Eira Stormborn")
        XCTAssertEqual(item.attributeSet.contentDescription, "Nord · Skyrim")
    }

    func testEntryItemIncludesTheWritingWhenOpen() {
        let (_, entry) = makeJournal()
        let item = SpotlightIndex.item(for: entry, includeText: true)
        XCTAssertEqual(item.attributeSet.title, "16th of Last Seed")
        XCTAssertTrue(item.attributeSet.contentDescription?.contains("The dragon came") ?? false)
    }

    func testLockedJournalKeepsTheWritingOutOfSearch() {
        let (_, entry) = makeJournal()
        let item = SpotlightIndex.item(for: entry, includeText: false)
        XCTAssertEqual(item.attributeSet.contentDescription, "The Journal of Eira Stormborn")
        XCTAssertFalse(item.attributeSet.contentDescription?.contains("dragon") ?? true)
    }

    func testItemsCoverEveryJournalAndEntry() {
        let (journal, _) = makeJournal()
        let items = SpotlightIndex.items(journals: [journal, Journal(characterName: "Empty")], includeText: true)
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
